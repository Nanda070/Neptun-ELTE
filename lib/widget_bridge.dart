import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'API/api_coms.dart' as api;
import 'storage.dart' as storage;

/// Exports today's timetable classes to the iOS App Group for WidgetKit.
///
/// No JWT / passwords / tokens — title, times, and location only.
/// Android widgets are deferred (plan item 14 MVP is iOS-first).
class WidgetBridge {
  static const MethodChannel _channel =
      MethodChannel('com.nanda070.neptun_mobile.app/widget');

  static const String _appGroupHint = 'group.com.nanda070.neptunmobile';

  /// Sync widget payload from week-1 cache and/or in-memory entries.
  ///
  /// When [preferEntries] is non-null it is treated as the current-week list
  /// (including an honest empty week). Otherwise reads `CachedCalendar_w1_*`.
  static Future<void> sync({List<api.CalendarEntry>? preferEntries}) async {
    if (kIsWeb || !Platform.isIOS) return;

    try {
      List<api.CalendarEntry>? entries = preferEntries;
      var hasCache = preferEntries != null;

      if (!hasCache) {
        final loaded = await _loadWeek1FromCache();
        hasCache = loaded != null;
        entries = loaded;
      }

      final cacheTimeStr = await storage.getString('CalendarCacheTime');
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      var stale = true;
      String? updatedAt = cacheTimeStr;
      if (cacheTimeStr != null) {
        final parsed = DateTime.tryParse(cacheTimeStr);
        if (parsed != null) {
          final cacheDay = DateTime(parsed.year, parsed.month, parsed.day);
          stale = cacheDay.isBefore(today);
          updatedAt = cacheDay.toIso8601String();
        }
      } else if (hasCache) {
        // ICS / memory-only path: treat as fresh for today.
        stale = false;
        updatedAt = today.toIso8601String();
      }

      final classes = <Map<String, String>>[];
      if (entries != null) {
        final dayStart = today.millisecondsSinceEpoch;
        final dayEnd = dayStart + const Duration(days: 1).inMilliseconds;
        final todayClasses = entries
            .where((e) =>
                !e.isExam &&
                !e.isTask &&
                !e.isPeriodBanner &&
                e.startEpoch >= dayStart &&
                e.startEpoch < dayEnd)
            .toList()
          ..sort((a, b) => a.startEpoch.compareTo(b.startEpoch));

        for (final e in todayClasses) {
          classes.add({
            'title': e.title,
            'start': DateTime.fromMillisecondsSinceEpoch(e.startEpoch)
                .toIso8601String(),
            'end': DateTime.fromMillisecondsSinceEpoch(e.endEpoch)
                .toIso8601String(),
            'location': e.location == 'NULL' ? '' : e.location,
          });
        }
      }

      final payload = <String, dynamic>{
        'hasCache': hasCache,
        'updatedAt': updatedAt,
        'stale': hasCache ? stale : true,
        'classes': classes,
        // Documented for native readers; never secrets.
        'appGroup': _appGroupHint,
      };

      await _channel.invokeMethod<void>('updateTodayClasses', <String, dynamic>{
        'json': jsonEncode(payload),
        'updatedAt': updatedAt,
      });
    } on MissingPluginException {
      // Simulator / non-iOS shell without the channel.
    } on PlatformException catch (e) {
      debugPrint('WidgetBridge sync failed: ${e.message}');
    } catch (e) {
      debugPrint('WidgetBridge sync error: $e');
    }
  }

  /// Returns week-1 entries, or null when cache keys are missing.
  /// Empty list means a cached free week.
  static Future<List<api.CalendarEntry>?> _loadWeek1FromCache() async {
    const weekKey = 'CachedCalendar_w1';
    var len = await storage.getInt('${weekKey}_len');
    len ??= await storage.getInt('CachedCalendarLength');
    if (len == null) return null;

    final list = <api.CalendarEntry>[];
    for (var i = 0; i < len; i++) {
      final raw = await storage.getString('${weekKey}_$i') ??
          await storage.getString('CachedCalendar_$i');
      if (raw != null) {
        list.add(
          api.CalendarEntry('0', '0', 'NULL', 'NULL', false).fillWithExisting(raw),
        );
      }
    }
    return list;
  }
}
