import 'dart:async';
import 'package:super_player/super_player.dart';
import 'package:xp2p_sdk/src/log/logger.dart';
export 'package:super_player/super_player.dart';

enum LiveStreamQuality {
  standard('standard'),
  high('high'),
  ultra('super');

  const LiveStreamQuality(this.value);

  final String value;
}

/// 播放器事件常量
class TXLivePlayEvent {
  static const int PLAY_EVT_PLAY_BEGIN = 2004;
  static const int PLAY_EVT_PLAY_LOADING = 2007;
  static const int PLAY_EVT_VOD_LOADING_END = 2014;
  static const int PLAY_EVT_PLAY_END = 2006;
  static const int PLAY_ERR_NET_DISCONNECT = -2301;
}

class TXLivePlayer {
  TXLivePlayer({this.observer, this.liveListener});

  static const String _tag = 'TXLivePlayer';

  final TXLivePlayerController _controller = TXLivePlayerController();

  /// 播放器观察者回调
  final void Function(String type, Map<dynamic, dynamic> data)? observer;

  /// 直播事件监听器
  final FTXLiveListener? liveListener;

  /// 事件订阅
  StreamSubscription? _eventSubscription;
  StreamSubscription? _netStatusSubscription;

  Completer<void>? _initCompleter;
  bool _isInitialized = false;

  /// 初始化播放器
  ///
  /// 返回一个 Future，完成后表示播放器初始化完毕
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    if (_initCompleter != null) {
      return _initCompleter!.future;
    }

    _initCompleter = Completer<void>();

    try {
      Logger.d('Initialize', _tag);

      if (liveListener != null) {
        _controller.liveListener = liveListener;
      }

      // 订阅播放器事件
      _eventSubscription = _controller.onPlayerEventBroadcast.listen((event) {
        if (observer != null) {
          observer!('event', event);
        }
      });

      _netStatusSubscription =
          _controller.onPlayerNetStatusBroadcast.listen((event) {
        if (observer != null) {
          observer!('netStatus', event);
        }
      });

      _isInitialized = true;
      _initCompleter!.complete();
      Logger.d('Initialized', _tag);
    } catch (e) {
      Logger.e('Init failed: $e', _tag);
      _initCompleter!.completeError(e);
      rethrow;
    }
  }

  /// 确保播放器已初始化
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  /// 设置渲染的视图
  ///
  /// 调用此方法前会自动确保播放器已初始化
  Future<void> setRenderView(int viewId) async {
    await _ensureInitialized();
    await _controller.setPlayerView(viewId);
  }

  /// 启动直播拉流
  ///
  /// [url] 播放地址
  /// 返回值：是否成功
  ///
  Future<bool?> startPlay(String? url) async {
    await _ensureInitialized();
    if (url == null || url.isEmpty) {
      Logger.e('Play failed: empty url', _tag);
      return null;
    }

    Logger.d('Start play: $url', _tag);
    final isPlay = await _controller.startLivePlay(url);

    if (!isPlay) {
      Logger.e('Play failed', _tag);
    }
    return isPlay;
  }

  /// 停止拉流
  void stopPlay() async {
    Logger.d('Stop', _tag);
    await _controller.stop();
  }

  /// 暂停播放
  void pausePlay() async {
    await _ensureInitialized();
    Logger.d('Pause', _tag);
    _controller.pause();
  }

  /// 恢复播放
  void resumePlay() async {
    await _ensureInitialized();
    Logger.d('Resume', _tag);
    _controller.resume();
  }

  /// 设置播放音量
  ///
  /// [volume] 音量大小，取值：0 - 100
  void setPlayVolume(int volume) async {
    await _ensureInitialized();
    _controller.setVolume(volume);
  }

  /// 视频截图
  ///
  Future<void> snapshot() async {
    await _ensureInitialized();
    await _controller.snapshot();
  }

  /// 开始录制视频
  ///
  /// [filePath] 录制文件完整路径（包含文件名），如果不提供则使用应用文档目录并自动生成文件名
  /// 返回是否成功开始录制
  ///
  Future<void> startRecord({required String filePath}) async {
    await _ensureInitialized();
    try {
      final params = FTXLiveLocalRecordingParams(filePath: filePath);
      await _controller.startLocalRecording(params);
    } catch (e) {
      Logger.e('Record start failed: $e', _tag);
    }
  }

  /// 停止录制视频
  ///
  Future<void> stopRecord() async {
    await _ensureInitialized();
    Logger.d('Stop record', _tag);
    await _controller.stopLocalRecording();
  }

  /// 销毁
  void dispose() {
    Logger.d('Dispose', _tag);

    // 停止播放
    stopPlay();

    // 取消事件订阅
    _eventSubscription?.cancel();
    _netStatusSubscription?.cancel();

    // 释放控制器
    _controller.dispose();

    _isInitialized = false;
  }
}
