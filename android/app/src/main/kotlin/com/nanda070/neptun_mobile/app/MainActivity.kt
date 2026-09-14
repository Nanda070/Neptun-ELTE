package com.nanda070.neptun_mobile.app

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.nanda070.neptun_mobile.app/shortcuts"
        private const val EXTRA_SHORTCUT_ID = "shortcut_id"
    }

    private var pendingShortcutId: String? = null
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        captureShortcut(intent)
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureShortcut(intent)
        val id = pendingShortcutId
        if (id != null) {
            methodChannel?.invokeMethod("shortcutActivated", id)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getLaunchShortcut" -> {
                        val id = pendingShortcutId
                        pendingShortcutId = null
                        result.success(id)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun captureShortcut(intent: Intent?) {
        if (intent == null) return
        val fromExtra = intent.getStringExtra(EXTRA_SHORTCUT_ID)
        if (!fromExtra.isNullOrBlank()) {
            pendingShortcutId = fromExtra
            return
        }
        val data = intent.data
        if (data != null && data.scheme == "neptunelte" && data.host == "shortcut") {
            val segment = data.lastPathSegment
            if (!segment.isNullOrBlank()) {
                pendingShortcutId = segment
            }
        }
    }
}
