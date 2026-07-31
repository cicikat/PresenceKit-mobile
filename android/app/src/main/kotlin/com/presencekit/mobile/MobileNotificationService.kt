package com.presencekit.mobile

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Person
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.drawable.Icon
import android.os.Build
import android.os.IBinder
import android.os.SystemClock
import android.provider.Settings
import android.util.Log
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject
import java.io.BufferedReader
import java.io.File
import java.io.IOException
import java.io.InputStreamReader
import java.net.ConnectException
import java.net.HttpURLConnection
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import java.net.URL
import java.util.Calendar
import java.util.concurrent.atomic.AtomicInteger

class MobileNotificationService : Service() {
    private val tag = "CompanionMobileService"
    private val legacyChannelId = "yexuan_mobile_channel"
    private val legacyServiceChannelId = "yexuan_mobile_service"
    private val serviceChannelId = "yexuan_mobile_keepalive"
    private val messageChannelId = "yexuan_mobile_messages"
    private val foregroundId = 10434
    private val quietStartMinute = 23 * 60 + 30
    private val quietEndMinute = 6 * 60 + 30
    private val messageCooldownMs = 30 * 60 * 1000L
    private val initialRetryDelayMs = 1000L
    private val maximumRetryDelayMs = 60_000L
    private val relayFallbackThresholdMs = 15 * 60 * 1000L
    private val relayReadTimeoutMs = 90_000
    private val supplementalPollIntervalMs = 6 * 60 * 60 * 1000L
    private val timeoutRecoveryDelayMs = 24 * 60 * 60 * 1000L + 5 * 60 * 1000L
    @Volatile private var running = false
    @Volatile private var pollInFlight = false
    @Volatile private var relayInFlight = false
    @Volatile private var relaySignalPollPending = false
    @Volatile private var fallbackPollScheduled = false
    @Volatile private var foregroundStarted = false
    @Volatile private var timeoutTriggered = false
    // scope 配错（403）对同一 token 重试没有意义，只会刷后端审计日志并可能触发 429；
    // 记住这次判定为 scope 不足的 token，同一 token 下跳过后续真实请求，直到用户换 token。
    @Volatile private var scopeInsufficientToken: String? = null
    @Volatile private var consumerSource = ConsumerSource.WAITING_RELAY
    @Volatile private var relayUnavailableSince = 0L
    private val notificationIndex = AtomicInteger(0)
    private val pollGeneration = AtomicInteger(0)
    private val pollStateLock = Any()
    private val messageConsumptionLock = Any()
    @Volatile private var activePollConnection: HttpURLConnection? = null
    @Volatile private var activeRelayConnection: HttpURLConnection? = null

    override fun onCreate() {
        super.onCreate()
        isServiceRunning = true
        createNotificationChannel()
        notificationPermissionError()?.let(::recordBackgroundError)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        ensureForeground("\u7b49\u5f85\u65b0\u6d88\u606f")
        val scheduledOneShot = intent?.getBooleanExtra(scheduledOneShotExtra, false) == true
        val debugContent = intent?.getStringExtra("debugDeliveryContent").orEmpty()
        if (debugContent.isNotBlank() && intent != null) {
            deliverDebugMessage(intent, debugContent)
            if (!running) {
                stopForegroundAndSelf(startId)
            }
            return START_NOT_STICKY
        }
        val prefs = servicePrefs()
        val token = BackendSecurityPolicy.adminToken(this, prefs)
        val baseUrl = backendBaseUrl()
        val gateError = when {
            scheduledOneShot && !prefs.getBoolean("backgroundNotificationsEnabled", true) ->
                "background notifications disabled"
            token.isBlank() -> "token invalid: missing credential"
            baseUrl == null || !BackendSecurityPolicy.isAllowedBaseUrl(baseUrl, prefs) ->
                "origin rejected"
            else -> null
        }
        if (gateError != null) {
            recordBackgroundError(gateError)
            stopForegroundAndSelf(startId)
            return START_NOT_STICKY
        }
        if (scheduledOneShot) {
            fallbackPollScheduled = false
            if (!running && relayConfig() != null) {
                running = true
                timeoutTriggered = false
                startConsumerCoordinator(startId)
            }
            if (consumerSource == ConsumerSource.RELAY) {
                cancelSupplementalPoll()
                return START_STICKY
            }
            runOneShotPoll(startId)
            return if (running) START_STICKY else START_NOT_STICKY
        }
        if (!running) {
            Log.d(tag, "starting background consumer")
            running = true
            timeoutTriggered = false
            startConsumerCoordinator(startId)
        }
        return START_STICKY
    }

    override fun onTimeout(startId: Int, fgsType: Int) {
        // The manifest uses specialUse, so Android should not invoke the dataSync quota callback.
        // Keep this defensive shutdown path in case a future manifest change reintroduces a quota.
        timeoutTriggered = true
        running = false
        pollGeneration.incrementAndGet()
        activeRelayConnection?.disconnect()
        activePollConnection?.disconnect()
        val reason = "dataSync foreground service time limit reached"
        recordBackgroundError(reason)
        recordRelayStatus("timeout", reason)
        servicePrefs().edit().putBoolean("backgroundNotificationServiceRunning", false).apply()
        scheduleSupplementalPoll(timeoutRecoveryDelayMs)
        Log.w(tag, "$reason; scheduled recovery poll after quota window")
        foregroundStarted = false
        stopForeground(true)
        stopSelf(startId)
    }

