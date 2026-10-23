import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    SensitiveScreenProtection.shared.bind(window: window)
    SensitiveScreenProtection.shared.setSceneInactive(false)
  }

  override func sceneWillResignActive(_ scene: UIScene) {
    SensitiveScreenProtection.shared.bind(window: window)
    SensitiveScreenProtection.shared.setSceneInactive(true)
    super.sceneWillResignActive(scene)
  }
}
