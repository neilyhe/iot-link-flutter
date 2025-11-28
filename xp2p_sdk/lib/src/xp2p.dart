import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:typed_data';
import 'dart:isolate';
import 'package:ffi/ffi.dart';

import 'log/logger.dart';
import 'xp2p_callback.dart';
import 'xp2p_app_config.dart';
import 'xp2p_types.dart';
import 'xp2p_ffi.dart';
import 'config_util.dart';

/// XP2P SDK 主类 提供 P2P 视频流传输的核心功能
class XP2P {
  static const String version = '2.4.1';

  static XP2PCallback? _callback;

  static bool _isRunSendService = false;

  static ffi.Pointer<ffi.NativeFunction<AvRecvHandleNative>>? _avRecvCallback;
  static ffi.Pointer<ffi.NativeFunction<MsgHandleNative>>? _msgCallback;
  static ffi.Pointer<ffi.NativeFunction<DeviceDataRecvHandleNative>>?
      _deviceDataCallback;

  /// 用于跨线程通信的端口
  static ReceivePort? _requestReceivePort; // 接收来自 C++ 的请求
  static ReceivePort? _responseReceivePort; // 预留给响应端口（当前未使用）
  static SendPort? _sendPort;

  /// 字符串缓存,避免内存泄漏
  static final List<ffi.Pointer<Utf8>> _stringCache = [];
  static final ffi.Pointer<Utf8> _emptyStringPtr = ''.toNativeUtf8();

  /// 设置回调接口
  static void setCallback(XP2PCallback callback) {
    _callback = callback;
    _requestReceivePort?.close();
    _requestReceivePort = ReceivePort();
    _responseReceivePort?.close();
    _responseReceivePort = ReceivePort();
    _requestReceivePort!.listen((dynamic message) {
      try {
        if (message is List && message.isNotEmpty) {
          _handleArrayMessage(message);
        } else {
          Logger.e('Unexpected message type: ${message.runtimeType}', 'XP2P');
        }
      } catch (e, stackTrace) {
        Logger.e('Error handling native callback: $e Stack trace: $stackTrace',
            'XP2P');
      }
    });

    // ==================== 初始化 Dart API DL (Android 必需) ====================
    // 在 Android 上，必须先初始化 Dart API DL，C++ 端才能调用 Dart_PostCObject_DL
    try {
      final initData = ffi.NativeApi.initializeApiDLData;
      final result = XP2PFFI.initDartApi(initData);
      if (result != 0) {
        Logger.e('   Callbacks from native might not work!', 'XP2P');
      }
    } catch (e) {
      Logger.e('⚠️ Warning: Failed to initialize Dart API DL: $e', 'XP2P');
    }

    XP2PFFI.setDartPort(
      _requestReceivePort!.sendPort.nativePort,
      _responseReceivePort!.sendPort.nativePort,
    );
  }

  static void _handleArrayMessage(List message) {
    final type = message[0] as String;

    switch (type) {
      case 'avRecv':
        if (message.length >= 3) {
          final id = message[1] as String;
          final data = message[2] as Uint8List;
          _callback?.onAvDataRecv(id, data, data.length);
        }
        break;

      case 'deviceData':
        if (message.length >= 3) {
          final id = message[1] as String;
          final data = message[2] as Uint8List;
          _callback?.onDeviceMsgArrived(id, data, data.length);
        }
        break;

      case 'deviceDataRequest':
        if (message.length >= 4) {
          final requestId = message[1] as String;
          final id = message[2] as String;
          final data = message[3] as Uint8List;
          final response =
              _callback?.onDeviceMsgArrived(id, data, data.length) ?? '';
          final requestIdPtr = requestId.toNativeUtf8();
          final responsePtr = response.toNativeUtf8();
          try {
            XP2PFFI.handleDeviceDataResponse(requestIdPtr, responsePtr);
          } finally {
            malloc.free(requestIdPtr);
            malloc.free(responsePtr);
          }
        }
        break;

      case 'msg':
        if (message.length >= 4) {
          final id = message[1] as String;
          final msgType = message[2] as int;
          final msg = message[3] as String;
          _handleNativeMessage(id, msgType, msg);
        }
        break;

      default:
        Logger.w('Unknown message type: $type', 'XP2P');
    }
  }

