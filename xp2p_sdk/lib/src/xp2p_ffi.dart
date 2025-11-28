import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';

// ==================== C 函数类型定义 begin ====================

/// 音视频数据接收回调函数类型
/// typedef void (*av_recv_handle_t)(const char *id, uint8_t *recv_buf, size_t recv_len);
typedef AvRecvHandleNative = ffi.Void Function(
    ffi.Pointer<Utf8> id,
    ffi.Pointer<ffi.Uint8> recvBuf,
    ffi.Size recvLen,
);

typedef AvRecvHandleDart = void Function(
    ffi.Pointer<Utf8> id,
    ffi.Pointer<ffi.Uint8> recvBuf,
    int recvLen,
);

/// 消息处理回调函数类型
/// typedef const char *(*msg_handle_t)(const char *id, XP2PType type, const char *msg);
typedef MsgHandleNative = ffi.Pointer<Utf8> Function(
    ffi.Pointer<Utf8> id,
    ffi.Int32 type,
    ffi.Pointer<Utf8> msg,
);

typedef MsgHandleDart = ffi.Pointer<Utf8> Function(
    ffi.Pointer<Utf8> id,
    int type,
    ffi.Pointer<Utf8> msg,
);

/// 设备数据接收回调函数类型
/// typedef char *(*device_data_recv_handle_t)(const char *id, uint8_t *recv_buf, size_t recv_len);
typedef DeviceDataRecvHandleNative = ffi.Pointer<Utf8> Function(
    ffi.Pointer<Utf8> id,
    ffi.Pointer<ffi.Uint8> recvBuf,
    ffi.Size recvLen,
);

typedef DeviceDataRecvHandleDart = ffi.Pointer<Utf8> Function(
    ffi.Pointer<Utf8> id,
    ffi.Pointer<ffi.Uint8> recvBuf,
    int recvLen,
);

typedef SetDartPortNative = ffi.Void Function(ffi.Int64 requestPort, ffi.Int64 responsePort);
typedef SetDartPortDart = void Function(int requestPort, int responsePort);

typedef HandleDeviceDataResponseNative = ffi.Void Function(
    ffi.Pointer<Utf8> requestId,
    ffi.Pointer<Utf8> response,
);
typedef HandleDeviceDataResponseDart = void Function(
    ffi.Pointer<Utf8> requestId,
    ffi.Pointer<Utf8> response,
);

// ==================== C 函数类型定义 end ====================

// ==================== C 结构体定义 begin ====================

/// AppConfig 结构体
final class AppConfigNative extends ffi.Struct {
  external ffi.Pointer<Utf8> server;
  external ffi.Pointer<Utf8> ip;
  @ffi.Uint64()
  external int port;
  @ffi.Int32()
  external int type; // XP2PProtocolType
  @ffi.Bool()
  external bool cross;
}

// ==================== C 结构体定义 end ====================

class XP2PFFI {

  static ffi.DynamicLibrary? _mainLib;

  /// 获取动态库实例
  static ffi.DynamicLibrary get mainLib {
    if (_mainLib != null) return _mainLib!;

    if (Platform.isAndroid) {
      _mainLib = ffi.DynamicLibrary.open('libiot_video_demo.so');
    } else if (Platform.isIOS) {
      _mainLib = ffi.DynamicLibrary.open('Frameworks/TencentENET.framework/TencentENET');
    } else {
      throw UnsupportedError('Unsupported platform');
    }

    return _mainLib!;
  }

  static ffi.DynamicLibrary? _bridgeLib;

  static ffi.DynamicLibrary get bridgeLib {
    if (_bridgeLib != null) return _bridgeLib!;

    if (Platform.isAndroid) {
      _bridgeLib = ffi.DynamicLibrary.open('libxp2p_bridge.so');
    } else if (Platform.isIOS) {
      _bridgeLib = ffi.DynamicLibrary.process();
    } else {
      throw UnsupportedError('Unsupported platform');
    }

    return _bridgeLib!;
  }

