package com.example.yexuan_memery.spike

import android.app.*
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.*
import android.util.Log
import androidx.core.app.NotificationCompat
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger

/**
 * Spike service: maintains a persistent SSE connection to an ntfy topic.
 * Does NOT share any code with MobileNotificationService.
 *
 * Key difference vs. MobileNotificationService long-poll:
 *   Long-poll:  client issues GET /mobile/poll?wait=55, server holds 55s, responds, client re-connects.
 *               Each cycle = 1 TCP connect + TLS handshake + HTTP round-trip.
 *   SSE relay:  client issues GET /topic/sse, server holds the socket open indefinitely.
 *               Messages stream as "data: …\n\n" lines. TCP connection is reused for all messages.
 *               The server pushes; the client just reads.
 *
 * Doze behaviour hypothesis:
 *   In Doze the kernel suspends non-exempt sockets after the maintenance window.
 *   A foreground dataSync service is NOT automatically network-exempt on stock Android 6+
 *   unless the user grants "Unrestricted" battery mode OR the app uses HIGH_PRIORITY FCM.
 *   On Chinese OEM ROMs the outcome depends on the vendor's allow-list.
 *   This spike measures empirically whether the SSE socket survives longer than the 55 s poll cycle.
 *
 * Setup:
 *   1. Add to AndroidManifest.xml — see manifest_additions.xml in this directory.
 *   2. Add OkHttp dependency — see build.gradle note below.
 *   3. Start with:
 *        NtfyRelayService.start(context, "http://192.168.x.x:8080", "yexuan-spike")
 *   4. Stop with:
 *        NtfyRelayService.stop(context)
 *
 * build.gradle additions (app module):
 *   implementation("com.squareup.okhttp3:okhttp:4.12.0")
 *   implementation("com.squareup.okhttp3:okhttp-sse:4.12.0")
 */
class NtfyRelayService : Service() {

    companion object {
        private const val TAG = "NtfyRelaySpike"
        private const val NOTIF_CHANNEL_SERVICE = "ntfy_spike_service"
        private const val NOTIF_CHANNEL_MSG     = "ntfy_spike_msg"
        private const val NOTIF_ID_ONGOING      = 9001

        private const val EXTRA_HOST  = "host"
        private const val EXTRA_TOPIC = "topic"

        // Reconnect backoff: 2s → 4s → 8s → … → 64s ceiling
        private const val BACKOFF_INITIAL_MS = 2_000L
        private const val BACKOFF_MAX_MS     = 64_000L

        // SSE keepalive: ntfy sends ": keepalive" comments every 55s.
        // If we see nothing for longer than this, the connection is dead.
        private const val READ_TIMEOUT_MS = 90_000

        fun start(ctx: Context, host: String, topic: String) {
            val intent = Intent(ctx, NtfyRelayService::class.java).apply {
                putExtra(EXTRA_HOST, host)
                putExtra(EXTRA_TOPIC, topic)
            }
            ctx.startForegroundService(intent)
        }

        fun stop(ctx: Context) {
            ctx.stopService(Intent(ctx, NtfyRelayService::class.java))
        }
    }

    private val running  = AtomicBoolean(false)
    private val msgCount = AtomicInteger(0)
    private val seenIds  = LinkedHashSet<String>()   // dedup; same pattern as MobileNotificationService
    private var sseThread: Thread? = null
    private var activeConn: HttpURLConnection? = null
    private lateinit var notificationManager: NotificationManager
    private lateinit var connectivityManager: ConnectivityManager
    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    // Config set from start intent
    private var host  = ""
    private var topic = ""

    // ---------------------------------------------------------------------------
    // Service lifecycle
    // ---------------------------------------------------------------------------

