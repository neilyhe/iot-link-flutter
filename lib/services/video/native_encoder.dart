import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'package:xp2p_sdk/src/log/logger.dart';

/// 视频编码器
/// 使用平台原生编码器将YUV420数据编码为H.264
class VideoEncoder {
  static const MethodChannel _channel = MethodChannel('video_encoder');

  bool _isInitialized = false;
  int _width = 0;
  int _height = 0;

  /// 初始化编码器
  /// [width] 视频宽度
  /// [height] 视频高度
  /// [fps] 帧率
  /// [bitrate] 比特率（bps）
  Future<bool> initialize({
    required int width,
    required int height,
    required int fps,
    required int bitrate,
  }) async {
    try {
      if (_isInitialized) {
        Logger.w('编码器已初始化', 'VideoEncoder');
        return true;
      }

      Logger.i('初始化编码器: ${width}x${height}, fps=$fps, bitrate=$bitrate', 'VideoEncoder');

      final result = await _channel.invokeMethod('initialize', {
        'width': width,
        'height': height,
        'fps': fps,
        'bitrate': bitrate,
      });

      _isInitialized = result == true;
      if (_isInitialized) {
        _width = width;
        _height = height;
        Logger.i('编码器初始化成功', 'VideoEncoder');
      } else {
        Logger.e('编码器初始化失败', 'VideoEncoder');
      }

      return _isInitialized;
    } catch (e) {
      Logger.eWithException('初始化编码器异常', e, 'VideoEncoder');
      return false;
    }
  }

  /// 编码单帧YUV420数据
  /// [yuvData] YUV420格式的原始数据
  /// 返回H.264编码后的数据（包含NALU）
  Future<Uint8List?> encodeFrame(Uint8List yuvData, bool mirror) async {
    try {
      if (!_isInitialized) {
        Logger.w('编码器未初始化', 'VideoEncoder');
        return null;
      }

      // 验证数据大小
      final expectedSize = (_width * _height * 3) ~/ 2; // YUV420: 1.5 bytes per pixel
      if (yuvData.length != expectedSize) {
        Logger.e('YUV数据大小不匹配: 期望$expectedSize, 实际${yuvData.length}', 'VideoEncoder');
        return null;
      }

      final result = await _channel.invokeMethod('encodeFrame', {
        'yuvData': yuvData,'mirror': mirror
      });

      if (result != null && result is Uint8List) {
        return result;
      }

      return null;
    } catch (e) {
      Logger.e('编码帧异常: $e', 'VideoEncoder');
      return null;
    }
  }

  /// 释放编码器资源
  Future<void> release() async {
    try {
      if (!_isInitialized) {
        return;
      }

      await _channel.invokeMethod('release');
      _isInitialized = false;
      _width = 0;
      _height = 0;
      Logger.i('编码器已释放', 'VideoEncoder');
    } catch (e) {
      Logger.eWithException('释放编码器异常', e, 'VideoEncoder');
    }
  }

  /// 是否已初始化
  bool get isInitialized => _isInitialized;
}