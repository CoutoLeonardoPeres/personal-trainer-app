import Flutter
import UIKit

// MARK: - Uso no telemóvel sem Xcode / após fechar o app
// Em iOS 26 + ProMotion, build **Debug** costumava crashar ao abrir só pelo ícone (flutter/flutter#183900).
// **FlutterTouchRateCrashFix.m** adia createTouchRateCorrectionVSyncClientIfNeeded para o próximo run loop.
// Reforço: scheme **Runner-Dispositivo** (Release) ou `flutter run --release` se notares anomalias de toque.

/// Logs no **Console.app** (Mac) com o iPhone conectado: filtre por `Runner/` ou `AppDelegate`.
private func runnerLog(_ message: String) {
  NSLog("[Runner/AppDelegate] %@", message)
}

private func logDisplayAndProcessContext(_ tag: String) {
  let pid = ProcessInfo.processInfo.processIdentifier
  let mainFPS = UIScreen.main.maximumFramesPerSecond
  let cadKey = Bundle.main.object(forInfoDictionaryKey: "CADisableMinimumFrameDurationOnPhone") as? Bool ?? false
  runnerLog("\(tag) pid=\(pid) UIScreen.main.maximumFramesPerSecond=\(mainFPS) CADisableMinimumFrameDurationOnPhone=\(cadKey)")
}

private func installUncaughtExceptionLogging() {
  NSSetUncaughtExceptionHandler { exc in
    let msg = "[Runner/FATAL] \(exc.name.rawValue): \(exc.reason ?? "nil")\n\(exc.callStackSymbols.joined(separator: "\n"))"
    NSLog("%@", msg)
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    installUncaughtExceptionLogging()
    logDisplayAndProcessContext("didFinishLaunching (antes super)")
    runnerLog("didFinishLaunching launchOptions.count=\(launchOptions?.count ?? 0)")
    GeneratedPluginRegistrant.register(with: self)
    let ok = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    logDisplayAndProcessContext("didFinishLaunching (depois super)")
    runnerLog("didFinishLaunching super returned \(ok)")
    return ok
  }

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

  override func application(
    _ application: UIApplication,
    shouldSaveSecureApplicationState coder: NSCoder
  ) -> Bool {
    // Em iOS 26.4 há relatos de relançamento falhando após fechamento com state restoration.
    // Mantemos o app stateless no nível UIKit; o estado funcional já está no SQLite/prefs.
    runnerLog("shouldSaveSecureApplicationState=false")
    return false
  }

  override func application(
    _ application: UIApplication,
    shouldRestoreSecureApplicationState coder: NSCoder
  ) -> Bool {
    runnerLog("shouldRestoreSecureApplicationState=false")
    return false
  }
}