  // ==================== 桥接层 C 函数绑定 ====================

  /// 初始化 Dart API DL (Android 必需)
  static late final int Function(ffi.Pointer<ffi.Void>) initDartApi = bridgeLib
      .lookup<ffi.NativeFunction<ffi.Int64 Function(ffi.Pointer<ffi.Void>)>>('xp2p_init_dart_api')
      .asFunction();

  static late final SetDartPortDart setDartPort = bridgeLib
      .lookup<ffi.NativeFunction<SetDartPortNative>>('xp2p_set_dart_port')
      .asFunction();

  static late final void Function() clearDartPort = bridgeLib
      .lookup<ffi.NativeFunction<ffi.Void Function()>>('xp2p_clear_dart_port')
      .asFunction();

  static late final HandleDeviceDataResponseDart handleDeviceDataResponse = bridgeLib
      .lookup<ffi.NativeFunction<HandleDeviceDataResponseNative>>('xp2p_handle_device_data_response')
      .asFunction();

  // static late final void Function() nativeAvRecvCallback =

  // ==================== main 库 C 函数绑定 ====================

  /// setUserCallbackToXp2p
  /// void setUserCallbackToXp2p(av_recv_handle_t recv_handle, msg_handle_t msg_handle, device_data_recv_handle_t device_data_handle);
  static late final setUserCallbackToXp2p = mainLib.lookupFunction<
      ffi.Void Function(
        ffi.Pointer<ffi.NativeFunction<AvRecvHandleNative>>,
        ffi.Pointer<ffi.NativeFunction<MsgHandleNative>>,
        ffi.Pointer<ffi.NativeFunction<DeviceDataRecvHandleNative>>,
      ),
      void Function(
        ffi.Pointer<ffi.NativeFunction<AvRecvHandleNative>>,
        ffi.Pointer<ffi.NativeFunction<MsgHandleNative>>,
        ffi.Pointer<ffi.NativeFunction<DeviceDataRecvHandleNative>>,
      )>('setUserCallbackToXp2p');

  static late final startService = mainLib.lookupFunction<
      ffi.Int32 Function(
        ffi.Pointer<Utf8>,
        ffi.Pointer<Utf8>,
        ffi.Pointer<Utf8>,
        AppConfigNative,
      ),
      int Function(
        ffi.Pointer<Utf8>,
        ffi.Pointer<Utf8>,
        ffi.Pointer<Utf8>,
        AppConfigNative,
      )>('startService');

  static late final startLanService = mainLib.lookupFunction<
      ffi.Int32 Function(
        ffi.Pointer<Utf8>,
        ffi.Pointer<Utf8>,
        ffi.Pointer<Utf8>,
        ffi.Pointer<Utf8>,
        ffi.Pointer<Utf8>,
      ),
      int Function(
        ffi.Pointer<Utf8>,
        ffi.Pointer<Utf8>,
        ffi.Pointer<Utf8>,
        ffi.Pointer<Utf8>,
        ffi.Pointer<Utf8>,
      )>('startLanService');

  static late final setDeviceXp2pInfo = mainLib.lookupFunction<
      ffi.Int32 Function(ffi.Pointer<Utf8>, ffi.Pointer<Utf8>),
      int Function(
          ffi.Pointer<Utf8>, ffi.Pointer<Utf8>)>('setDeviceXp2pInfo');

  static late final stopService = mainLib.lookupFunction<
      ffi.Void Function(ffi.Pointer<Utf8>),
      void Function(ffi.Pointer<Utf8>)>('stopService');

