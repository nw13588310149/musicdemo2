import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}

/// 让 App 在 iPad 上以沉浸式 / 全屏方式呈现：
/// - 隐藏顶部状态栏；
/// - 隐藏底部 home 指示条（无 home 键设备）；
/// - 延后系统底部上滑手势，避免误触退出。
///
/// Storyboard 里 Flutter 视图控制器的 `customClass` 指向本类。
@objc(RootFlutterViewController)
class RootFlutterViewController: FlutterViewController {
  /// 与 Info.plist 一致，仅横屏；竖握 iPad 时系统不旋转为竖屏 UI。
  override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
    return [.landscapeLeft, .landscapeRight]
  }

  override var prefersStatusBarHidden: Bool {
    return true
  }

  override var prefersHomeIndicatorAutoHidden: Bool {
    return true
  }

  override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
    return [.bottom]
  }
}
