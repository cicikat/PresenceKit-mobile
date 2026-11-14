package com.presencekit.mobile

import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import androidx.work.Constraints
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.OutOfQuotaPolicy
import androidx.work.WorkManager
import androidx.work.workDataOf
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.firebase.FirebaseApp
import com.google.firebase.messaging.FirebaseMessaging
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URI
import java.net.URL
import java.util.UUID
import java.util.concurrent.Executors

internal object FcmPush {
    private const val ENABLED = "fcmEnabled"
    private const val INSTALLATION = "fcmInstallation"
    private const val GENERATION = "fcmGeneration"
    private const val STATE = "fcmState"
    private const val SEEN = "fcmSeenMessages"
    private const val NOTIFICATION_ID = 317
    private val lock = Any()
    private val io = Executors.newSingleThreadExecutor()
    @Volatile var foreground = false

    private data class Binding(
        val origin: String,
        val credential: String,
        val installation: String,
        val character: String,
    )

    internal data class Wake(val id: String, val seq: Long, val installation: String, val generation: Long) {
        fun traceItem() = JSONObject().put("id", id)
    }

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(BackendSecurityPolicy.PREFS_NAME, Context.MODE_PRIVATE)

    fun enabled(prefs: SharedPreferences): Boolean = prefs.getBoolean(ENABLED, false)

    private fun hasFirebase(context: Context) = FirebaseApp.getApps(context).isNotEmpty()

    private fun hasPlayServices(context: Context) =
        GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(context) == ConnectionResult.SUCCESS

