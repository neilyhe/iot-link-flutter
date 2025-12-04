import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xp2p_sdk/xp2p_sdk.dart';
import 'package:iot_link_flutter/services/audio/audio_recorder.dart';
import 'package:iot_link_flutter/base/base_xp2p_stream_page.dart';

/// Mixin: 音频对讲能力
/// 提供音频录制、FLV打包、数据发送等功能
mixin AudioTalkCapability<T extends BaseXP2PStreamPage>
    on BaseXP2PStreamPageState<T> {
  late final AudioRecorderService audioRecorder;
  FLVPacker? flvPacker;
  String? currentFlvPath;

  /// 初始化音频录制服务
  void initAudioRecorder() {
    audioRecorder = AudioRecorderService();
    audioRecorder.addAACDataListener((aacData, timestamp) {
      sendAudioDataToDevice(aacData, timestamp);
    });
  }

  /// 发送音频数据到设备
  void sendAudioDataToDevice(Uint8List aacData, int timestamp) async {
    if (canSendAudio() && isConnected && flvPacker != null) {
      await flvPacker!.encodeAac(aacData, timestamp);
    } else {
      Logger.w(
          'AAC数据未处理: canSendAudio=${canSendAudio()}, isConnected=$isConnected, flvPacker=${flvPacker != null}',
          logTag);
    }
  }

  /// 发送FLV数据到设备
  void sendFlvDataToDevice(Uint8List flvData) {
    XP2P.dataSend(id: id, data: flvData);
  }

  /// 创建FLV打包器
  Future<FLVPacker?> createFlvPacker({
    required bool hasVideo,
    required String outputPath,
  }) async {
    final packer = FLVPacker();
    final success = await packer.init(
      hasAudio: true,
      hasVideo: hasVideo,
      outputPath: outputPath,
    );
    if (!success) {
      Logger.e('FLV打包器初始化失败', logTag);
      return null;
    }
    packer.setOnFLVDataCallback((flvData) {
      sendFlvDataToDevice(flvData);
    });

    return packer;
  }

  /// 启动XP2P发送服务
  Future<void> startXP2PSendService() async {
    final command = Command.getNvrIpcStatus(0, 0);
    final encode = utf8.encode(command);
    await XP2P.postCommandRequestSync(
        id: id, command: encode, timeoutUs: 2 * 1000 * 1000);
    XP2P.runSendService(id: id, cmd: Command.getTwoWayRadio(0), crypto: true);
  }

  /// 停止XP2P发送服务
  Future<void> stopXP2PSendService() async {
    XP2P.stopSendService(id);
    if (currentFlvPath != null) {
      final flvFile = File(currentFlvPath!);
      if (await flvFile.exists()) {
        final flvSize = await flvFile.length();
        Logger.i(
            'FLV文件已保存: $currentFlvPath, 大小: ${(flvSize / 1024).toStringAsFixed(2)} KB',
            logTag);
      }
      currentFlvPath = null;
    }
  }

  /// 获取FLV文件保存路径
  Future<String?> getFlvPath(String prefix) async {
    Directory? directory;
    if (Platform.isAndroid) {
      directory = await getExternalStorageDirectory();
    } else {
      directory = await getApplicationDocumentsDirectory();
    }

    if (directory == null) {
      Logger.e('无法获取存储目录', logTag);
      return null;
    }

    // 创建FLV文件目录
    final flvDir = Directory('${directory.path}/flv_recordings');
    if (!await flvDir.exists()) {
      await flvDir.create(recursive: true);
    }

    // 创建FLV文件，使用时间戳命名
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${prefix}_$timestamp.flv';
    return '${flvDir.path}/$fileName';
  }

  /// 释放音频对讲资源
  void disposeAudioTalk() {
    audioRecorder.dispose();
    flvPacker?.release();
  }

  // ========== 抽象方法 - 由子类实现 ==========
  /// 是否可以发送音频数据
  bool canSendAudio();
}
