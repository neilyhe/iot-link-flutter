import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:iot_link_flutter/base/tx_live_player.dart';
import 'package:xp2p_sdk/xp2p_sdk.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';

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
  
  late String _p2pInfo;

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
  void onPlayerEvent(String type, Map<dynamic, dynamic> data) {}

  // ========== XP2P生命周期管理 ==========
  @override
  void initState() {
    super.initState();
    _p2pInfo = widget.p2pInfo;
    Logger.i('进入页面: productId=${widget.productId}, deviceName=${widget.deviceName}', logTag);
    
    // 使用 try-catch 包裹初始化逻辑，防止 Release 模式下崩溃
    try {
      onInitServices();
      _initXP2P();
      _startService();
    } catch (e, stackTrace) {
      Logger.e('初始化失败: $e', logTag);
      Logger.e('堆栈信息: $stackTrace', logTag);
      if (mounted) {
        setState(() {
          _statusText = '初始化失败: $e';
        });
      }
    }
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
            _restartService();
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
      appKey: '<APPKEY>',
      appSecret: '<APPSECRET>',
      autoConfigFromDevice: true,
      crossStunTurn: false,
      type: XP2PProtocolType.udp,
    );

    final result = await XP2P.startService(
      productId: widget.productId,
      deviceName: widget.deviceName,
      xp2pInfo: _p2pInfo,
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
    } else {
      Logger.i('设备状态检查无响应', logTag);
      _restartService();
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

  /// 重启 XP2P 服务
  /// 触发时机：
  /// 1. onXp2pEventNotifyCallback 收到 disconnected
  /// 2. _checkDeviceStatus 无响应
  Future<void> _restartService() async {
    Logger.i('重启服务中...', logTag);
    stopService();

    // TODO 根据自身情况重新获取 p2pInfo
    // _p2pInfo = await updateP2PInfo();
    // _startService();
  }

  /// 更新 P2P Info
  Future<String?> updateP2PInfo() async {
    // 自行实现 P2PInfo 的获取逻辑
    // final newP2pInfo = await getP2PInfo();
    // setP2PInfo(newP2pInfo);
    return null;
  }

  void setP2PInfo(String newP2pInfo) {
    _p2pInfo = newP2pInfo;
    Logger.i('P2P Info 已更新', logTag);
  }

  // ========== 播放器管理 ==========
  /// 视频视图创建回调
  Future<void> onVideoViewCreated(int viewId) async {
    Logger.d('Video view created: $viewId', logTag);

    try {
      // 创建播放器实例
      _player = TXLivePlayer(
        observer: _onPlayerObserver,
        liveListener: _onLiveListener,
      );

      await _player!.initialize();
      await _player!.setRenderView(viewId);
      if (mounted) {
        setState(() {
          _isPlayerReady = true;
        });
      }

      // 如果 P2P 已连接，立即开始播放
      if (_isConnected) {
        startLivePlay();
      }
    } catch (e, stackTrace) {
      Logger.e('Failed to initialize player: $e', logTag);
      Logger.e('堆栈信息: $stackTrace', logTag);
      if (mounted) {
        setState(() {
          _statusText = '播放器初始化失败: $e';
        });
      }
    }
  }

  /// 播放器监听回调
  void _onPlayerObserver(String type, Map<dynamic, dynamic> data) {
    if (type == 'event') {
      final eventId = data['event'] ?? 0;
      switch (eventId) {
        case TXLivePlayEvent.PLAY_EVT_PLAY_BEGIN:
          Logger.i('播放开始', logTag);
          break;
        case TXLivePlayEvent.PLAY_EVT_PLAY_LOADING:
          Logger.i('播放 loading', logTag);
          break;
        case TXLivePlayEvent.PLAY_EVT_VOD_LOADING_END:
          Logger.i('播放 loading 结束', logTag);
          break;
        case TXLivePlayEvent.PLAY_EVT_PLAY_END:
          Logger.i('播放结束', logTag);
          break;
        case TXLivePlayEvent.PLAY_ERR_NET_DISCONNECT:
          Logger.e('网络断连', logTag);
          break;
        default:
          break;
      }
    } else if (type == 'netStatus') {
      Logger.d("==player netStatus= $data", logTag);
    }

    // 调用钩子方法让子类处理特定事件
    onPlayerEvent(type, data);
  }

  Future<String?> buildUrl() async {
    final baseUrl = XP2P.delegateHttpFlv(id);
    Logger.d('delegateHttpFlv, baseUrl: $baseUrl, id: $id', "BaseXp2pStreamPage");

    if (baseUrl.isEmpty) {
      Logger.e('get an empty url', "BaseXp2pStreamPage");
      return null;
    }

    final url = baseUrl + Command.getVideoUrlSuffix(0, LiveStreamQuality.standard.value);
    Logger.d('delegateHttpFlv, url: $url', "BaseXp2pStreamPage");
    return url;
  }

  /// 启动拉流播放
  void startLivePlay() async {
    final url = await buildUrl();
    await _player?.startPlay(url);
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
    return TXPlayerVideo(
      onRenderViewCreatedListener: onVideoViewCreated,
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
    Logger.i('页面销毁，清理资源...', logTag);

    try {
      if (_player != null) {
        _player!.stopPlay();
        _player!.dispose();
        _player = null;
      }

      XP2P.stopService(id);

      _isConnected = false;
      _isPlayerReady = false;
    } catch (e) {
      Logger.e('dispose 时发生错误: $e', logTag);
    }

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
  
  String get p2pInfo => _p2pInfo;

  FTXLiveListener get _onLiveListener => FTXLiveListener(
        // 截图完成回调
        snapshotCompleteCallback: (imageBytes) async {
          if (imageBytes == null) return;
          await _saveSnapshotToGallery(imageBytes);
        },
        // 录制开始回调
        recordBeginCallback: (code, storagePath) {
          Logger.i('录制开始: code=$code, path=$storagePath', logTag);
        },
        // 录制进行中回调（避免频繁打印）
        recordingCallback: (durationMs, storagePath) {
          // Logger.d('录制中: duration=${durationMs}ms', logTag);
        },
        // 录制完成回调
        recordCompleteCallback: (code, storagePath) async {
          await _saveVideoToGallery(code, storagePath);
        },
      );

  /// 保存截图到相册
  Future<void> _saveSnapshotToGallery(Uint8List imageBytes) async {
    try {
      // 请求存储权限
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          Logger.e('存储权限被拒绝', logTag);
          showMessage('需要存储权限才能保存截图');
          return;
        }
      } else if (Platform.isIOS) {
        final status = await Permission.photos.request();
        if (!status.isGranted) {
          Logger.e('相册权限被拒绝', logTag);
          showMessage('需要相册权限才能保存截图');
          return;
        }
      }

      // 保存到相册
      await Gal.putImageBytes(
        imageBytes,
        album: 'Screenshots',
      );
      
      Logger.i('截图保存成功', logTag);
      showMessage('截图已保存到相册');
    } catch (e, stackTrace) {
      Logger.e('保存截图异常: $e', logTag);
      Logger.e('堆栈信息: $stackTrace', logTag);
      showMessage('截图保存失败: $e');
    }
  }

  /// 保存视频到相册
  Future<void> _saveVideoToGallery(int code, String storagePath) async {
    try {
      Logger.i('录制完成: code=$code, path=$storagePath', logTag);

      if (code != 0) {
        Logger.e('录制失败: code=$code', logTag);
        showMessage('录制失败');
        return;
      }

      // 检查文件是否存在
      final file = File(storagePath);
      if (!await file.exists()) {
        Logger.e('录制文件不存在: $storagePath', logTag);
        showMessage('录制文件不存在');
        return;
      }

      // 请求存储权限
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          Logger.e('存储权限被拒绝', logTag);
          showMessage('需要存储权限才能保存视频');
          return;
        }
      } else if (Platform.isIOS) {
        final status = await Permission.photos.request();
        if (!status.isGranted) {
          Logger.e('相册权限被拒绝', logTag);
          showMessage('需要相册权限才能保存视频');
          return;
        }
      }

      // 保存到相册
      await Gal.putVideo(
        storagePath,
        album: 'Videos',
      );
      
      Logger.i('视频保存成功: $storagePath', logTag);
      showMessage('视频已保存到相册');
    } catch (e, stackTrace) {
      Logger.e('堆栈信息: $stackTrace', logTag);
      showMessage('视频保存失败: $e');
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
