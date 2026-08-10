package com.presencekit.mobile

import android.Manifest
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.provider.Settings
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class NativeCapabilitiesInstrumentedTest {
    private val context = ApplicationProvider.getApplicationContext<Context>()

    @After
    fun removeSyntheticCredentials() {
        val store = AndroidKeystoreCredentialStore(context)
        store.delete("instrumented-fixture-a")
        store.delete("instrumented-fixture-b")
        context.getSharedPreferences(BackendSecurityPolicy.PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .remove("instrumented-corrupt")
            .apply()
    }

    @Test
    fun notificationChannelsAreCreatedIdempotently() {
        NotificationChannels.ensure(context)
        NotificationChannels.ensure(context)

        val manager = context.getSystemService(NotificationManager::class.java)
        val service = manager.getNotificationChannel(NotificationChannels.SERVICE_ID)
        val messages = manager.getNotificationChannel(NotificationChannels.MESSAGE_ID)
        assertNotNull(service)
        assertNotNull(messages)
        assertEquals(NotificationManager.IMPORTANCE_MIN, service!!.importance)
        assertEquals(NotificationManager.IMPORTANCE_HIGH, messages!!.importance)
    }

    @Test
    fun manifestAndSystemPermissionGatesAreDeclared() {
        val packageManager = context.packageManager
        val accessibility = packageManager.getServiceInfo(
            ComponentName(context, YexuanAccessibilityService::class.java),
            PackageManager.GET_META_DATA,
        )
        assertEquals(Manifest.permission.BIND_ACCESSIBILITY_SERVICE, accessibility.permission)
        assertTrue(accessibility.metaData?.containsKey("android.accessibilityservice") == true)

        val accessibilitySettings = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
        assertNotNull(packageManager.resolveActivity(accessibilitySettings, 0))
        val overlayIntent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            android.net.Uri.parse("package:${context.packageName}"),
        )
        assertEquals(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, overlayIntent.action)
    }

    @Test
    fun keystoreRoundTripUsesCiphertextAndSeparatesLogicalAliases() {
        val store = AndroidKeystoreCredentialStore(context)
        assertTrue(store.write("instrumented-fixture-a", "synthetic-a"))
        assertTrue(store.write("instrumented-fixture-b", "synthetic-b"))
        assertEquals("synthetic-a", store.read("instrumented-fixture-a"))
        assertEquals("synthetic-b", store.read("instrumented-fixture-b"))

        val prefs = context.getSharedPreferences("presencekit_secure_credentials", Context.MODE_PRIVATE)
        assertNotEquals("synthetic-a", prefs.getString("instrumented-fixture-a", null))
        assertNotEquals("synthetic-b", prefs.getString("instrumented-fixture-b", null))

        prefs.edit().putString("instrumented-corrupt", "v2:not-valid").commit()
        assertNull(store.read("instrumented-corrupt"))
    }

    @Test
    fun accessibilityAndOverlayCapabilitiesFailClosedWithoutUserAuthorization() {
        assertNull(YexuanAccessibilityService.captureScreenContext())
        assertFalse(YexuanAccessibilityService.requestOpenCart("taobao"))
        val overlayIntent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            android.net.Uri.parse("package:${context.packageName}"),
        )
        assertNotNull(context.packageManager.resolveActivity(overlayIntent, 0))
    }
}
