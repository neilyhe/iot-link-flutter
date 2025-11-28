import 'dart:typed_data';

/// XP2P 回调接口
abstract class XP2PCallback {
  /// 连接失败回调
  ///
  /// 当 P2P 连接建立失败或发生错误时被调用
  ///
  /// [id] 设备唯一标识符,格式为 "productId/deviceName"
  /// [errorCode] 错误码,参见 [XP2PErrorCode]
  void onFail(String id, int errorCode);

  /// 命令请求回调
  ///
  /// 当收到来自设备的异步命令响应时被调用
  ///
  /// [id] 设备唯一标识符
  /// [msg] 命令响应消息内容
  void onCommandRequest(String id, String msg);

  /// XP2P 事件通知回调
  ///
  /// 用于接收 P2P 链路状态变化等事件通知
  ///
  /// [id] 设备唯一标识符
  /// [msg] 事件消息内容
  /// [event] 事件类型,参见 [XP2PType]
  void onXp2pEventNotify(String id, String msg, int event);

  /// 音视频数据接收回调
  ///
  /// 当收到来自设备的音视频流数据时被调用
  /// 注意: 此回调会被频繁调用,请确保处理逻辑高效
  ///
  /// [id] 设备唯一标识符
  /// [data] 音视频数据字节数组
  /// [len] 数据长度
  void onAvDataRecv(String id, Uint8List data, int len);

  /// 音视频数据通道关闭回调
  ///
  /// 当音视频数据接收通道关闭时被调用
  ///
  /// [id] 设备唯一标识符
  /// [msg] 关闭原因消息
  /// [errorCode] 错误码,0 表示正常关闭
  void onAvDataClose(String id, String msg, int errorCode);

  /// 设备消息到达回调
  ///
  /// 当设备主动向 App 发送消息时被调用
  /// 此回调需要返回响应数据给设备
  ///
  /// [id] 设备唯一标识符
  /// [data] 设备发送的消息数据
  /// [len] 数据长度
  /// 返回值: 响应给设备的字符串数据
  String onDeviceMsgArrived(String id, Uint8List data, int len);

  /// 数据上报回调(可选实现)
  void onReportData(
    String id,
    Uint8List reportBuf,
    int reportSize,
    int liveSize,
    String dataAction,
    String status,
    String uniqueId,
    String appPeerName,
    String deviceP2PInfo,
    int appUpByte,
    int appDownByte,
    String appConnectIp,
    int errorCode,
  ) {
    // 默认空实现,子类可选择性重写

  }
}