    private fun deliverDebugMessage(intent: Intent, content: String) {
        val behaviorRaw = intent.getStringExtra("debugDeliveryBehavior").orEmpty()
        val behavior = runCatching {
            if (behaviorRaw.isBlank()) null else JSONObject(behaviorRaw)
        }.getOrNull()
        Log.d(tag, "debug background delivery behavior=${behavior != null}")
        if (behavior == null) {
            showMessageNotification(content)
            return
        }
        deliverBackgroundMessage(content, behavior)
    }

    private fun startConsumerCoordinator(startId: Int) {
        val config = relayConfig()
        if (config == null) {
            recordRelayStatus("unconfigured", null)
            updateForegroundNotification("\u4e2d\u7ee7\u672a\u914d\u7f6e\uff0c\u4ec5\u5468\u671f\u8865\u507f")
            running = false
            runOneShotPoll(startId)
            return
        }
        consumerSource = ConsumerSource.WAITING_RELAY
        relayUnavailableSince = System.currentTimeMillis()
        recordRelayStatus("connecting", null)
        updateForegroundNotification("\u6b63\u5728\u8fde\u63a5\u4e2d\u7ee7")
        runRelayIfIdle()
    }

    private fun runRelayIfIdle() {
        if (!running || relayInFlight) return
        relayInFlight = true
        Thread {
            var retryDelayMs = initialRetryDelayMs
            try {
                while (running) {
                    val config = relayConfig()
                    if (config == null) {
                        schedulePollingFallback("relay configuration unavailable")
                        running = false
                        stopSelf()
                        return@Thread
                    }
                    activatePollingFallbackIfThresholdReached()
                    try {
                        connectAndReadRelay(config)
                        retryDelayMs = initialRetryDelayMs
                    } catch (error: Exception) {
                        if (!running) break
                        val wasConnected = consumerSource == ConsumerSource.RELAY
                        markRelayDisconnected()
                        if (wasConnected) retryDelayMs = initialRetryDelayMs
                        val reason = readableRelayError(error)
                        recordRelayStatus(
                            if (fallbackPollScheduled) "fallback_poll" else "reconnecting",
                            reason,
                        )
                        if (reason.startsWith("subscription failed")) {
                            schedulePollingFallback(reason)
                        } else {
                            activatePollingFallbackIfThresholdReached()
                        }
                        Log.w(tag, "relay subscription failed: $reason", error)
                        waitForRetry(retryDelayMs)
                        retryDelayMs = (retryDelayMs * 2).coerceAtMost(maximumRetryDelayMs)
                    }
                }
            } finally {
                relayInFlight = false
            }
        }.apply {
            name = "companion-mobile-relay"
            start()
        }
    }

    private fun connectAndReadRelay(config: RelayConfig) {
        val endpoint = "${config.baseUrl}/${config.topic}/sse"
        val connection = (URL(endpoint).openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            instanceFollowRedirects = false
            connectTimeout = 8000
            readTimeout = relayReadTimeoutMs
            setRequestProperty("Accept", "text/event-stream")
            setRequestProperty("Cache-Control", "no-cache")
            config.token?.let { setRequestProperty("Authorization", "Bearer $it") }
        }
        activeRelayConnection = connection
        try {
            val statusCode = connection.responseCode
            if (statusCode !in 200..299) {
                connection.errorStream?.close()
                throw IOException("HTTP $statusCode")
            }
            val generation = activateRelayConsumer()
            BufferedReader(InputStreamReader(connection.inputStream, Charsets.UTF_8)).use { reader ->
                readRelayStream(reader, generation)
            }
            if (running && consumerSource == ConsumerSource.RELAY) {
                markRelayDisconnected()
                throw IOException("relay stream closed")
            }
        } finally {
            if (activeRelayConnection === connection) activeRelayConnection = null
            connection.disconnect()
        }
    }

    private fun activateRelayConsumer(): Int {
        val generation = pollGeneration.incrementAndGet()
        consumerSource = ConsumerSource.RELAY
        relayUnavailableSince = 0L
        activePollConnection?.disconnect()
        cancelSupplementalPoll()
        recordRelayStatus("connected", null)
        recordRelayHeartbeat()
        recordBackgroundError(notificationPermissionError())
        updateForegroundNotification("\u4e2d\u7ee7\u5df2\u8fde\u63a5")
        Log.d(tag, "relay connected; poll generation=$generation")
        return generation
    }

    private fun markRelayDisconnected() {
        if (relayUnavailableSince == 0L) relayUnavailableSince = System.currentTimeMillis()
        if (consumerSource == ConsumerSource.RELAY) {
            pollGeneration.incrementAndGet()
            consumerSource = ConsumerSource.WAITING_RELAY
        }
    }

    private fun activatePollingFallbackIfThresholdReached() {
        if (consumerSource == ConsumerSource.RELAY) return
        val unavailableSince = relayUnavailableSince.takeIf { it > 0 } ?: System.currentTimeMillis()
        relayUnavailableSince = unavailableSince
        if (System.currentTimeMillis() - unavailableSince >= relayFallbackThresholdMs) {
            schedulePollingFallback("relay unavailable for ${relayFallbackThresholdMs / 60_000}m")
        }
    }

    private fun schedulePollingFallback(reason: String) {
        if (consumerSource == ConsumerSource.RELAY || fallbackPollScheduled) return
        recordRelayStatus("fallback_poll", reason)
        recordBackgroundError("relay unavailable; periodic polling fallback scheduled")
        updateForegroundNotification("\u4e2d\u7ee7\u4e0d\u53ef\u7528\uff0c\u5df2\u5b89\u6392\u5468\u671f\u8865\u507f")
        scheduleSupplementalPoll(1000L)
        Log.w(tag, "scheduled periodic polling fallback: $reason")
    }

