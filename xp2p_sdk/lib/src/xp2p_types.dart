/// XP2P 类型定义
///
/// 包含 SDK 中使用的所有枚举类型和数据结构

/// XP2P 协议类型
/// 用于指定 P2P 连接使用的网络协议
enum XP2PProtocolType {
  /// 自动模式: UDP 不通时自动切换到 TCP
  auto(0),

  /// UDP 传输模式
  udp(1),

  /// TCP 传输模式
  tcp(2);

  const XP2PProtocolType(this.value);

  /// 协议类型的整数值
  final int value;
}

/// XP2P 事件类型
/// 用于标识不同类型的回调事件
enum XP2PType {
  /// 数据传输完成
  close(1000),

  /// 日志输出
  log(1001),

  /// 命令 JSON 消息
  cmd(1002),

  /// P2P 链路断开
  disconnect(1003),

  /// P2P 链路初始化成功
  detectReady(1004),

  /// P2P 链路初始化失败
  detectError(1005),

  /// 设备端向 App 发送消息
  deviceMsgArrived(1006),

  /// 设备未返回 App 自定义信令
  cmdNoReturn(1007),

  /// 设备停止推流,或达到最大连接数拒绝推流
  streamEnd(1008),

  /// 下载结束
  downloadEnd(1009),

  /// 设备拒绝推流,请求的 deviceName 不一致
  streamRefresh(1010),

  /// 获取保存音视频流开关状态
  saveFileOn(8000),

  /// 获取音视频流保存路径
  saveFileUrl(8001);

  const XP2PType(this.value);

  /// 事件类型的整数值
  final int value;

  /// 从整数值创建事件类型
  static XP2PType fromValue(int value) {
    return XP2PType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => XP2PType.log,
    );
  }
}

/// XP2P 关闭子类型
/// 用于标识服务关闭的具体类型
enum XP2PCloseSubType {
  /// 语音对讲服务关闭
  voiceServiceClose(2000),

  /// 音视频流接收服务关闭
  streamServiceClose(2001);

  const XP2PCloseSubType(this.value);

  /// 关闭类型的整数值
  final int value;
}

/// 应用配置
/// 用于配置 P2P 连接的服务器和网络参数
/// 对应 Android 的 AppConfig.java
class AppConfig {

  /// 创建应用配置
  ///
  /// [server] STUN/TURN 服务器地址
  /// [ip] 服务器 IP
  /// [port] 服务器端口
  /// [type] 协议类型,默认为自动模式
  /// [cross] 是否启用跨域,默认为 false
  AppConfig({
    this.server = '',
    this.ip = '',
    this.port = 20002,
    this.type = XP2PProtocolType.auto,
    this.cross = false,
  });

  /// STUN/TURN 服务器地址
  String server;

  /// 服务器 IP 地址
  String ip;

  /// 服务器端口号
  int port;

  /// 协议类型
  XP2PProtocolType type;

  /// 是否启用跨域 STUN/TURN
  bool cross;

  /// 转换为 Map 格式
  Map<String, dynamic> toMap() {
    return {
      'server': server,
      'ip': ip,
      'port': port,
      'type': type.value,
      'cross': cross,
    };
  }

  @override
  String toString() {
    return 'AppConfig(server: $server, ip: $ip, port: $port, type: $type, cross: $cross)';
  }
}

/// 用于上报 P2P 连接的统计数据
class DataReport {

  const DataReport({
    required this.reportBuf,
    required this.reportSize,
    required this.liveSize,
    required this.dataAction,
    required this.status,
    required this.uniqueId,
    required this.appPeerName,
    required this.deviceP2PInfo,
    required this.appUpByte,
    required this.appDownByte,
    required this.appConnectIp,
    required this.errorCode,
  });
  final List<int> reportBuf;

  final int reportSize;

  final int liveSize;

  final String dataAction;

  final String status;

  final String uniqueId;

  final String appPeerName;

  final String deviceP2PInfo;

  final int appUpByte;

  final int appDownByte;

  final String appConnectIp;

  final int errorCode;
}
