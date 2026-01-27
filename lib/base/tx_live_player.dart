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
  TXLivePlayer({this.observer});

  static const String _tag = 'TXLivePlayer';

  final TXLivePlayerController _controller = TXLivePlayerController();

  /// 播放器观察者回调
  final void Function(String type, Map<dynamic, dynamic> data)? observer;

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
      Logger.d('Initialize TXLivePlayer', _tag);

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
      Logger.d('TXLivePlayer initialized successfully', _tag);
    } catch (e) {
      Logger.e('Failed to initialize TXLivePlayer: $e', _tag);
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
  /// [id] 要拉取的设备 id
  /// [quality] 视频流画质
  /// [encrypt] 是否加密（暂不支持）
  /// 返回值：结果码
  ///
  Future<bool?> startPlay(String? url) async {
    await _ensureInitialized();
    Logger.d('start play: $url', _tag);
    if (url == null || url.isEmpty) {
      return null;
    }

    final isPlay = await _controller.startLivePlay(url);

    if (!isPlay) {
      Logger.e('play error: $isPlay url: $url', _tag);
    } else {
      Logger.d('play success', _tag);
    }
    return isPlay;
  }

  /// 停止拉流
  void stopPlay() async {
    Logger.d('stopPlay', _tag);
    await _controller.stop();
  }

  /// 暂停播放
  void pausePlay() async {
    await _ensureInitialized();

    Logger.d('pausePlay', _tag);
    _controller.pause();
  }

  /// 恢复播放
  void resumePlay() async {
    await _ensureInitialized();

    Logger.d('resumePlay', _tag);
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
  /// 如果同时提供 path 和 fileName 则保存至具体路径
  /// 如果只提供 fileName 则保存至 App 应用文档路径
  /// 如果都不提供则该方法不负责保存
  /// [path] 路径
  /// [fileName] 文件名
  ///
  Future<void> snapshot({String? path, String? fileName}) async {
    await _ensureInitialized();
    Logger.d('snapshot, path: $path, fileName: $fileName', _tag);
  }

  Future<void> record({String? path, String? fileName}) async{
    Logger.d('Video record, path: $path, fileName: $fileName', _tag);
  }

  /// 销毁
  void dispose() {
    Logger.d('Dispose TXLivePlayer', _tag);

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
