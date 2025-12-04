import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:xp2p_sdk/xp2p_sdk.dart';
import '../base_xp2p_stream_page.dart';
import 'package:iot_link_flutter/base/capabilities/audio_talk_capability.dart';
import 'package:iot_link_flutter/services/video/video_capture_service.dart';

/// Mixin: 视频采集能力
/// 提供视频采集、摄像头切换等功能
/// 依赖 AudioTalkCapability 提供的 flvPacker
mixin VideoCaptureCapability<T extends BaseXP2PStreamPage>
    on BaseXP2PStreamPageState<T>, AudioTalkCapability<T> {
  late final VideoCaptureService videoCapture;

  /// 初始化视频采集服务
  void initVideoCapture() {
    videoCapture = VideoCaptureService();
    videoCapture.addH264DataListener((h264Data, timestamp) {
      sendVideoDataToDevice(h264Data, timestamp);
    });
  }

  /// 发送视频数据到设备
  void sendVideoDataToDevice(Uint8List h264Data, int timestamp) async {
    if (canSendVideo() && flvPacker != null) {
      await flvPacker!.encodeAvc(h264Data, timestamp);
    }
  }

  /// 切换摄像头
  Future<void> switchCamera() async {
    if (canSwitchCamera()) {
      final success = await videoCapture.switchCamera();
      if (success) {
        showMessage('已切换摄像头');
      }
    }
  }

  /// 释放视频采集资源
  void disposeVideoCapture() {
    videoCapture.dispose();
  }

  // ========== 抽象方法 - 由子类实现 ==========
  /// 是否可以发送视频数据
  bool canSendVideo();

  /// 是否可以切换摄像头
  bool canSwitchCamera();
}
