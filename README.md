# IoT Link Flutter Demo

基于腾讯云 IoT XP2P SDK 的 Flutter 示例应用，展示了如何使用 XP2P SDK 实现 IoT 设备的视频流传输和双向音视频通话功能。

## 📱 项目简介

这是一个完整的 IoT 视频应用示例，演示了如何通过 P2P 技术直连 IoT 设备，实现：
- 📹 **实时视频预览**：低延迟的设备视频流播放
- 🎙️ **双向音视频通话**：与设备进行语音和视频对讲
- 🔐 **P2P 直连**：支持直连和中继模式的 P2P 连接
- 📡 **信令通信**：设备命令同步和异步消息传输

## ✨ 主要功能

### 1. 视频预览
- 实时视频流播放
- 支持视频质量调整
- 低延迟 P2P 传输
- 自动重连机制

### 2. 双向通话
- 音频对讲功能
- 视频采集与传输
- 摄像头切换
- 实时音视频编解码

### 3. 设备管理
- 设备连接配置
- P2P 连接状态监控
- 设备信息管理
- 日志系统集成

## 🚀 快速开始

### 环境要求

- Flutter SDK: >=3.0.0 <4.0.0
- Dart SDK: >=3.0.0
- iOS: 11.0+
- Android: API 21+

### 安装依赖

```bash
flutter pub get
```

### 配置 License

在 `lib/main.dart` 中配置您的腾讯云 License：

```dart
const String LICENSEURL = 'your_license_url';
const String LICENSEURLKEY = 'your_license_key';
```

> 获取 License：访问 [腾讯云 License 管理页面](https://console.cloud.tencent.com/live/license)

### 运行应用

```bash
# iOS
flutter run -d ios

# Android
flutter run -d android
```

## 📦 项目结构

```
iot_link_flutter/
├── lib/
│   ├── main.dart                    # 应用入口和主页面
│   ├── pages/
│   │   ├── video_stream_page.dart   # 视频预览页面
│   │   └── two_way_call_page.dart   # 双向通话页面
│   ├── base/
│   │   ├── base_xp2p_stream_page.dart      # XP2P 基础页面
│   │   └── capabilities/                    # 功能模块
│   │       ├── audio_talk_capability.dart   # 音频对讲能力
│   │       └── video_capture_capability.dart # 视频采集能力
│   └── services/
│       ├── audio/                   # 音频服务
│       └── video/                   # 视频服务
├── assets/                          # 资源文件
└── docs/                            # 文档

```

## 🔧 核心依赖

| 依赖包 | 版本        | 用途 |
|--------|-----------|------|
| xp2p_sdk | 1.0.1     | 腾讯云 IoT XP2P SDK |
| camera | ^0.10.5+5 | 摄像头采集 |
| record | ^6.1.2    | 音频录制 |
| audioplayers | ^5.2.1    | 音频播放 |
| permission_handler | ^11.0.1   | 权限管理 |
| device_info_plus | ^9.0.0    | 设备信息 |
| path_provider | ^2.1.1    | 路径管理 |

## 📖 使用指南

### 1. 连接设备

启动应用后，在登录页面输入：
- **Product ID**：产品 ID
- **Device Name**：设备名称
- **P2P Info**：设备的 P2P 信息字符串

点击"连接设备"按钮，选择功能：
- **预览**：查看设备实时视频
- **IPC双向通话**：与设备进行音视频对讲

### 2. 视频预览

进入预览页面后：
- 自动建立 P2P 连接
- 开始接收并播放视频流
- 可查看连接状态和日志信息

### 3. 双向通话

进入双向通话页面后：
- 自动初始化本地摄像头和麦克风
- 建立双向音视频通道
- 支持切换前后摄像头
- 实时音视频传输

## 🔐 权限配置

### iOS (Info.plist)

```xml
<key>NSCameraUsageDescription</key>
<string>需要访问相机进行视频通话</string>
<key>NSMicrophoneUsageDescription</key>
<string>需要访问麦克风进行语音通话</string>
```

### Android (AndroidManifest.xml)

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
```

## 📝 日志系统

项目集成了统一的日志系统，支持：
- 多级别日志（DEBUG、INFO、WARN、ERROR）
- 控制台输出
- UI 日志显示
- 级别过滤

详细说明请参考：[日志系统集成文档](LOGGER_INTEGRATION_SUMMARY.md)

## 🏗️ 构建发布

### iOS

```bash
# 使用提供的构建脚本
./build_ios.sh

# 或手动构建
flutter build ios --release
```

### Android

```bash
flutter build apk --release
# 或
flutter build appbundle --release
```

## 📚 XP2P SDK

本项目使用的 XP2P SDK 是一个 Flutter 插件，提供了：
- P2P 视频流传输
- 命令同步和异步消息
- 音视频数据收发
- LAN 服务支持
- FFI 原生集成

详细文档请参考：[xp2p_sdk/README.md](xp2p_sdk/README.md)

## ⚠️ 注意事项

1. **License 配置**：使用前必须配置有效的腾讯云 License
2. **网络环境**：确保设备和手机在可通信的网络环境中
3. **权限申请**：首次使用需要授予相机和麦克风权限
4. **设备兼容性**：确保 IoT 设备支持 XP2P 协议

## 🐛 常见问题

### 1. 无法连接设备
- 检查 Product ID、Device Name 和 P2P Info 是否正确
- 确认设备在线且网络正常
- 查看日志输出的错误信息

### 2. 视频无法播放
- 检查 License 是否有效
- 确认 P2P 连接已建立
- 查看设备是否正在推流

### 3. 音视频通话无声音
- 检查麦克风和扬声器权限
- 确认设备支持双向通话
- 查看音频编解码是否正常

## 📞 联系方式

如有问题，请访问 [腾讯云 IoT 官网](https://cloud.tencent.com/product/iot)。

---

**注意**：这是一个示例项目，仅用于演示 XP2P SDK 的基本功能。生产环境使用请根据实际需求进行调整和优化。