  static late final delegateHttpFlv = mainLib.lookupFunction<
      ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>),
      ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>)>('delegateHttpFlv');

  static late final getLanUrl = mainLib.lookupFunction<
      ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>),
      ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>)>('getLanUrl');

  static late final getLanProxyPort = mainLib.lookupFunction<
      ffi.Int32 Function(ffi.Pointer<Utf8>),
      int Function(ffi.Pointer<Utf8>)>('getLanProxyPort');

  static late final getStreamLinkMode = mainLib.lookupFunction<
      ffi.Int32 Function(ffi.Pointer<Utf8>),
      int Function(ffi.Pointer<Utf8>)>('getStreamLinkMode');

  static late final getStreamBufSize = mainLib.lookupFunction<
      ffi.Size Function(ffi.Pointer<Utf8>),
      int Function(ffi.Pointer<Utf8>)>('getStreamBufSize');

  static late final postCommandRequestSync = mainLib.lookupFunction<
      ffi.Int32 Function(
        ffi.Pointer<Utf8>,
        ffi.Pointer<ffi.Uint8>,
        ffi.Size,
        ffi.Pointer<ffi.Pointer<ffi.Uint8>>,
        ffi.Pointer<ffi.Size>,
        ffi.Uint64,
      ),
      int Function(
        ffi.Pointer<Utf8>,
        ffi.Pointer<ffi.Uint8>,
        int,
        ffi.Pointer<ffi.Pointer<ffi.Uint8>>,
        ffi.Pointer<ffi.Size>,
        int,
      )>('postCommandRequestSync');

  static late final startAvRecvService = mainLib.lookupFunction<
      ffi.Pointer<ffi.Void> Function(
          ffi.Pointer<Utf8>, ffi.Pointer<Utf8>, ffi.Bool),
      ffi.Pointer<ffi.Void> Function(ffi.Pointer<Utf8>, ffi.Pointer<Utf8>,
          bool)>('startAvRecvService');

  static late final stopAvRecvService = mainLib.lookupFunction<
      ffi.Int32 Function(ffi.Pointer<Utf8>, ffi.Pointer<ffi.Void>),
      int Function(
          ffi.Pointer<Utf8>, ffi.Pointer<ffi.Void>)>('stopAvRecvService');

  static late final runSendService = mainLib.lookupFunction<
      ffi.Pointer<ffi.Void> Function(
          ffi.Pointer<Utf8>, ffi.Pointer<Utf8>, ffi.Bool),
      ffi.Pointer<ffi.Void> Function(
          ffi.Pointer<Utf8>, ffi.Pointer<Utf8>, bool)>('runSendService');

  static late final stopSendService = mainLib.lookupFunction<
      ffi.Int32 Function(ffi.Pointer<Utf8>, ffi.Pointer<ffi.Void>),
      int Function(
          ffi.Pointer<Utf8>, ffi.Pointer<ffi.Void>)>('stopSendService');

  static late final dataSend = mainLib.lookupFunction<
      ffi.Int32 Function(ffi.Pointer<Utf8>, ffi.Pointer<ffi.Uint8>, ffi.Size),
      int Function(
          ffi.Pointer<Utf8>, ffi.Pointer<ffi.Uint8>, int)>('dataSend');

  static late final setQcloudApiCred = mainLib.lookupFunction<
      ffi.Int32 Function(ffi.Pointer<Utf8>, ffi.Pointer<Utf8>),
      int Function(ffi.Pointer<Utf8>, ffi.Pointer<Utf8>)>('setQcloudApiCred');

  static late final setStunServerToXp2p = mainLib.lookupFunction<
      ffi.Void Function(ffi.Pointer<Utf8>, ffi.Uint16),
      void Function(ffi.Pointer<Utf8>, int)>('setStunServerToXp2p');

  static late final setCrossStunTurn = mainLib.lookupFunction<
      ffi.Void Function(ffi.Bool),
      void Function(bool)>('setCrossStunTurn');

  static late final setLogEnable = mainLib.lookupFunction<
      ffi.Void Function(ffi.Bool, ffi.Bool),
      void Function(bool, bool)>('setLogEnable');

  static late final startRecordPlayerStream = mainLib.lookupFunction<
      ffi.Void Function(ffi.Pointer<Utf8>),
      void Function(ffi.Pointer<Utf8>)>('startRecordPlayerStream');
}
