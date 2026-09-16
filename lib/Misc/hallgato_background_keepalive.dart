import 'dart:developer' as debug;
import 'dart:io';

import 'package:background_fetch/background_fetch.dart';
import 'package:background_fetch/background_fetch.dart' as bg;
import 'package:flutter/widgets.dart';
import 'package:neptun2/API/api_coms.dart' as api;
import 'package:neptun2/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart' as wm;

/// Optional hallgato JWT maintenance while the app is not foreground-resumed.
///
/// **Battery / OS honesty (1.5.10):** Android periodic is **45 min** with
/// network + battery-not-low only — **no** `requiresDeviceIdle` (1.5.9 idle
/// blocked nearly all runs on phones that rarely enter true idle). First
/// WorkManager tick after arming uses a **15 min** initial delay so AFK
/// sessions can refresh before the full period. iOS minimum fetch interval
/// **45 min**; the OS may defer or never run (Low Power, Background App
/// Refresh off, force-quit). Do **not** require charging. Foreground 3 min
/// 30 s remains primary; background tasks are cancelled while `resumed` and
/// coalesced via [SessionGuard] last-success timestamp.
///
/// Uses the same [SessionGuard.runBackgroundTokenMaintenance] helper as
/// foreground maintenance; shares [_APIRequest] refresh mutex — no parallel
/// GetNewTokens.
class HallgatoBackgroundKeepAlive {
  HallgatoBackgroundKeepAlive._();

  static const String prefsKeyEnabled = 'SETTING_BackgroundHallgatoKeepAlive';

  static const String _workUniqueName =
      'com.nanda070.neptunmobile.hallgato_keepalive';
  static const String _workTaskName = 'hallgatoTokenRefresh';

  /// Android WorkManager period. Longer than the OS 15 min floor to cut battery
  /// cost; tradeoff vs 15 min: less refresh guarantee while backgrounded.
  static const Duration androidPeriod = Duration(minutes: 45);

  /// First Android tick sooner than [androidPeriod] so mid-length AFK can still
  /// refresh before the refresh JWT dies.
  static const Duration androidInitialDelay = Duration(minutes: 15);

  /// iOS Background Fetch minimum interval (minutes). System may schedule later
  /// or never.
  static const int iosMinimumFetchIntervalMinutes = 45;

  static bool _workmanagerInitialized = false;
  static bool _backgroundFetchConfigured = false;

  /// Call from [main] before [runApp] (headless entry points).
  static void registerHeadlessEntryPoints() {
    if (Platform.isIOS) {
      BackgroundFetch.registerHeadlessTask(_backgroundFetchHeadless);
    }
  }