  static void _handleNativeMessage(String id, int type, String msg) {
    final xp2pType = XP2PType.fromValue(type);

    switch (xp2pType) {
      case XP2PType.close:
        _callback?.onAvDataClose(id, msg, 0);
        break;

      case XP2PType.log:
        Logger.d('[$id] $msg', 'XP2P');
        break;

      case XP2PType.cmd:
        _callback?.onCommandRequest(id, msg);
        break;

      case XP2PType.disconnect:
      case XP2PType.detectReady:
      case XP2PType.detectError:
      case XP2PType.streamEnd:
      case XP2PType.cmdNoReturn:
      case XP2PType.downloadEnd:
        _callback?.onXp2pEventNotify(id, msg, xp2pType.value);
        break;

      case XP2PType.deviceMsgArrived:
      case XP2PType.streamRefresh:
        break;

      case XP2PType.saveFileOn:
        throw UnimplementedError();
      case XP2PType.saveFileUrl:
        throw UnimplementedError();
    }
  }

  /// 清理字符串缓存
  static void _cleanupStringCache() {
    for (final ptr in _stringCache) {
      if (ptr != _emptyStringPtr) {
        malloc.free(ptr);
      }
    }
    _stringCache.clear();
  }

  /// 启动 XP2P 服务
  static Future<int> startService({
    required String productId,
    required String deviceName,
    required String xp2pInfo,
    required XP2PAppConfig config,
  }) async {
    final id = '$productId/$deviceName';

    if (ConfigUtil.instance.checkVersionAfterPercent(xp2pInfo)) {
      config = config.copyWith(autoConfigFromDevice: false);
    }

    if (config.autoConfigFromDevice) {
      return await _startServiceWithDeviceConfig(
        id, productId, deviceName, xp2pInfo, config,
      );
    } else {
      return await _startServiceWithDefaultConfig(
        id, productId, deviceName, xp2pInfo, config,
      );
    }
  }

  /// 使用从云端获取的设备配置启动服务
  static Future<int> _startServiceWithDeviceConfig(
    String id,
    String productId,
    String deviceName,
    String xp2pInfo,
    XP2PAppConfig xp2pAppConfig,
  ) async {
    final completer = Completer<int>();
    await ConfigUtil.instance.getDeviceConfig(
      productId,
      deviceName,
      xp2pAppConfig,
      (appConfig) async {
        try {
          XP2PFFI.setCrossStunTurn(appConfig.cross);
          final result = await _callNativeStartService(
            id, productId, deviceName, appConfig,
          );
          Logger.d('startServiceNative result code: $result',"XP2P");
          if (result == 0) {
            final xp2pInfoResult = setDeviceXp2pInfo(id, xp2pInfo);
            Logger.d('setDeviceXp2pInfo result code: $xp2pInfoResult',"XP2P");
          }

          completer.complete(result);
        } catch (e) {
          Logger.e('Error in _startServiceWithDeviceConfig: $e',"XP2P");
          completer.completeError(e);
        }
      },
    );

    return completer.future;
  }

  static Future<int> _startServiceWithDefaultConfig(
    String id,
    String productId,
    String deviceName,
    String xp2pInfo,
    XP2PAppConfig xp2pAppConfig,
  ) async {
    final appConfig = AppConfig(
      server: '',
      ip: '',
      port: 20002,
      type: xp2pAppConfig.type,
    );

    if (xp2pAppConfig.crossStunTurn) {
      XP2PFFI.setCrossStunTurn(true);
    }

    final result = await _callNativeStartService(
      id, productId, deviceName, appConfig,
    );
    Logger.d('startServiceNative result code: $result',"XP2P");

    // 设置 XP2P 信息
    if (result == 0) {
      final xp2pInfoResult = setDeviceXp2pInfo(id, xp2pInfo);
      Logger.d('setDeviceXp2pInfo result code: $xp2pInfoResult',"XP2P");
    }

    return result;
  }

  static Future<int> _callNativeStartService(
    String id,
    String productId,
    String deviceName,
    AppConfig appConfig,
  ) async {
    final idPtr = id.toNativeUtf8();
    final productIdPtr = productId.toNativeUtf8();
    final deviceNamePtr = deviceName.toNativeUtf8();
    final serverPtr = appConfig.server.toNativeUtf8();
    final ipPtr = appConfig.ip.toNativeUtf8();

    try {
      final nativeConfig = calloc<AppConfigNative>();
      nativeConfig.ref.server = serverPtr;
      nativeConfig.ref.ip = ipPtr;
      nativeConfig.ref.port = appConfig.port;
      nativeConfig.ref.type = appConfig.type.value;
      nativeConfig.ref.cross = appConfig.cross;

      final result = XP2PFFI.startService(
        idPtr,
        productIdPtr,
        deviceNamePtr,
        nativeConfig.ref,
      );

      calloc.free(nativeConfig);
      return result;
    } finally {
      malloc.free(idPtr);
      malloc.free(productIdPtr);
      malloc.free(deviceNamePtr);
      malloc.free(serverPtr);
      malloc.free(ipPtr);
    }
  }

