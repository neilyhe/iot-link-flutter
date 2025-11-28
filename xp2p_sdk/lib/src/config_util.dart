import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:xp2p_sdk/src/log/logger.dart';

import 'http_utils.dart';
import 'xp2p_app_config.dart';
import 'xp2p_types.dart';
import 'log_config.dart';

typedef OnResultListener<T> = void Function(T result);

/// 配置工具类
///
/// 用于从云端获取设备配置和用户配置
class ConfigUtil {
  static final ConfigUtil _instance = ConfigUtil._internal();

  factory ConfigUtil() => _instance;

  ConfigUtil._internal();

  static ConfigUtil get instance => _instance;

  static const String _signature = 'Signature';

  /// 获取用户配置
  Future<void> getUserConfig(
    XP2PAppConfig appConfig,
    String userId,
    OnResultListener<LogConfig> listener,
  ) async {
    final config = LogConfig();

    if (appConfig.appSecret.isEmpty) {
      listener(config);
      return;
    }

    const paramUrl = 'https://iot.cloud.tencent.com/api/exploreropen/appapi';
    final requestId = _generateUuid();

    final params = <String, dynamic>{
      'Action': 'AppDescribeLogLevel',
      'Timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'Nonce': DateTime.now().millisecondsSinceEpoch,
      'AppKey': appConfig.appKey,
      'UserId': userId,
      'RequestId': requestId,
    };

    final stringToSign = _getStringToSign(params);
    final signature = _sign(stringToSign, appConfig.appSecret, '');
    params['Signature'] = signature;

    final jsonData = json.encode(params);
    final data = Uint8List.fromList(utf8.encode(jsonData));

    await HttpUtils.instance.basePost(
      paramUrl,
      data,
      requestId,
      (requestId, responseCode, msg, responseContent) {
        print('getUserConfig Response Code: $responseCode, Content: $responseContent');

        if (responseCode == 200) {
          try {
            final jsonResponse = json.decode(responseContent) as Map<String, dynamic>;
            final code = jsonResponse['code'] as int;
            final responseMsg = jsonResponse['msg'] as String;
            final data = jsonResponse['data'] as Map<String, dynamic>;

            if (code == 0) {
              final logConfigData = data['Data'] as Map<String, dynamic>;
              config.p2pLogEnabled = logConfigData['P2PLogEnabled'] as bool;
              config.opsLogEnabled = logConfigData['OpsLogEnabled'] as bool;
              final p2pLogLevel = logConfigData['P2PLogLevel'] as String?;
              if (p2pLogLevel != null && p2pLogLevel.isNotEmpty) {
                config.p2pLogLevel = p2pLogLevel;
              }
            } else {
              print('getUserConfig parse response code: $code, msg: $responseMsg');
            }
          } catch (e) {
            print('getUserConfig parse response error: $e');
          }
        }

        listener(config);
      },
    );
  }

