import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';

/// iOS平台AAC编码器服务
/// 用于将PCM音频数据实时转换为AAC格式
class AACEncoderService {
  static const MethodChannel _channel = MethodChannel('aac_encoder');
  static const EventChannel _eventChannel = EventChannel('aac_encoder/stream');
  
  bool _isInitialized = false;
  
  /// 初始化编码器
  Future<bool> initEncoder() async {
    if (!Platform.isIOS) {
      return false;
    }
    
    try {
      final result = await _channel.invokeMethod('initEncoder');
      _isInitialized = result == true;
      return _isInitialized;
    } catch (e) {
      print('[AACEncoder] 初始化失败: $e');
      return false;
    }
  }
  
  /// 编码PCM数据为AAC
  /// 
  /// [pcmData] PCM 16bit 单声道音频数据
  /// 返回AAC编码后的数据，如果缓冲区数据不足一帧则返回null
  Future<Uint8List?> encodePCM(Uint8List pcmData) async {
    if (!Platform.isIOS) {
      // Android平台直接返回原始数据（Android的record插件可以直接输出AAC）
      return pcmData;
    }
    
    if (!_isInitialized) {
      return null;
    }
    
    try {
      final result = await _channel.invokeMethod('encodePCM', {
        'pcmData': pcmData,
      });
      
      if (result != null) {
        return result as Uint8List;
      }
      return null;
    } catch (e) {
      print('[AACEncoder] 编码失败: $e');
      return null;
    }
  }
  
  /// 释放编码器资源
  Future<void> releaseEncoder() async {
    if (!Platform.isIOS || !_isInitialized) {
      return;
    }
    
    try {
      await _channel.invokeMethod('releaseEncoder');
      _isInitialized = false;
    } catch (e) {
      print('[AACEncoder] 释放失败: $e');
    }
  }
  
  /// 检查是否已初始化
  bool get isInitialized => _isInitialized;
}
