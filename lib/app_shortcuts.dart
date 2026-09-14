import 'package:flutter/services.dart';
import 'Pages/main_page.dart';

/// Home-screen quick actions (Android static shortcuts + iOS Quick Actions).
///
/// Ids: `calendar` (tab 0), `mail` (tab 3), `payments` (drawer 4).
/// Maps / next-room shortcut is out of scope (plan item 8).
class AppShortcuts {
  static const MethodChannel _channel =
      MethodChannel('com.nanda070.neptun_mobile.app/shortcuts');

  static const String idCalendar = 'calendar';
  static const String idMail = 'mail';
  static const String idPayments = 'payments';

  static bool _handlerInstalled = false;

  /// Install warm-start listener (app already running / singleTop resume).
  static void ensureHandlerInstalled() {
    if (_handlerInstalled) return;
    _handlerInstalled = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'shortcutActivated') return null;
      final view = viewIndexForId(call.arguments as String?);
      if (view == null) return null;
      HomePageState.navigateToView(view);
      return null;
    });
  }

  /// Consumes the cold-start shortcut id from the platform (cleared after read).
  static Future<String?> takeLaunchShortcutId() async {
    ensureHandlerInstalled();
    try {
      final id = await _channel.invokeMethod<String>('getLaunchShortcut');
      if (id == null || id.isEmpty) return null;
      return id;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Maps platform shortcut id → [HomePage] view index, or null if unknown.
  static int? viewIndexForId(String? id) {
    switch (id) {
      case idCalendar:
        return 0;
      case idMail:
        return HomePageState.viewMail;
      case idPayments:
        return HomePageState.viewPayments;
      default:
        return null;
    }
  }

  static Future<int?> takeLaunchViewIndex() async {
    return viewIndexForId(await takeLaunchShortcutId());
  }
}
