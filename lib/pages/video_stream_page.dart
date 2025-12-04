import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:xp2p_sdk/xp2p_sdk.dart';
import 'package:path_provider/path_provider.dart';
import 'package:iot_link_flutter/base/base_xp2p_stream_page.dart';
import 'package:iot_link_flutter/base/capabilities/audio_talk_capability.dart';

/// 视频拉流页面
class VideoStreamPage extends BaseXP2PStreamPage {
  const VideoStreamPage({
    super.key,
    required super.productId,
    required super.deviceName,
    required super.p2pInfo,
  });

  @override
  State<VideoStreamPage> createState() => _VideoStreamPageState();
}

class _VideoStreamPageState extends BaseXP2PStreamPageState<VideoStreamPage>
    with AudioTalkCapability {
  bool _isTalking = false;

  // AAC文件保存相关
  File? _aacFile;
  IOSink? _aacFileSink;

  @override
  String get logTag => 'VideoStream';

  @override
  void onInitServices() {
    initAudioRecorder();
  }

  @override
  bool canSendAudio() => _isTalking;

  @override
  void onPlayerEvent(V2TXLivePlayerListenerType type, dynamic param) {
    if (type == V2TXLivePlayerListenerType.onSnapshotComplete) {
      if (param is Map && param.containsKey('image')) {
        _saveSnapshotImage(param);
      }
    }
  }

  /// 初始化AAC文件
  Future<void> _initAacFile() async {
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
        Logger.e('无法获取存储目录', logTag);
        return;
      }

      // 创建AAC文件目录
      final aacDir = Directory('${directory.path}/aac_recordings');
      if (!await aacDir.exists()) {
        await aacDir.create(recursive: true);
      }

      // 创建AAC文件，使用时间戳命名
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'audio_talk_$timestamp.aac';
      _aacFile = File('${aacDir.path}/$fileName');

      // 打开文件写入流
      _aacFileSink = _aacFile!.openWrite(mode: FileMode.writeOnlyAppend);

      Logger.i('AAC文件已创建: ${_aacFile!.path}', logTag);
    } catch (e) {
      Logger.e('创建AAC文件失败: $e', logTag);
    }
  }

  /// 关闭AAC文件流
  Future<void> _closeAacFile() async {
    try {
      if (_aacFileSink != null) {
        await _aacFileSink!.flush();
        await _aacFileSink!.close();
        Logger.i('AAC文件已保存: ${_aacFile?.path}', logTag);
        _aacFileSink = null;
        _aacFile = null;
      }
    } catch (e) {
      Logger.e('关闭AAC文件失败: $e', logTag);
    }
  }

  @override
  void sendAudioDataToDevice(Uint8List aacData, int timestamp) async {
    Logger.d('收到AAC数据: ${aacData.length} bytes, timestamp: $timestamp', logTag);
    if (_isTalking && isConnected && flvPacker != null) {
      _saveAacDataToFile(aacData);
      await flvPacker!.encodeAac(aacData, timestamp);
    } else {
      Logger.w(
          'AAC数据未处理: _isTalking=$_isTalking, isConnected=$isConnected, flvPacker=${flvPacker != null}',
          logTag);
    }
  }

  /// 将AAC数据保存到文件
  void _saveAacDataToFile(Uint8List audioData) {
    try {
      if (_aacFileSink != null) {
        _aacFileSink!.add(audioData);
      } else {
        Logger.w('AAC文件流未初始化，无法写入数据', logTag);
      }
    } catch (e) {
      Logger.e('写入AAC文件失败: $e', logTag);
    }
  }

  /// 截图
  void _snapshot() {
    // player?.snapshot(fileName: 'img_${DateTime.now().millisecondsSinceEpoch}.png');
    player?.snapshot();
  }

  /// 录制
  void _record() {
    showMessage('视频录制功能正在开发中...');
    player?.record();
  }

  /// 发送信令测试
  Future<void> _postCommand(String command) async {
    Logger.i('发送信令测试$command', logTag);
    final commandStr = Command.getCustomCommand(0, command);
    final encode = utf8.encode(commandStr);
    final result = await XP2P.postCommandRequestSync(
        id: id, command: encode, timeoutUs: 2 * 1000 * 1000);

    if (result != null) {
      Logger.i('Received response: ${utf8.decode(result)}', logTag);
    }
  }

  /// 语音对讲
  Future<void> _radioTalk() async {
    if (_isTalking) {
      Logger.i('停止语音对讲', logTag);
      await stopXP2PSendService();
      flvPacker?.release();
      final recordingPath = await audioRecorder.stopRecording();
      if (recordingPath != null) {
        Logger.i('录音已停止，文件路径: $recordingPath', logTag);
      }
      await _closeAacFile();

      if (mounted) {
        setState(() {
          _isTalking = false;
          statusText = '语音对讲已停止';
        });
      }
    } else {
      Logger.i('开始语音对讲', logTag);

      await _initAacFile();

      // 创建FLV文件路径
      currentFlvPath = await getFlvPath('audio_talk');
      if (currentFlvPath == null) {
        return;
      }

      flvPacker = await createFlvPacker(
        hasVideo: false,
        outputPath: currentFlvPath!,
      );

      if (flvPacker == null) {
        Logger.e('初始化FLV打包器失败', logTag);
        await _closeAacFile();
        return;
      }

      await startXP2PSendService();

      final success = await audioRecorder.startStreamRecording();
      if (success) {
        if (mounted) {
          setState(() {
            _isTalking = true;
            statusText = '语音对讲中...';
          });
        }
      } else {
        Logger.e('语音对讲开始失败', logTag);
        if (mounted) {
          setState(() {
            statusText = '语音对讲启动失败';
          });
        }
      }
    }
  }

  @override
  void dispose() {
    if (_isTalking) {
      audioRecorder.stopRecording();
    }
    disposeAudioTalk();
    _closeAacFile();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('设备: ${widget.deviceName}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 状态显示
            buildStatusBar(),

            // 视频区域 - 固定尺寸300x200dp
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                  color: Colors.black,
                  child: isConnected
                      ? buildBaseVideoArea()
                      : const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text(
                                '等待设备连接...',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        )),
            ),

            // 信令按钮区域
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _postCommand("test"),
                    icon: const Icon(Icons.send),
                    label: const Text('发送信令'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _radioTalk,
                    icon: Icon(_isTalking ? Icons.mic_off : Icons.mic),
                    label: Text(_isTalking ? '停止对讲' : '语音对讲'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isTalking ? Colors.red : null,
                      foregroundColor: _isTalking ? Colors.white : null,
                    ),
                  ),
                ],
              ),
            ),

            // 截图、录制区域
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _snapshot,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('视频截图'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _record,
                    icon: const Icon(Icons.videocam_outlined),
                    label: const Text('视频录制'),
                  ),
                ],
              ),
            ),

            // 语音对讲状态显示
            if (_isTalking)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.red.withOpacity(0.1),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.mic,
                      color: Colors.red,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text(
                      '语音对讲中...',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

            // // 占用剩余空间的空白区域
            // Expanded(
            //   child: Container(),
            // ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveSnapshotImage(Map<dynamic, dynamic> param) async {
    if (param['image'] is Uint8List) {
      final file = await FileUtils.saveUint8ListToAppDocument(
          param['image'], 'img_${DateTime.now().millisecondsSinceEpoch}.jpeg');

      if (file == null) {
        showMessage('截图保存失败！');
      } else {
        showMessage('截图保存成功!');
      }
    }
  }
}