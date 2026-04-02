import Flutter
import UIKit

/// Logs no **Console.app** (Mac) com o iPhone conectado: busque `Runner/AppDelegate`.
private func runnerLog(_ message: String) {
  NSLog("[Runner/AppDelegate] %@", message)
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    runnerLog("didFinishLaunching launchOptions.count=\(launchOptions?.count ?? 0)")
    let ok = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    runnerLog("didFinishLaunching super returned \(ok)")
    return ok
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    runnerLog("didInitializeImplicitFlutterEngine — GeneratedPluginRegistrant")
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  // Não sobrescrever application(_:configurationForConnecting:).
  // No iOS 26.x a sessão chegava com session.configuration.name == nil apesar do nome
  // no objeto retornado, o que quebrava NSUserActivity / restauração. Deixar o sistema
  // montar a cena só a partir do UIApplicationSceneManifest no Info.plist (nome, storyboard,
  // delegate) alinha session.configuration com o plist.

  override func applicationDidBecomeActive(_ application: UIApplication) {
    runnerLog("applicationDidBecomeActive")
    super.applicationDidBecomeActive(application)
  }

  override func applicationWillResignActive(_ application: UIApplication) {
    runnerLog("applicationWillResignActive")
    super.applicationWillResignActive(application)
  }

  override func applicationDidEnterBackground(_ application: UIApplication) {
    runnerLog("applicationDidEnterBackground")
    super.applicationDidEnterBackground(application)
  }

  override func applicationWillEnterForeground(_ application: UIApplication) {
    runnerLog("applicationWillEnterForeground")
    super.applicationWillEnterForeground(application)
  }
}
