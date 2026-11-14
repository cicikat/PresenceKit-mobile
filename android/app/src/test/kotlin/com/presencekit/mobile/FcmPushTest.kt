package com.presencekit.mobile

import android.app.NotificationManager
import android.content.Context
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RuntimeEnvironment
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class FcmPushTest {
    @Test
    fun onlyCurrentOptedInBackgroundInstallationPostsOneNotification() {
        val context = RuntimeEnvironment.getApplication()
        val prefs = context.getSharedPreferences(BackendSecurityPolicy.PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().clear().putString("fcmInstallation", "fixture-installation")
            .putLong("fcmGeneration", 42L).commit()
        val data = mapOf(
            "type" to "new_message", "message_id" to "test-message",
            "seq" to "1", "installation_id" to "fixture-installation", "generation" to "42",
        )
        val notifications = context.getSystemService(NotificationManager::class.java)
        assertNull(FcmPush.notifyIfEligible(context, data))
        prefs.edit().putBoolean("fcmEnabled", true).commit()
        assertNull(FcmPush.notifyIfEligible(context, data + ("generation" to "41")))
        assertNull(FcmPush.notifyIfEligible(context, data + ("seq" to "-1")))
        try {
            FcmPush.foreground = true
            assertNull(FcmPush.notifyIfEligible(context, data))
            assertEquals(0, notifications.activeNotifications.size)
            FcmPush.foreground = false
            assertNotNull(FcmPush.notifyIfEligible(context, data))
            assertNull(FcmPush.notifyIfEligible(context, data))
            val shown = notifications.activeNotifications.single()
            assertEquals("test-message", shown.tag)
            assertNotNull(shown.notification.contentIntent)
            FcmPush.disconnect(context)
            assertEquals(0, notifications.activeNotifications.size)
            assertNull(FcmPush.notifyIfEligible(context, data))
        } finally {
            FcmPush.foreground = false
        }
    }
}