  /// 启动局域网服务
  static Future<int> startLanService({
    required String productId,
    required String deviceName,
    required String host,
    required String port,
  }) async {
    final id = '$productId/$deviceName';
    final idPtr = id.toNativeUtf8();
    final productIdPtr = productId.toNativeUtf8();
    final deviceNamePtr = deviceName.toNativeUtf8();
    final hostPtr = host.toNativeUtf8();
    final portPtr = port.toNativeUtf8();

    try {
      return XP2PFFI.startLanService(
        idPtr,
        productIdPtr,
        deviceNamePtr,
        hostPtr,
        portPtr,
      );
    } finally {
      malloc.free(idPtr);
      malloc.free(productIdPtr);
      malloc.free(deviceNamePtr);
      malloc.free(hostPtr);
      malloc.free(portPtr);
    }
  }

  /// 设置设备 XP2P 信息
  static int setDeviceXp2pInfo(String id, String xp2pInfo) {
    final idPtr = id.toNativeUtf8();
    final infoPtr = xp2pInfo.toNativeUtf8();

    try {
      return XP2PFFI.setDeviceXp2pInfo(idPtr, infoPtr);
    } finally {
      malloc.free(idPtr);
      malloc.free(infoPtr);
    }
  }

  /// 停止 XP2P 服务
  static void stopService(String id) {
    final idPtr = id.toNativeUtf8();
    try {
      XP2PFFI.stopService(idPtr);
      // 清理字符串缓存
      _cleanupStringCache();
    } finally {
      malloc.free(idPtr);
    }
  }

  /// 清理所有资源
  static void dispose() {
    _cleanupStringCache();
    _requestReceivePort?.close();
    _requestReceivePort = null;
    _responseReceivePort?.close();
    _responseReceivePort = null;
    _sendPort = null;
    _callback = null;
  }

  /// 获取本地代理 HTTP-FLV URL
  static String delegateHttpFlv(String id) {
    final idPtr = id.toNativeUtf8();
    try {
      final resultPtr = XP2PFFI.delegateHttpFlv(idPtr);
      return resultPtr.toDartString();
    } finally {
      malloc.free(idPtr);
    }
  }

  /// 获取局域网 URL
  static String getLanUrl(String id) {
    final idPtr = id.toNativeUtf8();
    try {
      final resultPtr = XP2PFFI.getLanUrl(idPtr);
      return resultPtr.toDartString();
    } finally {
      malloc.free(idPtr);
    }
  }

  /// 获取局域网代理端口
  static int getLanProxyPort(String id) {
    final idPtr = id.toNativeUtf8();
    try {
      return XP2PFFI.getLanProxyPort(idPtr);
    } finally {
      malloc.free(idPtr);
    }
  }

  /// 发送同步信令请求
  ///
  /// 向设备发送信令并等待响应,阻塞调用
  ///
  /// [id] 设备标识符
  /// [command] 信令数据,可以是任意格式的二进制数据
  /// [timeoutUs] 超时时间(微秒),0 表示使用默认超时(约 7500ms)
  ///
  /// 返回值: 设备响应的数据,如果失败返回 null
  static Future<Uint8List?> postCommandRequestSync({
    required String id,
    required Uint8List command,
    int timeoutUs = 0,
  }) async {
    final idPtr = id.toNativeUtf8();
    final commandPtr = malloc<ffi.Uint8>(command.length);
    final recvBufPtr = malloc<ffi.Pointer<ffi.Uint8>>();
    final recvLenPtr = malloc<ffi.Size>();

    try {
      for (int i = 0; i < command.length; i++) {
        commandPtr[i] = command[i];
      }

      final result = XP2PFFI.postCommandRequestSync(
        idPtr, commandPtr, command.length, recvBufPtr, recvLenPtr, timeoutUs,
      );

      if (result != 0) {
        return null;
      }

      final recvBuf = recvBufPtr.value;
      final recvLen = recvLenPtr.value;

      if (recvBuf == ffi.nullptr || recvLen == 0) {
        return null;
      }
      return Uint8List.fromList(recvBuf.asTypedList(recvLen));
    } finally {
      malloc.free(idPtr);
      malloc.free(commandPtr);
      malloc.free(recvBufPtr);
      malloc.free(recvLenPtr);
    }
  }

