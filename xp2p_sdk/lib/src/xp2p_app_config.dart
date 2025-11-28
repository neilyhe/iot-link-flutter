import 'xp2p_types.dart';

/// XP2P 应用配置
class XP2PAppConfig {
  /// 应用 Key
  ///
  /// 在腾讯云物联网开发平台(IoT Explorer)注册的应用 appKey
  /// 获取路径: 控制台 -> 应用开发 -> 选择对应应用 -> appKey
  final String appKey;

  /// 应用密钥
  ///
  /// 在腾讯云物联网开发平台注册的应用 appSecret
  /// 获取路径: 控制台 -> 应用开发 -> 选择对应应用 -> appSecret
  final String appSecret;

  /// 是否自动从设备获取配置
  ///
  /// 当设置为 true 时,SDK 会从云端获取设备的最佳配置
  /// 此时 [crossStunTurn] 和 [type] 等配置将不生效
  ///
  /// 默认值: true
  final bool autoConfigFromDevice;

  /// 是否启用跨域 STUN/TURN
  ///
  /// 启用后可以使用跨域的 STUN/TURN 服务器提高连接成功率
  /// 注意: 当 [autoConfigFromDevice] 为 true 时此配置不生效
  ///
  /// 默认值: false
  final bool crossStunTurn;

  /// 通信协议类型
  ///
  /// 指定 P2P 连接使用的网络协议
  /// 注意: 当 [autoConfigFromDevice] 为 true 时此配置不生效
  ///
  /// 可选值:
  /// - [XP2PProtocolType.auto]: 自动模式(推荐),UDP 不通时自动切换 TCP
  /// - [XP2PProtocolType.udp]: 仅使用 UDP
  /// - [XP2PProtocolType.tcp]: 仅使用 TCP
  ///
  /// 默认值: XP2PProtocolType.auto
  final XP2PProtocolType type;

  /// 创建 XP2P 应用配置
  ///
  /// [appKey] 必填,应用 Key
  /// [appSecret] 必填,应用密钥
  /// [autoConfigFromDevice] 是否自动从设备获取配置,默认 true
  /// [crossStunTurn] 是否启用跨域 STUN/TURN,默认 false
  /// [type] 通信协议类型,默认自动模式
  const XP2PAppConfig({
    required this.appKey,
    required this.appSecret,
    this.autoConfigFromDevice = true,
    this.crossStunTurn = false,
    this.type = XP2PProtocolType.auto,
  });

  Map<String, dynamic> toMap() {
    return {
      'appKey': appKey,
      'appSecret': appSecret,
      'autoConfigFromDevice': autoConfigFromDevice,
      'crossStunTurn': crossStunTurn,
      'type': type.value,
    };
  }

  factory XP2PAppConfig.fromMap(Map<String, dynamic> map) {
    return XP2PAppConfig(
      appKey: map['appKey'] as String,
      appSecret: map['appSecret'] as String,
      autoConfigFromDevice: map['autoConfigFromDevice'] as bool? ?? true,
      crossStunTurn: map['crossStunTurn'] as bool? ?? false,
      type: XP2PProtocolType.values.firstWhere(
        (t) => t.value == (map['type'] as int? ?? 0),
        orElse: () => XP2PProtocolType.auto,
      ),
    );
  }

  /// 创建配置副本
  ///
  /// 可以选择性地覆盖某些字段
  XP2PAppConfig copyWith({
    String? appKey,
    String? appSecret,
    bool? autoConfigFromDevice,
    bool? crossStunTurn,
    XP2PProtocolType? type,
  }) {
    return XP2PAppConfig(
      appKey: appKey ?? this.appKey,
      appSecret: appSecret ?? this.appSecret,
      autoConfigFromDevice: autoConfigFromDevice ?? this.autoConfigFromDevice,
      crossStunTurn: crossStunTurn ?? this.crossStunTurn,
      type: type ?? this.type,
    );
  }

  @override
  String toString() {
    return 'XP2PAppConfig(appKey: $appKey, autoConfigFromDevice: $autoConfigFromDevice, '
        'crossStunTurn: $crossStunTurn, type: $type)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is XP2PAppConfig &&
        other.appKey == appKey &&
        other.appSecret == appSecret &&
        other.autoConfigFromDevice == autoConfigFromDevice &&
        other.crossStunTurn == crossStunTurn &&
        other.type == type;
  }

  @override
  int get hashCode {
    return appKey.hashCode ^
        appSecret.hashCode ^
        autoConfigFromDevice.hashCode ^
        crossStunTurn.hashCode ^
        type.hashCode;
  }
}
