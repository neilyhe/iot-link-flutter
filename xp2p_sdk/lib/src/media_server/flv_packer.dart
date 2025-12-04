import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:xp2p_sdk/src/log/logger.dart';
import 'flv_ffi_bindings.dart';

typedef FLVDataCallback = void Function(Uint8List flvData);

class FLVPacker {
  late final FlvFfiBindings _bindings;
  ffi.Pointer<ffi.Void>? _muxer;
  ffi.Pointer<ffi.Void>? _writer;
  ffi.Pointer<ffi.NativeFunction<FlvMuxerHandlerNative>>? _muxerHandlerPtr;
  ffi.Pointer<ffi.NativeFunction<FlvWriterOnwriteNative>>? _writerCallbackPtr;

  FLVDataCallback? _onFLVData;
  bool _isInitialized = false;

  final List<int> _flvBuffer = [];

  File? _outputFile;
  IOSink? _fileSink;

  // 使用实例映射来处理回调
  static final Map<int, FLVPacker> _instances = {};
  late final int _instanceId;

  FLVPacker() {
    _bindings = FlvFfiBindings();
    _instanceId = DateTime.now().microsecondsSinceEpoch;
    _instances[_instanceId] = this;
  }

  /// 初始化FLV打包器
  /// [hasAudio] 是否包含音频
  /// [hasVideo] 是否包含视频
  /// [outputPath] 输出文件路径（可选）
  Future<bool> init({
    bool hasAudio = true,
    bool hasVideo = false,
    String? outputPath,
  }) async {
    try {
      if (_isInitialized) {
        Logger.e('FLV打包器已经初始化，请先释放再重新初始化', 'FLVPacker');
        return false;
      }

      // 清空缓冲区
      _flvBuffer.clear();

      if (outputPath != null) {
        _outputFile = File(outputPath);
        _fileSink = _outputFile!.openWrite();
        Logger.d('FLV输出文件: $outputPath', 'FLVPacker');
      }

      _writerCallbackPtr = ffi.Pointer.fromFunction<FlvWriterOnwriteNative>(
        _onWriteCallback,
        0,
      );
      // 将实例ID作为参数传递给native层
      final paramPtr = ffi.Pointer<ffi.Int64>.fromAddress(_instanceId);
      _writer = _bindings.flvWriterCreate2(
        hasAudio ? 1 : 0,
        hasVideo ? 1 : 0,
        _writerCallbackPtr!,
        paramPtr.cast<ffi.Void>(),
      );

      if (_writer == ffi.nullptr) {
        Logger.e('创建FLV Writer失败', 'FLVPacker');
        return false;
      }

      _muxerHandlerPtr = ffi.Pointer.fromFunction<FlvMuxerHandlerNative>(
        _onMuxerCallback,
        0,
      );
      _muxer = _bindings.flvMuxerCreate(_muxerHandlerPtr!, _writer!);

      if (_muxer == ffi.nullptr) {
        Logger.e('创建FLV Muxer失败', 'FLVPacker');
        _bindings.flvWriterDestroy(_writer!);
        _writer = null;
        return false;
      }

      _isInitialized = true;
      Logger.d(
          'FLV打包器初始化成功 (hasAudio=$hasAudio, hasVideo=$hasVideo)', 'FLVPacker');
      return true;
    } catch (e) {
      Logger.eWithException('FLV打包器初始化失败: $e', 'FLVPacker');
      return false;
    }
  }

  static int _onMuxerCallback(
    ffi.Pointer<ffi.Void> param,
    int type,
    ffi.Pointer<ffi.Void> data,
    int bytes,
    int timestamp,
  ) {
    try {
      final bindings = FlvFfiBindings();
      return bindings.flvWriterInput(param, type, data, bytes, timestamp);
    } catch (e) {
      Logger.eWithException('Muxer回调错误: $e', 'FLVPacker');
      return -1;
    }
  }

