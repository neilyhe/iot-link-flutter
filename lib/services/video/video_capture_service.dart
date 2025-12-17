import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xp2p_sdk/xp2p_sdk.dart' show Logger;
import 'package:iot_link_flutter/services/video/native_encoder.dart';

/// H.264视频数据回调
typedef H264DataCallback = void Function(Uint8List h264Data, int timestamp);

/// 视频采集服务
/// 负责使用相机采集视频并输出H.264编码数据
class VideoCaptureService {
  CameraController? _cameraController;
  bool _isInitialized = false;
  bool _isStreaming = false;

  final List<H264DataCallback> _h264DataListeners = [];
  final VideoEncoder _encoder = VideoEncoder();
  bool _encoderInitialized = false;

  // 文件保存相关
  File? _yuvFile;
  IOSink? _yuvFileSink;
  File? _h264File;
  IOSink? _h264FileSink;
  bool _isSavingToFile = false;

  late int _width;
  late int _height;

  /// 添加H.264数据监听器
  void addH264DataListener(H264DataCallback callback) {
    _h264DataListeners.add(callback);
  }

  /// 移除H.264数据监听器
  void removeH264DataListener(H264DataCallback callback) {
    _h264DataListeners.remove(callback);
  }

  /// 初始化相机
  Future<bool> initialize() async {
    try {
      if (_isInitialized) {
        Logger.w('视频采集服务已初始化', 'VideoCapture');
        return true;
      }

      // 获取可用相机列表
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        Logger.e('没有可用的相机', 'VideoCapture');
        return false;
      }

      // 优先使用前置摄像头
      CameraDescription? frontCamera;
      CameraDescription? backCamera;

      for (var camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.front) {
          frontCamera = camera;
        } else if (camera.lensDirection == CameraLensDirection.back) {
          backCamera = camera;
        }
      }

      final selectedCamera = frontCamera ?? backCamera ?? cameras.first;
      Logger.i('选择相机: ${selectedCamera.name}', 'VideoCapture');

      // 创建相机控制器
      _cameraController = CameraController(
        selectedCamera,
        ResolutionPreset.medium, // 中等分辨率，平衡质量和性能
        enableAudio: false, // 音频由AudioRecorderService处理
        imageFormatGroup: ImageFormatGroup.yuv420, // YUV420格式
      );

      // 初始化相机
      await _cameraController!.initialize();

      // 初始化H.264编码器
      final cameraValue = _cameraController!.value;
      _width = cameraValue.previewSize?.height.toInt() ?? 640;
      _height = cameraValue.previewSize?.width.toInt() ?? 480;

