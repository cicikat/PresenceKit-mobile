package com.presencekit.mobile

import android.content.Context
import android.app.KeyguardManager
import org.robolectric.Shadows.shadowOf
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class AmbientSensorsTest {
    @Test
    fun `locked phone returns unavailable facts even while activity is foreground`() {
        val context = RuntimeEnvironment.getApplication() as Context
        val prefs = context.getSharedPreferences("ambient-locked-fixture", Context.MODE_PRIVATE)
        val sensors = AmbientSensors(context, prefs)
        val keyguard = shadowOf(context.getSystemService(KeyguardManager::class.java))
        try {
            for (kind in listOf("light", "motion", "usage")) sensors.setEnabled(kind, true)
            sensors.refresh(true)
            keyguard.setKeyguardLocked(true)
            val observation = sensors.sample()
            assertEquals(setOf("light", "motion", "usage"), observation.keys)
            for (fact in observation.values) {
                assertEquals("unavailable", fact["status"])
                assertFalse(fact.containsKey("category_seconds"))
                assertFalse(fact.containsKey("lux"))
            }
        } finally {
            keyguard.setKeyguardLocked(false)
            sensors.refresh(false)
            prefs.edit().clear().commit()
        }
    }
    @Test
    fun `enabled foreground sources reach the platform sample and pause clears it`() {
        val context = RuntimeEnvironment.getApplication() as Context
        val prefs = context.getSharedPreferences("ambient-fixture", Context.MODE_PRIVATE)
        prefs.edit().clear().commit()
        val sensors = AmbientSensors(context, prefs)
        try {
            for (kind in listOf("light", "motion", "usage")) sensors.setEnabled(kind, true)
            sensors.refresh(true)
            val observation = sensors.sample()
            // Even missing hardware or denied permission must produce an explicit
            // fact; an empty sample silently prevents every HTTP upload.
            assertEquals(setOf("light", "motion", "usage"), observation.keys)
            for (fact in observation.values) {
                assertNotNull(fact["status"])
                assertTrue(fact["observed_at"] is Double)
            }
            sensors.setEnabled("light", false)
            assertEquals(setOf("motion", "usage"), sensors.sample().keys)
            sensors.refresh(false)
            assertTrue(sensors.sample().isEmpty())
        } finally {
            sensors.refresh(false)
            prefs.edit().clear().commit()
        }
    }
}
