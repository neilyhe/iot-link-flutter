/// XP2P 错误码定义
///
/// 包含所有可能的错误码及其说明

/// XP2P 错误码枚举
enum XP2PErrorCode {
  /// 成功
  none(0, '成功'),

  /// 入参为空
  initParam(-1000, '入参为空'),

  /// SDK 内部请求 xp2p info 失败
  getXp2pInfo(-1001, 'SDK 内部请求 xp2p info 失败'),

  /// 本地 P2P 代理初始化失败
  proxyInit(-1002, '本地 P2P 代理初始化失败'),

  /// 数据接收/发送服务未初始化
  uninit(-1003, '数据接收/发送服务未初始化'),

  /// 数据加密失败
  encrypt(-1004, '数据加密失败'),

  /// 请求超时
  timeout(-1005, '请求超时'),

  /// 请求错误
  requestFail(-1006, '请求错误'),

  /// 设备版本过低,请升级设备固件
  version(-1007, '设备版本过低,请升级设备固件'),

  /// Application 初始化失败
  application(-1008, 'Application 初始化失败'),

  /// Request 初始化失败
  request(-1009, 'Request 初始化失败'),

  /// P2P 探测未完成
  detectNotReady(-1010, 'P2P 探测未完成'),

  /// 当前 ID 对应的 P2P 已完成初始化
  p2pInited(-1011, '当前 ID 对应的 P2P 已完成初始化'),

  /// 当前 ID 对应的 P2P 未初始化
  p2pUninit(-1012, '当前 ID 对应的 P2P 未初始化'),

  /// 内存申请失败
  newMemory(-1013, '内存申请失败'),

  /// 获取到的 xp2p info 格式错误
  xp2pInfoRule(-1014, '获取到的 xp2p info 格式错误'),

  /// 获取到的 xp2p info 解码失败
  xp2pInfoDecrypt(-1015, '获取到的 xp2p info 解码失败'),

  /// 本地代理监听端口失败
  proxyListen(-1016, '本地代理监听端口失败'),

  /// 云端返回空数据
  cloudEmpty(-1017, '云端返回空数据'),

  /// JSON 解析失败
  jsonParse(-1018, 'JSON 解析失败'),

  /// 当前 ID 对应的服务(语音、直播等)没有在运行
  serviceNotRun(-1019, '当前 ID 对应的服务没有在运行'),

  /// 从 map 中取出的 client 为空
  clientNull(-1020, '从 map 中取出的 client 为空');

  const XP2PErrorCode(this.code, this.message);

  /// 错误码
  final int code;

  /// 错误信息
  final String message;

  /// 从错误码创建枚举
  static XP2PErrorCode fromCode(int code) {
    return XP2PErrorCode.values.firstWhere(
      (error) => error.code == code,
      orElse: () => XP2PErrorCode.none,
    );
  }

  /// 获取错误描述
  String get description => '[$code] $message';

  @override
  String toString() => description;
}
