import 'package:flutter_test/flutter_test.dart';
import 'package:xp2p_sdk/xp2p_sdk.dart';
import 'dart:typed_data';

/// XP2P SDK 测试套件
///
/// 注意: 这些测试需要实际的设备和网络环境才能运行
/// 单元测试主要验证 API 接口和类型定义
void main() {
  group('XP2PAppConfig Tests', () {
    test('XP2PAppConfig 构造函数', () {
      final config = XP2PAppConfig(
        appKey: 'test_key',
        appSecret: 'test_secret',
        autoConfigFromDevice: true,
        crossStunTurn: false,
        type: XP2PProtocolType.auto,
      );

      expect(config.appKey, 'test_key');
      expect(config.appSecret, 'test_secret');
      expect(config.autoConfigFromDevice, true);
      expect(config.crossStunTurn, false);
      expect(config.type, XP2PProtocolType.auto);
    });

    test('XP2PAppConfig toMap', () {
      final config = XP2PAppConfig(
        appKey: 'test_key',
        appSecret: 'test_secret',
      );

      final map = config.toMap();

      expect(map['appKey'], 'test_key');
      expect(map['appSecret'], 'test_secret');
      expect(map['autoConfigFromDevice'], true);
      expect(map['crossStunTurn'], false);
      expect(map['type'], 0);
    });

    test('XP2PAppConfig fromMap', () {
      final map = {
        'appKey': 'test_key',
        'appSecret': 'test_secret',
        'autoConfigFromDevice': false,
        'crossStunTurn': true,
        'type': 2,
      };

      final config = XP2PAppConfig.fromMap(map);

      expect(config.appKey, 'test_key');
      expect(config.appSecret, 'test_secret');
      expect(config.autoConfigFromDevice, false);
      expect(config.crossStunTurn, true);
      expect(config.type, XP2PProtocolType.tcp);
    });

    test('XP2PAppConfig copyWith', () {
      final config = XP2PAppConfig(
        appKey: 'old_key',
        appSecret: 'old_secret',
      );

      final newConfig = config.copyWith(
        appKey: 'new_key',
        crossStunTurn: true,
      );

      expect(newConfig.appKey, 'new_key');
      expect(newConfig.appSecret, 'old_secret');
      expect(newConfig.crossStunTurn, true);
    });

    test('XP2PAppConfig equality', () {
      final config1 = XP2PAppConfig(
        appKey: 'test_key',
        appSecret: 'test_secret',
      );

      final config2 = XP2PAppConfig(
        appKey: 'test_key',
        appSecret: 'test_secret',
      );

      expect(config1, equals(config2));
      expect(config1.hashCode, equals(config2.hashCode));
    });
  });

  group('XP2PProtocolType Tests', () {
    test('协议类型值正确', () {
      expect(XP2PProtocolType.auto.value, 0);
      expect(XP2PProtocolType.udp.value, 1);
      expect(XP2PProtocolType.tcp.value, 2);
    });
  });

  group('XP2PType Tests', () {
    test('事件类型值正确', () {
      expect(XP2PType.close.value, 1000);
      expect(XP2PType.log.value, 1001);
      expect(XP2PType.cmd.value, 1002);
      expect(XP2PType.disconnect.value, 1003);
      expect(XP2PType.detectReady.value, 1004);
      expect(XP2PType.detectError.value, 1005);
    });

    test('从值创建事件类型', () {
      expect(XP2PType.fromValue(1000), XP2PType.close);
      expect(XP2PType.fromValue(1004), XP2PType.detectReady);
      expect(XP2PType.fromValue(9999), XP2PType.log); // 未知值返回默认
    });
  });

  group('XP2PErrorCode Tests', () {
    test('错误码值正确', () {
      expect(XP2PErrorCode.none.code, 0);
      expect(XP2PErrorCode.initParam.code, -1000);
      expect(XP2PErrorCode.timeout.code, -1005);
    });

    test('从错误码创建枚举', () {
      expect(XP2PErrorCode.fromCode(0), XP2PErrorCode.none);
      expect(XP2PErrorCode.fromCode(-1000), XP2PErrorCode.initParam);
      expect(XP2PErrorCode.fromCode(-9999), XP2PErrorCode.none); // 未知值
    });

    test('错误描述格式正确', () {
      final error = XP2PErrorCode.timeout;
      expect(error.description, contains('-1005'));
      expect(error.description, contains('请求超时'));
    });
  });

  group('AppConfig Tests', () {
    test('AppConfig 构造和 toMap', () {
      final config = AppConfig(
        server: 'stun.server.com',
        ip: '192.168.1.1',
        port: 8080,
        type: XP2PProtocolType.tcp,
        cross: true,
      );

      expect(config.server, 'stun.server.com');
      expect(config.ip, '192.168.1.1');
      expect(config.port, 8080);
      expect(config.type, XP2PProtocolType.tcp);
      expect(config.cross, true);

      final map = config.toMap();
      expect(map['server'], 'stun.server.com');
      expect(map['port'], 8080);
      expect(map['type'], 2);
      expect(map['cross'], true);
    });
  });

  group('XP2PCallback Tests', () {
    test('回调接口可以被实现', () {
      final callback = TestCallback();

      expect(callback, isA<XP2PCallback>());
    });
  });

  group('XP2P API Tests', () {
    test('获取版本号', () {
      final version = XP2P.getVersion();
      expect(version, isNotEmpty);
      expect(version, '2.4.1');
    });

    // 注意: 以下测试需要实际的设备和网络环境
    // 在 CI/CD 环境中应该跳过这些测试

    test('设置回调不抛出异常', () {
      expect(() {
        XP2P.setCallback(TestCallback());
      }, returnsNormally);
    });

    test('设置日志开关不抛出异常', () {
      expect(() {
        XP2P.setLogEnable(console: true, file: false);
      }, returnsNormally);
    });
  });
}

/// 测试用回调实现
class TestCallback extends XP2PCallback {
  @override
  void onFail(String id, int errorCode) {
    // 测试实现
  }

  @override
  void onCommandRequest(String id, String msg) {
    // 测试实现
  }

  @override
  void onXp2pEventNotify(String id, String msg, int event) {
    // 测试实现
  }

  @override
  void onAvDataRecv(String id, Uint8List data, int len) {
    // 测试实现
  }

  @override
  void onAvDataClose(String id, String msg, int errorCode) {
    // 测试实现
  }

  @override
  String onDeviceMsgArrived(String id, Uint8List data, int len) {
    return 'test_response';
  }
}
