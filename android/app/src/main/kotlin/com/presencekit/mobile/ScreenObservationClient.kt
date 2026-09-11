package com.presencekit.mobile

import android.content.Context
import android.app.KeyguardManager
import android.os.Build
import android.os.PowerManager
import android.os.SystemClock
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.Proxy
import java.net.URL
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.CountDownLatch

/** The accessibility service owns this worker; no image or caption is persisted. */
class ScreenObservationClient(private val service: YexuanAccessibilityService) : AutoCloseable {
    private val executor = Executors.newSingleThreadScheduledExecutor()
    @Volatile private var closed = false
    @Volatile private var lastInteraction = 0L
    @Volatile private var connection: HttpURLConnection? = null

    fun start() { executor.scheduleWithFixedDelay({ runCatching { poll() } }, 0, 5, TimeUnit.SECONDS) }
    fun interacted() { lastInteraction = SystemClock.elapsedRealtime() }
    override fun close() { closed = true; connection?.disconnect(); executor.shutdownNow() }

    private fun credentials(): Pair<String, String>? {
        val prefs = service.getSharedPreferences(BackendSecurityPolicy.PREFS_NAME, Context.MODE_PRIVATE)
        val base = prefs.getString("backendBaseUrl", "")?.trim()?.trimEnd('/').orEmpty()
        if (!BackendSecurityPolicy.isAllowedBaseUrl(base, prefs)) return null
        val token = BackendSecurityPolicy.adminToken(service, prefs)
        if (token.isNullOrBlank()) return null
        return base to token
    }

    private fun post(credentials: Pair<String, String>, path: String, body: JSONObject): JSONObject? {
        if (closed || credentials() != credentials) return null
        val conn = URL(credentials.first + path).openConnection(Proxy.NO_PROXY) as HttpURLConnection
        connection = conn
        return try {
            conn.instanceFollowRedirects = false
            conn.connectTimeout = 5000; conn.readTimeout = 5000
            conn.requestMethod = "POST"; conn.doOutput = true
            conn.setRequestProperty("Authorization", "Bearer ${credentials.second}")
            conn.setRequestProperty("Content-Type", "application/json")
            conn.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
            if (conn.responseCode != 200) null else conn.inputStream.bufferedReader().use { JSONObject(it.readText()) }
        } finally { conn.disconnect(); connection = null }
    }

    private fun poll() {
        val credentials = credentials() ?: return
        val revision = revision(service)
        val idle = if (lastInteraction == 0L) 864000.0 else ((SystemClock.elapsedRealtime()-lastInteraction)/1000.0).coerceIn(0.0, 864000.0)
        val response = post(credentials, "/perception/screen/poll", JSONObject()
            .put("device", "mobile").put("available", available(service)).put("idle_seconds", idle)) ?: return
        if (!response.optBoolean("enabled")) return
        val request = response.optJSONObject("request") ?: return
        val deadline = SystemClock.elapsedRealtime() + (request.optDouble("ttl_seconds", 0.0)*1000).toLong()
        val latch = CountDownLatch(1)
        val captured = java.util.concurrent.atomic.AtomicReference<String?>(null)
        val accepting = java.util.concurrent.atomic.AtomicBoolean(true)
        fun current() = !closed && accepting.get() && revision(service) == revision && SystemClock.elapsedRealtime() < deadline
        if (available(service) && !closed) {
            service.captureObservation(::current) { value -> if (current()) captured.set(value); latch.countDown() }
            latch.await(5, TimeUnit.SECONDS)
        }
        accepting.set(false)
        if (closed || credentials() != credentials || revision(service) != revision || SystemClock.elapsedRealtime() >= deadline) return
        var image = captured.getAndSet(null)
        if (!available(service)) image = null
        post(credentials, "/perception/screen/result", JSONObject().put("device", "mobile")
            .put("request_id", request.getString("request_id"))
            .put("status", if (image != null) "ok" else "failed").put("image_base64", image ?: ""))
    }

    companion object {
        private const val PREFS = "screen_observation"
        private fun revision(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getLong("revision", 0)
        fun enabled(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean("enabled", false)
        fun available(context: Context): Boolean = enabled(context) && Build.VERSION.SDK_INT >= 30 &&
            context.getSystemService(PowerManager::class.java).isInteractive &&
            !context.getSystemService(KeyguardManager::class.java).isKeyguardLocked

        fun register(context: Context, messenger: BinaryMessenger) {
            MethodChannel(messenger, "presence_mobile/screen_observation").setMethodCallHandler { call, result ->
                when (call.method) {
                    "get", "set" -> {
                        if (call.method == "set") {
                            val value = call.argument<Boolean>("enabled")
                            if (value == null) { result.error("invalid", "enabled required", null); return@setMethodCallHandler }
                            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean("enabled", value)
                                .putLong("revision", revision(context) + 1).apply()
                        }
                        result.success(mapOf("enabled" to enabled(context), "supported" to (Build.VERSION.SDK_INT >= 30)))
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }
}
