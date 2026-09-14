import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let channelName = "com.nanda070.neptun_mobile.app/shortcuts"
  private static let typePrefix = "com.nanda070.neptunmobile.shortcut."

  private var pendingShortcutId: String?
  private var methodChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let shortcutItem = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem {
      pendingShortcutId = Self.shortcutId(from: shortcutItem)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: Self.channelName,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(nil)
        return
      }
      if call.method == "getLaunchShortcut" {
        let id = self.pendingShortcutId
        self.pendingShortcutId = nil
        result(id)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    methodChannel = channel
  }

  override func application(
    _ application: UIApplication,
    performActionFor shortcutItem: UIApplicationShortcutItem,
    completionHandler: @escaping (Bool) -> Void
  ) {
    let id = Self.shortcutId(from: shortcutItem)
    pendingShortcutId = id
    methodChannel?.invokeMethod("shortcutActivated", arguments: id)
    completionHandler(id != nil)
  }

  private static func shortcutId(from item: UIApplicationShortcutItem) -> String? {
    guard item.type.hasPrefix(typePrefix) else { return nil }
    let id = String(item.type.dropFirst(typePrefix.count))
    switch id {
    case "calendar", "mail", "payments":
      return id
    default:
      return nil
    }
  }
}
