package com.presencekit.mobile.finance

import android.content.Context
import com.presencekit.mobile.BackendSecurityPolicy
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

class FinanceHttpError(val status: Int) : Exception("http_$status")

class FinanceSync(private val context: Context, private val store: FinanceStore,
    private val tokenProvider: (() -> String)? = null,
    private val transport: ((String, JSONObject?) -> JSONObject)? = null) {
    fun check(origin: String, owner: String): String {
        require(FinanceAccess.current(context) == Pair(origin, owner)) { "account_changed" }
        require(origin.isNotEmpty() && owner.matches(Regex("[A-Za-z0-9_-]+"))) { "setup_required" }
        require(BackendSecurityPolicy.isAllowedBaseUrl(origin, FinanceAccess.prefs(context))) { "origin_untrusted" }
        return FinanceAccess.realm(origin, owner)
    }
    fun request(origin: String, owner: String, path: String, body: JSONObject? = null): JSONObject {
        check(origin, owner)
        transport?.let { return it(path, body) }
        val token = tokenProvider?.invoke() ?: BackendSecurityPolicy.adminToken(context, FinanceAccess.prefs(context))
        require(token.isNotBlank()) { "setup_required" }
        val connection = URL(origin + path).openConnection() as HttpURLConnection
        val deadline = deadlines.schedule({ connection.disconnect() }, 30, java.util.concurrent.TimeUnit.SECONDS)
        try {
            connection.instanceFollowRedirects = false; connection.connectTimeout = 8000; connection.readTimeout = 15000
            connection.setRequestProperty("Authorization", "Bearer $token")
            if (body != null) {
                connection.requestMethod = "POST"; connection.doOutput = true
                connection.setRequestProperty("Content-Type", "application/json; charset=utf-8")
                val bytes = body.toString().toByteArray(Charsets.UTF_8)
                connection.setFixedLengthStreamingMode(bytes.size); connection.outputStream.use { it.write(bytes) }
            }
            val status = connection.responseCode
            if (status !in 200..299) throw FinanceHttpError(status)
            val output = java.io.ByteArrayOutputStream()
            connection.inputStream.use { input ->
                val buffer = ByteArray(8192)
                while (true) { val size = input.read(buffer); if (size < 0) break; require(output.size() + size <= 4 * 1024 * 1024) { "invalid_response" }; output.write(buffer, 0, size) }
            }
            return JSONObject(output.toString("UTF-8"))
        } finally { deadline.cancel(false); connection.disconnect() }
    }
    fun run(origin: String, owner: String, manual: Boolean = false, cancelled: () -> Boolean = { false }): JSONObject {
        val realm = check(origin, owner); val meta = store.meta(realm); val now = System.currentTimeMillis()
        if (!manual && meta.optLong("next_attempt") > now) return meta
        var op: JSONObject? = null
        try {
            if (FinanceAccess.enabled(context, realm) && !FinanceAccess.permission(context)) error("permission_required")
            val capability = request(origin, owner, "/finance/capabilities")
            require(capability.optInt("schema_version") == 1) { "unsupported" }
            if (!capability.optBoolean("effective")) error("disabled")
            var sent = 0
            while (!cancelled() && sent++ < 100) {
                op = store.next(realm) ?: break
                val automatic = op.getJSONObject("record").optString("source_app") != "manual"
                if (automatic && (!FinanceAccess.enabled(context, realm) || !FinanceAccess.permission(context))) error("paused")
                val ack = request(origin, owner, "/finance/candidates/sync", op)
                check(origin, owner)
                store.acknowledge(realm, op, ack); op = null
            }
            // Read actual server records; a failed read never changes a queued operation's identity.
            var cursor = ""
            var pages = 0
            do {
                if (cancelled()) break
                val response = request(origin, owner, "/finance/candidates?limit=200&cursor=$cursor")
                check(origin, owner); store.merge(realm, response.getJSONArray("records"))
                cursor = response.optString("next_cursor")
            } while (cursor.isNotEmpty() && ++pages < 50)
            meta.put("status", "ready").put("attempts", 0).put("next_attempt", 0)
        } catch (e: Exception) {
            val status = when (e) {
                is FinanceHttpError -> when (e.status) { 401 -> "auth"; 403 -> "forbidden"; 409 -> "conflict"; 429 -> "rate_limited"; 404 -> "unsupported"; 422 -> "rejected"; else -> "offline" }
                is IllegalArgumentException, is IllegalStateException -> e.message?.takeIf { it in setOf("disabled", "paused", "permission_required", "account_changed", "origin_untrusted", "setup_required", "unsupported", "invalid_response") } ?: "invalid_response"
                else -> "offline"
            }
            if (op != null && status in setOf("conflict", "rejected")) store.fail(realm, op.getString("candidate_id"), status)
            val attempts = (meta.optInt("attempts") + 1).coerceAtMost(6)
            meta.put("status", status).put("attempts", attempts).put("next_attempt", now + (30000L * (1L shl attempts)).coerceAtMost(900000))
        }
        store.setMeta(realm, meta); return meta
    }
    companion object {
        private val deadlines = java.util.concurrent.Executors.newSingleThreadScheduledExecutor { Thread(it, "finance-deadline").apply { isDaemon = true } }
    }
}
