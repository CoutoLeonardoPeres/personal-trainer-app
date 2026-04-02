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

  override func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    sceneLog("scene willConnect persistentIdentifier=\(session.persistentIdentifier)")
    let cfgName = session.configuration.name ?? "nil"
    sceneLog("scene willConnect session.configuration.name=\(cfgName)")
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