    override fun onCreate() {
        super.onCreate()
        notificationManager  = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        connectivityManager  = getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager
        createNotificationChannels()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        host  = intent?.getStringExtra(EXTRA_HOST)  ?: host
        topic = intent?.getStringExtra(EXTRA_TOPIC) ?: topic

        startForeground(NOTIF_ID_ONGOING, buildOngoingNotification("connecting…"))
        Log.i(TAG, "onStartCommand  host=$host  topic=$topic")

        if (!running.getAndSet(true)) {
            startSseThread()
            registerNetworkCallback()
        }
        return START_STICKY   // ask OS to restart if killed
    }

    override fun onDestroy() {
        running.set(false)
        unregisterNetworkCallback()
        activeConn?.disconnect()
        sseThread?.interrupt()
        Log.i(TAG, "onDestroy — total messages received: ${msgCount.get()}")
        super.onDestroy()
    }

    override fun onBind(intent: Intent?) = null

    // ---------------------------------------------------------------------------
    // SSE loop (raw HttpURLConnection — no extra lib needed)
    // ---------------------------------------------------------------------------

    private fun startSseThread() {
        sseThread = Thread({ sseLoop() }, "ntfy-spike-sse").apply {
            isDaemon = false
            start()
        }
    }

    private fun sseLoop() {
        var backoff = BACKOFF_INITIAL_MS
        while (running.get()) {
            try {
                connectAndRead()
                backoff = BACKOFF_INITIAL_MS    // reset on clean disconnect
            } catch (e: InterruptedException) {
                Log.d(TAG, "SSE thread interrupted — shutting down")
                break
            } catch (e: Exception) {
                if (!running.get()) break
                Log.w(TAG, "SSE error, reconnect in ${backoff}ms: ${e.message}")
                updateOngoingNotification("reconnecting in ${backoff / 1000}s…")
                waitOrAbort(backoff)
                backoff = (backoff * 2).coerceAtMost(BACKOFF_MAX_MS)
            }
        }
        Log.i(TAG, "SSE loop exited")
    }

    private fun connectAndRead() {
        // ntfy SSE endpoint: GET /topic/sse
        // Optional: ?poll=1 to also receive cached messages from the last 24h
        val url = URL("$host/$topic/sse?poll=1&since=all")
        Log.i(TAG, "SSE connecting to $url")
        updateOngoingNotification("connected to $topic")

        val conn = (url.openConnection() as HttpURLConnection).apply {
            requestMethod         = "GET"
            setRequestProperty("Accept", "text/event-stream")
            setRequestProperty("Cache-Control", "no-cache")
            connectTimeout        = 10_000
            readTimeout           = READ_TIMEOUT_MS
            doInput               = true
        }
        activeConn = conn

        try {
            val code = conn.responseCode
            if (code != 200) throw Exception("HTTP $code")

            val reader = BufferedReader(InputStreamReader(conn.inputStream, Charsets.UTF_8))
            parseSseStream(reader)
        } finally {
            conn.disconnect()
            activeConn = null
        }
    }

    /**
     * Parse an SSE stream line-by-line.
     * ntfy event format:
     *   event: message
     *   id: <uuid>
     *   data: {"id":"…","time":…,"event":"message","topic":"…","message":"…","title":"…"}
     *   (blank line)
     *
     *   : keepalive          ← comment, no id/data
     */
    private fun parseSseStream(reader: BufferedReader) {
        var eventId   = ""
        var eventData = ""
        var eventType = ""

        while (running.get()) {
            val line = reader.readLine() ?: break   // null = EOF / connection dropped

            when {
                line.startsWith("id:")    -> eventId   = line.removePrefix("id:").trim()
                line.startsWith("event:") -> eventType = line.removePrefix("event:").trim()
                line.startsWith("data:")  -> eventData = line.removePrefix("data:").trim()
                line.startsWith(":")      -> { /* keepalive comment — connection is alive */ }
                line.isEmpty() -> {
                    // blank line = event boundary, dispatch if we have data
                    if (eventData.isNotEmpty() && eventType != "open") {
                        onSseEvent(eventId, eventData)
                    }
                    eventId = ""; eventData = ""; eventType = ""
                }
            }
        }
    }

