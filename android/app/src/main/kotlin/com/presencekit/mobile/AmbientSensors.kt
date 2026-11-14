package com.presencekit.mobile

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.SharedPreferences
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.Process
import android.os.SystemClock
import kotlin.math.abs

/** Foreground-only sensing. No raw samples or package names leave this class. */
internal class AmbientSensors(context: Context, private val prefs: SharedPreferences) : SensorEventListener {
    private val context = context.applicationContext
    private val sensors = context.getSystemService(SensorManager::class.java)
    private val light = sensors.getDefaultSensor(Sensor.TYPE_LIGHT)
    private val gravity = sensors.getDefaultSensor(Sensor.TYPE_GRAVITY)
    private val readings = mutableMapOf<String, Map<String, Any>>()
    private var active = false
    private var luxBaseline: Double? = null
    private var previousPose: String? = null

    fun refresh(foreground: Boolean) {
        sensors.unregisterListener(this)
        active = foreground
        readings.clear()
        luxBaseline = null
        previousPose = null
        if (!active) return
        if (enabled("light") && light != null) sensors.registerListener(this, light, SensorManager.SENSOR_DELAY_NORMAL)
        if (enabled("motion") && gravity != null) sensors.registerListener(this, gravity, SensorManager.SENSOR_DELAY_NORMAL)
    }

    fun settings() = keys.associateWith { enabled(it) } + mapOf(
        "lightSupported" to (light != null),
        "motionSupported" to (gravity != null),
        "usageSupported" to (Build.VERSION.SDK_INT >= 28),
        "usageGranted" to usageGranted(),
    )

    fun setEnabled(kind: String, value: Boolean) {
        require(kind in keys)
        prefs.edit().putBoolean("ambient_$kind", value).apply()
        refresh(active)
    }

    fun sample(): Map<String, Map<String, Any>> {
        if (!active) return emptyMap()
        val now = System.currentTimeMillis() / 1000.0
        return buildMap {
            for (kind in keys) {
                if (!enabled(kind)) continue
                val fact = when (kind) {
                    "light" -> reading(kind, light, now)
                    "motion" -> reading(kind, gravity, now)
                    else -> usage(now)
                }
                put(kind, fact)
            }
        }
    }

    private fun reading(kind: String, sensor: Sensor?, now: Double): Map<String, Any> {
        if (sensor == null) return fact("not_supported", now)
        val current = readings[kind] ?: return fact("unavailable", now)
        val observed = current["observed_at"] as Double
        return if (now - observed <= 120.0) current else fact("unavailable", now)
    }

    private fun enabled(kind: String) = prefs.getBoolean("ambient_$kind", false)

