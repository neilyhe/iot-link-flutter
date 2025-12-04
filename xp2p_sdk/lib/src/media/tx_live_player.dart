
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:live_flutter_plugin/v2_tx_live_code.dart';
import 'package:live_flutter_plugin/v2_tx_live_def.dart';
import 'package:live_flutter_plugin/v2_tx_live_player.dart';
import 'package:live_flutter_plugin/v2_tx_live_player_observer.dart';
import 'package:live_flutter_plugin/v2_tx_live_premier.dart';
import 'package:xp2p_sdk/src/log/logger.dart';
import 'package:xp2p_sdk/src/utils/file_utils.dart';
import 'package:xp2p_sdk/src/utils/string_ext.dart';
import 'package:xp2p_sdk/src/xp2p.dart';
import 'package:xp2p_sdk/src/command.dart';

enum LiveStreamQuality {
  standard('standard'),
  high('high'),
  ultra('super');

  const LiveStreamQuality(this.value);
  final String value;
}

const V2TXLiveCode PLAYER_HAS_STARTED = 1;
const V2TXLiveCode DELEGATE_FLV_FAILED = -9;

class TXLivePlayer {
  TXLivePlayer({
    int? localViewId,
    this.observer
  }) : _localViewId = localViewId;

  static const String _tag = 'TXLivePlayer';

  V2TXLivePlayer? _livePlayer;
  int? _localViewId;
  V2TXLivePlayerObserver? observer;

  String _currentUrl = '';
  String get currentUrl => _currentUrl;
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;
  bool _isMute = false;
  bool get isMute => _isMute;

  Completer<void>? _initCompleter;
  bool _isInitialized = false;

  static void setupLicense(String licenseUrl, String licenseUrlKey) {
    V2TXLivePremier.setLicence(licenseUrl, licenseUrlKey);
  }

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
      _livePlayer = await V2TXLivePlayer.create();

      if (observer != null) {
        addListener(observer!);
      }

      addListener(_onPlayerObserver);
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

  /// 添加监听器
  ///
  /// [observer] 监听器
  void addListener(V2TXLivePlayerObserver observer) {
    _livePlayer?.addListener(observer);
  }

  /// 移除监听器
  void removeListener() {
    if (observer != null) {
      _livePlayer?.removeListener(observer!);
    }
  }

  /// 设置渲染的视图
  /// 
  /// 调用此方法前会自动确保播放器已初始化
  Future<void> setRenderView(int viewId) async {
    await _ensureInitialized();
    
    _localViewId = viewId;
    final code = await _livePlayer?.setRenderViewID(viewId);
    
    if (code != V2TXLIVE_OK) {
      Logger.e('Failed to set render view: $code', _tag);
    } else {
      Logger.d('Render view set successfully: $viewId', _tag);
    }
  }

  /// 启动直播拉流
  ///
  /// [id] 要拉取的设备 id
  /// [quality] 视频流画质
  /// [encrypt] 是否加密（暂不支持）
  /// 返回值：结果码
  /// 
  Future<V2TXLiveCode?> startPlay(String id, {
    LiveStreamQuality quality = LiveStreamQuality.standard,
    bool encrypt = false
  }) async {
    await _ensureInitialized();
    
    Logger.d('start play...', _tag);
    if (_isPlaying) {
      Logger.e('startPlay error: player has been started', _tag);
      return PLAYER_HAS_STARTED;
    }

    if (_localViewId != null) {
      Logger.d('_localViewId $_localViewId', _tag);
      final code = await _livePlayer?.setRenderViewID(_localViewId!);
      if (code != V2TXLIVE_OK) {
        Logger.e('startPlay error: please check remoteView load', _tag);
      }
    }

    final baseUrl = XP2P.delegateHttpFlv(id);
    Logger.d('delegateHttpFlv, baseUrl: $baseUrl, id: $id', _tag);

    if (baseUrl.isEmpty) {
      Logger.e('get an empty url', _tag);
      return DELEGATE_FLV_FAILED;
    }

    final url = baseUrl + Command.getVideoUrlSuffix(0, quality.value);
    Logger.d('play url: $url', _tag);
    final playStatus = await _livePlayer?.startLivePlay(url);

    if (playStatus == null || playStatus != V2TXLIVE_OK) {
      Logger.e('play error: $playStatus url: $url', _tag);
    } else {
      Logger.d('play success', _tag);
    }

    await _livePlayer?.setRenderFillMode(V2TXLiveFillMode.v2TXLiveFillModeFit);
    await _livePlayer?.setPlayoutVolume(100);
    _isPlaying = true;
    _currentUrl = url;
    return playStatus;
  }

