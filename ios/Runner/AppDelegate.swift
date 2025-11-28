import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    // 移除原生权限请求，让Flutter的permission_handler统一管理
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
