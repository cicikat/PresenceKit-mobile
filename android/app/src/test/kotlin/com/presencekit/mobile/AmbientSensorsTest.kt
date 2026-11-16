package com.presencekit.mobile

import android.content.Context
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
