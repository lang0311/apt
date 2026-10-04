package com.teamjkk.apt

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * 인스타그램 등에서 "공유 → 우리 앱"으로 들어온 텍스트(URL)를 Flutter로 전달한다.
 * - 콜드 스타트: getInitialText 로 1회 전달
 * - 웜 스타트(singleTop): onNewIntent → EventChannel
 */
class MainActivity : FlutterActivity() {
    private var initialText: String? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        initialText = extractSharedText(intent)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "apt/share").setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialText" -> {
                    result.success(initialText)
                    initialText = null
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "apt/share/events").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            },
        )
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        extractSharedText(intent)?.let { eventSink?.success(it) }
    }

    private fun extractSharedText(intent: Intent?): String? {
        if (intent?.action != Intent.ACTION_SEND || intent.type != "text/plain") return null
        return intent.getStringExtra(Intent.EXTRA_TEXT)
    }
}