    override fun onSensorChanged(event: SensorEvent) {
        if (!active) return
        val now = System.currentTimeMillis() / 1000.0
        val age = (SystemClock.elapsedRealtimeNanos() - event.timestamp) / 1e9
        if (age !in 0.0..5.0 || event.accuracy == SensorManager.SENSOR_STATUS_UNRELIABLE) return
        when (event.sensor.type) {
            Sensor.TYPE_LIGHT -> {
                val lux = event.values[0].toDouble()
                if (lux !in 0.0..300_000.0) return
                val baseline = luxBaseline ?: lux
                val margin = maxOf(5.0, baseline * 0.25)
                val trend = when {
                    lux > baseline + margin -> "brighter"
                    lux < baseline - margin -> "darker"
                    else -> "stable"
                }
                luxBaseline = baseline * 0.8 + lux * 0.2
                val level = when {
                    lux < 10 -> "dark"
                    lux < 80 -> "dim"
                    lux < 500 -> "moderate"
                    else -> "bright"
                }
                readings["light"] = fact("available", now, 0.8) +
                    mapOf("lux" to lux, "level" to level, "trend" to trend)
            }
            Sensor.TYPE_GRAVITY -> {
                val z = event.values[2]
                if (!z.isFinite()) return
                val pose = when {
                    z > 8.0 -> "face_up"
                    z < -8.0 -> "face_down"
                    abs(z) < 3.0 -> "upright"
                    else -> null
                }
                if (pose != null && pose == previousPose) {
                    readings["motion"] = fact("available", now, 0.75) + ("kind" to pose)
                } else {
                    readings.remove("motion")
                }
                previousPose = pose
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    @Suppress("DEPRECATION")
    private fun usageGranted(): Boolean {
        val ops = context.getSystemService(AppOpsManager::class.java)
        return ops.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName,
        ) == AppOpsManager.MODE_ALLOWED
    }

    private fun usage(now: Double): Map<String, Any> {
        if (Build.VERSION.SDK_INT < 28) return fact("not_supported", now)
        if (!usageGranted()) return fact("permission_denied", now)
        val end = (now * 1000).toLong()
        val start = end - 3_600_000L
        val manager = context.getSystemService(UsageStatsManager::class.java)
        val events = manager.queryEvents(start - 3_600_000L, end) ?: return fact("unavailable", now)
        val row = UsageEvents.Event()
        var screenStart: Long? = null
        var interactiveMs = 0L
        var sessions = 0
        var sawScreenEvent = false
        var foregroundPackage: String? = null
        var foregroundSince = start
        val categoryMs = mutableMapOf<String, Long>()
        val packageCategories = mutableMapOf<String, String?>()
        fun finishApp(at: Long) {
            val name = foregroundPackage ?: return
            val duration = (at - foregroundSince).coerceAtLeast(0)
            if (duration == 0L) return
            if (!packageCategories.containsKey(name)) packageCategories[name] = category(name)
            val category = packageCategories[name] ?: return
            categoryMs[category] = (categoryMs[category] ?: 0) + duration
        }
        while (events.hasNextEvent()) {
            events.getNextEvent(row)
            when (row.eventType) {
                UsageEvents.Event.MOVE_TO_FOREGROUND -> {
                    finishApp(row.timeStamp)
                    foregroundPackage = row.packageName
                    foregroundSince = maxOf(start, row.timeStamp)
                }
                UsageEvents.Event.MOVE_TO_BACKGROUND -> {
                    if (foregroundPackage == row.packageName) {
                        finishApp(row.timeStamp)
                        foregroundPackage = null
                    }
                }
                UsageEvents.Event.SCREEN_INTERACTIVE -> {
                    sawScreenEvent = true
                    if (screenStart == null) {
                        screenStart = maxOf(row.timeStamp, start)
                        if (row.timeStamp >= start) sessions++
                    }
                }
                UsageEvents.Event.SCREEN_NON_INTERACTIVE -> {
                    finishApp(row.timeStamp)
                    foregroundPackage = null
                    sawScreenEvent = true
                    interactiveMs += screenStart?.let { (row.timeStamp - it).coerceAtLeast(0) } ?: 0
                    screenStart = null
                }
            }
        }
        finishApp(end)
        if (!sawScreenEvent) return fact("unavailable", now)
        interactiveMs += screenStart?.let { end - it } ?: 0
        return fact("available", now, 0.7) + mapOf(
            "window_start" to start / 1000.0,
            "screen_sessions" to sessions,
            "interactive_seconds" to interactiveMs / 1000,
            "category_seconds" to categoryMs.mapValues { (_, duration) -> duration / 1000 },
        )
    }

    @Suppress("DEPRECATION")
    private fun category(packageName: String): String? {
        if (packageName == context.packageName) return null
        val info = try {
            context.packageManager.getApplicationInfo(packageName, 0)
        } catch (_: PackageManager.NameNotFoundException) {
            return null
        }
        // Share only explicit low-sensitivity platform categories. Undefined,
        // social, communication and restricted packages contribute no duration.
        return when (info.category) {
            ApplicationInfo.CATEGORY_GAME -> "games"
            ApplicationInfo.CATEGORY_AUDIO, ApplicationInfo.CATEGORY_VIDEO -> "media"
            else -> null
        }
    }

    private fun fact(status: String, at: Double, confidence: Double = 0.0) =
        mapOf("status" to status, "observed_at" to at, "confidence" to confidence)

    companion object {
        private val keys = listOf("light", "motion", "usage")
    }
}
