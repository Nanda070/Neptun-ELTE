import Flutter
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let shortcutsChannelName = "com.nanda070.neptun_mobile.app/shortcuts"
  private static let widgetChannelName = "com.nanda070.neptun_mobile.app/widget"
  private static let typePrefix = "com.nanda070.neptunmobile.shortcut."
  private static let appGroupId = "group.com.nanda070.neptunmobile"
  private static let todayClassesJsonKey = "todayClassesJson"

  private var pendingShortcutId: String?
  private var methodChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let shortcutItem = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem {
      pendingShortcutId = Self.shortcutId(from: shortcutItem)
    }
    if let url = launchOptions?[.url] as? URL {
      pendingShortcutId = Self.shortcutId(from: url) ?? pendingShortcutId
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()

    let shortcuts = FlutterMethodChannel(
      name: Self.shortcutsChannelName,
      binaryMessenger: messenger
    )
    shortcuts.setMethodCallHandler { [weak self] call, result in
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
    methodChannel = shortcuts

    let widget = FlutterMethodChannel(
      name: Self.widgetChannelName,
      binaryMessenger: messenger
    )
    widget.setMethodCallHandler { call, result in
      if call.method == "updateTodayClasses" {
        guard let args = call.arguments as? [String: Any],
              let json = args["json"] as? String else {
          result(FlutterError(code: "bad_args", message: "json required", details: nil))
          return
        }
        // Timetable snapshot only — never tokens / passwords.
        let defaults = UserDefaults(suiteName: Self.appGroupId)
        defaults?.set(json, forKey: Self.todayClassesJsonKey)
        if let updatedAt = args["updatedAt"] as? String {
          defaults?.set(updatedAt, forKey: "todayClassesUpdatedAt")
        }
        defaults?.synchronize()
        WidgetCenter.shared.reloadAllTimelines()
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
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

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if let id = Self.shortcutId(from: url) {
      pendingShortcutId = id
      methodChannel?.invokeMethod("shortcutActivated", arguments: id)
      return true
    }
    return super.application(app, open: url, options: options)
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

  /// Widget tap: `neptunelte://shortcut/calendar`
  private static func shortcutId(from url: URL) -> String? {
    guard url.scheme == "neptunelte" else { return nil }
    if url.host == "shortcut" {
      let id = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      switch id {
      case "calendar", "mail", "payments":
        return id
      default:
        return nil
      }
    }
    return nil
  }
}
