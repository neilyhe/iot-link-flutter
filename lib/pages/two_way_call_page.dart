import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:xp2p_sdk/xp2p_sdk.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:iot_link_flutter/base/base_xp2p_stream_page.dart';
import 'package:iot_link_flutter/base/capabilities/audio_talk_capability.dart';
import 'package:iot_link_flutter/base/capabilities/video_capture_capability.dart';

/// IPC双向通话页面
/// 实现音视频双向通信功能
class TwoWayCallPage extends BaseXP2PStreamPage {
  const TwoWayCallPage({
    super.key,
    required super.productId,
    required super.deviceName,
    required super.p2pInfo,
  });

  @override
  State<TwoWayCallPage> createState() => _TwoWayCallPageState();
}

class _TwoWayCallPageState extends BaseXP2PStreamPageState<TwoWayCallPage>
    with AudioTalkCapability, VideoCaptureCapability {
  bool _isCalling = false;

  @override
  String get logTag => 'TwoWayCall';

  @override
  void onInitServices() {
    initAudioRecorder();
    initVideoCapture();
  }

  @override
  bool canSendAudio() => _isCalling;

  @override
  bool canSendVideo() => _isCalling && isConnected;

  @override
  bool canSwitchCamera() => _isCalling;

  @override
  void onP2PDisconnect() {
    super.onP2PDisconnect();
    if (mounted) {
      setState(() {
        _isCalling = false;
      });
    }
  }

  /// 开始/停止通话
  Future<void> _toggleCall() async {
    if (_isCalling) {
      await _stopCall();
    } else {
      await _startCall();
    }
  }

  /// 开始通话
  Future<void> _startCall() async {
    try {
      Logger.i('开始双向通话', logTag);

      // 请求权限
      final cameraStatus = await Permission.camera.request();
      final micStatus = await Permission.microphone.request();

      if (!cameraStatus.isGranted || !micStatus.isGranted) {
        showMessage('需要相机和麦克风权限');
        return;
      }

      // 初始化视频采集
      final videoInitSuccess = await videoCapture.initialize();
      if (!videoInitSuccess) {
        Logger.e('视频采集初始化失败', logTag);
        showMessage('视频采集初始化失败');
        return;
      }

      // 创建FLV文件路径
      currentFlvPath = await getFlvPath('two_way_call');
      if (currentFlvPath == null) {
        await videoCapture.dispose();
        return;
      }

      flvPacker = await createFlvPacker(
        hasVideo: true,
        outputPath: currentFlvPath!,
      );

      // 启动XP2P发送服务
      await startXP2PSendService();

      // 开始音频录制
      final audioSuccess = await audioRecorder.startStreamRecording();
      if (!audioSuccess) {
        Logger.e('音频录制启动失败', logTag);
        return;
      }

      // 开始视频采集
      final videoSuccess = await videoCapture.startStreaming();
      if (!videoSuccess) {
        Logger.e('视频采集启动失败', logTag);
        return;
      }

      if (mounted) {
        setState(() {
          _isCalling = true;
          statusText = '通话中...';
        });
      }

      Logger.i('双向通话已启动', logTag);
    } catch (e) {
      Logger.eWithException('启动双向通话失败', e, logTag);
      if (mounted) {
        setState(() {
          statusText = '启动通话失败: $e';
        });
      }
    }
  }

  /// 停止通话
  Future<void> _stopCall() async {
    try {
      Logger.i('停止双向通话', logTag);
      // 停止XP2P发送服务
      await stopXP2PSendService();
      await flvPacker?.release();
      // 停止视频采集
      await videoCapture.stopStreaming();

      // 停止音频录制
      await audioRecorder.stopRecording();


      if (mounted) {
        setState(() {
          _isCalling = false;
          statusText = '通话已结束';
        });
      }

      Logger.i('双向通话已停止', logTag);
    } catch (e) {
      Logger.eWithException('停止双向通话失败', e, logTag);
    }
  }

  @override
  void dispose() {
    if (_isCalling) {
      _stopCall();
    }
    disposeAudioTalk();
    disposeVideoCapture();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IPC双向通话'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isCalling)
            IconButton(
              icon: const Icon(Icons.switch_camera),
              onPressed: switchCamera,
              tooltip: '切换摄像头',
            ),
        ],
      ),
      body: Column(
        children: [
          // 状态显示
          buildStatusBar(),

          // 视频预览区域
          Expanded(
            child: Container(
              color: Colors.black,
              child: Stack(
                children: [
                  // 主视频区域：显示对端视频流
                  Center(
                    child: isConnected
                        ? buildBaseVideoArea()
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(
                                color: Colors.white54,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                isConnected ? '正在连接对端视频...' : '等待设备连接...',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                  ),

                  // 小窗口：显示本地摄像头画面（仅在通话时显示）
                  if (_isCalling && videoCapture.isInitialized)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        width: 120,
                        height: 160,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: CameraPreview(videoCapture.cameraController!),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 控制按钮区域
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // 主通话按钮
                SizedBox(
                  width: 80,
                  height: 80,
                  child: FloatingActionButton(
                    onPressed: isConnected ? _toggleCall : null,
                    backgroundColor: _isCalling ? Colors.red : Colors.green,
                    child: Icon(
                      _isCalling ? Icons.call_end : Icons.call,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _isCalling ? '结束通话' : '开始通话',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '设备: ${widget.deviceName}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}