  static int _onWriteCallback(
    ffi.Pointer<ffi.Void> param,
    ffi.Pointer<FlvVec> vec,
    int n,
  ) {
    try {
      // 从参数中获取实例ID
      final instanceId = param.address;
      final instance = _instances[instanceId];
      
      if (instance == null) {
        Logger.e('找不到FLVPacker实例: $instanceId', 'FLVPacker');
        return -1;
      }

      int totalSize = 0;
      for (int i = 0; i < n; i++) {
        final v = vec.elementAt(i).ref;
        totalSize += v.len;
      }

      final flvData = Uint8List(totalSize);
      int offset = 0;
      for (int i = 0; i < n; i++) {
        final v = vec.elementAt(i).ref;
        final dataPtr = v.ptr.cast<ffi.Uint8>();
        for (int j = 0; j < v.len; j++) {
          flvData[offset++] = dataPtr.elementAt(j).value;
        }
      }
      instance._handleFlvData(flvData);
      return 0;
    } catch (e) {
      Logger.eWithException('Writer回调错误: $e', 'FLVPacker');
      return -1;
    }
  }

  void _handleFlvData(Uint8List flvData) {
    _flvBuffer.addAll(flvData);
    if (_fileSink != null) {
      _fileSink!.add(flvData);
    }
    _onFLVData?.call(flvData);
  }

  /// 设置FLV数据回调
  void setOnFLVDataCallback(FLVDataCallback callback) {
    _onFLVData = callback;
  }

  Future<int> encodeAac(Uint8List aacData, int timestamp) async {
    if (!_isInitialized || _muxer == null) {
      Logger.e('FLV打包器未初始化', 'FLVPacker');
      return -1;
    }

    try {
      final dataPtr = malloc.allocate<ffi.Uint8>(aacData.length);
      for (int i = 0; i < aacData.length; i++) {
        dataPtr.elementAt(i).value = aacData[i];
      }
      final result = _bindings.flvMuxerAac(
        _muxer!,
        dataPtr.cast<ffi.Void>(),
        aacData.length,
        timestamp,
        timestamp,
      );
      malloc.free(dataPtr);

      return result;
    } catch (e) {
      Logger.eWithException('编码AAC失败: $e', 'FLVPacker');
      return -1;
    }
  }

  /// 编码H.264/AVC视频数据到FLV
  /// [avcData] H.264/AVC视频数据（AVCC格式）
  /// [timestamp] 时间戳（毫秒）
  /// [dts] 解码时间戳（可选，默认与pts相同）
  /// 返回0表示成功，-1表示失败
  Future<int> encodeAvc(Uint8List avcData, int timestamp, {int? dts}) async {
    if (!_isInitialized || _muxer == null) {
      Logger.e('FLV打包器未初始化', 'FLVPacker');
      return -1;
    }

    try {
      final dataPtr = malloc.allocate<ffi.Uint8>(avcData.length);
      for (int i = 0; i < avcData.length; i++) {
        dataPtr.elementAt(i).value = avcData[i];
      }
      final result = _bindings.flvMuxerAvc(
        _muxer!,
        dataPtr.cast<ffi.Void>(),
        avcData.length,
        timestamp,
        dts ?? timestamp,
      );
      malloc.free(dataPtr);

      return result;
    } catch (e) {
      Logger.eWithException('编码AVC失败: $e', 'FLVPacker');
      return -1;
    }
  }

  Uint8List getBufferedData() {
    return Uint8List.fromList(_flvBuffer);
  }

  void clearBuffer() {
    _flvBuffer.clear();
  }

  Future<void> flush() async {
    await _fileSink?.flush();
  }

  Future<void> release() async {
    try {
      // 从实例映射中移除
      _instances.remove(_instanceId);

      if (_fileSink != null) {
        await _fileSink!.flush();
        await _fileSink!.close();
        _fileSink = null;
        Logger.d('FLV文件已保存: ${_outputFile?.path}', 'FLVPacker');
      }

      if (_muxer != null && _muxer != ffi.nullptr) {
        _bindings.flvMuxerDestroy(_muxer!);
        _muxer = null;
      }

      if (_writer != null && _writer != ffi.nullptr) {
        _bindings.flvWriterDestroy(_writer!);
        _writer = null;
      }

      _isInitialized = false;
      _flvBuffer.clear();
      _onFLVData = null;
    } catch (e) {
      Logger.e('释放FLV打包器失败: $e', 'FLVPacker');
    }
  }
}