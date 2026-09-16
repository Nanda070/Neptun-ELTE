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
/// **Battery / OS honesty:** intervals are conservative (15+ min). Android WorkManager
/// and iOS Background Fetch defer or skip tasks (Doze, Low Power Mode, force-stop).
/// Uses the same [SessionGuard.runBackgroundTokenMaintenance] helper as foreground
/// maintenance; shares [_APIRequest] refresh mutex — no parallel GetNewTokens.
class HallgatoBackgroundKeepAlive {
  HallgatoBackgroundKeepAlive._();

  static const String prefsKeyEnabled = 'SETTING_BackgroundHallgatoKeepAlive';

  static const String _workUniqueName =
      'com.nanda070.neptunmobile.hallgato_keepalive';
  static const String _workTaskName = 'hallgatoTokenRefresh';

  /// Android WorkManager minimum practical period (OS may defer further).
  static const Duration _androidPeriod = Duration(minutes: 15);

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
          minimumFetchInterval: 15,
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

  /// Register or cancel platform tasks from Settings + after [DataCache.loadData].
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

    await initialize();

    if (Platform.isAndroid) {
      await wm.Workmanager().registerPeriodicTask(
        _workUniqueName,
        _workTaskName,
        frequency: _androidPeriod,
        initialDelay: _androidPeriod,
        constraints: wm.Constraints(
          networkType: wm.NetworkType.connected,
          requiresBatteryNotLow: true,
        ),
        existingWorkPolicy: wm.ExistingPeriodicWorkPolicy.update,
      );
      debug.log('HallgatoBackgroundKeepAlive: WorkManager periodic registered');
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

  /// Cancel platform tasks (logout / toggle off / not logged in).
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
