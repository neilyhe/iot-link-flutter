import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:xp2p_sdk/xp2p_sdk.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:xp2p_sdk/src/log/logger.dart';
import 'package:xp2p_sdk/src/media_server/flv_packer.dart';
import 'package:path_provider/path_provider.dart';
import '../audio_recorder.dart'; // 导入音频录制服务

/// 视频拉流页面
class VideoStreamPage extends StatefulWidget {
  final String productId;
  final String deviceName;
  final String p2pInfo;

  const VideoStreamPage({
    super.key,
    required this.productId,
    required this.deviceName,
    required this.p2pInfo,
  });

  @override
  State<VideoStreamPage> createState() => _VideoStreamPageState();
}

class _VideoStreamPageState extends State<VideoStreamPage> {
  String _statusText = '正在初始化...';
  bool _isConnected = false;
  bool _isStreaming = false;
  bool _isTalking = false;
  String? _flvUrl;

  late final Player _player;
  late final VideoController _videoController;
  late final AudioRecorderService _audioRecorder;
  FLVPacker? _flvPacker;

  // AAC文件保存相关
  File? _aacFile;
  IOSink? _aacFileSink;

  // FLV文件保存相关
  String? _currentFlvPath;

  String get id => '${widget.productId}/${widget.deviceName}';

  @override
  void initState() {
    super.initState();
    _initAudioRecorder();
    _initXP2P();
    _startService();
  }

