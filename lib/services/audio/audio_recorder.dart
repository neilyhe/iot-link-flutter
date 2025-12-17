import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart' as device_info_plus;
import 'package:xp2p_sdk/xp2p_sdk.dart';
import 'aac_encoder_service.dart';

/// AAC数据监听器回调
typedef AACDataListener = void Function(Uint8List aacData, int timestamp);

class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  final AACEncoderService _aacEncoder = AACEncoderService();
  SoundTouch? _soundTouch;
  bool _isRecording = false;
  bool _isInitialized = false; // 标记是否已经初始化过录制
  Stream<Uint8List>? _audioStream;
  StreamSubscription<Uint8List>? _streamSubscription;
  
  // 变调参数（-12到12，0表示不变调）
  int _pitch = 6;

  // AAC数据监听器列表
  final List<AACDataListener> _aacDataListeners = [];

  bool get isRecording => _isRecording;

  /// 设置变调参数（-12到12，0表示不变调）
  void setPitch(int pitch) {
    _pitch = pitch;
  }

  /// 添加AAC数据监听器
  void addAACDataListener(AACDataListener listener) {
    _aacDataListeners.add(listener);
  }

  /// 移除AAC数据监听器
  void removeAACDataListener(AACDataListener listener) {
    _aacDataListeners.remove(listener);
  }

  /// 通知所有AAC数据监听器
  void _notifyAACDataListeners(Uint8List aacData, int timestamp) {
    for (final listener in _aacDataListeners) {
      listener(aacData, timestamp);
    }
  }

  /// 请求录音权限
  Future<bool> requestPermission() async {
    // 请求麦克风权限
    final micStatus = await Permission.microphone.request();

    // iOS平台权限处理
    if (Platform.isIOS) {
      // iOS只需要麦克风权限
      return micStatus == PermissionStatus.granted;
    }

    // 对于Android 10以下设备，请求存储权限
    if (Platform.isAndroid) {
      final deviceInfo = device_info_plus.DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      if (androidInfo.version.sdkInt < 29) {
        // Android 10 (API 29)以下
        final storageStatus = await Permission.storage.request();
        if (storageStatus != PermissionStatus.granted) {
          return false;
        }
      }
    }

    return micStatus == PermissionStatus.granted;
  }

  /// 检查权限状态
  Future<bool> checkPermission() async {
    final micStatus = await Permission.microphone.status;

    // iOS平台权限检查
    if (Platform.isIOS) {
      // iOS只需要检查麦克风权限
      return micStatus == PermissionStatus.granted;
    }

    // 对于Android 10以下设备，检查存储权限
    if (Platform.isAndroid) {
      final deviceInfo = device_info_plus.DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      if (androidInfo.version.sdkInt < 29) {
        // Android 10 (API 29)以下
        final storageStatus = await Permission.storage.status;
        if (storageStatus != PermissionStatus.granted) {
          return false;
        }
      }
    }

    return micStatus == PermissionStatus.granted;
  }

  /// 开始流式录音（实时获取AAC数据）
  /// iOS: PCM -> AAC实时编码
  /// Android: 直接输出AAC-LC编码
  Future<bool> startStreamRecording() async {
    try {
      // 检查权限
      if (!await checkPermission()) {
        final granted = await requestPermission();
        if (!granted) {
          Logger.e('录音权限被拒绝',"AudioRecorder");
          return false;
        }
      }

      // 检查是否支持录音
      if (!await _recorder.hasPermission()) {
        Logger.e('没有录音权限',"AudioRecorder");
        return false;
      }

      // 如果已经初始化过录制，则使用resume恢复录制，避免重复调用startStream卡主线程
      if (_isInitialized && !_isRecording) {
        await _recorder.resume();
        _isRecording = true;
        Logger.i('恢复录制成功 - 使用resume避免startStream卡顿',"AudioRecorder");
        return true;
      }

      // 首次初始化录制
      // 初始化AAC编码器（iOS和Android都需要）
      final encoderInitialized = await _aacEncoder.initEncoder();
      if (!encoderInitialized) {
        Logger.e('AAC编码器初始化失败',"AudioRecorder");
        return false;
      }
      Logger.i('AAC编码器初始化成功',"AudioRecorder");

      // 初始化SoundTouch（如果需要变调）
      if (_pitch != 0) {
        _soundTouch = SoundTouch(
          track: 0,
          channels: 1,
          samplingRate: 16000,
          bytesPerSample: 2,
          tempo: 1.0,
          pitch: _pitch,
        );
      }

      // 配置录音参数（iOS和Android都使用PCM格式，然后通过编码器转换为AAC）
      // streamBufferSize设置为1024帧，对应2048字节（16bit单声道），与AAC编码器帧大小对齐
      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits, // PCM 16bit
        sampleRate: 16000, // 16 kHz
        numChannels: 1, // 单声道
        autoGain: true,
        echoCancel: true,
        noiseSuppress: true,
        streamBufferSize: 1024, // 1024帧 = 2048字节，与AAC编码器对齐
      );

      // 开始流式录音
      _audioStream = await _recorder.startStream(config);

      // 订阅数据流
      _streamSubscription = _audioStream!.listen(
        (Uint8List audioData) {
          //变声
          if (_pitch != 0 && _soundTouch != null) {
            _soundTouch?.putBytes(audioData);

            Uint8List processedData;
            while ((processedData = _soundTouch!.getBytes()).isNotEmpty) {
              slicePCM(processedData);
            }
          } else {
            slicePCM(audioData);
          }
        },
        onError: (error) {
          Logger.e('音频流错误: $error',"AudioRecorder");
        },
        onDone: () {
          Logger.i('音频流结束',"AudioRecorder");
        },
        cancelOnError: true,
      );

      _isRecording = true;
      _isInitialized = true; // 标记已经初始化过录制
      Logger.i('开始流式录音成功 - 实时输出AAC数据',"AudioRecorder");
      return true;
    } catch (e) {
      Logger.e('开始流式录音失败: $e',"AudioRecorder");
      // 清理编码器（iOS和Android都需要）
      await _aacEncoder.releaseEncoder();
      return false;
    }
  }


  void slicePCM(Uint8List pcmData) {
    // 将PCM编码为AAC（iOS和Android都需要）
    // 数据分片：将大块PCM数据切分成640字节的小块
    // 640字节 = 320个样本 = 20ms音频 (16kHz采样率)
    const chunkSize = 640;

    for (int offset = 0; offset < pcmData.length; offset += chunkSize) {
      final end = (offset + chunkSize < pcmData.length)
          ? offset + chunkSize
          : pcmData.length;
      final chunk = pcmData.sublist(offset, end);

      // 编码PCM数据块
      _aacEncoder.encodePCM(chunk).then((aacData) {
        if (aacData != null && aacData.isNotEmpty) {
          final chunkTimestamp = DateTime.now().millisecondsSinceEpoch;
          _notifyAACDataListeners(aacData, chunkTimestamp);
        }
      }).catchError((error) {
        Logger.e('AAC编码失败: $error', "AudioRecorder");
      });
    }
  }

  /// 停止录音（如果只是暂停录制，使用pause而不是完全stop）
  Future<String?> stopRecording({bool completeStop = false}) async {
    try {
      if (!_isRecording) {
        Logger.i('当前没有正在进行的录音',"AudioRecorder");
        return null;
      }

      // 如果只是暂停录制而不是完全停止，使用pause方法
      if (!completeStop && _isInitialized) {
        await _recorder.pause();
        _isRecording = false;
        Logger.i('暂停录制成功 - 使用pause避免stop/startStream卡顿',"AudioRecorder");
        return null;
      }

      // 完全停止录制，释放所有资源
      // 停止流式录音订阅
      if (_streamSubscription != null) {
        await _streamSubscription!.cancel();
        _streamSubscription = null;
        _audioStream = null;
        Logger.i('已停止流式录音数据采集',"AudioRecorder");
      }

      // 释放AAC编码器（iOS和Android都需要）
      await _aacEncoder.releaseEncoder();
      
      // 清理SoundTouch资源
      if (_soundTouch != null) {
        _soundTouch!.finish();
        _soundTouch!.clearBuffer();
        _soundTouch = null;
        Logger.i('SoundTouch资源已释放',"AudioRecorder");
      }
      
      final path = await _recorder.stop();
      _isRecording = false;
      _isInitialized = false; // 重置初始化标记

      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          final size = await file.length();
          Logger.i('录音完成: $path (${size} bytes)',"AudioRecorder");
          return path;
        }
      }

      Logger.e('录音文件不存在',"AudioRecorder");
      return null;
    } catch (e) {
      Logger.e('停止录音失败: $e',"AudioRecorder");
      _isRecording = false;
      return null;
    }
  }

  /// 暂停录音（使用pause而不是stop，避免重新startStream卡顿）
  Future<void> pauseRecording() async {
    try {
      if (_isRecording) {
        await _recorder.pause();
        _isRecording = false;
        Logger.i('录音已暂停 - 使用pause避免stop/startStream卡顿',"AudioRecorder");
      }
    } catch (e) {
      Logger.e('暂停录音失败: $e',"AudioRecorder");
    }
  }

  /// 恢复录音（如果已经初始化过录制，直接resume）
  Future<void> resumeRecording() async {
    try {
      if (_isInitialized && !_isRecording) {
        await _recorder.resume();
        _isRecording = true;
        Logger.i('录音已恢复 - 使用resume避免startStream卡顿',"AudioRecorder");
      } else if (!_isInitialized) {
        Logger.w('录音未初始化，请先调用startStreamRecording',"AudioRecorder");
      }
    } catch (e) {
      Logger.e('恢复录音失败: $e',"AudioRecorder");
    }
  }

  /// 完全停止录制并释放所有资源
  Future<String?> completeStopRecording() async {
    return await stopRecording(completeStop: true);
  }

  /// 获取录音振幅（用于显示音量波形）
  Future<Amplitude> getAmplitude() async {
    try {
      final amplitude = await _recorder.getAmplitude();
      return amplitude;
    } catch (e) {
      Logger.e('获取振幅失败: $e',"AudioRecorder");
      return Amplitude(current: 0, max: 0);
    }
  }

  /// 取消录音（删除文件）
  Future<void> cancelRecording() async {
    try {
      await _recorder.stop();
      _isRecording = false;
    } catch (e) {
      Logger.e('取消录音失败: $e',"AudioRecorder");
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    // 清理流式录音资源
    if (_streamSubscription != null) {
      await _streamSubscription!.cancel();
      _streamSubscription = null;
    }
    _audioStream = null;

    // 释放AAC编码器（iOS和Android都需要）
    await _aacEncoder.releaseEncoder();

    // 清理SoundTouch资源
    if (_soundTouch != null) {
      _soundTouch!.finish();
      _soundTouch!.clearBuffer();
      _soundTouch = null;
    }

    // 重置状态标记
    _isRecording = false;
    _isInitialized = false;

    await _recorder.dispose();
  }

  /// 获取所有录音文件
  Future<List<File>> getAllRecordings() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = directory
          .listSync()
          .where((item) =>
              item is File &&
              (item.path.endsWith('.m4a') || item.path.endsWith('.aac')))
          .map((item) => item as File)
          .toList();

      // 按修改时间排序
      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      return files;
    } catch (e) {
      Logger.e('获取录音文件列表失败: $e',"AudioRecorder");
      return [];
    }
  }

  /// 删除录音文件
  Future<bool> deleteRecording(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        Logger.i('文件已删除: $path',"AudioRecorder");
        return true;
      }
      return false;
    } catch (e) {
      Logger.e('删除文件失败: $e',"AudioRecorder");
      return false;
    }
  }
}