    private fun readRelayStream(reader: BufferedReader, generation: Int) {
        var eventType = ""
        val data = StringBuilder()
        while (running && consumerSource == ConsumerSource.RELAY && pollGeneration.get() == generation) {
            val line = reader.readLine() ?: return
            recordRelayHeartbeat()
            when {
                line.startsWith("event:") -> eventType = line.removePrefix("event:").trim()
                line.startsWith("data:") -> {
                    if (data.isNotEmpty()) data.append('\n')
                    data.append(line.removePrefix("data:").trimStart())
                }
                line.isEmpty() -> {
                    if (data.isNotEmpty() && (eventType.isEmpty() || eventType == "message")) {
                        consumeRelayEvent(data.toString(), generation)
                    }
                    eventType = ""
                    data.setLength(0)
                }
            }
        }
    }

    private fun consumeRelayEvent(rawData: String, generation: Int) {
        if (pollGeneration.get() != generation || consumerSource != ConsumerSource.RELAY) return
        decodeRelayMessage(rawData) ?: return
        servicePrefs().edit().putLong("lastRelayDeliveredAt", System.currentTimeMillis()).apply()
        // Relay is wake-only. Even legacy payloads containing content must return to the
        // authenticated backend so message bodies never become a relay delivery path.
        triggerRelaySignalPoll(generation)
    }

    private fun decodeRelayMessage(rawData: String): JSONObject? {
        return runCatching {
            val outer = JSONObject(rawData)
            if (outer.optString("event").isNotBlank() && outer.optString("event") != "message") {
                return@runCatching null
            }
            when (val wrapped = outer.opt("message")) {
                is JSONObject -> wrapped
                is String -> JSONObject(wrapped)
                else -> outer
            }
        }.onFailure {
            recordRelayStatus("connected", "relay payload parse failed")
            Log.w(tag, "relay payload parse failed", it)
        }.getOrNull()
    }

    private fun triggerRelaySignalPoll(generation: Int) {
        synchronized(pollStateLock) {
            if (pollGeneration.get() != generation || consumerSource != ConsumerSource.RELAY) return
            relaySignalPollPending = true
            if (pollInFlight) return
            pollInFlight = true
        }
        Thread {
            try {
                while (pollGeneration.get() == generation && consumerSource == ConsumerSource.RELAY) {
                    val shouldPoll = synchronized(pollStateLock) {
                        if (!relaySignalPollPending) {
                            false
                        } else {
                            relaySignalPollPending = false
                            true
                        }
                    }
                    if (!shouldPoll) break
                    pollOnce(allowRelayFallback = true, allowRelayConnected = true)
                }
            } finally {
                synchronized(pollStateLock) {
                    pollInFlight = false
                }
                resumePendingRelaySignalPoll()
            }
        }.apply {
            name = "companion-mobile-relay-signal-poll"
            start()
        }
    }

    private fun resumePendingRelaySignalPoll() {
        val generation = pollGeneration.get()
        if (relaySignalPollPending && consumerSource == ConsumerSource.RELAY) {
            triggerRelaySignalPoll(generation)
        }
    }

    private fun runOneShotPoll(startId: Int) {
        if (servicePrefs().getBoolean("mobileAppInForeground", false)) {
            cancelSupplementalPoll()
            if (!running) stopForegroundAndSelf(startId)
            return
        }
        if (consumerSource == ConsumerSource.RELAY) {
            cancelSupplementalPoll()
            if (!running) stopForegroundAndSelf(startId)
            return
        }
        val started = synchronized(pollStateLock) {
            if (pollInFlight) {
                false
            } else {
                pollInFlight = true
                true
            }
        }
        if (!started) {
            scheduleSupplementalPoll(supplementalPollIntervalMs)
            return
        }
        Thread {
            try {
                pollOnce(allowRelayFallback = true)
            } finally {
                synchronized(pollStateLock) {
                    pollInFlight = false
                }
                resumePendingRelaySignalPoll()
                if (consumerSource != ConsumerSource.RELAY && shouldScheduleSupplementalPoll()) {
                    scheduleSupplementalPoll(supplementalPollIntervalMs)
                }
                if (!running) {
                    stopForegroundAndSelf(startId)
                }
            }
        }.apply {
            name = "companion-mobile-one-shot-poll"
            start()
        }
    }

    private fun shouldScheduleSupplementalPoll(): Boolean {
        val prefs = servicePrefs()
        val baseUrl = backendBaseUrl()
        return prefs.getBoolean("backgroundNotificationsEnabled", true) &&
            BackendSecurityPolicy.adminToken(this, prefs).isNotBlank() &&
            baseUrl != null &&
            BackendSecurityPolicy.isAllowedBaseUrl(baseUrl, prefs)
    }