  /// 初始化音频录制服务
  void _initAudioRecorder() {
    _audioRecorder = AudioRecorderService();
    _audioRecorder.addAACDataListener((aacData, timestamp) {
      _sendAudioDataToDevice(aacData, timestamp);
    });
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
        Logger.e('无法获取存储目录', 'AudioTalk');
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

      Logger.i('AAC文件已创建: ${_aacFile!.path}', 'AudioTalk');
    } catch (e) {
      Logger.e('创建AAC文件失败: $e', 'AudioTalk');
    }
  }

  /// 关闭AAC文件流
  Future<void> _closeAacFile() async {
    try {
      if (_aacFileSink != null) {
        await _aacFileSink!.flush();
        await _aacFileSink!.close();
        Logger.i('AAC文件已保存: ${_aacFile?.path}', 'AudioTalk');
        _aacFileSink = null;
        _aacFile = null;
      }
    } catch (e) {
      Logger.e('关闭AAC文件失败: $e', 'AudioTalk');
    }
  }

  void _sendAudioDataToDevice(Uint8List aacData, int timestamp) async {
    if (_isTalking && _isConnected && _flvPacker != null) {
      _saveAacDataToFile(aacData);
      await _flvPacker!.encodeAac(aacData, timestamp);
    }
  }

  void _sendFlvDataToDevice(Uint8List flvData) {
    XP2P.dataSend(id: id, data: flvData);
  }

  /// 将AAC数据保存到文件
  void _saveAacDataToFile(Uint8List audioData) {
    try {
      if (_aacFileSink != null) {
        _aacFileSink!.add(audioData);
      } else {
        Logger.w('AAC文件流未初始化，无法写入数据', 'AudioTalk');
      }
    } catch (e) {
      Logger.e('写入AAC文件失败: $e', 'AudioTalk');
    }
  }

  /// 初始化 XP2P SDK
  void _initXP2P() {
    Logger.i('XP2P SDK 初始化', 'XP2P');
    XP2P.setCallback(_createCallback());
    XP2P.setLogEnable(console: true, file: false);

    // 初始化 media_kit 播放器
    _player = Player();
    _videoController = VideoController(_player);
  }

  /// 创建回调对象
  XP2PCallback _createCallback() {
    return _MyXP2PCallback(
      onFailCallback: (id, errorCode) {
        Logger.e('连接失败: id=$id, errorCode=$errorCode', 'XP2P');
        if (mounted) {
          setState(() {
            _statusText = '连接失败: $errorCode';
          });
        }
      },
      onCommandRequestCallback: (id, msg) {
        Logger.i('收到命令响应: id=$id, msg=$msg', 'XP2P');
      },
      onXp2pEventNotifyCallback: (id, msg, event) {
        final eventType = XP2PType.fromValue(event);
        Logger.i('事件通知: id=$id, event=$eventType, msg=$msg', 'XP2P');

        // 根据不同事件更新状态
        switch (eventType) {
          case XP2PType.detectReady:
            if (mounted) {
              setState(() {
                _statusText = 'P2P 连接就绪';
                _isConnected = true;
              });
            }
            // XP2PType.detectReady以后，执行_postCommand
            _checkDeviceStatus();
            break;
          case XP2PType.disconnect:
            if (mounted) {
              setState(() {
                _statusText = 'P2P 连接断开';
                _isConnected = false;
                _isStreaming = false;
              });
            }
            break;
          default:
            break;
        }
      },
      onAvDataRecvCallback: (id, data, len) {
        Logger.d('收到视频数据: id=$id, size=$len bytes', 'XP2P');
      },
      onAvDataCloseCallback: (id, msg, errorCode) {
        Logger.w('视频通道关闭: id=$id, msg=$msg, errorCode=$errorCode', 'XP2P');
      },
      onDeviceMsgArrivedCallback: (id, data, len) {
        Logger.i('收到设备消息: id=$id, size=$len bytes', 'XP2P');
        // 返回响应给设备
        return 'received';
      },
    );
  }

  /// 启动服务
  Future<void> _startService() async {
    Logger.i('正在启动服务...', 'Service');

    // 配置参数
    const config = XP2PAppConfig(
      appKey: '***REMOVED***',
      appSecret: '***REMOVED***',
      autoConfigFromDevice: false,
      crossStunTurn: false,
      type: XP2PProtocolType.udp,
    );

    // 启动服务
    final result = await XP2P.startService(
      productId: widget.productId,
      deviceName: widget.deviceName,
      xp2pInfo: widget.p2pInfo,
      config: config,
    );

    if (result == 0) {
      if (mounted) {
        setState(() {
          _statusText = '服务启动成功';
        });
      }
      Logger.i('服务启动成功', 'Service');
    } else {
      if (mounted) {
        setState(() {
          _statusText = '服务启动失败: $result';
        });
      }
      Logger.e('服务启动失败: $result', 'Service');
    }
  }

  void _delegateHttpFlv() {
    final url =
        XP2P.delegateHttpFlv(id) + Command.getVideoStandardQualityUrlSuffix(0);
    ;
    Logger.i("获取到 flv http: $url", 'Video');

    if (url.isNotEmpty) {
      if (mounted) {
        setState(() {
          _flvUrl = url;
          _isStreaming = true;
        });
      }

      // 开始拉流
      _startStreaming();
    }
  }

  /// 开始拉流
  Future<void> _startStreaming() async {
    if (_flvUrl == null) return;

    try {
      Logger.i('开始拉流: $_flvUrl', 'Video');
      await _player.open(Media(_flvUrl!));
      if (mounted) {
        setState(() {
          _isStreaming = true;
        });
      }
    } catch (e) {
      Logger.eWithException('拉流失败', e, 'Video');
      if (mounted) {
        setState(() {
          _statusText = '拉流失败: $e';
          _isStreaming = false; // 拉流失败时重置状态
        });
      }
    }
  }

  /// 检查设备状态
  Future<void> _checkDeviceStatus() async {
    Logger.i('检查设备状态', 'Command');
    final commandStr = Command.getDeviceStatus(0, 'standard');
    final encode = utf8.encode(commandStr);
    final result = await XP2P.postCommandRequestSync(
        id: id, command: encode, timeoutUs: 2 * 1000 * 1000);

    if (result != null) {
      Logger.i('Received response: ${utf8.decode(result)}', 'Command');
      _delegateHttpFlv();
    }
  }

  /// 发送信令测试
  Future<void> _postCommand(String command) async {
    Logger.i('发送信令测试$command', 'Command');
    final commandStr = Command.getCustomCommand(0, command);
    final encode = utf8.encode(commandStr);
    final result = await XP2P.postCommandRequestSync(
        id: id, command: encode, timeoutUs: 2 * 1000 * 1000);

    if (result != null) {
      Logger.i('Received response: ${utf8.decode(result)}', 'Command');
    }
  }

  /// 停止服务
  void _stopService() {
    Logger.i('停止服务...', 'Service');
    XP2P.stopService(id);

    if (mounted) {
      setState(() {
        _statusText = '服务已停止';
        _isConnected = false;
        _isStreaming = false;
      });
    }
  }

  /// 语音对讲
  Future<void> _radioTalk() async {
    try {
      if (_isTalking) {
        Logger.i('停止语音对讲', 'AudioTalk');
        final recordingPath = await _audioRecorder.stopRecording();
        if (recordingPath != null) {
          Logger.i('录音已停止，文件路径: $recordingPath', 'AudioTalk');
        }

        await _closeAacFile();
        XP2P.stopSendService(id);

        // 释放FLV打包器
        if (_flvPacker != null) {
          await _flvPacker!.flush();
          await _flvPacker!.release();


          if (_currentFlvPath != null) {
            final flvFile = File(_currentFlvPath!);
            if (await flvFile.exists()) {
              final flvSize = await flvFile.length();
              Logger.i('FLV文件路径: $_currentFlvPath FLV文件大小: ${(flvSize / 1024).toStringAsFixed(2)} KB',
                  'AudioTalk');
            }
          }
          _flvPacker = null;
          _currentFlvPath = null;
        }

        if (mounted) {
          setState(() {
            _isTalking = false;
            _statusText = '语音对讲已停止';
          });
        }
      } else {
        Logger.i('开始语音对讲', 'AudioTalk');

        await _initAacFile();

        Directory? directory;
        if (Platform.isAndroid) {
          directory = await getExternalStorageDirectory();
        } else {
          directory = await getApplicationDocumentsDirectory();
        }

        if (directory == null) {
          Logger.e('无法获取存储目录', 'AudioTalk');
          return;
        }

        // 创建FLV文件目录
        final flvDir = Directory('${directory.path}/flv_recordings');
        if (!await flvDir.exists()) {
          await flvDir.create(recursive: true);
        }

        // 创建FLV文件，使用时间戳命名
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'audio_talk_$timestamp.flv';
        _currentFlvPath = '${flvDir.path}/$fileName';

        _flvPacker = await FLVPackerFactory.create(
          hasAudio: true,
          hasVideo: false,
          outputPath: _currentFlvPath,
        );

        if (_flvPacker == null) {
          Logger.e('初始化FLV打包器失败', 'AudioTalk');
          await _closeAacFile();
          return;
        }

        // 设置FLV数据回调
        _flvPacker!.setOnFLVDataCallback((flvData) {
          _sendFlvDataToDevice(flvData);
        });

        final command = Command.getNvrIpcStatus(0, 0);
        final encode = utf8.encode(command);
        final result = await XP2P.postCommandRequestSync(
            id: id, command: encode, timeoutUs: 2 * 1000 * 1000);
        XP2P.runSendService(
            id: id, cmd: Command.getTwoWayRadio(0), crypto: true);

        final success = await _audioRecorder.startStreamRecording();
        if (success) {
          if (mounted) {
            setState(() {
              _isTalking = true;
              _statusText = '语音对讲中...';
            });
          }
        } else {
          await _flvPacker?.release();
          _flvPacker = null;
          await _closeAacFile();
          Logger.e('语音对讲开始失败', 'AudioTalk');
          if (mounted) {
            setState(() {
              _statusText = '语音对讲启动失败';
            });
          }
        }
      }
    } catch (e) {
      Logger.eWithException('语音对讲操作失败', e, 'AudioTalk');
      if (mounted) {
        setState(() {
          _statusText = '语音对讲操作失败: $e';
          _isTalking = false;
        });
      }
    }
  }

  @override
  void dispose() {
    if (_isTalking) {
      _audioRecorder.stopRecording();
    }
    _audioRecorder.dispose();
    _closeAacFile(); // 关闭AAC文件流
    _flvPacker?.release(); // 释放FLV打包器
    _player.dispose();
    _stopService();
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
      body: Column(
        children: [
          // 状态显示
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              children: [
                Icon(
                  _isConnected ? Icons.check_circle : Icons.error,
                  color: _isConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _statusText,
                    style: TextStyle(
                      color: _isConnected ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 视频区域 - 固定尺寸300x200dp
          Container(
            width: 300,
            height: 200,
            color: Colors.black,
            child: _isStreaming
                ? Video(
                    controller: _videoController,
                    fit: BoxFit.contain,
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          _isConnected ? '正在连接视频流...' : '等待设备连接...',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
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

          // 语音对讲状态显示
          if (_isTalking)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.red.withOpacity(0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.mic,
                    color: Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
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

          // 占用剩余空间的空白区域
          Expanded(
            child: Container(),
          ),
        ],
      ),
    );
  }
}

/// XP2P 回调实现
class _MyXP2PCallback extends XP2PCallback {
  final void Function(String id, int errorCode) onFailCallback;
  final void Function(String id, String msg) onCommandRequestCallback;
  final void Function(String id, String msg, int event)
      onXp2pEventNotifyCallback;
  final void Function(String id, Uint8List data, int len) onAvDataRecvCallback;
  final void Function(String id, String msg, int errorCode)
      onAvDataCloseCallback;
  final String Function(String id, Uint8List data, int len)
      onDeviceMsgArrivedCallback;

  _MyXP2PCallback({
    required this.onFailCallback,
    required this.onCommandRequestCallback,
    required this.onXp2pEventNotifyCallback,
    required this.onAvDataRecvCallback,
    required this.onAvDataCloseCallback,
    required this.onDeviceMsgArrivedCallback,
  });

  @override
  void onFail(String id, int errorCode) {
    onFailCallback(id, errorCode);
  }

  @override
  void onCommandRequest(String id, String msg) {
    onCommandRequestCallback(id, msg);
  }

  @override
  void onXp2pEventNotify(String id, String msg, int event) {
    onXp2pEventNotifyCallback(id, msg, event);
  }

  @override
  void onAvDataRecv(String id, Uint8List data, int len) {
    onAvDataRecvCallback(id, data, len);
  }

  @override
  void onAvDataClose(String id, String msg, int errorCode) {
    onAvDataCloseCallback(id, msg, errorCode);
  }

  @override
  String onDeviceMsgArrived(String id, Uint8List data, int len) {
    return onDeviceMsgArrivedCallback(id, data, len);
  }
}
