# XP2P SDK for Flutter

Flutter SDK for Tencent IoT XP2P video streaming. This SDK enables P2P connectivity for IoT video devices.

## Features

- P2P video streaming with direct/relay connection
- Command synchronization and asynchronous messaging
- Audio/Video data reception
- Voice/Data transmission
- LAN service support
- FFI-based native integration (replaces JNI)

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  xp2p_sdk: ^2.4.1
```

## Usage

```dart
import 'package:xp2p_sdk/xp2p_sdk.dart';

// Initialize XP2P service
final config = XP2PAppConfig(
  appKey: 'your_app_key',
  appSecret: 'your_app_secret',
  autoConfigFromDevice: true,
);

// Set callback
XP2P.setCallback(MyXP2PCallback());

// Start service
await XP2P.startService(
  productId: 'your_product_id',
  deviceName: 'your_device_name',
  xp2pInfo: 'xp2p_info_string',
  config: config,
);

// Start receiving video
XP2P.startAvRecvService(
  id: 'product_id/device_name',
  cmd: 'action=live',
  crypto: true,
);

// Stop service
XP2P.stopService('product_id/device_name');
```

## Version

SDK Version: 2.4.1

## License

Tencent Binary License