  /// One-time plugin setup (safe to call on every cold start).
  static Future<void> initialize() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    if (Platform.isAndroid && !_workmanagerInitialized) {
      await wm.Workmanager().initialize(_workmanagerCallbackDispatcher);
      _workmanagerInitialized = true;
    }
    if (Platform.isIOS && !_backgroundFetchConfigured) {
      await BackgroundFetch.configure(
        BackgroundFetchConfig(
          minimumFetchInterval: iosMinimumFetchIntervalMinutes,
          stopOnTerminate: false,
          enableHeadless: true,
          startOnBoot: true,
          requiresBatteryNotLow: true,
          requiresCharging: false,
          requiresStorageNotLow: false,
          requiresDeviceIdle: false,
          requiredNetworkType: bg.NetworkType.ANY,
        ),
        _onBackgroundFetchEvent,
        _onBackgroundFetchTimeout,
      );
      _backgroundFetchConfigured = true;
    }
  }

  /// True when the OS should own JWT maintenance (app not actively resumed).
  static bool get _lifecycleAllowsBackgroundRegistration {
    final life = WidgetsBinding.instance.lifecycleState;
    // null = binding not fully up yet (cold start before first frame) — treat
    // as background-eligible so startup sync can arm when toggle is on.
    if (life == null) return true;
    return life == AppLifecycleState.paused ||
        life == AppLifecycleState.hidden ||
        life == AppLifecycleState.detached;
  }

  /// Register or cancel platform tasks from Settings + after [DataCache.loadData].
  ///
  /// Registers only when toggle **on**, logged in with refresh token, modern API,
  /// and lifecycle is **not** `resumed` (foreground timer owns maintenance then).
  static Future<void> syncScheduledTasks() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    final enabled = DataCache.getBackgroundHallgatoKeepAlive() ?? false;
    final loggedIn =
        (DataCache.getHasLogin() ?? false) &&
        (DataCache.getRefreshToken()?.isNotEmpty ?? false) &&
        DataCache.getIsModernApi();

    if (!enabled || !loggedIn) {
      await _cancelAll();
      return;
    }

    // Avoid duplicate WorkManager / BGFetch ticks while foreground 3m30s runs.
    if (!_lifecycleAllowsBackgroundRegistration) {
      await _cancelAll();
      return;
    }

    await initialize();

    if (Platform.isAndroid) {
      await wm.Workmanager().registerPeriodicTask(
        _workUniqueName,
        _workTaskName,
        frequency: androidPeriod,
        initialDelay: androidInitialDelay,
        constraints: wm.Constraints(
          networkType: wm.NetworkType.connected,
          requiresBatteryNotLow: true,
          requiresCharging: false,
          requiresDeviceIdle: false,
        ),
        existingWorkPolicy: wm.ExistingPeriodicWorkPolicy.update,
      );
      debug.log(
        'HallgatoBackgroundKeepAlive: WorkManager periodic registered '
        '(${androidPeriod.inMinutes} min, initial '
        '${androidInitialDelay.inMinutes} min, batteryNotLow+network)',
      );
    }

    if (Platform.isIOS) {
      final status = await BackgroundFetch.status;
      if (status == BackgroundFetch.STATUS_AVAILABLE) {
        await BackgroundFetch.start();
        debug.log('HallgatoBackgroundKeepAlive: BackgroundFetch started');
      } else {
        debug.log(
          'HallgatoBackgroundKeepAlive: BackgroundFetch unavailable ($status)',
        );
      }
    }
  }

  /// Cancel platform tasks (logout / toggle off / not logged in / resumed).
  static Future<void> cancelScheduledTasks() => _cancelAll();

  static Future<void> _cancelAll() async {
    if (Platform.isAndroid && _workmanagerInitialized) {
      await wm.Workmanager().cancelByUniqueName(_workUniqueName);
    } else if (Platform.isAndroid) {
      try {
        await wm.Workmanager().cancelByUniqueName(_workUniqueName);
      } catch (_) {}
    }
    if (Platform.isIOS) {
      try {
        await BackgroundFetch.stop();
      } catch (_) {}
    }
  }

  static Future<bool> _prefEnabledFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(prefsKeyEnabled) ?? 0) != 0;
  }

  static Future<void> _runMaintenanceFromHeadless() async {
    if (!await _prefEnabledFromDisk()) return;
    WidgetsFlutterBinding.ensureInitialized();
    await DataCache.loadData();
    if (!(DataCache.getHasLogin() ?? false)) return;
    await api.SessionGuard.runBackgroundTokenMaintenance();
  }
}

@pragma('vm:entry-point')
void _workmanagerCallbackDispatcher() {
  wm.Workmanager().executeTask((task, inputData) async {
    try {
      await HallgatoBackgroundKeepAlive._runMaintenanceFromHeadless();
    } catch (e, st) {
      debug.log('WorkManager hallgato keep-alive error: $e\n$st');
    }
    return true;
  });
}

@pragma('vm:entry-point')
void _backgroundFetchHeadless(HeadlessEvent event) async {
  final taskId = event.taskId;
  if (event.timeout) {
    BackgroundFetch.finish(taskId);
    return;
  }
  try {
    await HallgatoBackgroundKeepAlive._runMaintenanceFromHeadless();
  } catch (e, st) {
    debug.log('BackgroundFetch headless hallgato keep-alive error: $e\n$st');
  }
  BackgroundFetch.finish(taskId);
}

void _onBackgroundFetchEvent(String taskId) async {
  if (!(DataCache.getBackgroundHallgatoKeepAlive() ?? false) ||
      !(DataCache.getHasLogin() ?? false)) {
    BackgroundFetch.finish(taskId);
    return;
  }
  try {
    await api.SessionGuard.runBackgroundTokenMaintenance();
  } catch (e, st) {
    debug.log('BackgroundFetch hallgato keep-alive error: $e\n$st');
  }
  BackgroundFetch.finish(taskId);
}

void _onBackgroundFetchTimeout(String taskId) {
  BackgroundFetch.finish(taskId);
}
