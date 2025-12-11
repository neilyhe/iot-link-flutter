import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var encoder: VideoEncoder?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // 注册AAC编码器插件
    AACEncoderPlugin.register(with: registrar(forPlugin: "AACEncoderPlugin")!)


    // 注册H.264编码器通道
    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: "h264_encoder", binaryMessenger: controller.binaryMessenger)

    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "initialize":
        guard let args = call.arguments as? [String: Any],
              let width = args["width"] as? Int,
              let height = args["height"] as? Int,
              let fps = args["fps"] as? Int,
              let bitrate = args["bitrate"] as? Int else {
          result(FlutterError(code: "INVALID_ARGS", message: "参数无效", details: nil))
          return
        }

        self?.encoder = VideoEncoder()
        let success = self?.encoder?.initialize(width: width, height: height, fps: fps, bitrate: bitrate) ?? false
        if success {
          result(true)
        } else {
          result(FlutterError(code: "INIT_FAILED", message: "编码器初始化失败", details: nil))
        }

      case "encodeFrame":
        guard let args = call.arguments as? [String: Any],
              let yuvData = args["yuvData"] as? FlutterStandardTypedData else {
          result(FlutterError(code: "NO_DATA", message: "YUV数据为空", details: nil))
          return
        }

        if let encodedData = self?.encoder?.encodeFrame(yuvData: yuvData.data) {
          result(FlutterStandardTypedData(bytes: encodedData))
        } else {
          result(FlutterError(code: "ENCODE_FAILED", message: "编码失败", details: nil))
        }

      case "finalize":
        // VideoEncoder 不需要 finalize 方法，直接返回成功
        result(nil)

      case "release":
        self?.encoder?.release()
        self?.encoder = nil
        result(nil)

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // 移除原生权限请求，让Flutter的permission_handler统一管理
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
