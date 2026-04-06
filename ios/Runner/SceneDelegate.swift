import Flutter
import UIKit

/// Deve ser idêntico a NSUserActivityTypes e UISceneConfigurationName no Info.plist.
private let kFlutterSceneActivityType = "com.personaltrainer.appPersonal.scene"

private func sceneLog(_ message: String) {
  NSLog("[Runner/SceneDelegate] %@", message)
}

/// Garante [scene.userActivity] com activityType válido antes do engine Flutter chamar
/// stateRestorationActivityForScene — se estiver nil, o Flutter usa
/// session.configuration.name, que em alguns iOS (ex.: 26.x) fica nil e gera
/// NSInvalidArgumentException ("activityType" vazio).
private func ensureSceneUserActivity(_ scene: UIScene) {
  if scene.userActivity == nil {
    scene.userActivity = NSUserActivity(activityType: kFlutterSceneActivityType)
    scene.userActivity?.isEligibleForHandoff = false
    sceneLog("ensureSceneUserActivity: criou userActivity")
    return
  }
  let t = scene.userActivity?.activityType ?? ""
  if t.isEmpty {
    scene.userActivity = NSUserActivity(activityType: kFlutterSceneActivityType)
    scene.userActivity?.isEligibleForHandoff = false
    sceneLog("ensureSceneUserActivity: substituiu activityType vazio")
  }
}

class SceneDelegate: FlutterSceneDelegate {

  /// O engine Flutter ([FlutterSceneLifeCycle stateRestorationActivityForScene:]) usa
  /// `scene.userActivity` ou, se nil, `[[NSUserActivity alloc] initWithActivityType:session.configuration.name]`.
  /// Em alguns iOS (ex.: 26.x) `configuration.name` chega nil no arranque — **antes** de `super` o
  /// `userActivity` tem de existir, senão a segunda abertura (restauração / resign) pode rebentar.
  override func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
    ensureSceneUserActivity(scene)
    // Não delegar para `super` aqui: o caminho interno do Flutter pode voltar a
    // tentar `session.configuration.name` quando nil em alguns iOS 26.x.
    // Ao devolver `scene.userActivity`, garantimos activityType válido no relançamento.
    return scene.userActivity
  }

  override func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    let fps = UIScreen.main.maximumFramesPerSecond
    sceneLog("scene willConnect pid=\(ProcessInfo.processInfo.processIdentifier) maxFPS=\(fps)")
    sceneLog("scene willConnect persistentIdentifier=\(session.persistentIdentifier)")
    let cfgName = session.configuration.name ?? "nil"
    sceneLog("scene willConnect session.configuration.name=\(cfgName)")
    ensureSceneUserActivity(scene)
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    ensureSceneUserActivity(scene)
    sceneLog("scene willConnect super returned")
  }

  override func sceneWillResignActive(_ scene: UIScene) {
    if let ws = scene as? UIWindowScene {
      let cn = ws.session.configuration.name ?? "nil"
      sceneLog("sceneWillResignActive configuration.name=\(cn)")
    }
    ensureSceneUserActivity(scene)
    super.sceneWillResignActive(scene)
  }

  override func sceneDidEnterBackground(_ scene: UIScene) {
    ensureSceneUserActivity(scene)
    super.sceneDidEnterBackground(scene)
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    // Não chamar ensureSceneUserActivity aqui: no resume o sistema já entrega toques;
    // trabalho extra no becomeActive pode agravar “gesture gate timed out”.
    sceneLog("sceneDidBecomeActive")
    super.sceneDidBecomeActive(scene)
  }

  override func sceneWillEnterForeground(_ scene: UIScene) {
    sceneLog("sceneWillEnterForeground")
    super.sceneWillEnterForeground(scene)
  }

  override func sceneDidDisconnect(_ scene: UIScene) {
    sceneLog("sceneDidDisconnect")
    super.sceneDidDisconnect(scene)
  }
}