    private fun scheduleSupplementalPoll(delayMs: Long) {
        runCatching {
            val manager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val triggerAt = SystemClock.elapsedRealtime() + delayMs
            val operation = PendingIntent.getForegroundService(
                this,
                supplementalPollRequestCode,
                Intent(this, MobileNotificationService::class.java).apply {
                    putExtra(scheduledOneShotExtra, true)
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !manager.canScheduleExactAlarms()) {
                manager.setAndAllowWhileIdle(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    triggerAt,
                    operation,
                )
            } else {
                manager.setExactAndAllowWhileIdle(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    triggerAt,
                    operation,
                )
            }
            fallbackPollScheduled = true
            Log.d(tag, "scheduled supplemental poll in ${delayMs / 60_000} minutes")
        }.onFailure { error ->
            val reason = "supplemental poll schedule failed: ${error.javaClass.simpleName}"
            recordBackgroundError(reason)
            Log.e(tag, reason, error)
        }
    }

    private fun cancelSupplementalPoll() {
        cancelScheduledFallback(this)
        fallbackPollScheduled = false
    }

    override fun onDestroy() {
        Log.d(tag, "service destroyed")
        isServiceRunning = false
        running = false
        pollGeneration.incrementAndGet()   // 令所有在途轮次失效
        activeRelayConnection?.disconnect()
        activePollConnection?.disconnect() // 主动中断在途补偿轮询，避免服务销毁后继续消费。
        recordRelayStatus("stopped", null)
        servicePrefs().edit().putBoolean("backgroundNotificationServiceRunning", false).apply()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun stopForegroundAndSelf(startId: Int) {
        foregroundStarted = false
        servicePrefs().edit().putBoolean("backgroundNotificationServiceRunning", false).apply()
        stopForeground(true)
        stopSelf(startId)
    }

    private fun pollOnce(
        allowRelayFallback: Boolean = false,
        allowRelayConnected: Boolean = false,
    ): Boolean {
        val prefs = servicePrefs()
        val gen = pollGeneration.get()
        if (!allowRelayConnected && consumerSource == ConsumerSource.RELAY ||
            running && !allowRelayFallback
        ) {
            return true
        }
        prefs.edit().putLong("lastBackgroundPollAt", System.currentTimeMillis()).apply()
        val token = BackendSecurityPolicy.adminToken(this, prefs)
        val baseUrl = backendBaseUrl()
        if (token.isBlank()) {
            recordBackgroundError("token invalid: missing credential")
            running = false
            stopSelf()
            return false
        }
        if (baseUrl == null || !BackendSecurityPolicy.isAllowedBaseUrl(baseUrl, prefs)) {
            recordBackgroundError("origin rejected")
            running = false
            stopSelf()
            return false
        }
        if (scopeInsufficientToken == token) {
            // 同一 token 已确认 scope 不足；跳过本次真实请求，避免继续刷审计日志/触发 429。
            return false
        }
        try {
            Log.d(tag, "polling $baseUrl")
            postScreenContext(baseUrl, token)
            val activation = JSONObject(postJson("$baseUrl/mobile/activate", "{}", token))
            if (!activation.optBoolean("ok") || !activation.optBoolean("active")) {
                throw IOException(activation.optString("error", "mobile channel is not active"))
            }
            if (pollGeneration.get() != gen ||
                !allowRelayConnected && consumerSource == ConsumerSource.RELAY
            ) {
                Log.d(tag, "poll generation changed before fallback poll request")
                return true
            }
            // signal 即时回源与周期补偿都只做一次非阻塞拉取，不在后台维持长轮询。
            val lastAckedSeq = prefs.getLong("lastAckedSeq", Long.MIN_VALUE)
            val afterQuery = if (lastAckedSeq == Long.MIN_VALUE) "" else "&after=$lastAckedSeq"
            val body = pollJson("$baseUrl/mobile/poll?limit=20$afterQuery", token)
            val decoded = JSONObject(body)
            if (!decoded.optBoolean("ok") || !decoded.optBoolean("active")) {
                throw IOException(decoded.optString("error", "mobile channel is not active"))
            }
            val messages = decoded.optJSONArray("messages") ?: throw JSONException("messages missing")
            Log.d(tag, "received ${messages.length()} messages")
            if (pollGeneration.get() != gen) {
                // onDestroy() 已调用，此轮结果属于僵尸轮次，丢弃避免前台串台。
                Log.d(tag, "poll generation stale (gen=$gen), discarding ${messages.length()} messages")
                return true
            }
            var batchMaxSeq: Long? = null
            for (i in 0 until messages.length()) {
                if (pollGeneration.get() != gen ||
                    !allowRelayConnected && consumerSource == ConsumerSource.RELAY
                ) {
                    Log.d(tag, "stopping stale poll delivery at message index=$i")
                    break
                }
                val item = messages.optJSONObject(i) ?: continue
                consumeMobileMessage(item, "poll")
                if (item.has("seq") && !item.isNull("seq")) {
                    val seq = item.optLong("seq", Long.MIN_VALUE)
                    if (seq != Long.MIN_VALUE && (batchMaxSeq == null || seq > batchMaxSeq!!)) {
                        batchMaxSeq = seq
                    }
                }
            }
            if (batchMaxSeq != null) {
                val ack = JSONObject(postJson(
                    "$baseUrl/mobile/ack",
                    JSONObject().put("ack_seq", batchMaxSeq).toString(),
                    token,
                ))
                if (!ack.optBoolean("ok")) {
                    throw IOException(ack.optString("error", "mobile acknowledgement failed"))
                }
                persistLastAckedSeq(batchMaxSeq)
            }
            if (!timeoutTriggered) {
                recordBackgroundError(notificationPermissionError())
            }
            return true
        } catch (error: Exception) {
            if (pollGeneration.get() != gen ||
                !allowRelayConnected && consumerSource == ConsumerSource.RELAY
            ) {
                Log.d(tag, "stale poll interrupted after consumer source changed")
                return true
            }
            val reason = readablePollError(error)
            if (!timeoutTriggered) {
                recordBackgroundError(reason)
            }
            if (reason == "token scope insufficient") {
                scopeInsufficientToken = token
            }
            Log.w(tag, "background poll failed: $reason", error)
            return false
        }
    }

    private fun waitForRetry(delayMs: Long) {
        Log.d(tag, "retrying background consumer in ${delayMs / 1000.0}s")
        var remainingMs = delayMs
        while (running && remainingMs > 0) {
            val sleepMs = remainingMs.coerceAtMost(500L)
            try {
                Thread.sleep(sleepMs)
            } catch (_: InterruptedException) {
                Thread.currentThread().interrupt()
                return
            }
            remainingMs -= sleepMs
        }
    }

    private fun readablePollError(error: Exception): String {
        if (error is JSONException) return "parse failed"
        if (error is SocketTimeoutException) return "network timeout"
        if (error is UnknownHostException) return "network unavailable: host not found"
        if (error is ConnectException) return "network unavailable: connection failed"
        val message = error.message.orEmpty()
        if (error is IOException && message.contains("HTTP 401")) return "token invalid"
        if (error is IOException && message.contains("HTTP 403")) return "token scope insufficient"
        if (error is IOException && message.startsWith("HTTP ")) return "backend error: $message"
        if (error is IOException) return "network failed"
        return "poll failed: ${error.javaClass.simpleName}"
    }

    private fun readableRelayError(error: Exception): String {
        if (error is SocketTimeoutException) return "relay heartbeat timeout"
        if (error is UnknownHostException) return "relay network unavailable: host not found"
        if (error is ConnectException) return "relay network unavailable: connection failed"
        val message = error.message.orEmpty()
        if (error is IOException && message.startsWith("HTTP ")) {
            return "subscription failed: $message"
        }
        if (error is IOException) return "relay network failed"
        return "relay failed: ${error.javaClass.simpleName}"
    }

    private fun notificationPermissionError(): String? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            return "notification permission denied"
        }
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && !manager.areNotificationsEnabled()) {
            "notifications disabled in system settings"
        } else {
            null
        }
    }

    private fun recordBackgroundError(reason: String?) {
        val editor = servicePrefs().edit()
        if (reason == null) {
            editor.remove("lastBackgroundError")
        } else {
            editor.putString("lastBackgroundError", reason)
        }
        editor.apply()
    }

    private fun recordRelayStatus(status: String, error: String?) {
        val editor = servicePrefs().edit().putString("relayConnectionStatus", status)
        if (error.isNullOrBlank()) {
            editor.remove("lastRelayError")
        } else {
            editor.putString("lastRelayError", error)
        }
        editor.apply()
    }

    private fun recordRelayHeartbeat() {
        servicePrefs().edit().putLong("lastRelayHeartbeatAt", System.currentTimeMillis()).apply()
    }

    private fun backendBaseUrl(): String? {
        val prefs = servicePrefs()
        val stored = prefs.getString("backendBaseUrl", null)?.trim().orEmpty()
        val value = (stored.ifEmpty { "http://127.0.0.1:8080" }).trimEnd('/')
        return if (BackendSecurityPolicy.originFor(value) != null) value else null
    }

    private fun servicePrefs() =
        getSharedPreferences(BackendSecurityPolicy.PREFS_NAME, Context.MODE_PRIVATE)

    private fun getJson(endpoint: String, token: String): String {
        val connection = (URL(endpoint).openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            instanceFollowRedirects = false
            connectTimeout = 8000
            readTimeout = 70000
            setRequestProperty("Authorization", "Bearer $token")
        }
        try {
            val statusCode = connection.responseCode
            val stream = if (statusCode in 200..299) {
                connection.inputStream
            } else {
                connection.errorStream
            }
            val body = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
            if (statusCode !in 200..299) throw IOException("HTTP $statusCode")
            return body
        } finally {
            connection.disconnect()
        }
    }

    // 专用于补偿轮询端点：将连接引用暴露给 onDestroy() 以便主动 disconnect()。
    private fun pollJson(endpoint: String, token: String): String {
        val connection = (URL(endpoint).openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            instanceFollowRedirects = false
            connectTimeout = 8000
            readTimeout = 70000
            setRequestProperty("Authorization", "Bearer $token")
        }
        activePollConnection = connection
        try {
            val statusCode = connection.responseCode
            val stream = if (statusCode in 200..299) connection.inputStream else connection.errorStream
            val body = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
            if (statusCode !in 200..299) throw IOException("HTTP $statusCode")
            return body
        } finally {
            activePollConnection = null
            connection.disconnect()
        }
    }

    private fun consumeMobileMessage(item: JSONObject, source: String): Boolean {
        val content = item.optString("content").trim()
        if (content.isEmpty()) return false
        val id = item.optString("id").trim()
        synchronized(messageConsumptionLock) {
            if (id.isNotEmpty()) {
                val seenIds = readSeenMobileMessageIds()
                if (!seenIds.add(id)) {
                    Log.d(tag, "skipping already-seen $source message id=$id")
                    return false
                }
                while (seenIds.size > 200) {
                    seenIds.iterator().let { iterator ->
                        iterator.next()
                        iterator.remove()
                    }
                }
                // Intentional dual write with Flutter _pollMobile (via MethodChannel), guarded by
                // foreground/background handoff timing; this is not a bug. A future option is one
                // MethodChannel merge writer.
                val persisted = servicePrefs().edit()
                    .putString("seenMobileMessageIds", JSONArray(seenIds.toList()).toString())
                    .commit()
                if (!persisted) throw IOException("could not persist seen mobile message ids")
            }
            deliverBackgroundMessage(content, item.optJSONObject("behavior"))
        }
        return true
    }

    private fun readSeenMobileMessageIds(): LinkedHashSet<String> {
        val json = servicePrefs().getString("seenMobileMessageIds", null) ?: return LinkedHashSet()
        return runCatching {
            val arr = JSONArray(json)
            (0 until arr.length()).mapTo(LinkedHashSet()) { arr.getString(it) }
        }.getOrElse { LinkedHashSet() }
    }

    private fun persistLastAckedSeq(value: Long) {
        synchronized(messageConsumptionLock) {
            val prefs = servicePrefs()
            val current = prefs.getLong("lastAckedSeq", Long.MIN_VALUE)
            if (value <= current) return
            if (!prefs.edit().putLong("lastAckedSeq", value).commit()) {
                throw IOException("could not persist last acked mobile seq")
            }
        }
    }

    private fun relayConfig(): RelayConfig? {
        val prefs = servicePrefs()
        val baseUrl = BackendSecurityPolicy.relayBaseUrl(prefs)?.trimEnd('/') ?: return null
        val topic = BackendSecurityPolicy.relayTopic(prefs) ?: return null
        if (!BackendSecurityPolicy.isAllowedRelayUrl(baseUrl, prefs) ||
            topic.length > 128 ||
            !topic.matches(Regex("[a-z0-9/_-]+"))
        ) {
            return null
        }
        return RelayConfig(baseUrl, topic, BackendSecurityPolicy.relayToken(this, prefs))
    }

    private fun postJson(endpoint: String, payload: String, token: String): String {
        val bytes = payload.toByteArray(Charsets.UTF_8)
        val connection = (URL(endpoint).openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            instanceFollowRedirects = false
            connectTimeout = 8000
            readTimeout = 20000
            doOutput = true
            setRequestProperty("Authorization", "Bearer $token")
            setRequestProperty("Content-Type", "application/json; charset=utf-8")
        }
        try {
            connection.outputStream.use { it.write(bytes) }
            val statusCode = connection.responseCode
            val stream = if (statusCode in 200..299) {
                connection.inputStream
            } else {
                connection.errorStream
            }
            val body = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
            if (statusCode !in 200..299) throw IOException("HTTP $statusCode")
            return body
        } finally {
            connection.disconnect()
        }
    }

    private fun postScreenContext(baseUrl: String, token: String) {
        if (!BackendSecurityPolicy.screenContextUploadEnabled(servicePrefs())) return
        val snapshot = YexuanAccessibilityService.captureScreenContext() ?: return
        if (snapshot["isBlocked"] == true) return
        val packageName = snapshot["packageName"]?.toString().orEmpty()
        val appLabel = snapshot["appLabel"]?.toString().orEmpty()
        // 不再有按 App 的文本上传白名单——唯一闸是上面的 screenContextUploadEnabled()
        // 主开关；敏感 App/密码框/敏感关键词的内容拦截仍在 captureScreenContext() 里做。
        val title = snapshot["windowTitle"]?.toString().orEmpty()
        val visible = snapshot["visibleText"] as? List<*> ?: emptyList<Any>()
        val clickable = snapshot["clickableText"] as? List<*> ?: emptyList<Any>()
        val payload = JSONObject().apply {
            put("window_seconds", 60)
            put("ts", System.currentTimeMillis() / 1000.0)
            put("sensor_version", "android_accessibility_1.0")
            put(
                "input",
                JSONObject().apply {
                    put("keystrokes", 0)
                    put("mouse_clicks", 0)
                    put("mouse_distance_px", 0)
                    put("idle_seconds", 0)
                },
            )
            put(
                "focus",
                JSONObject().apply {
                    put("app", packageName)
                    put("title_hint", title.ifBlank { appLabel })
                    put("switch_count", 0)
                },
            )
            put(
                "screen",
                JSONObject().apply {
                    put("package_name", packageName)
                    put("app_label", appLabel)
                    put("window_title", title)
                    put("visible_text", JSONArray(visible.map { it.toString() }))
                    put("clickable_text", JSONArray(clickable.map { it.toString() }))
                },
            )
        }
        runCatching {
            postJson("$baseUrl/sensor/realtime", payload.toString(), token)
        }.onFailure {
            Log.d(tag, "screen context push skipped", it)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        val prefs = getSharedPreferences("yexuan_memery", Context.MODE_PRIVATE)
        if (prefs.getInt("notificationChannelVersion", 0) < 6) {
            manager.deleteNotificationChannel(legacyChannelId)
            manager.deleteNotificationChannel(legacyServiceChannelId)
            manager.deleteNotificationChannel(serviceChannelId)
            manager.deleteNotificationChannel(messageChannelId)
            prefs.edit().putInt("notificationChannelVersion", 6).apply()
        }
        val serviceChannel = NotificationChannel(
            serviceChannelId,
            "\u540e\u53f0\u5e38\u9a7b",
            NotificationManager.IMPORTANCE_MIN,
        ).apply {
            description = "\u4fdd\u6301\u540e\u53f0\u63a5\u6536\u72b6\u6001\uff0c\u4e0d\u7528\u4e8e\u6d88\u606f\u5f39\u7a97"
            setSound(null, null)
            enableVibration(false)
        }
        val messageChannel = NotificationChannel(
            messageChannelId,
            "\u6d88\u606f\u901a\u77e5",
            // IMPORTANCE_DEFAULT \u53ea\u4f1a\u8fdb\u901a\u77e5\u680f\uff0c\u7cfb\u7edf\u4e0d\u4f1a\u5f39\u6a2a\u5e45(heads-up)\uff1b
            // channel importance \u521b\u5efa\u540e\u4e0d\u53ef\u6539\uff0cversion 6 \u5f3a\u5236\u5220\u65e7\u5efa\u65b0\u4ee5\u751f\u6548\u3002
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "\u540e\u53f0\u63a5\u6536\u540e\u7aef mobile channel \u4e3b\u52a8\u6d88\u606f\uff0c\u53d7\u9759\u97f3\u65f6\u6bb5\u548c\u51b7\u5374\u63a7\u5236"
        }
        manager.createNotificationChannel(serviceChannel)
        manager.createNotificationChannel(messageChannel)
    }

    private fun ensureForeground(text: String) {
        if (foregroundStarted) {
            updateForegroundNotification(text)
            return
        }
        foregroundStarted = true
        servicePrefs().edit().putBoolean("backgroundNotificationServiceRunning", true).apply()
        startForeground(foregroundId, buildForegroundNotification(text))
    }

    private fun buildForegroundNotification(text: String) =
        notificationBuilder(serviceChannelId)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("PresenceKit\u540e\u53f0\u63a5\u6536")
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setLocalOnly(true)
            .setCategory(android.app.Notification.CATEGORY_SERVICE)
            .setPriority(android.app.Notification.PRIORITY_MIN)
            .setContentIntent(openAppIntent())
            .build()

    private fun deliverBackgroundMessage(content: String, behavior: JSONObject?) {
        val overlay = overlayRequestFor(behavior)
        if (overlay != null && showBehaviorOverlay(content, overlay)) {
            return
        }
        handleIncomingMessage(content)
    }

    private fun handleIncomingMessage(content: String) {
        val now = System.currentTimeMillis()
        val blockReason = notificationBlockReason(now)
        if (blockReason != null) {
            recordSuppressedMessage(blockReason)
            return
        }
        showMessageNotification(content)
        servicePrefs()
            .edit()
            .putLong("lastMessageNotificationAt", now)
            .putInt("suppressedMessageNotifications", 0)
            .remove("lastNotificationSuppressReason")
            .apply()
    }

    private fun overlayRequestFor(behavior: JSONObject?): OverlayRequest? {
        if (behavior == null) return null
        val mode = modeFor(
            behavior.optString("behavior_id"),
            behavior.optString("kind"),
            behavior.optString("delivery"),
            behavior.optString("level"),
        ) ?: return null
        val route = if (mode == "lock" || mode == "order" || mode == "control") "action" else "presence"
        val taskId = if (mode == "control") behavior.optString("task_id").ifBlank { null } else null
        val task = if (mode == "control") behavior.optString("task").ifBlank { null } else null
        return OverlayRequest(mode, route, taskId, task)
    }

    companion object {
        @Volatile
        var isServiceRunning: Boolean = false
            private set

        private const val scheduledOneShotExtra = "scheduledOneShotPoll"
        private const val supplementalPollRequestCode = 10435

        internal fun cancelScheduledFallback(context: Context) {
            val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val operation = PendingIntent.getForegroundService(
                context,
                supplementalPollRequestCode,
                Intent(context, MobileNotificationService::class.java).apply {
                    putExtra(scheduledOneShotExtra, true)
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            manager.cancel(operation)
        }

        // Exact whitelist \u2014 only explicit IDs and kinds trigger high-intent overlays.
        // Unknown behavior_id or kind falls through to structural fields, then returns null
        // (caller degrades to a regular notification).
        internal fun modeFor(
            behaviorId: String,
            kind: String,
            delivery: String,
            level: String,
        ): String? = when (behaviorId) {
            "lock_screen", "lock_screen_confirm" -> "lock"
            "takeout_order", "takeout_overlay" -> "order"
            "phone_control_task" -> "control"
            "presence_ping" -> "message"
            else -> when (kind) {
                "lock_screen_confirm" -> "lock"
                "takeout_overlay" -> "order"
                "overlay_message" -> "message"
                else -> when {
                    delivery == "overlay" ||
                        level == "attention_grab" ||
                        level == "direct_act" -> "message"
                    else -> null
                }
            }
        }
    }

    private fun showBehaviorOverlay(content: String, request: OverlayRequest): Boolean {
        if (!canDrawOverlays()) {
            Log.d(tag, "overlay skipped: missing permission route=${request.route}")
            return false
        }
        startService(
            Intent(this, FloatingBubbleService::class.java).apply {
                putExtra("mode", request.mode)
                putExtra("message", content)
                putExtra("target", "meituan")
                request.taskId?.let { putExtra("task_id", it) }
                request.task?.let { putExtra("task", it) }
            },
        )
        val label = if (request.route == "action") {
            "\u5df2\u5f39\u51fa\u4e00\u4e2a\u786e\u8ba4\u8bf7\u6c42"
        } else {
            "\u5df2\u5f39\u51fa\u4e00\u6761\u60ac\u6d6e\u63d0\u9192"
        }
        updateForegroundNotification(label)
        Log.d(tag, "overlay shown route=${request.route} mode=${request.mode}")
        return true
    }

    private data class OverlayRequest(
        val mode: String,
        val route: String,
        val taskId: String? = null,
        val task: String? = null,
    )

    private data class RelayConfig(
        val baseUrl: String,
        val topic: String,
        val token: String?,
    )

    private enum class ConsumerSource {
        WAITING_RELAY,
        RELAY,
    }

    private fun canDrawOverlays(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(this)
    }

    private fun notificationBlockReason(now: Long): String? {
        if (servicePrefs().getBoolean("notificationTestMode", false)) {
            return null
        }
        if (isQuietMinute(currentMinuteOfDay())) {
            return "\u9759\u97f3\u65f6\u6bb5 23:30-06:30"
        }
        val lastShown = servicePrefs().getLong("lastMessageNotificationAt", 0L)
        if (lastShown > 0 && now - lastShown < messageCooldownMs) {
            return "30 \u5206\u949f\u51b7\u5374\u4e2d"
        }
        return null
    }

    private fun currentMinuteOfDay(): Int {
        val calendar = Calendar.getInstance()
        return calendar.get(Calendar.HOUR_OF_DAY) * 60 + calendar.get(Calendar.MINUTE)
    }

    private fun isQuietMinute(minute: Int): Boolean {
        return minute >= quietStartMinute || minute < quietEndMinute
    }

    private fun recordSuppressedMessage(reason: String) {
        val count = suppressedCount() + 1
        servicePrefs()
            .edit()
            .putInt("suppressedMessageNotifications", count)
            .putString("lastNotificationSuppressReason", reason)
            .apply()
        updateForegroundNotification("\u5df2\u9759\u9ed8\u6536\u53d6 $count \u6761\u00b7$reason")
        Log.d(tag, "message notification suppressed: $reason")
    }

    private fun suppressedCount(): Int {
        return servicePrefs().getInt("suppressedMessageNotifications", 0)
    }

    private fun updateForegroundNotification(text: String) {
        if (!foregroundStarted) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(foregroundId, buildForegroundNotification(text))
    }

    // Fully-resolved character display name cached by Flutter's
    // _syncCachedCharacterDisplayName() (local nickname override, else backend
    // character name, else neutral fallback). Falls back to the neutral label
    // here too in case the cache was never written (fresh install, or the
    // MethodChannel write raced with the very first background message).
    private fun characterDisplayName(): String {
        val cached = servicePrefs().getString("cachedCharacterDisplayName", null)?.trim().orEmpty()
        return cached.ifBlank { "TA" }
    }

    // Same file MainActivity.avatarFile() writes to (app-private filesDir, not
    // scoped by servicePrefs). Any Context \u2014 Service included \u2014 sees the same
    // filesDir for this app, so no extra plumbing needed to share it.
    private fun avatarBitmap(): Bitmap? {
        val file = File(filesDir, "profile_avatar.png")
        if (!file.exists()) return null
        return runCatching { BitmapFactory.decodeFile(file.absolutePath) }.getOrNull()
    }

    // Banner preview budget: ~15 CJK chars/line, 2 lines max before it looks
    // cramped on a heads-up notification \u2014 measured empirically on-device, not
    // an OS constant. Set below the naive 2\u00d715=30 because 30 (29 chars + "\u2026")
    // still wrapped to 3 lines in practice \u2014 keeping a margin here instead of
    // cutting it exactly at the line budget. Only the popup is capped; the
    // in-app chat history still gets the untruncated `content`.
    private val notificationPreviewMaxChars = 25

    // Only the first "bubble" (paragraph \u2014 same \n+ split desktop uses to turn
    // one reply into multiple chat bubbles) is ever shown in the popup; the
    // rest is truncated with an ellipsis, same as if that first paragraph
    // alone had run past the 2-line budget. Full text is one tap away in-app.
    private fun notificationPreviewText(content: String): String {
        val firstParagraph = content
            .split(Regex("\n+"))
            .map { it.trim() }
            .firstOrNull { it.isNotEmpty() }
            ?: content.trim()
        return if (firstParagraph.length > notificationPreviewMaxChars) {
            firstParagraph.take(notificationPreviewMaxChars - 1) + "\u2026"
        } else {
            firstParagraph
        }
    }

    // 已静默收取的条数不再拼进弹窗正文（会顶掉两行预算）；能力检查页和常驻前台
    // 状态栏（recordSuppressedMessage → updateForegroundNotification）已经展示这个计数。
    private fun showMessageNotification(content: String) {
        val id = 20000 + (notificationIndex.getAndIncrement() % 1000)
        val preview = notificationPreviewText(content)
        val displayName = characterDisplayName()
        val avatar = avatarBitmap()
        val builder = notificationBuilder(messageChannelId)
            .setSmallIcon(android.R.drawable.ic_dialog_email)
            .setContentTitle(displayName)
            .setContentText(preview)
            .setAutoCancel(true)
            .setContentIntent(openAppIntent())
        if (avatar != null) {
            builder.setLargeIcon(avatar)
        }
        // MessagingStyle renders the sender's avatar on the left like a chat
        // bubble (Person requires API 28+); older devices keep the plain
        // BigTextStyle + setLargeIcon() from before \u2014 avatar still shows, just
        // on the right instead of the left. Both styles use the same
        // paragraph-capped `preview`, not the raw multi-paragraph `content` \u2014
        // expanding the notification must not spill the full reply either.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val sender = Person.Builder().setName(displayName).apply {
                if (avatar != null) setIcon(Icon.createWithBitmap(avatar))
            }.build()
            val me = Person.Builder().setName("").build()
            builder.setStyle(
                android.app.Notification.MessagingStyle(me)
                    .addMessage(preview, System.currentTimeMillis(), sender),
            )
        } else {
            builder.setStyle(android.app.Notification.BigTextStyle().bigText(preview))
        }
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(id, builder.build())
    }

    private fun notificationBuilder(channelId: String): android.app.Notification.Builder {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            android.app.Notification.Builder(this, channelId)
        } else {
            @Suppress("DEPRECATION")
            android.app.Notification.Builder(this)
        }
    }

    private fun openAppIntent(): PendingIntent {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        return PendingIntent.getActivity(this, 0, intent, flags)
    }
}
