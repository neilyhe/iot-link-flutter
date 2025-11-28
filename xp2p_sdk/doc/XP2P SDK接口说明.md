# XP2P SDK API 使用指南

## 目录

1. [概述](#概述)
2. [快速开始](#快速开始)
3. [核心概念](#核心概念)
4. [API 详细说明](#api-详细说明)
5. [最佳实践](#最佳实践)

## 概述

XP2P SDK 是腾讯云物联网 P2P 视频传输  Flutter 实现

## 快速开始

### 1. 添加依赖

```
dependencies:
  xp2p_sdk: 
```

### 2. 基本使用

```
import 'package:xp2p_sdk/xp2p_sdk.dart';

// 实现回调
class MyCallback implements XP2PCallback {
  @override
  void onFail(String id, int errorCode) {
    print('连接失败: $errorCode');
  }

  @override
  void onCommandRequest(String id, String msg) {
    print('收到命令: $msg');
  }

  @override
  void onXp2pEventNotify(String id, String msg, int event) {
    print('事件通知: $event - $msg');
  }

  @override
  void onAvDataRecv(String id, Uint8List data, int len) {
    // 处理音视频数据
    print('收到视频数据: $len bytes');
  }

  @override
  void onAvDataClose(String id, String msg, int errorCode) {
    print('视频通道关闭');
  }

  @override
  String onDeviceMsgArrived(String id, Uint8List data, int len) {
    // 处理设备消息并返回响应
    return 'received';
  }
}

// 使用 SDK
void main() async {
  // 1. 设置回调
  XP2P.setCallback(MyCallback());

  // 2. 配置参数
  final config = XP2PAppConfig(
    appKey: 'your_app_key',
    appSecret: 'your_app_secret',
    autoConfigFromDevice: true,
  );

  // 3. 启动服务
  final result = await XP2P.startService(
    productId: 'PRODUCT_ID',
    deviceName: 'DEVICE_NAME',
    xp2pInfo: 'xp2p_info_from_cloud',
    config: config,
  );
}
```

## 核心概念

### 设备标识符 (ID)

设备标识符格式为: `productId/deviceName`

```
final deviceId = 'ABCD1234/device001';
```

### 协议类型

```
enum XP2PProtocolType {
  auto,  // 自动模式(推荐): UDP 不通时自动切换 TCP
  udp,   // 仅 UDP
  tcp,   // 仅 TCP
}
```

### 事件类型

```
enum XP2PType {
  close,          // 数据传输完成
  log,            // 日志输出
  cmd,            // 命令消息
  disconnect,     // P2P 链路断开
  detectReady,    // P2P 链路就绪
  detectError,    // P2P 链路失败
  deviceMsgArrived, // 设备消息到达
  cmdNoReturn,    // 命令无响应
  streamEnd,      // 推流结束
  downloadEnd,    // 下载结束
  streamRefresh,  // 推流拒绝
  saveFileOn,     // 保存文件开关
  saveFileUrl,    // 文件保存路径
}
```

## API 详细说明

### 服务管理

#### startService - 启动服务

启动 P2P 服务,建立与设备的连接。

```
Future<int> startService({
  required String productId,
  required String deviceName,
  required String xp2pInfo,
  required XP2PAppConfig config,
})
```

**参数:**
- `productId`: 产品 ID,在控制台创建产品时生成
- `deviceName`: 设备名称,设备的唯一标识
- `xp2pInfo`: XP2P 信息字符串,需要从云端 API 获取
- `config`: 应用配置,包含 appKey、appSecret 等

**返回值:**
- `0`: 成功
- `非0`: 失败,参考 [XP2PErrorCode](#错误码)

**示例:**
```
final config = XP2PAppConfig(
  appKey: 'app_key',
  appSecret: 'app_secret',
  autoConfigFromDevice: true,
  crossStunTurn: false,
  type: XP2PProtocolType.auto,
);

final result = await XP2P.startService(
  productId: 'ABCD1234',
  deviceName: 'device001',
  xp2pInfo: xp2pInfoString,
  config: config,
);
```

#### stopService - 停止服务

停止 P2P 服务,断开与设备的连接。

```
void stopService(String id)
```

**参数:**
- `id`: 设备标识符,格式: `productId/deviceName`

**示例:**
```
XP2P.stopService('ABCD1234/device001');
```

### 视频流接收

#### startAvRecvService - 开始接收视频

启动音视频数据接收服务。

```
void startAvRecvService({
  required String id,
  required String cmd,
  bool crypto = true,
})
```

**参数:**
- `id`: 设备标识符
- `cmd`: 请求参数,格式: `key1=value1&key2=value2`
  - 直播: `action=live`
  - 回放: `action=playback&start_time=xxx&end_time=xxx`
- `crypto`: 是否启用传输层加密,建议开启

**示例:**
```
// 请求直播流
XP2P.startAvRecvService(
  id: 'ABCD1234/device001',
  cmd: 'action=live',
  crypto: true,
);

// 请求回放
XP2P.startAvRecvService(
  id: 'ABCD1234/device001',
  cmd: 'action=playback&start_time=1609459200&end_time=1609462800',
  crypto: true,
);
```

**回调:**
接收到的数据通过 `XP2PCallback.onAvDataRecv` 回调返回。

#### stopAvRecvService - 停止接收视频

停止音视频数据接收服务。

```
int stopAvRecvService(String id)
```

**返回值:**
- `0`: 成功
- `非0`: 失败

### 数据发送

#### runSendService - 启动发送服务

启动数据发送服务,用于向设备发送语音或自定义数据。

```
void runSendService({
  required String id,
  required String cmd,
  bool crypto = true,
})
```

**参数:**
- `id`: 设备标识符
- `cmd`: 请求参数
- `crypto`: 是否启用加密

**示例:**
```
XP2P.runSendService(
  id: 'ABCD1234/device001',
  cmd: 'action=voice',
  crypto: true,
);
```

#### dataSend - 发送数据

发送语音或自定义数据,需要先调用 `runSendService`。

```
int dataSend({
  required String id,
  required Uint8List data,
})
```

**参数:**
- `id`: 设备标识符
- `data`: 要发送的数据

**返回值:**
- `0`: 成功
- `非0`: 失败

**示例:**
```
// 发送音频数据
final audioData = Uint8List.fromList([...]);
final result = XP2P.dataSend(
  id: 'ABCD1234/device001',
  data: audioData,
);
```

#### stopSendService - 停止发送服务

停止数据发送服务。

```
int stopSendService(String id)
```

### 命令消息

#### postCommandRequestSync - 同步命令请求

向设备发送命令并同步等待响应。

```
Future<Uint8List?> postCommandRequestSync({
  required String id,
  required Uint8List command,
  int timeoutUs = 0,
})
```

**参数:**
- `id`: 设备标识符
- `command`: 命令数据,可以是任意二进制格式
- `timeoutUs`: 超时时间(微秒),0 表示使用默认超时(约 7500ms)

**返回值:**
- 成功: 设备响应的数据
- 失败: `null`

**示例:**
```
final command = Uint8List.fromList([0x01, 0x02, 0x03]);
final response = await XP2P.postCommandRequestSync(
  id: 'ABCD1234/device001',
  command: command,
  timeoutUs: 5000000, // 5秒超时
);

if (response != null) {
  print('收到响应: ${response.length} bytes');
}
```

### 工具方法

#### delegateHttpFlv - 获取本地代理 URL

获取本地 HTTP-FLV 代理 URL,可用于视频播放器。

```
String delegateHttpFlv(String id)
```

**示例:**
```
final url = XP2P.delegateHttpFlv('ABCD1234/device001');
// url: http://127.0.0.1:8080/flv
videoPlayer.setDataSource(url);
```

#### setLogEnable - 设置日志开关

控制日志输出。

```
void setLogEnable({
  required bool console,
  required bool file,
})
```

**参数:**
- `console`: 是否输出到控制台
- `file`: 是否输出到文件

**示例:**
```
// 开发环境: 开启控制台日志
XP2P.setLogEnable(console: true, file: false);

// 生产环境: 开启文件日志
XP2P.setLogEnable(console: false, file: true);
```

## 最佳实践

### 1. 错误处理

```
try {
  final result = await XP2P.startService(
    productId: productId,
    deviceName: deviceName,
    xp2pInfo: xp2pInfo,
    config: config,
  );

  if (result != 0) {
    final error = XP2PErrorCode.fromCode(result);
    print('启动失败: ${error.description}');
    // 根据错误码进行处理
    handleError(error);
  }
} catch (e) {
  print('异常: $e');
}
```

### 2. 资源管理

```
class VideoService {
  String? _deviceId;

  Future<void> start() async {
    _deviceId = 'PRODUCT_ID/DEVICE_NAME';
    await XP2P.startService(...);
  }

  void dispose() {
    if (_deviceId != null) {
      XP2P.stopAvRecvService(_deviceId!);
      XP2P.stopService(_deviceId!);
      _deviceId = null;
    }
  }
}
```

### 3. 回调处理

```
class VideoCallback implements XP2PCallback {
  final StreamController<Uint8List> _dataController;

  VideoCallback(this._dataController);

  @override
  void onAvDataRecv(String id, Uint8List data, int len) {
    // 将数据发送到 Stream,避免阻塞回调
    _dataController.add(data);
  }

  // 实现其他回调...
}

// 使用
final controller = StreamController<Uint8List>();
XP2P.setCallback(VideoCallback(controller));

controller.stream.listen((data) {
  // 在独立的 isolate 或 async 上下文中处理数据
  processVideoData(data);
});
```

### 4. 连接状态管理

```
enum ConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

class XP2PManager {
  ConnectionState _state = ConnectionState.disconnected;

  void handleEvent(int event) {
    final eventType = XP2PType.fromValue(event);
    switch (eventType) {
      case XP2PType.detectReady:
        _state = ConnectionState.connected;
        break;
      case XP2PType.disconnect:
      case XP2PType.detectError:
        _state = ConnectionState.error;
        break;
      default:
        break;
    }
    notifyListeners();
  }
}
```

## 错误码

参见 `XP2PErrorCode` 枚举定义。

主要错误码:

| 错误码 | 说明 | 解决方法 |
|--------|------|----------|
| -1000 | 入参为空 | 检查传入的参数 |
| -1001 | 获取 xp2pInfo 失败 | 检查网络和云 API 配置 |
| -1002 | 代理初始化失败 | 检查端口占用 |
| -1005 | 请求超时 | 增加超时时间或检查网络 |
| -1007 | 设备版本过低 | 升级设备固件 |
| -1010 | P2P 探测未完成 | 等待连接建立 |
