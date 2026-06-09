package com.kleenops.kleenops_admin

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/**
 * Minimal foreground service that lets the WebRTC MediaProjection screen
 * capturer run during a call screen share. On Android 14+ (API 34+),
 * MediaProjectionManager.getMediaProjection() throws unless a
 * mediaProjection-typed foreground service is already running; the vendored
 * flutter_webrtc fork does not start one, so the app provides it here.
 *
 * Started/stopped from Dart via the "app/screen_capture" method channel
 * (MainActivity) immediately around getDisplayMedia.
 */
class ScreenCaptureService : Service() {
    companion object {
        private const val CHANNEL_ID = "screen_capture_channel"
        private const val NOTIFICATION_ID = 7613
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createChannel()

        val notification: Notification = Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("Sharing your screen")
            .setContentText("Your screen is being shared on a call.")
            .setSmallIcon(android.R.drawable.ic_menu_share)
            .setOngoing(true)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        return START_NOT_STICKY
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(NotificationManager::class.java) ?: return
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Screen sharing",
            NotificationManager.IMPORTANCE_LOW
        )
        channel.description = "Active while you share your screen on a call."
        nm.createNotificationChannel(channel)
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