  /// 获取设备配置
  Future<void> getDeviceConfig(
    String productId,
    String deviceName,
    XP2PAppConfig appConfig,
    OnResultListener<AppConfig> listener,
  ) async {
    final config = AppConfig(
      port: 20002,
      type: appConfig.type,
    );

    if (appConfig.appSecret.isEmpty) {
      listener(config);
      return;
    }

    const paramUrl = 'https://iot.cloud.tencent.com/api/exploreropen/appapi';
    final requestId = _generateUuid();

    final params = <String, dynamic>{
      'Action': 'AppDescribeConfigureDeviceP2P',
      'Timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'Nonce': DateTime.now().millisecondsSinceEpoch,
      'AppKey': appConfig.appKey,
      'ProductId': productId,
      'DeviceName': deviceName,
      'RequestId': requestId,
    };

    final content = _getStringToSign(params);
    final signature = _sign(content, appConfig.appSecret, '');
    params['Signature'] = signature;

    final jsonData = json.encode(params);
    final data = Uint8List.fromList(utf8.encode(jsonData));

    await HttpUtils.instance.basePost(
      paramUrl,
      data,
      requestId,
      (requestId, responseCode, msg, responseContent) {
        print('getDeviceConfig Response Code: $responseCode, Content: $responseContent');

        if (responseCode == 200) {
          try {
            final jsonResponse = json.decode(responseContent) as Map<String, dynamic>;
            final code = jsonResponse['code'] as int;
            final responseMsg = jsonResponse['msg'] as String;
            final data = jsonResponse['data'] as Map<String, dynamic>;

            if (code == 0) {
              final dataConfig = data['Config'] as Map<String, dynamic>;
              final enableCrossStunTurn = dataConfig['EnableCrossStunTurn'] as int;
              final stunPort = dataConfig['StunPort'] as int;
              final stunHost = dataConfig['StunHost'] as String?;
              final stunIP = dataConfig['StunIP'] as String?;
              final protocol = dataConfig['Protocol'] as String?;

              config.cross = enableCrossStunTurn == 1;
              if (stunPort != 0) {
                config.port = stunPort;
              }
              if (stunHost != null && stunHost.isNotEmpty) {
                config.server = stunHost;
              }
              if (stunIP != null && stunIP.isNotEmpty) {
                config.ip = stunIP;
              }
              if (protocol == 'TCP') {
                config.type = XP2PProtocolType.tcp;
              } else {
                config.type = XP2PProtocolType.auto;
              }
            } else {
              Logger.e('getDeviceConfig parse response code: $code, msg: $responseMsg',"XP2P");
            }
          } catch (e) {
            Logger.e('getDeviceConfig parse response error: $e',"XP2P");
          }
        }

        listener(config);
      },
    );
  }

  String _getStringToSign(Map<String, dynamic> params) {
    final keys = params.keys.where((key) => key != _signature).toList()..sort();

    final buffer = StringBuffer();
    for (final key in keys) {
      final value = params[key];
      if (value != null && value.toString().isNotEmpty) {
        buffer.write(key.replaceAll('_', '.'));
        buffer.write('=');
        buffer.write(value.toString());
        buffer.write('&');
      }
    }

    final result = buffer.toString();
    return result.isNotEmpty ? result.substring(0, result.length - 1) : result;
  }
  
  String _sign(String s, String secretKey, String method) {
    try {
      final Hmac hmac;
      if (method == 'SHA-256') {
        hmac = Hmac(sha256, utf8.encode(secretKey));
      } else {
        hmac = Hmac(sha1, utf8.encode(secretKey));
      }

      final digest = hmac.convert(utf8.encode(s));
      return base64.encode(digest.bytes);
    } catch (e) {
      throw Exception('Error while signing string: $e');
    }
  }

  String _generateUuid() {
    final random = DateTime.now().millisecondsSinceEpoch;
    return '$random-${random.hashCode}';
  }

  bool checkVersionAfterPercent(String xp2pInfo) {
    try {
      final percentIndex = xp2pInfo.indexOf('%');
      if (percentIndex == -1) {
        Logger.e('The % symbol is not checked.',"XP2P");
        return false;
      }

      final versionString = xp2pInfo.substring(percentIndex + 1);
      return _isVersionLessThanTarget(versionString, '2.4.49');
    } catch (e) {
      Logger.e('checkVersionAfterPercent error: $e',"XP2P");
    }
    return true;
  }

  bool _isVersionLessThanTarget(String currentVersion, String targetVersion) {
    final currentItems = currentVersion.split('.');
    final targetItems = targetVersion.split('.');

    final minLength = currentItems.length < targetItems.length
        ? currentItems.length
        : targetItems.length;

    for (int i = 0; i < minLength; i++) {
      final current = int.tryParse(currentItems[i]) ?? 0;
      final target = int.tryParse(targetItems[i]) ?? 0;

      if (current < target) {
        return true;
      } else if (current > target) {
        return false;
      }
    }

    return false;
  }
}