      _isInitialized = true;
      Logger.i('视频采集服务初始化成功', 'VideoCapture');
      return true;
    } catch (e) {
      Logger.eWithException('视频采集服务初始化失败', e, 'VideoCapture');
      return false;
    }
  }

  /// 开始视频流采集
  Future<bool> startStreaming() async {
    if (!_isInitialized || _cameraController == null) {
      Logger.e('视频采集服务未初始化', 'VideoCapture');
      return false;
    }

    if (_isStreaming) {
      Logger.w('视频流已在采集中', 'VideoCapture');
      return true;
    }

    try {
      // 开始图像流
      await _cameraController!.startImageStream(_onImageAvailable);
      _isStreaming = true;
      _encoderInitialized = await _encoder.initialize(
        width: _width, height: _height, fps: 30, bitrate: 1000000, // 1Mbps
      );

      if (!_encoderInitialized) {
        Logger.w('H.264编码器初始化失败，将无法编码视频', 'VideoCapture');
      } else {
        Logger.i('H.264编码器初始化成功: ${_width}x${_height}', 'VideoCapture');
      }
      Logger.i('开始视频流采集', 'VideoCapture');
      return true;
    } catch (e) {
      Logger.eWithException('启动视频流失败', e, 'VideoCapture');
      return false;
    }
  }

  /// 停止视频流采集
  Future<void> stopStreaming() async {
    if (!_isStreaming || _cameraController == null) {
      return;
    }
    // 释放编码器（必须在相机之前释放）
    if (_encoderInitialized) {
      await _encoder.release();
      _encoderInitialized = false;
    }
    try {
      await _cameraController!.stopImageStream();
      _isStreaming = false;
      Logger.i('停止视频流采集', 'VideoCapture');
    } catch (e) {
      Logger.eWithException('停止视频流失败', e, 'VideoCapture');
    }
  }

  /// 处理相机图像数据
  void _onImageAvailable(CameraImage image) async {
    try {
      final yuvData = _convertCameraImageToYUV420(image);
      if (yuvData == null) {
        return;
      }

      if (_isSavingToFile && _yuvFileSink != null) {
        _saveYuvDataToFile(yuvData);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      // 使用硬件编码器（Android: MediaCodec, iOS: VideoToolbox）
      _convertToH264WithYuvData(yuvData, timestamp);
    } catch (e) {
      Logger.e('处理图像数据失败: $e', 'VideoCapture');
    }
  }

  /// 将YUV420数据转换为H.264编码数据
  /// 使用平台原生编码器（Android: MediaCodec, iOS: VideoToolbox）
  void _convertToH264WithYuvData(Uint8List yuvData, int timestamp) {
    if (!_encoderInitialized) {
      Logger.w('编码器未初始化', 'VideoCapture');
      return;
    }

    _encoder.encodeFrame(yuvData, true).then((h264Data) {
      try {
        if (h264Data != null && h264Data.isNotEmpty) {
          if (_isSavingToFile && _h264FileSink != null) {
            _saveH264DataToFile(h264Data);
          }
          for (var listener in _h264DataListeners) {
            listener(h264Data, timestamp);
          }
        }
      } catch (e) {
        Logger.e('处理H.264数据失败: $e', 'VideoCapture');
      }
    }).catchError((e) {
      Logger.e('H.264编码失败: $e', 'VideoCapture');
    });
  }

  /// 将CameraImage转换为YUV420字节数组
  Uint8List? _convertCameraImageToYUV420(CameraImage image) {
    try {
      final int width = image.width;
      final int height = image.height;

      // YUV420格式：Y平面 + U平面 + V平面
      // Y: width * height
      // U: (width * height) / 4
      // V: (width * height) / 4
      final int ySize = width * height;
      final int uvSize = ySize ~/ 4;
      final int totalSize = ySize + uvSize * 2;

      final Uint8List yuv420 = Uint8List(totalSize);

      // 处理Y平面
      final yPlane = image.planes[0];
      final int yRowStride = yPlane.bytesPerRow;
      final int yPixelStride = yPlane.bytesPerPixel ?? 1;

      if (yPixelStride == 1 && yRowStride == width) {
        // 数据是连续的，直接复制
        yuv420.setRange(0, ySize, yPlane.bytes);
      } else {
        // 数据有padding，需要逐行复制
        for (int row = 0; row < height; row++) {
          final int srcOffset = row * yRowStride;
          final int dstOffset = row * width;
          for (int col = 0; col < width; col++) {
            yuv420[dstOffset + col] = yPlane.bytes[srcOffset + col * yPixelStride];
          }
        }
      }

      // 处理U和V平面
      if (image.planes.length == 3) {
        // Android格式：3个独立的平面 (Y, U, V)
        final uPlane = image.planes[1];
        final vPlane = image.planes[2];

        final int uvWidth = width ~/ 2;
        final int uvHeight = height ~/ 2;
        final int uRowStride = uPlane.bytesPerRow;
        final int vRowStride = vPlane.bytesPerRow;
        final int uPixelStride = uPlane.bytesPerPixel ?? 1;
        final int vPixelStride = vPlane.bytesPerPixel ?? 1;

        int uIndex = ySize;
        int vIndex = ySize + uvSize;

        for (int row = 0; row < uvHeight; row++) {
          for (int col = 0; col < uvWidth; col++) {
            final int uOffset = row * uRowStride + col * uPixelStride;
            final int vOffset = row * vRowStride + col * vPixelStride;

            yuv420[uIndex++] = uPlane.bytes[uOffset];
            yuv420[vIndex++] = vPlane.bytes[vOffset];
          }
        }
      } else if (image.planes.length == 2) {
        // iOS格式：2个平面 (Y, UV交错)
        final uvPlane = image.planes[1];
        final int uvRowStride = uvPlane.bytesPerRow;
        final int uvPixelStride = uvPlane.bytesPerPixel ?? 2;

        final int uvWidth = width ~/ 2;
        final int uvHeight = height ~/ 2;

        int uIndex = ySize;
        int vIndex = ySize + uvSize;

        for (int row = 0; row < uvHeight; row++) {
          for (int col = 0; col < uvWidth; col++) {
            final int uvOffset = row * uvRowStride + col * uvPixelStride;

            // UV交错存储，U在偶数位置，V在奇数位置
            yuv420[uIndex++] = uvPlane.bytes[uvOffset];
            yuv420[vIndex++] = uvPlane.bytes[uvOffset + 1];
          }
        }
      } else {
        Logger.e('不支持的图像平面数量: ${image.planes.length}', 'VideoCapture');
        return null;
      }
      
      return yuv420;
    } catch (e) {
      Logger.e('转换YUV420失败: $e', 'VideoCapture');
      return null;
    }
  }

  /// 获取相机控制器（用于预览）
  CameraController? get cameraController => _cameraController;

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 是否正在采集
  bool get isStreaming => _isStreaming;

  /// 开始保存到文件
  Future<bool> startSavingToFile() async {
    if (_isSavingToFile) {
      Logger.w('已经在保存文件中', 'VideoCapture');
      return true;
    }

    try {
      Directory? directory;

      // Android平台使用外部存储目录
      // iOS平台使用应用文档目录
      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        Logger.e('无法获取存储目录', 'VideoCapture');
        return false;
      }

      // 创建视频文件目录
      final videoDir = Directory('${directory.path}/video_recordings');
      if (!await videoDir.exists()) {
        await videoDir.create(recursive: true);
      }

      // 创建文件，使用时间戳命名
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // 创建YUV文件
      _yuvFile = File('${videoDir.path}/video_$timestamp.yuv');
      _yuvFileSink = _yuvFile!.openWrite(mode: FileMode.writeOnlyAppend);
      
      // 创建H.264文件
      _h264File = File('${videoDir.path}/video_$timestamp.h264');
      _h264FileSink = _h264File!.openWrite(mode: FileMode.writeOnlyAppend);

      _isSavingToFile = true;
      Logger.i('开始保存视频文件:\nYUV: ${_yuvFile!.path}\nH.264: ${_h264File!.path}', 'VideoCapture');
      return true;
    } catch (e) {
      Logger.e('创建视频文件失败: $e', 'VideoCapture');
      return false;
    }
  }

  /// 停止保存到文件
  Future<void> stopSavingToFile() async {
    if (!_isSavingToFile) {
      return;
    }

    try {
      // 关闭YUV文件
      if (_yuvFileSink != null) {
        await _yuvFileSink!.flush();
        await _yuvFileSink!.close();
        Logger.i('YUV文件已保存: ${_yuvFile?.path}', 'VideoCapture');
        _yuvFileSink = null;
      }

      // 关闭H.264文件
      if (_h264FileSink != null) {
        await _h264FileSink!.flush();
        await _h264FileSink!.close();
        Logger.i('H.264文件已保存: ${_h264File?.path}', 'VideoCapture');
        _h264FileSink = null;
      }

      _isSavingToFile = false;
    } catch (e) {
      Logger.e('关闭视频文件失败: $e', 'VideoCapture');
    }
  }

  /// 保存YUV数据到文件
  void _saveYuvDataToFile(Uint8List yuvData) {
    try {
      if (_yuvFileSink != null) {
        _yuvFileSink!.add(yuvData);
      }
    } catch (e) {
      Logger.e('保存YUV数据失败: $e', 'VideoCapture');
    }
  }

  /// 保存H.264数据到文件
  void _saveH264DataToFile(Uint8List h264Data) {
    try {
      if (_h264FileSink != null) {
        _h264FileSink!.add(h264Data);
      }
    } catch (e) {
      Logger.e('保存H.264数据失败: $e', 'VideoCapture');
    }
  }

  bool get isSavingToFile => _isSavingToFile;

  String? get currentYuvFilePath => _yuvFile?.path;

  String? get currentH264FilePath => _h264File?.path;

  /// 释放资源
  Future<void> dispose() async {
    try {
      if (_isStreaming) {
        await stopStreaming();
      }

      // 停止文件保存
      if (_isSavingToFile) {
        await stopSavingToFile();
      }

      if (_cameraController != null) {
        await _cameraController!.dispose();
        _cameraController = null;
      }

      // 释放编码器
      if (_encoderInitialized) {
        await _encoder.release();
        _encoderInitialized = false;
      }

      _h264DataListeners.clear();
      _isInitialized = false;
      Logger.i('视频采集服务已释放', 'VideoCapture');
    } catch (e) {
      Logger.eWithException('释放视频采集服务失败', e, 'VideoCapture');
    }
  }

  /// 切换摄像头
  Future<bool> switchCamera() async {
    if (!_isInitialized) {
      return false;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.length < 2) {
        Logger.w('只有一个摄像头，无法切换', 'VideoCapture');
        return false;
      }

      final currentLensDirection = _cameraController!.description.lensDirection;
      CameraDescription? newCamera;

      for (var camera in cameras) {
        if (camera.lensDirection != currentLensDirection) {
          newCamera = camera;
          break;
        }
      }

      if (newCamera == null) {
        return false;
      }

      // 停止当前流
      final wasStreaming = _isStreaming;
      if (wasStreaming) {
        await stopStreaming();
      }

      // 释放当前控制器
      await _cameraController!.dispose();

      // 创建新控制器
      _cameraController = CameraController(
        newCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();

      // 如果之前在采集，重新开始
      if (wasStreaming) {
        await startStreaming();
      }

      Logger.i('切换到摄像头: ${newCamera.name}', 'VideoCapture');
      return true;
    } catch (e) {
      Logger.eWithException('切换摄像头失败', e, 'VideoCapture');
      return false;
    }
  }
}
