import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart' as device_info_plus;

/// AAC数据监听器回调
typedef AACDataListener = void Function(Uint8List aacData, int timestamp);

class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
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
  /// iOS: 实时输出 AAC-LC 编码的音频数据流
  /// Android: 实时输出 AAC-LC 编码的音频数据流
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

      // 开始流式录音
      _audioStream = await _recorder.startStream(config);
      
      // 订阅数据流，实时输出AAC数据给监听器
      _streamSubscription = _audioStream!.listen(
        (Uint8List audioData) {
          // 获取当前时间戳
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          
          // 通知所有AAC数据监听器
          _notifyAACDataListeners(audioData, timestamp);
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
      print('开始流式录音 - 实时输出AAC数据给监听器');
      return true;
    } catch (e) {
      print('开始流式录音失败: $e');
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