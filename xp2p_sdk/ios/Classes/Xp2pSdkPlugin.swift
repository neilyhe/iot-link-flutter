import Flutter
import UIKit

public class Xp2pSdkPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "xp2p_sdk", binaryMessenger: registrar.messenger())
    let instance = Xp2pSdkPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}