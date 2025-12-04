import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

/// SoundTouch 设置 ID 常量
class SoundTouchSetting {
  /// 启用/禁用音调转换器中的抗锯齿滤波器 (0 = 禁用)
  static const int useAAFilter = 0;

  /// 音调转换器抗锯齿滤波器长度 (8 .. 128 taps, 默认 = 32)
  static const int aaFilterLength = 1;

  /// 启用/禁用节奏变换器中的快速寻址算法
  static const int useQuickSeek = 2;

  /// 时间拉伸算法单个处理序列长度（毫秒）
  static const int sequenceMs = 3;

  /// 时间拉伸算法寻址窗口长度（毫秒）
  static const int seekWindowMs = 4;

  /// 时间拉伸算法重叠长度（毫秒）
  static const int overlapMs = 5;

  /// 查询处理序列大小（样本数）- 只读
  static const int nominalInputSequence = 6;

  /// 查询标称平均处理输出大小（样本数）- 只读
  static const int nominalOutputSequence = 7;

  /// 查询初始处理延迟（样本数）- 只读
  static const int initialLatency = 8;
}

/// SoundTouch FFI 绑定类
class SoundTouchFFI {
  late final ffi.DynamicLibrary _dylib;

  SoundTouchFFI() {
    if (Platform.isAndroid) {
      _dylib = ffi.DynamicLibrary.open('libsoundtouch.so');
    } else if (Platform.isIOS) {
      _dylib = ffi.DynamicLibrary.process();
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  // ========== 创建和销毁 ==========

  late final _soundtouch_create = _dylib.lookupFunction<
      ffi.Pointer<ffi.Void> Function(),
      ffi.Pointer<ffi.Void> Function()>('soundtouch_create');

  ffi.Pointer<ffi.Void> create() {
    return _soundtouch_create();
  }

  late final _soundtouch_destroy = _dylib.lookupFunction<
      ffi.Void Function(ffi.Pointer<ffi.Void>),
      void Function(ffi.Pointer<ffi.Void>)>('soundtouch_destroy');

  void destroy(ffi.Pointer<ffi.Void> handle) {
    _soundtouch_destroy(handle);
  }

  // ========== 基本设置 ==========

  late final _soundtouch_set_sample_rate = _dylib.lookupFunction<
      ffi.Void Function(ffi.Pointer<ffi.Void>, ffi.Uint32),
      void Function(ffi.Pointer<ffi.Void>, int)>('soundtouch_set_sample_rate');

  void setSampleRate(ffi.Pointer<ffi.Void> handle, int sampleRate) {
    _soundtouch_set_sample_rate(handle, sampleRate);
  }

  late final _soundtouch_set_channels = _dylib.lookupFunction<
      ffi.Void Function(ffi.Pointer<ffi.Void>, ffi.Uint32),
      void Function(ffi.Pointer<ffi.Void>, int)>('soundtouch_set_channels');

  void setChannels(ffi.Pointer<ffi.Void> handle, int channels) {
    _soundtouch_set_channels(handle, channels);
  }

  // ========== 音频效果参数 ==========

  late final _soundtouch_set_rate = _dylib.lookupFunction<
      ffi.Void Function(ffi.Pointer<ffi.Void>, ffi.Double),
      void Function(ffi.Pointer<ffi.Void>, double)>('soundtouch_set_rate');

  void setRate(ffi.Pointer<ffi.Void> handle, double rate) {
    _soundtouch_set_rate(handle, rate);
  }

  late final _soundtouch_set_tempo = _dylib.lookupFunction<
      ffi.Void Function(ffi.Pointer<ffi.Void>, ffi.Double),
      void Function(ffi.Pointer<ffi.Void>, double)>('soundtouch_set_tempo');

  void setTempo(ffi.Pointer<ffi.Void> handle, double tempo) {
    _soundtouch_set_tempo(handle, tempo);
  }

  late final _soundtouch_set_rate_change = _dylib.lookupFunction<
      ffi.Void Function(ffi.Pointer<ffi.Void>, ffi.Double),
      void Function(
          ffi.Pointer<ffi.Void>, double)>('soundtouch_set_rate_change');

  void setRateChange(ffi.Pointer<ffi.Void> handle, double rateChange) {
    _soundtouch_set_rate_change(handle, rateChange);
  }

  late final _soundtouch_set_tempo_change = _dylib.lookupFunction<
      ffi.Void Function(ffi.Pointer<ffi.Void>, ffi.Double),
      void Function(
          ffi.Pointer<ffi.Void>, double)>('soundtouch_set_tempo_change');

  void setTempoChange(ffi.Pointer<ffi.Void> handle, double tempoChange) {
    _soundtouch_set_tempo_change(handle, tempoChange);
  }

  late final _soundtouch_set_pitch = _dylib.lookupFunction<
      ffi.Void Function(ffi.Pointer<ffi.Void>, ffi.Double),
      void Function(ffi.Pointer<ffi.Void>, double)>('soundtouch_set_pitch');

  void setPitch(ffi.Pointer<ffi.Void> handle, double pitch) {
    _soundtouch_set_pitch(handle, pitch);
  }

  late final _soundtouch_set_pitch_octaves = _dylib.lookupFunction<
      ffi.Void Function(ffi.Pointer<ffi.Void>, ffi.Double),
      void Function(
          ffi.Pointer<ffi.Void>, double)>('soundtouch_set_pitch_octaves');

  void setPitchOctaves(ffi.Pointer<ffi.Void> handle, double pitchOctaves) {
    _soundtouch_set_pitch_octaves(handle, pitchOctaves);
  }

  late final _soundtouch_set_pitch_semitones = _dylib.lookupFunction<
      ffi.Void Function(ffi.Pointer<ffi.Void>, ffi.Double),
      void Function(
          ffi.Pointer<ffi.Void>, double)>('soundtouch_set_pitch_semitones');

  void setPitchSemiTones(ffi.Pointer<ffi.Void> handle, double pitchSemiTones) {
    _soundtouch_set_pitch_semitones(handle, pitchSemiTones);
  }

  // ========== 音频处理 ==========

  late final _soundtouch_put_samples = _dylib.lookupFunction<
      ffi.Void Function(
          ffi.Pointer<ffi.Void>, ffi.Pointer<ffi.Float>, ffi.Uint32),
      void Function(ffi.Pointer<ffi.Void>, ffi.Pointer<ffi.Float>,
          int)>('soundtouch_put_samples');

  void putSamples(ffi.Pointer<ffi.Void> handle, ffi.Pointer<ffi.Float> samples,
      int numSamples) {
    _soundtouch_put_samples(handle, samples, numSamples);
  }

  late final _soundtouch_receive_samples = _dylib.lookupFunction<
      ffi.Uint32 Function(
          ffi.Pointer<ffi.Void>, ffi.Pointer<ffi.Float>, ffi.Uint32),
      int Function(ffi.Pointer<ffi.Void>, ffi.Pointer<ffi.Float>,
          int)>('soundtouch_receive_samples');

  int receiveSamples(ffi.Pointer<ffi.Void> handle,
      ffi.Pointer<ffi.Float> output, int maxSamples) {
    return _soundtouch_receive_samples(handle, output, maxSamples);
  }

  late final _soundtouch_flush = _dylib.lookupFunction<
      ffi.Void Function(ffi.Pointer<ffi.Void>),
      void Function(ffi.Pointer<ffi.Void>)>('soundtouch_flush');

  void flush(ffi.Pointer<ffi.Void> handle) {
    _soundtouch_flush(handle);
  }

  late final _soundtouch_clear = _dylib.lookupFunction<
      ffi.Void Function(ffi.Pointer<ffi.Void>),
      void Function(ffi.Pointer<ffi.Void>)>('soundtouch_clear');

  void clear(ffi.Pointer<ffi.Void> handle) {
    _soundtouch_clear(handle);
  }

  // ========== 查询函数 ==========

  late final _soundtouch_num_samples = _dylib.lookupFunction<
      ffi.Uint32 Function(ffi.Pointer<ffi.Void>),
      int Function(ffi.Pointer<ffi.Void>)>('soundtouch_num_samples');

  int numSamples(ffi.Pointer<ffi.Void> handle) {
    return _soundtouch_num_samples(handle);
  }

  late final _soundtouch_num_unprocessed_samples = _dylib.lookupFunction<
      ffi.Uint32 Function(ffi.Pointer<ffi.Void>),
      int Function(
          ffi.Pointer<ffi.Void>)>('soundtouch_num_unprocessed_samples');

  int numUnprocessedSamples(ffi.Pointer<ffi.Void> handle) {
    return _soundtouch_num_unprocessed_samples(handle);
  }

  late final _soundtouch_is_empty = _dylib.lookupFunction<
      ffi.Int32 Function(ffi.Pointer<ffi.Void>),
      int Function(ffi.Pointer<ffi.Void>)>('soundtouch_is_empty');

  bool isEmpty(ffi.Pointer<ffi.Void> handle) {
    return _soundtouch_is_empty(handle) != 0;
  }

  late final _soundtouch_get_input_output_sample_ratio = _dylib.lookupFunction<
      ffi.Double Function(ffi.Pointer<ffi.Void>),
      double Function(
          ffi.Pointer<ffi.Void>)>('soundtouch_get_input_output_sample_ratio');

  double getInputOutputSampleRatio(ffi.Pointer<ffi.Void> handle) {
    return _soundtouch_get_input_output_sample_ratio(handle);
  }

  // ========== 版本信息 ==========

  late final _soundtouch_get_version_string = _dylib.lookupFunction<
      ffi.Pointer<Utf8> Function(),
      ffi.Pointer<Utf8> Function()>('soundtouch_get_version_string');

  String getVersionString() {
    return _soundtouch_get_version_string().toDartString();
  }

  late final _soundtouch_get_version_id =
      _dylib.lookupFunction<ffi.Uint32 Function(), int Function()>(
          'soundtouch_get_version_id');

  int getVersionId() {
    return _soundtouch_get_version_id();
  }

  // ========== 设置参数 ==========

  late final _soundtouch_set_setting = _dylib.lookupFunction<
      ffi.Int32 Function(ffi.Pointer<ffi.Void>, ffi.Int32, ffi.Int32),
      int Function(ffi.Pointer<ffi.Void>, int, int)>('soundtouch_set_setting');

  bool setSetting(ffi.Pointer<ffi.Void> handle, int settingId, int value) {
    return _soundtouch_set_setting(handle, settingId, value) != 0;
  }

  late final _soundtouch_get_setting = _dylib.lookupFunction<
      ffi.Int32 Function(ffi.Pointer<ffi.Void>, ffi.Int32),
      int Function(ffi.Pointer<ffi.Void>, int)>('soundtouch_get_setting');

  int getSetting(ffi.Pointer<ffi.Void> handle, int settingId) {
    return _soundtouch_get_setting(handle, settingId);
  }
}

/// SoundTouch 高级封装类
class SoundTouch {
  late final SoundTouchFFI _ffi;
  late final ffi.Pointer<ffi.Void> _handle;
  bool _disposed = false;

  final int track;
  final int channels;
  final int samplingRate;
  final int bytesPerSample;
  final double tempo;
  final int pitchSemi;

  static const int _bufferSizePut = 4096;

  /// 创建 SoundTouch 实例
  ///
  /// [track] 音轨ID（用于多音轨处理）
  /// [channels] 声道数，1=单声道, 2=立体声
  /// [samplingRate] 采样率，例如 44100, 48000
  /// [bytesPerSample] 每个样本的字节数，通常为 2（16位）
  /// [tempo] 节奏变化，1.0=正常, <1.0=变慢, >1.0=变快
  /// [pitchSemi] 音调变化（半音），-12 到 +12
  SoundTouch({
    required this.track,
    required this.channels,
    required this.samplingRate,
    required this.bytesPerSample,
    required this.tempo,
    required this.pitchSemi,
  }) {
    _ffi = SoundTouchFFI();
    _handle = _ffi.create();

    // 设置基本参数
    _ffi.setSampleRate(_handle, samplingRate);
    _ffi.setChannels(_handle, channels);

    // 设置音频效果
    _ffi.setTempo(_handle, tempo);
    _ffi.setPitchSemiTones(_handle, pitchSemi.toDouble());
    _ffi.setRateChange(_handle, 0);

    // 设置处理参数（与 Java 版本保持一致）
    _ffi.setSetting(_handle, SoundTouchSetting.useQuickSeek, 0);
    _ffi.setSetting(_handle, SoundTouchSetting.useAAFilter, 1);
  }

  /// 检查是否已释放
  void _checkDisposed() {
    if (_disposed) {
      throw StateError('SoundTouch instance has been disposed');
    }
  }

  // ========== 音频效果设置 ==========

  /// 设置速率（影响速度和音调）
  ///
  /// [rate] 速率值，1.0=正常, <1.0=变慢, >1.0=变快
  void setRate(double rate) {
    _checkDisposed();
    _ffi.setRate(_handle, rate);
  }

  /// 设置节奏（只影响速度，不影响音调）
  ///
  /// [tempo] 节奏值，1.0=正常, <1.0=变慢, >1.0=变快
  void setTempo(double tempo) {
    _checkDisposed();
    _ffi.setTempo(_handle, tempo);
  }

  /// 设置速率变化百分比
  ///
  /// [rateChange] 速率变化百分比，-50 到 +100
  void setRateChange(double rateChange) {
    _checkDisposed();
    _ffi.setRateChange(_handle, rateChange);
  }

  /// 设置节奏变化百分比
  ///
  /// [tempoChange] 节奏变化百分比，-50 到 +100
  void setTempoChange(double tempoChange) {
    _checkDisposed();
    _ffi.setTempoChange(_handle, tempoChange);
  }

  /// 设置音调（只影响音调，不影响速度）
  ///
  /// [pitch] 音调值，1.0=正常, <1.0=降低, >1.0=升高
  void setPitch(double pitch) {
    _checkDisposed();
    _ffi.setPitch(_handle, pitch);
  }

  /// 设置音调变化（八度）
  ///
  /// [pitchOctaves] 音调变化八度，-1.0 到 +1.0
  void setPitchOctaves(double pitchOctaves) {
    _checkDisposed();
    _ffi.setPitchOctaves(_handle, pitchOctaves);
  }

  /// 设置音调变化（半音）
  ///
  /// [pitchSemiTones] 音调变化半音，-12 到 +12
  ///
  /// 例如：
  /// - 男声变女声：+5 到 +7
  /// - 女声变男声：-5 到 -7
  void setPitchSemiTones(double pitchSemiTones) {
    _checkDisposed();
    _ffi.setPitchSemiTones(_handle, pitchSemiTones);
  }

  // ========== 音频处理==========

  /// 输入音频字节数据
  ///
  /// [input] 音频字节数据（16位 PCM 格式）
  void putBytes(Uint8List input) {
    _checkDisposed();

    final length = input.length;
    final numSamples = length ~/ bytesPerSample;

    // 将字节转换为 float 样本
    final floatBuffer = _convertBytesToFloat(input, numSamples);

    try {
      _ffi.putSamples(_handle, floatBuffer, numSamples ~/ channels);
    } finally {
      malloc.free(floatBuffer);
    }
  }

  /// 获取处理后的音频字节数据
  ///
  /// [output] 输出缓冲区
  /// 返回实际写入的字节数
  int getBytes(Uint8List output) {
    _checkDisposed();

    final maxSamples = output.length ~/ bytesPerSample;
    final floatBuffer = malloc<ffi.Float>(maxSamples);

    try {
      final numReceived =
          _ffi.receiveSamples(_handle, floatBuffer, maxSamples ~/ channels);

      if (numReceived == 0) {
        return 0;
      }

      // 将 float 样本转换为字节
      final bytesWritten =
          _convertFloatToBytes(floatBuffer, numReceived * channels, output);
      return bytesWritten;
    } finally {
      malloc.free(floatBuffer);
    }
  }

  /// 完成处理，刷新剩余数据
  ///
  /// 在写入最后一批字节后调用此方法
  void finish() {
    _checkDisposed();
    _ffi.flush(_handle);
  }

  /// 清空缓冲区
  void clearBuffer() {
    _checkDisposed();
    _ffi.clear(_handle);
  }

  // ========== 内部辅助方法 ==========

  /// 将字节数组转换为 float 样本（16位 PCM）
  ffi.Pointer<ffi.Float> _convertBytesToFloat(Uint8List input, int numSamples) {
    final floatBuffer = malloc<ffi.Float>(numSamples);
    const double conv = 1.0 / 32768.0;

    for (int i = 0; i < numSamples; i++) {
      // 16位小端序
      int byteIndex = i * 2;
      int value = input[byteIndex] | (input[byteIndex + 1] << 8);

      // 转换为有符号 16 位整数
      if (value >= 32768) {
        value -= 65536;
      }

      floatBuffer[i] = value * conv;
    }

    return floatBuffer;
  }

  /// 将 float 样本转换为字节数组（16位 PCM）
  int _convertFloatToBytes(
      ffi.Pointer<ffi.Float> floatBuffer, int numSamples, Uint8List output) {
    int bytesWritten = 0;

    for (int i = 0; i < numSamples && bytesWritten < output.length - 1; i++) {
      // 将 float 转换为 16 位整数
      double fValue = floatBuffer[i] * 32768.0;

      // 饱和处理
      if (fValue > 32767.0) {
        fValue = 32767.0;
      } else if (fValue < -32768.0) {
        fValue = -32768.0;
      }

      int value = fValue.toInt();

      // 转换为无符号 16 位整数
      if (value < 0) {
        value += 65536;
      }

      // 写入小端序字节
      output[bytesWritten++] = value & 0xFF;
      output[bytesWritten++] = (value >> 8) & 0xFF;
    }

    return bytesWritten;
  }

  /// 设置处理参数
  ///
  /// [settingId] 设置ID，使用 SoundTouchSetting 中的常量
  /// [value] 设置值
  bool setSetting(int settingId, int value) {
    _checkDisposed();
    return _ffi.setSetting(_handle, settingId, value);
  }

  /// 获取处理参数
  ///
  /// [settingId] 设置ID，使用 SoundTouchSetting 中的常量
  int getSetting(int settingId) {
    _checkDisposed();
    return _ffi.getSetting(_handle, settingId);
  }

  /// 获取可用的处理后样本数量
  int numSamples() {
    _checkDisposed();
    return _ffi.numSamples(_handle);
  }

  /// 检查是否为空（没有可用样本）
  bool isEmpty() {
    _checkDisposed();
    return _ffi.isEmpty(_handle);
  }

  /// 获取输入输出样本比率
  double getInputOutputSampleRatio() {
    _checkDisposed();
    return _ffi.getInputOutputSampleRatio(_handle);
  }

  // ========== 静态方法 ==========

  /// 获取 SoundTouch 版本字符串
  static String getVersionString() {
    final ffi = SoundTouchFFI();
    return ffi.getVersionString();
  }

  /// 获取 SoundTouch 版本ID
  static int getVersionId() {
    final ffi = SoundTouchFFI();
    return ffi.getVersionId();
  }

  /// 释放资源
  void dispose() {
    if (!_disposed) {
      _ffi.destroy(_handle);
      _disposed = true;
    }
  }
}