    private fun canNotify(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= 33 &&
            context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) !=
            android.content.pm.PackageManager.PERMISSION_GRANTED
        ) return false
        val manager = context.getSystemService(NotificationManager::class.java)
        return (Build.VERSION.SDK_INT < 24 || manager.areNotificationsEnabled()) &&
            (Build.VERSION.SDK_INT < 26 ||
                manager.getNotificationChannel(NotificationChannels.MESSAGE_ID)?.importance !=
                NotificationManager.IMPORTANCE_NONE)
    }

    fun status(context: Context): Map<String, Any> {
        val prefs = prefs(context)
        val state = when {
            !hasFirebase(context) -> "unconfigured"
            !hasPlayServices(context) -> "play_services_unavailable"
            !enabled(prefs) -> "off"
            !canNotify(context) -> "permission_required"
            else -> prefs.getString(STATE, "waiting") ?: "waiting"
        }
        return mapOf(
            "enabled" to enabled(prefs),
            "state" to state,
            "lastDelayMs" to prefs.getLong("fcmLastDelayMs", -1),
        )
    }

    fun setEnabled(context: Context, enabled: Boolean, character: String?): Boolean {
        if (!enabled) {
            disconnect(context)
            return true
        }
        if (!hasFirebase(context) || !hasPlayServices(context)) return false
        val prefs = prefs(context)
        synchronized(lock) {
            if (!prefs.edit().putBoolean(ENABLED, true)
                    .putBoolean("backgroundNotificationsEnabled", false).commit()) return false
        }
        context.stopService(Intent(context, MobileNotificationService::class.java))
        MobileNotificationService.cancelScheduledFallback(context)
        refresh(context, character)
        return true
    }

    private fun binding(context: Context, character: String? = null): Binding? {
        val prefs = prefs(context)
        val origin = BackendSecurityPolicy.originFor(prefs.getString("backendBaseUrl", "").orEmpty()) ?: return null
        val url = URI(origin)
        if (url.scheme != "https" && url.host !in setOf("127.0.0.1", "localhost")) return null
        val owner = BackendSecurityPolicy.ownerUserId(prefs)
        val selected = character?.takeIf { it.isNotBlank() }
            ?: prefs.getString("sessionCharacterId.$origin|$owner", null) ?: return null
        val credential = BackendSecurityPolicy.adminToken(context, prefs).takeIf { it.isNotBlank() } ?: return null
        val installation = synchronized(lock) {
            prefs.getString(INSTALLATION, null) ?: UUID.randomUUID().toString().also {
                if (!prefs.edit().putString(INSTALLATION, it).commit()) return null
            }
        }
        return Binding(origin, credential, installation, selected)
    }

    fun disconnect(context: Context) {
        val app = context.applicationContext
        val prefs = prefs(app)
        val previous = if (prefs.contains(INSTALLATION)) binding(app) else null
        synchronized(lock) {
            prefs.edit().remove(INSTALLATION).remove(GENERATION).remove(SEEN)
                .remove("fcmLastDelayMs").putBoolean(ENABLED, false).commit()
        }
        val manager = app.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 23) {
            for (entry in manager.activeNotifications) {
                if (entry.id == NOTIFICATION_ID) manager.cancel(entry.tag, entry.id)
            }
        }
        if (hasFirebase(app)) {
            val messaging = FirebaseMessaging.getInstance()
            messaging.isAutoInitEnabled = false
            // The current binding is rejected locally even if the network is down.
            // Drop the Google registration when it cannot be revoked at our backend.
            if (previous == null) messaging.deleteToken()
        }
        if (previous != null) io.execute {
            runCatching {
                request(previous, "DELETE", "/mobile/push/devices/self?installation_id=${previous.installation}")
            }.onFailure {
                if (!enabled(prefs) && hasFirebase(app)) FirebaseMessaging.getInstance().deleteToken()
            }
        }
    }

    fun refresh(context: Context, character: String? = null) {
        val app = context.applicationContext
        if (!enabled(prefs(app)) || !hasFirebase(app) || !hasPlayServices(app)) return
        NotificationChannels.ensure(app)
        if (!canNotify(app)) {
            suspendRegistration(app)
            return
        }
        val binding = binding(app, character) ?: return
        val sdk = FirebaseMessaging.getInstance()
        if (sdk.isAutoInitEnabled && prefs(app).getLong(GENERATION, -1) >= 0 &&
            System.currentTimeMillis() - prefs(app).getLong("fcmRegisteredAt", 0) < 3600_000L
        ) return
        // Request the current token only after local permission and explicit consent.
        sdk.isAutoInitEnabled = true
        sdk.token.addOnSuccessListener { token -> register(app, binding, token) }
            .addOnFailureListener { prefs(app).edit().putString(STATE, "waiting").apply() }
    }

    fun newToken(context: Context, token: String) {
        if (!enabled(prefs(context)) || !canNotify(context)) return
        val binding = binding(context) ?: return
        register(context.applicationContext, binding, token)
    }

    private fun suspendRegistration(context: Context) {
        val prefs = prefs(context)
        val previous = binding(context) ?: return
        prefs.edit().remove(GENERATION).commit()
        if (hasFirebase(context)) FirebaseMessaging.getInstance().isAutoInitEnabled = false
        io.execute { runCatching {
            request(previous, "DELETE", "/mobile/push/devices/self?installation_id=${previous.installation}")
        } }
    }

    private fun register(context: Context, binding: Binding, token: String) = io.execute {
        val prefs = prefs(context)
        if (!enabled(prefs) || !canNotify(context) || binding(context) != binding) return@execute
        try {
            val session = request(
                binding, "POST", "/v1/sessions",
                JSONObject().put("char_id", binding.character).put("domain", "reality"),
            ).getString("session_id")
            val registration = request(
                binding, "PUT", "/mobile/push/devices/self",
                JSONObject().put("installation_id", binding.installation)
                    .put("registration", token).put("consent", true),
                session,
            )
            synchronized(lock) {
                if (enabled(prefs) && binding(context) == binding && canNotify(context)) {
                    prefs.edit().putLong(GENERATION, registration.getLong("generation"))
                        .putString(STATE, "registered").putLong("fcmRegisteredAt", System.currentTimeMillis()).commit()
                }
            }
        } catch (_: Exception) {
            prefs.edit().putString(STATE, "waiting").apply()
        }
    }

    private fun request(binding: Binding, method: String, path: String, body: JSONObject? = null, session: String? = null): JSONObject {
        val connection = (URL(binding.origin + path).openConnection() as HttpURLConnection).apply {
            requestMethod = method
            connectTimeout = 4000
            readTimeout = 4000
            instanceFollowRedirects = false
            setRequestProperty("Authorization", "Bearer ${binding.credential}")
            if (session != null) setRequestProperty("X-Presence-Session", session)
            if (body != null) {
                doOutput = true
                setRequestProperty("Content-Type", "application/json")
            }
        }
        try {
            if (body != null) connection.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
            if (connection.responseCode !in 200..299) throw java.io.IOException("Push request failed")
            return connection.inputStream.bufferedReader().use { JSONObject(it.readText()) }
        } finally {
            connection.disconnect()
        }
    }

    internal fun parse(data: Map<String, String>): Wake? {
        if (data["type"] != "new_message") return null
        val id = data["message_id"]?.takeIf { it.matches(Regex("[A-Za-z0-9._:-]{1,128}")) } ?: return null
        val seq = data["seq"]?.toLongOrNull()?.takeIf { it > 0 } ?: return null
        val installation = data["installation_id"] ?: return null
        val generation = data["generation"]?.toLongOrNull()?.takeIf { it >= 0 } ?: return null
        return Wake(id, seq, installation, generation)
    }

    private fun eligible(context: Context, wake: Wake): Boolean {
        val prefs = prefs(context)
        return enabled(prefs) && !foreground &&
            prefs.getString(INSTALLATION, null) == wake.installation &&
            prefs.getLong(GENERATION, -1) == wake.generation && canNotify(context)
    }

    fun receive(context: Context, data: Map<String, String>) {
        val wake = notifyIfEligible(context, data) ?: return
        scheduleReconciliation(context, wake)
    }

    internal fun notifyIfEligible(context: Context, data: Map<String, String>): Wake? {
        val wake = parse(data) ?: return null
        val prefs = prefs(context)
        synchronized(lock) {
            NotificationChannels.ensure(context)
            if (!eligible(context, wake)) return null
            if (MobileDeliveryStateStore.of(prefs).loadSeen().contains(wake.id)) return null
            val seen = runCatching { JSONArray(prefs.getString(SEEN, "[]")) }.getOrElse { JSONArray() }
            if ((0 until seen.length()).any { seen.optString(it) == wake.id }) return null
            val bounded = JSONArray()
            for (index in maxOf(0, seen.length() - 499) until seen.length()) bounded.put(seen.getString(index))
            bounded.put(wake.id)
            if (!prefs.edit().putString(SEEN, bounded.toString()).commit()) return null
            MobileDeliveryTrace.mark(prefs, wake.traceItem(), "fcm_received")
            data["sent_at_ms"]?.toLongOrNull()?.let {
                val delay = System.currentTimeMillis() - it
                if (delay >= 0) prefs.edit().putLong("fcmLastDelayMs", delay).apply()
            }
            post(context, wake, null)
            MobileDeliveryTrace.mark(prefs, wake.traceItem(), "notification_posted")
        }

        return wake
    }

    private fun scheduleReconciliation(context: Context, wake: Wake) {
        val work = OneTimeWorkRequestBuilder<FcmReconcileWorker>()
            .setInputData(workDataOf(
                "id" to wake.id, "seq" to wake.seq, "installation" to wake.installation,
                "generation" to wake.generation,
            ))
            .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
        // On older Android, expedited work can start a foreground service.
        if (Build.VERSION.SDK_INT >= 31) work.setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
        WorkManager.getInstance(context).enqueueUniqueWork(
            "fcm-message-${wake.id}", ExistingWorkPolicy.KEEP, work.build(),
        )
    }

    fun reconcile(context: Context, wake: Wake) {
        val binding = binding(context) ?: return
        if (!eligible(context, wake)) return
        val row = request(binding, "GET", "/mobile/push/message?installation_id=${wake.installation}" +
            "&generation=${wake.generation}&seq=${wake.seq}&message_id=${wake.id}")
        val prefs = prefs(context)
        synchronized(lock) {
            if (!eligible(context, wake) || binding(context) != binding) return
            if (row.optString("id") != wake.id || row.optLong("seq") != wake.seq ||
                row.optString("char_id") != binding.character) return
            val store = MobileDeliveryStateStore.of(prefs)
            val stored = store.acceptIncoming(row, binding.origin, row.optString("user_id"))
            if (!stored) return
            MobileDeliveryTrace.mark(prefs, wake.traceItem(), "full_body_reconciled")
            val manager = context.getSystemService(NotificationManager::class.java)
            if (Build.VERSION.SDK_INT >= 23 && manager.activeNotifications.any {
                it.id == NOTIFICATION_ID && it.tag == wake.id
            }) {
                post(context, wake, row.optString("content").lineSequence().firstOrNull()?.take(120))
            }
        }
    }

    private fun post(context: Context, wake: Wake, preview: String?) {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            action = MobileNotificationService.openLatestMessageAction
        }
        val pending = PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) {
            Notification.Builder(context, NotificationChannels.MESSAGE_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        val generic = context.getString(R.string.fcm_new_message)
        val publicNotification = builder.setSmallIcon(android.R.drawable.ic_dialog_email)
            .setContentTitle(context.getString(R.string.app_name)).setContentText(generic).build()
        val notification = builder
            .setContentText(preview?.takeIf { it.isNotBlank() } ?: generic)
            .setVisibility(Notification.VISIBILITY_PRIVATE).setPublicVersion(publicNotification)
            .setContentIntent(pending).setAutoCancel(true).setOnlyAlertOnce(preview != null).build()
        context.getSystemService(NotificationManager::class.java).notify(wake.id, NOTIFICATION_ID, notification)
    }
}
