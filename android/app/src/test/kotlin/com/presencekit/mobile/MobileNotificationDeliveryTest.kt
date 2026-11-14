package com.presencekit.mobile

import android.app.NotificationManager
import android.content.Context
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Assert.assertNotSame
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class MobileNotificationDeliveryTest {
    @Test
    fun `same foreground state and repeated starts do not rewrite notification`() {
        val lifecycle = Robolectric.buildService(MobileNotificationService::class.java).create()
        val service = lifecycle.get()
        val ensure = MobileNotificationService::class.java.getDeclaredMethod("ensureForeground", String::class.java)
            .apply { isAccessible = true }
        val update = MobileNotificationService::class.java.getDeclaredMethod("updateForegroundNotification", String::class.java)
            .apply { isAccessible = true }
        val disconnect = MobileNotificationService::class.java.getDeclaredMethod("markRelayDisconnected")
            .apply { isAccessible = true }
        val fallback = MobileNotificationService::class.java.getDeclaredMethod("activatePollingFallbackIfThresholdReached")
            .apply { isAccessible = true }
        val manager = service.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        fun current() = manager.activeNotifications.single { it.id == 10434 }.notification
        try {
            ensure.invoke(service, "waiting")
            update.invoke(service, "connected")
            val connected = current()
            repeat(10) {
                disconnect.invoke(service)
                fallback.invoke(service)
                update.invoke(service, "connected")
                ensure.invoke(service, "waiting")
            }
            assertSame(connected, current())
            // A sustained loss must still show the existing honest fallback state.
            MobileNotificationService::class.java.getDeclaredField("relayUnavailableSince").apply {
                isAccessible = true
                setLong(service, System.currentTimeMillis() - 61_000)
            }
            fallback.invoke(service)
            assertNotSame(connected, current())
            assertEquals("中继不可用，已安排周期补偿", current().extras.getString("android.text"))
            lifecycle.destroy()
            update.invoke(service, "late worker")
            assertEquals(0, manager.activeNotifications.count { it.id == 10434 })
        } finally {
            if (MobileNotificationService.isServiceRunning) lifecycle.destroy()
        }
    }

    @Test
    fun `distinct messages notify within thirty minutes and redelivery is deduplicated`() {
        val lifecycle = Robolectric.buildService(MobileNotificationService::class.java).create()
        val service = lifecycle.get()
        val prefs = service.getSharedPreferences(BackendSecurityPolicy.PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().clear()
            .putString("backendBaseUrl", "http://127.0.0.1:8080")
            .putString("ownerUserId", "owner")
            .putBoolean("notificationTestMode", false)
            .putLong("lastMessageNotificationAt", System.currentTimeMillis())
            .commit()
        val consume = MobileNotificationService::class.java.getDeclaredMethod(
            "consumeMobileMessage", JSONObject::class.java, String::class.java,
        ).apply { isAccessible = true }
        fun deliver(id: String, seq: Long) {
            consume.invoke(service, JSONObject().put("id", id).put("seq", seq)
                .put("content", "message $id").put("timestamp", System.currentTimeMillis() / 1000.0), "poll")
        }
        try {
            deliver("first", 1)
            deliver("second", 2)
            deliver("second", 2)
            val manager = service.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            assertEquals(2, manager.activeNotifications.count { it.id >= 20000 })
            assertEquals(0, prefs.getInt("suppressedMessageNotifications", 0))
        } finally {
            lifecycle.destroy()
        }
    }
}
