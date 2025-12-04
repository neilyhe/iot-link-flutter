import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:xp2p_sdk/xp2p_sdk.dart';

/// XP2P流媒体页面基类
/// 提供XP2P服务管理、TXLivePlayer播放器管理等公共功能
abstract class BaseXP2PStreamPage extends StatefulWidget {
  final String productId;
  final String deviceName;
  final String p2pInfo;

  const BaseXP2PStreamPage({
    super.key,
    required this.productId,
    required this.deviceName,
    required this.p2pInfo,
  });
}

/// XP2P流媒体页面State基类
abstract class BaseXP2PStreamPageState<T extends BaseXP2PStreamPage>
    extends State<T> {
  // ========== 公共状态变量 ==========
  String _statusText = '正在初始化...';
  bool _isConnected = false;
  bool _isPlayerReady = false;

  TXLivePlayer? _player;

  String get id => '${widget.productId}/${widget.deviceName}';

  // ========== 抽象属性和方法 - 子类必须实现 ==========
  /// 日志标签
  String get logTag;

  /// 初始化各自的服务（音频、视频等）
  void onInitServices();

  // ========== 钩子方法 - 子类可选覆盖 ==========
  /// P2P连接就绪回调
  void onP2PReady() {}

  /// P2P连接断开回调
  void onP2PDisconnect() {}

  /// 播放器事件回调
  void onPlayerEvent(V2TXLivePlayerListenerType type, dynamic param) {}

  // ========== XP2P生命周期管理 ==========
  @override
  void initState() {
    super.initState();
    Logger.i('进入页面: productId=${widget.productId}, deviceName=${widget.deviceName}', logTag);
    onInitServices();
    _initXP2P();
    _startService();
  }

  /// 初始化 XP2P SDK
  void _initXP2P() {
    Logger.i('XP2P SDK 初始化', logTag);
    XP2P.setCallback(_createCallback());
    XP2P.setLogEnable(console: true, file: false);
  }

  /// 创建XP2P回调对象
  XP2PCallback _createCallback() {
    return _MyXP2PCallback(
      onFailCallback: (id, errorCode) {
        Logger.e('连接失败: id=$id, errorCode=$errorCode', logTag);
        if (mounted) {
          setState(() {
            _statusText = '连接失败: $errorCode';
          });
        }
      },
      onCommandRequestCallback: (id, msg) {
        Logger.i('收到命令响应: id=$id, msg=$msg', logTag);
      },
      onXp2pEventNotifyCallback: (id, msg, event) {
        final eventType = XP2PType.fromValue(event);
        Logger.i('事件通知: id=$id, event=$eventType, msg=$msg', logTag);

        switch (eventType) {
          case XP2PType.detectReady:
            if (mounted) {
              setState(() {
                _statusText = 'P2P 连接就绪';
                _isConnected = true;
              });
            }
            _checkDeviceStatus();
            onP2PReady();
            break;
          case XP2PType.disconnect:
            if (mounted) {
              setState(() {
                _statusText = 'P2P 连接断开';
                _isConnected = false;
                _isPlayerReady = false;
              });
            }
            onP2PDisconnect();
            break;
          default:
            break;
        }
      },
      onAvDataRecvCallback: (id, data, len) {
        Logger.d('收到设备数据: id=$id, size=$len bytes', logTag);
      },
      onAvDataCloseCallback: (id, msg, errorCode) {
        Logger.w('数据通道关闭: id=$id, msg=$msg, errorCode=$errorCode', logTag);
      },
      onDeviceMsgArrivedCallback: (id, data, len) {
        Logger.i('收到设备消息: id=$id, size=$len bytes', logTag);
        return 'received';
      },
    );
  }

  /// 启动XP2P服务
  Future<void> _startService() async {
    Logger.i('正在启动服务...', logTag);

    const config = XP2PAppConfig(
      appKey: '***REMOVED***',
      appSecret: '***REMOVED***',
      autoConfigFromDevice: false,
      crossStunTurn: false,
      type: XP2PProtocolType.udp,
    );

    final result = await XP2P.startService(
      productId: widget.productId,
      deviceName: widget.deviceName,
      xp2pInfo: widget.p2pInfo,
      config: config,
    );

    if (result == 0) {
      if (mounted) {
        setState(() {
          _statusText = '服务启动成功';
        });
      }
      Logger.i('服务启动成功', logTag);
    } else {
      if (mounted) {
        setState(() {
          _statusText = '服务启动失败: $result';
        });
      }
      Logger.e('服务启动失败: $result', logTag);
    }
  }

  /// 检查设备状态
  Future<void> _checkDeviceStatus() async {
    Logger.i('检查设备状态', logTag);
    final commandStr = Command.getDeviceStatus(0, 'standard');
    final encode = utf8.encode(commandStr);
    final result = await XP2P.postCommandRequestSync(
        id: id, command: encode, timeoutUs: 2 * 1000 * 1000);

    if (result != null) {
      Logger.i('收到设备状态响应: ${utf8.decode(result)}', logTag);
    }
  }

  /// 停止XP2P服务
  void stopService() {
    Logger.i('停止服务...', logTag);
    XP2P.stopService(id);

    if (mounted) {
      setState(() {
        _statusText = '服务已停止';
        _isConnected = false;
      });
    }
  }

  // ========== 播放器管理 ==========
  /// 视频视图创建回调
  Future<void> onVideoViewCreated(int viewId) async {
    Logger.d('Video view created: $viewId', logTag);

    // 创建播放器实例
    _player = TXLivePlayer(
      observer: _onPlayerObserver,
    );

    try {
      // 显式初始化播放器
      await _player!.initialize();

      // 设置渲染视图
      await _player!.setRenderView(viewId);

      // 更新状态为播放器就绪
      if (mounted) {
        setState(() {
          _isPlayerReady = true;
        });
      }

      // 如果 P2P 已连接，立即开始播放
      if (_isConnected) {
        startLivePlay();
      }
    } catch (e) {
      Logger.e('Failed to initialize player: $e', logTag);
      if (mounted) {
        setState(() {
          _statusText = '播放器初始化失败';
        });
      }
    }
  }

  /// 播放器监听回调
  void _onPlayerObserver(V2TXLivePlayerListenerType type, param) {
    switch (type) {
      case V2TXLivePlayerListenerType.onStatisticsUpdate:
        break;
      case V2TXLivePlayerListenerType.onError:
      case V2TXLivePlayerListenerType.onWarning:
      case V2TXLivePlayerListenerType.onVideoResolutionChanged:
      case V2TXLivePlayerListenerType.onConnected:
      case V2TXLivePlayerListenerType.onVideoPlaying:
      case V2TXLivePlayerListenerType.onAudioPlaying:
      case V2TXLivePlayerListenerType.onVideoLoading:
      case V2TXLivePlayerListenerType.onAudioLoading:
      case V2TXLivePlayerListenerType.onPlayoutVolumeUpdate:
      case V2TXLivePlayerListenerType.onRenderVideoFrame:
      case V2TXLivePlayerListenerType.onReceiveSeiMessage:
      case V2TXLivePlayerListenerType.onPictureInPictureStateUpdate:
        Logger.d("==player listener type= ${type.toString()}", logTag);
        Logger.d("==player listener param= $param", logTag);
        break;
      default:
        break;
    }
    // 调用钩子方法让子类处理特定事件
    onPlayerEvent(type, param);
  }

  /// 启动拉流播放
  void startLivePlay() async {
    final result = await _player?.startPlay(id);

    if (result == DELEGATE_FLV_FAILED) {
      showMessage('无效链接，请检查设备连接！');
    } else if (result == V2TXLIVE_ERROR_INVALID_LICENSE) {
      showMessage('License Error!');
    }
  }

  // ========== UI组件 ==========
  /// 构建状态栏
  Widget buildStatusBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Row(
        children: [
          Icon(
            _isConnected ? Icons.check_circle : Icons.error,
            color: _isConnected ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _statusText,
              style: TextStyle(
                color: _isConnected ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建基础视频区域
  Widget buildBaseVideoArea() {
    return V2TXLiveVideoWidget(
      onViewCreated: onVideoViewCreated,
    );
  }

  /// 显示提示消息
  void showMessage(String msg, {Duration? duration}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: duration ?? const Duration(seconds: 1),
      ),
    );
  }

  // ========== 生命周期 ==========
  @override
  void dispose() {
    _player?.dispose();
    XP2P.stopService(id);
    super.dispose();
  }

  // ========== Getters for mixins ==========
  bool get isConnected => _isConnected;
  bool get isPlayerReady => _isPlayerReady;
  TXLivePlayer? get player => _player;
  String get statusText => _statusText;
  set statusText(String value) {
    if (mounted) {
      setState(() {
        _statusText = value;
      });
    }
  }
}

/// XP2P 回调实现
class _MyXP2PCallback extends XP2PCallback {
  final void Function(String id, int errorCode) onFailCallback;
  final void Function(String id, String msg) onCommandRequestCallback;
  final void Function(String id, String msg, int event)
      onXp2pEventNotifyCallback;
  final void Function(String id, Uint8List data, int len) onAvDataRecvCallback;
  final void Function(String id, String msg, int errorCode)
      onAvDataCloseCallback;
  final String Function(String id, Uint8List data, int len)
      onDeviceMsgArrivedCallback;

  _MyXP2PCallback({
    required this.onFailCallback,
    required this.onCommandRequestCallback,
    required this.onXp2pEventNotifyCallback,
    required this.onAvDataRecvCallback,
    required this.onAvDataCloseCallback,
    required this.onDeviceMsgArrivedCallback,
  });

  @override
  void onFail(String id, int errorCode) {
    onFailCallback(id, errorCode);
  }

  @override
  void onCommandRequest(String id, String msg) {
    onCommandRequestCallback(id, msg);
  }

  @override
  void onXp2pEventNotify(String id, String msg, int event) {
    onXp2pEventNotifyCallback(id, msg, event);
  }

  @override
  void onAvDataRecv(String id, Uint8List data, int len) {
    onAvDataRecvCallback(id, data, len);
  }

  @override
  void onAvDataClose(String id, String msg, int errorCode) {
    onAvDataCloseCallback(id, msg, errorCode);
  }

  @override
  String onDeviceMsgArrived(String id, Uint8List data, int len) {
    return onDeviceMsgArrivedCallback(id, data, len);
  }
}
