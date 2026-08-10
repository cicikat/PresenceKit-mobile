package com.presencekit.mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build

/** Idempotent notification-channel creation shared by the service and tests. */
object NotificationChannels {
    const val LEGACY_ID = "yexuan_mobile_channel"
    const val LEGACY_SERVICE_ID = "yexuan_mobile_service"
    const val SERVICE_ID = "yexuan_mobile_keepalive"
    const val MESSAGE_ID = "yexuan_mobile_messages"
    private const val CHANNEL_VERSION_KEY = "notificationChannelVersion"
    private const val CHANNEL_VERSION = 6

    fun ensure(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        val prefs = context.getSharedPreferences(BackendSecurityPolicy.PREFS_NAME, Context.MODE_PRIVATE)
        if (prefs.getInt(CHANNEL_VERSION_KEY, 0) < CHANNEL_VERSION) {
            manager.deleteNotificationChannel(LEGACY_ID)
            manager.deleteNotificationChannel(LEGACY_SERVICE_ID)
            manager.deleteNotificationChannel(SERVICE_ID)
            manager.deleteNotificationChannel(MESSAGE_ID)
            prefs.edit().putInt(CHANNEL_VERSION_KEY, CHANNEL_VERSION).apply()
        }
        manager.createNotificationChannel(
            NotificationChannel(SERVICE_ID, "后台常驻", NotificationManager.IMPORTANCE_MIN).apply {
                description = "保持后台接收状态，不用于消息弹窗"
                setSound(null, null)
                enableVibration(false)
            },
        )
        manager.createNotificationChannel(
            NotificationChannel(MESSAGE_ID, "消息通知", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "后台接收后端 mobile channel 主动消息，受静音时段和冷却控制"
            },
        )
    }
}