  /// 开始接收音视频流
  static void startAvRecvService({
    required String id,
    required String cmd,
    bool crypto = true,
  }) {
    final idPtr = id.toNativeUtf8();
    final cmdPtr = cmd.toNativeUtf8();

    try {
      XP2PFFI.startAvRecvService(idPtr, cmdPtr, crypto);
    } finally {
      malloc.free(idPtr);
      malloc.free(cmdPtr);
    }
  }

  /// 停止接收音视频流
  static int stopAvRecvService(String id) {
    final idPtr = id.toNativeUtf8();
    try {
      return XP2PFFI.stopAvRecvService(idPtr, ffi.nullptr);
    } finally {
      malloc.free(idPtr);
    }
  }

  /// 启动数据发送服务
  static void runSendService({
    required String id,
    required String cmd,
    bool crypto = true,
  }) {
    final idPtr = id.toNativeUtf8();
    final cmdPtr = cmd.toNativeUtf8();

    try {
      _isRunSendService = true;
      XP2PFFI.runSendService(idPtr, cmdPtr, crypto);
    } finally {
      malloc.free(idPtr);
      malloc.free(cmdPtr);
    }
  }

  /// 停止数据发送服务
  static int stopSendService(String id) {
    final idPtr = id.toNativeUtf8();
    try {
      _isRunSendService = false;
      return XP2PFFI.stopSendService(idPtr, ffi.nullptr);
    } finally {
      malloc.free(idPtr);
    }
  }

  /// 发送数据
  static int dataSend({
    required String id,
    required Uint8List data,
  }) {
    if (!_isRunSendService) {
      return 9000; // 服务未运行
    }

    final idPtr = id.toNativeUtf8();
    final dataPtr = malloc<ffi.Uint8>(data.length);

    try {
      // 复制数据
      for (int i = 0; i < data.length; i++) {
        dataPtr[i] = data[i];
      }

      return XP2PFFI.dataSend(idPtr, dataPtr, data.length);
    } finally {
      malloc.free(idPtr);
      malloc.free(dataPtr);
    }
  }

  /// 获取流连接模式
  static int getStreamLinkMode(String id) {
    final idPtr = id.toNativeUtf8();
    try {
      return XP2PFFI.getStreamLinkMode(idPtr);
    } finally {
      malloc.free(idPtr);
    }
  }

  /// 获取发送缓冲区大小
  static int getStreamBufSize(String id) {
    if (!_isRunSendService) {
      return 9000;
    }

    final idPtr = id.toNativeUtf8();
    try {
      return XP2PFFI.getStreamBufSize(idPtr);
    } finally {
      malloc.free(idPtr);
    }
  }

  /// 设置日志开关
  ///
  /// [console] 是否输出日志到控制台
  /// [file] 是否输出日志到文件
  static void setLogEnable({
    required bool console,
    required bool file,
  }) {
    XP2PFFI.setLogEnable(console, file);
  }

  /// 设置 STUN 服务器
  static void setStunServer({
    required String server,
    required int port,
  }) {
    final serverPtr = server.toNativeUtf8();
    try {
      XP2PFFI.setStunServerToXp2p(serverPtr, port);
    } finally {
      malloc.free(serverPtr);
    }
  }

  /// 设置跨域 STUN/TURN 开关
  ///
  /// [enable] 是否启用
  static void setCrossStunTurn(bool enable) {
    XP2PFFI.setCrossStunTurn(enable);
  }

  /// 设置云 API 凭证(已废弃)
  @Deprecated('Use setDeviceXp2pInfo instead')
  static int setQcloudApiCred({
    required String apiId,
    required String apiKey,
  }) {
    final idPtr = apiId.toNativeUtf8();
    final keyPtr = apiKey.toNativeUtf8();

    try {
      return XP2PFFI.setQcloudApiCred(idPtr, keyPtr);
    } finally {
      malloc.free(idPtr);
      malloc.free(keyPtr);
    }
  }

  /// 开始录制播放流(调试用)
  static void recordStream(String id) {
    final idPtr = id.toNativeUtf8();
    try {
      XP2PFFI.startRecordPlayerStream(idPtr);
    } finally {
      malloc.free(idPtr);
    }
  }

  /// 获取 SDK 版本号
  static String getVersion() {
    return version;
  }
}