    private fun onSseEvent(id: String, rawData: String) {
        // Dedup by ntfy message ID (same pattern as seenMobileMessageIds in MobileNotificationService)
        if (id.isNotEmpty()) {
            synchronized(seenIds) {
                if (!seenIds.add(id)) return   // already seen
                if (seenIds.size > 200) seenIds.iterator().let { it.next(); it.remove() }
            }
        }

        // Extract message text — minimal JSON parse without a library
        val msg   = jsonField(rawData, "message")  ?: rawData
        val title = jsonField(rawData, "title")     ?: "ntfy-spike"
        val ts    = System.currentTimeMillis()

        val count = msgCount.incrementAndGet()
        Log.i(TAG, "MSG #$count  id=$id  title=$title  msg=$msg  epoch=$ts")
        updateOngoingNotification("$count msg(s) received; last: ${msg.take(40)}")
        postMessageNotification(count, title, msg, ts)
    }

    // ---------------------------------------------------------------------------
    // Network callback — reconnect immediately when network comes back
    // ---------------------------------------------------------------------------

    private fun registerNetworkCallback() {
        val req = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()
        networkCallback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                Log.i(TAG, "Network available — triggering reconnect")
                activeConn?.disconnect()   // current read will throw, sseLoop will reconnect
            }
        }
        connectivityManager.registerNetworkCallback(req, networkCallback!!)
    }

    private fun unregisterNetworkCallback() {
        networkCallback?.let { connectivityManager.unregisterNetworkCallback(it) }
        networkCallback = null
    }

    // ---------------------------------------------------------------------------
    // Notifications
    // ---------------------------------------------------------------------------

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        notificationManager.createNotificationChannel(
            NotificationChannel(NOTIF_CHANNEL_SERVICE, "ntfy Relay (Spike)", NotificationManager.IMPORTANCE_LOW)
                .apply { description = "Persistent relay spike service" }
        )
        notificationManager.createNotificationChannel(
            NotificationChannel(NOTIF_CHANNEL_MSG, "ntfy Messages (Spike)", NotificationManager.IMPORTANCE_HIGH)
                .apply { description = "Messages received via ntfy spike" }
        )
    }

    private fun buildOngoingNotification(status: String): Notification =
        NotificationCompat.Builder(this, NOTIF_CHANNEL_SERVICE)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("ntfy Relay Spike")
            .setContentText(status)
            .setOngoing(true)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()

    private fun updateOngoingNotification(status: String) {
        notificationManager.notify(NOTIF_ID_ONGOING, buildOngoingNotification(status))
    }

    private fun postMessageNotification(seq: Int, title: String, body: String, epochMs: Long) {
        val notif = NotificationCompat.Builder(this, NOTIF_CHANNEL_MSG)
            .setSmallIcon(android.R.drawable.ic_popup_reminder)
            .setContentTitle("[$seq] $title")
            .setContentText(body)
            .setWhen(epochMs)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()
        notificationManager.notify(NOTIF_ID_ONGOING + seq, notif)
    }

    // ---------------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------------

    private fun waitOrAbort(ms: Long) {
        try { Thread.sleep(ms) } catch (_: InterruptedException) { Thread.currentThread().interrupt() }
    }

    /** Minimal regex-free JSON field extractor — avoids a JSON library dep in the spike. */
    private fun jsonField(json: String, key: String): String? {
        val marker = "\"$key\":"
        val start  = json.indexOf(marker).takeIf { it >= 0 } ?: return null
        val after  = json.indexOf('"', start + marker.length).takeIf { it >= 0 } ?: return null
        val end    = json.indexOf('"', after + 1).takeIf { it >= 0 } ?: return null
        return json.substring(after + 1, end)
    }
}
