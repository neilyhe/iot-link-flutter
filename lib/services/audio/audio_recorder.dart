import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart' as device_info_plus;
import 'aac_encoder_service.dart';

/// AAC数据监听器回调
typedef AACDataListener = void Function(Uint8List aacData, int timestamp);

class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  final AACEncoderService _aacEncoder = AACEncoderService();
  String? _currentRecordingPath;
  bool _isRecording = false;
  Stream<Uint8List>? _audioStream;
  StreamSubscription<Uint8List>? _streamSubscription;
  
  // AAC数据监听器列表
  final List<AACDataListener> _aacDataListeners = [];

  bool get isRecording => _isRecording;
  String? get currentRecordingPath => _currentRecordingPath;

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
      if (androidInfo.version.sdkInt < 29) { // Android 10 (API 29)以下
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
      if (androidInfo.version.sdkInt < 29) { // Android 10 (API 29)以下
        final storageStatus = await Permission.storage.status;
        if (storageStatus != PermissionStatus.granted) {
          return false;
        }
      }
    }
    
    return micStatus == PermissionStatus.granted;
  }

  /// 开始录音（AAC 格式）
  /// iOS: 使用 AAC-LC 编码，输出 .m4a 格式（MPEG-4 Audio容器）
  /// Android: 使用 AAC-LC 编码，输出 .m4a 格式
  Future<bool> startRecording() async {
    try {
      // 检查权限
      if (!await checkPermission()) {
        final granted = await requestPermission();
        if (!granted) {
          print('录音权限被拒绝');
          return false;
        }
      }

      // 检查是否支持录音
      if (!await _recorder.hasPermission()) {
        print('没有录音权限');
        return false;
      }

      // 生成文件路径（iOS和Android都使用.m4a格式）
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${directory.path}/recording_$timestamp.m4a';

      // 配置录音参数（iOS和Android通用）
      const config = RecordConfig(
        encoder: AudioEncoder.aacLc, // AAC-LC 编码器（iOS原生支持）
        bitRate: 64000, // 64 kbps
        sampleRate: 16000, // 16 kHz
        numChannels: 1, // 单声道
        autoGain: true, // 自动增益
        echoCancel: true, // 回声消除
        noiseSuppress: true, // 噪音抑制
      );

      // 开始录音
      await _recorder.start(
        config,
        path: _currentRecordingPath!,
      );

      _isRecording = true;
      print('开始录音: $_currentRecordingPath');
      return true;
    } catch (e) {
      print('开始录音失败: $e');
      return false;
    }
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
          print('录音权限被拒绝');
          return false;
        }
      }

      // 检查是否支持录音
      if (!await _recorder.hasPermission()) {
        print('没有录音权限');
        return false;
      }

      // iOS平台：初始化AAC编码器
      if (Platform.isIOS) {
        final encoderInitialized = await _aacEncoder.initEncoder();
        if (!encoderInitialized) {
          print('AAC编码器初始化失败');
          return false;
        }
        print('AAC编码器初始化成功');
      }

      // 配置录音参数
      RecordConfig config;
      
      if (Platform.isIOS) {
        // iOS: 使用PCM格式，后续通过编码器转换为AAC
        // streamBufferSize设置为1024帧，对应2048字节（16bit单声道），与AAC编码器帧大小对齐
        config = const RecordConfig(
          encoder: AudioEncoder.pcm16bits, // PCM 16bit
          sampleRate: 16000, // 16 kHz
          numChannels: 1, // 单声道
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
          streamBufferSize: 1024, // 1024帧 = 2048字节，与AAC编码器对齐
        );
        print('iOS平台：使用PCM录音 + AAC编码 (buffer: 1024帧/2048字节)');
      } else {
        // Android: 直接使用AAC编码
        config = const RecordConfig(
          encoder: AudioEncoder.aacLc, // AAC-LC
          bitRate: 64000,
          sampleRate: 16000,
          numChannels: 1,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
        );
        print('Android平台：直接使用AAC录音');
      }

      // 开始流式录音
      _audioStream = await _recorder.startStream(config);
      
      // 订阅数据流
      _streamSubscription = _audioStream!.listen(
        (Uint8List audioData) async {
          // 获取当前时间戳
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          
          // iOS平台：将PCM编码为AAC
          if (Platform.isIOS) {
            // 数据分片：将大块PCM数据切分成640字节的小块
            // 640字节 = 320个样本 = 20ms音频 (16kHz采样率)
            const chunkSize = 640;
            
            for (int offset = 0; offset < audioData.length; offset += chunkSize) {
              final end = (offset + chunkSize < audioData.length) 
                  ? offset + chunkSize 
                  : audioData.length;
              final chunk = audioData.sublist(offset, end);
              
              // 编码PCM数据块
              final aacData = await _aacEncoder.encodePCM(chunk);
              if (aacData != null && aacData.isNotEmpty) {
                // 通知所有AAC数据监听器
                _notifyAACDataListeners(aacData, timestamp + (offset ~/ chunkSize) * 20);
              }
            }
          } else {
            // Android平台：直接使用AAC数据
            _notifyAACDataListeners(audioData, timestamp);
          }
        },
        onError: (error) {
          print('音频流错误: $error');
        },
        onDone: () {
          print('音频流结束');
        },
        cancelOnError: true,
      );

      _isRecording = true;
      print('开始流式录音成功 - 实时输出AAC数据');
      return true;
    } catch (e) {
      print('开始流式录音失败: $e');
      // 清理编码器
      if (Platform.isIOS) {
        await _aacEncoder.releaseEncoder();
      }
      return false;
    }
  }

  /// 停止录音
  Future<String?> stopRecording() async {
    try {
      if (!_isRecording) {
        print('当前没有正在进行的录音');
        return null;
      }

      // 停止流式录音订阅
      if (_streamSubscription != null) {
        await _streamSubscription!.cancel();
        _streamSubscription = null;
        _audioStream = null;
        print('已停止流式录音数据采集');
      }

      // 释放AAC编码器
      if (Platform.isIOS) {
        await _aacEncoder.releaseEncoder();
      }
      final path = await _recorder.stop();
      _isRecording = false;

      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          final size = await file.length();
          print('录音完成: $path (${size} bytes)');
          return path;
        }
      }

      print('录音文件不存在');
      return null;
    } catch (e) {
      print('停止录音失败: $e');
      _isRecording = false;
      return null;
    }
  }

  /// 暂停录音
  Future<void> pauseRecording() async {
    try {
      if (_isRecording) {
        await _recorder.pause();
        print('录音已暂停');
      }
    } catch (e) {
      print('暂停录音失败: $e');
    }
  }

  /// 恢复录音
  Future<void> resumeRecording() async {
    try {
      await _recorder.resume();
      print('录音已恢复');
    } catch (e) {
      print('恢复录音失败: $e');
    }
  }

  /// 获取录音振幅（用于显示音量波形）
  Future<Amplitude> getAmplitude() async {
    try {
      final amplitude = await _recorder.getAmplitude();
      return amplitude;
    } catch (e) {
      print('获取振幅失败: $e');
      return Amplitude(current: 0, max: 0);
    }
  }

  /// 取消录音（删除文件）
  Future<void> cancelRecording() async {
    try {
      await _recorder.stop();
      _isRecording = false;

      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
          print('录音已取消并删除文件');
        }
      }
      _currentRecordingPath = null;
    } catch (e) {
      print('取消录音失败: $e');
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
    
    // 释放AAC编码器
    if (Platform.isIOS) {
      await _aacEncoder.releaseEncoder();
    }
    
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
      files.sort((a, b) =>
          b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      return files;
    } catch (e) {
      print('获取录音文件列表失败: $e');
      return [];
    }
  }

  /// 删除录音文件
  Future<bool> deleteRecording(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        print('文件已删除: $path');
        return true;
      }
      return false;
    } catch (e) {
      print('删除文件失败: $e');
      return false;
    }
  }
}