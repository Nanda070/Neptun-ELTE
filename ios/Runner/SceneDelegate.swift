import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  /// Widget / deep-link taps while the scene is active.
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    super.scene(scene, openURLContexts: URLContexts)
    guard let url = URLContexts.first?.url,
          let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
      return
    }
    _ = appDelegate.application(UIApplication.shared, open: url, options: [:])
  }
}
