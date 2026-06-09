package com.kleenops.kleenops_admin

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val screenCaptureChannel = "app/screen_capture"
    private val fcmDefaultChannelId = "fcm_default_channel"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createFcmDefaultNotificationChannel()
    }

    private fun createFcmDefaultNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(NotificationManager::class.java) ?: return
        val channel = NotificationChannel(
            fcmDefaultChannelId,
            "Messages & Alerts",
            NotificationManager.IMPORTANCE_HIGH
        )
        channel.description = "Calls, texts, and alerts"
        nm.createNotificationChannel(channel)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            screenCaptureChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    startScreenCaptureService()
                    result.success(true)
                }
                "stop" -> {
                    stopScreenCaptureService()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Starts the mediaProjection foreground service ahead of capture. */
    private fun startScreenCaptureService() {
        val intent = Intent(this, ScreenCaptureService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopScreenCaptureService() {
        stopService(Intent(this, ScreenCaptureService::class.java))
    }
}
