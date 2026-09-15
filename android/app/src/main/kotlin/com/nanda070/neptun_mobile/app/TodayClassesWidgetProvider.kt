package com.nanda070.neptun_mobile.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

/**
 * Homescreen widget: today's classes from calendar-cache JSON only.
 * No JWT / passwords / tokens — mirrors iOS TodayClassesWidget honesty.
 */
class TodayClassesWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, id)
        }
    }

    companion object {
        const val PREFS_NAME = "neptun_widget"
        const val KEY_JSON = "todayClassesJson"
        const val KEY_UPDATED_AT = "todayClassesUpdatedAt"

        private val timeFmt: DateTimeFormatter =
            DateTimeFormatter.ofPattern("HH:mm").withZone(ZoneId.systemDefault())

        fun savePayload(context: Context, json: String, updatedAt: String?) {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putString(KEY_JSON, json)
                .apply {
                    if (updatedAt != null) putString(KEY_UPDATED_AT, updatedAt)
                }
                .apply()
            requestUpdate(context)
        }

        fun requestUpdate(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, TodayClassesWidgetProvider::class.java),
            )
            if (ids.isEmpty()) return
            val intent = Intent(context, TodayClassesWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            context.sendBroadcast(intent)
        }

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
        ) {
            val views = RemoteViews(context.packageName, R.layout.widget_today_classes)
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val raw = prefs.getString(KEY_JSON, null)

            val openCalendar = PendingIntent.getActivity(
                context,
                appWidgetId,
                Intent(Intent.ACTION_VIEW, Uri.parse("neptunelte://shortcut/calendar")).apply {
                    setPackage(context.packageName)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_root, openCalendar)

            if (raw.isNullOrBlank()) {
                bindEmpty(views, title = context.getString(R.string.widget_open_app), footer = context.getString(R.string.widget_no_cache))
                appWidgetManager.updateAppWidget(appWidgetId, views)
                return
            }

            try {
                val payload = JSONObject(raw)
                val hasCache = payload.optBoolean("hasCache", false)
                val stale = payload.optBoolean("stale", true)
                val classes = payload.optJSONArray("classes") ?: JSONArray()

                if (!hasCache) {
                    bindEmpty(views, title = context.getString(R.string.widget_open_app), footer = context.getString(R.string.widget_no_cache))
                } else if (classes.length() == 0) {
                    bindEmpty(
                        views,
                        title = context.getString(R.string.widget_no_classes),
                        footer = if (stale) {
                            context.getString(R.string.widget_footer_stale)
                        } else {
                            context.getString(R.string.widget_footer_cached)
                        },
                    )
                } else {
                    views.setViewVisibility(R.id.widget_empty, View.GONE)
                    views.setViewVisibility(R.id.widget_list, View.VISIBLE)
                    views.setViewVisibility(
                        R.id.widget_stale,
                        if (stale) View.VISIBLE else View.GONE,
                    )
                    val rowIds = intArrayOf(
                        R.id.widget_row0,
                        R.id.widget_row1,
                        R.id.widget_row2,
                        R.id.widget_row3,
                    )
                    val timeIds = intArrayOf(
                        R.id.widget_row0_time,
                        R.id.widget_row1_time,
                        R.id.widget_row2_time,
                        R.id.widget_row3_time,
                    )
                    val titleIds = intArrayOf(
                        R.id.widget_row0_title,
                        R.id.widget_row1_title,
                        R.id.widget_row2_title,
                        R.id.widget_row3_title,
                    )
                    val locIds = intArrayOf(
                        R.id.widget_row0_loc,
                        R.id.widget_row1_loc,
                        R.id.widget_row2_loc,
                        R.id.widget_row3_loc,
                    )
                    val limit = minOf(classes.length(), rowIds.size)
                    for (i in rowIds.indices) {
                        if (i < limit) {
                            val item = classes.getJSONObject(i)
                            views.setViewVisibility(rowIds[i], View.VISIBLE)
                            views.setTextViewText(timeIds[i], formatRange(item))
                            views.setTextViewText(titleIds[i], item.optString("title", ""))
                            val loc = item.optString("location", "")
                            if (loc.isBlank()) {
                                views.setViewVisibility(locIds[i], View.GONE)
                            } else {
                                views.setViewVisibility(locIds[i], View.VISIBLE)
                                views.setTextViewText(locIds[i], loc)
                            }
                        } else {
                            views.setViewVisibility(rowIds[i], View.GONE)
                        }
                    }
                    views.setTextViewText(
                        R.id.widget_footer,
                        if (stale) {
                            context.getString(R.string.widget_footer_stale)
                        } else {
                            context.getString(R.string.widget_footer_cached)
                        },
                    )
                }
            } catch (_: Exception) {
                bindEmpty(views, title = context.getString(R.string.widget_open_app), footer = context.getString(R.string.widget_no_cache))
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun bindEmpty(views: RemoteViews, title: String, footer: String) {
            views.setViewVisibility(R.id.widget_list, View.GONE)
            views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
            views.setViewVisibility(R.id.widget_stale, View.GONE)
            views.setTextViewText(R.id.widget_empty, title)
            views.setTextViewText(R.id.widget_footer, footer)
            for (id in intArrayOf(
                R.id.widget_row0, R.id.widget_row1, R.id.widget_row2, R.id.widget_row3,
            )) {
                views.setViewVisibility(id, View.GONE)
            }
        }

        private fun formatRange(item: JSONObject): String {
            val start = formatTime(item.optString("start", ""))
            val end = formatTime(item.optString("end", ""))
            return "$start–$end"
        }

        private fun formatTime(iso: String): String {
            if (iso.isBlank()) return "--:--"
            return try {
                val instant = Instant.parse(iso)
                timeFmt.format(instant)
            } catch (_: Exception) {
                // Tolerant of fractional / local formats from Dart.
                try {
                    val trimmed = iso.replace(Regex("\\.\\d+"), "")
                    val instant = Instant.parse(trimmed)
                    timeFmt.format(instant)
                } catch (_: Exception) {
                    if (iso.length >= 16) iso.substring(11, 16) else "--:--"
                }
            }
        }
    }
}