  /// 停止拉流
  void stopPlay() async {
    await _ensureInitialized();
    
    Logger.d('stopPlay', _tag);
    await _livePlayer?.stopPlay();
    _isPlaying = false;
  }

  /// 暂停播放
  void pausePlay() async {
    await _ensureInitialized();
    
    Logger.d('pausePlay', _tag);
    _livePlayer?.pauseVideo();
  }

  /// 恢复播放
  void resumePlay() async {
    await _ensureInitialized();
    
    Logger.d('resumePlay', _tag);
    _livePlayer?.resumeVideo();
  }

  /// 设置静音
  ///
  /// [isMute] 是否静音
  void setMute(bool isMute) async {
    await _ensureInitialized();
    
    Logger.d('setMute: $isMute', _tag);

    V2TXLiveCode? res;
    if (isMute) {
      res = await _livePlayer?.setPlayoutVolume(0);
    } else {
      res = await _livePlayer?.setPlayoutVolume(100);
    }

    if (res != null && res == V2TXLIVE_OK) {
      _isMute = isMute;
    }
  }

  /// 设置播放音量
  ///
  /// [volume] 音量大小，取值：0 - 100
  void setPlayVolume(int volume) async {
    await _ensureInitialized();
    
    _livePlayer?.setPlayoutVolume(volume);
  }

  /// 视频截图
  ///
  /// 如果同时提供 path 和 fileName 则保存至具体路径
  /// 如果只提供 fileName 则保存至 App 应用文档路径
  /// 如果都不提供则该方法不负责保存
  /// [path] 路径
  /// [fileName] 文件名
  ///
  void snapshot({String? path, String? fileName}) async {
    await _ensureInitialized();
    
    Logger.d('snapshot, path: $path, fileName: $fileName', _tag);
    _path = path;
    _fileName = fileName;
    _isSave = _path.isNotNullOrEmpty || _fileName.isNotNullOrEmpty;

    final code = await _livePlayer?.snapshot();
    if (code == null || code != V2TXLIVE_OK) {
      Logger.e('snapshot error: $code, url: $_currentUrl', _tag);
    }
  }

  /// 添加截图监听
  bool _isSave = false;
  String? _path, _fileName;
  void _onPlayerObserver(V2TXLivePlayerListenerType type, param) async {
    if (_isSave && type == V2TXLivePlayerListenerType.onSnapshotComplete
        && param['image'] != null && param['image'] is Uint8List) {
      File? result;

      if (_path.isNotNullOrEmpty) {
        if (!_fileName.isNotNullOrEmpty) {
          _fileName = 'img_${DateTime.now().millisecondsSinceEpoch}.png';
        }

        result = await FileUtils.saveUint8ListToPath(param['image'], _path!, _fileName!);
      } else if (_fileName.isNotNullOrEmpty) {
        result = await FileUtils.saveUint8ListToAppDocument(param['image'], _fileName!);
      }

      if (result == null) {
        Logger.e('Save snapshot error.', _tag);
      }
    }
  }

  /// 视频录制
  void record() {
    Logger.d('Video record', _tag);
  }

  /// 销毁
  void dispose() {
    Logger.d('Dispose TXLivePlayer', _tag);

    stopPlay();
    removeListener();
    _livePlayer?.removeListener(_onPlayerObserver);
    _livePlayer?.destroy();
    _livePlayer = null;
  }

}