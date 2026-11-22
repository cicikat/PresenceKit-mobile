package com.presencekit.mobile.finance

import android.content.Context
import com.presencekit.mobile.BackendSecurityPolicy
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

class FinanceHttpError(val status: Int, val reason: String? = null) : Exception("http_$status")

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
            if (status !in 200..299) {
                val reason = runCatching {
                    connection.errorStream?.use { input ->
                        val output = java.io.ByteArrayOutputStream()
                        val buffer = ByteArray(1024)
                        while (true) {
                            val size = input.read(buffer)
                            if (size < 0) break
                            require(output.size() + size <= 8192) { "invalid_response" }
                            output.write(buffer, 0, size)
                        }
                        JSONObject(output.toString("UTF-8")).optString("detail")
                    }
                }.getOrNull()
                throw FinanceHttpError(status, reason)
            }
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
        if (!manual && (meta.optString("status") in userActionStatuses || meta.optLong("next_attempt") > now)) return meta
        var op: JSONObject? = null
        try {
            fun automaticAllowed() = FinanceAccess.enabled(context, realm) && FinanceAccess.permission(context)
            fun pausedStatus() = if (FinanceAccess.enabled(context, realm)) "permission_required" else "paused"
            if (store.next(realm, automaticAllowed()) == null && store.next(realm) != null) error(pausedStatus())
            val capability = request(origin, owner, "/finance/capabilities")
            require(capability.optInt("schema_version") == 1) { "unsupported" }
            if (!capability.optBoolean("effective")) error("disabled")
            var sent = 0
            var rowFailure: String? = null
            while (!cancelled() && sent++ < 100) {
                op = store.next(realm, automaticAllowed()) ?: break
                try {
                    val ack = request(origin, owner, "/finance/candidates/sync", op)
                    check(origin, owner)
                    store.acknowledge(realm, op, ack)
                } catch (e: FinanceHttpError) {
                    if (e.status !in setOf(409, 422)) throw e
                    rowFailure = if (e.status == 409) "conflict" else "rejected"
                    store.fail(realm, op.getString("candidate_id"), rowFailure)
                }
                op = null
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
            val remainingPaused = !automaticAllowed() && store.next(realm) != null && store.next(realm, false) == null
            meta.put("status", rowFailure ?: if (remainingPaused) pausedStatus() else "ready").put("attempts", 0).put("next_attempt", 0)
        } catch (e: Exception) {
            val classified = when (e) {
                is FinanceHttpError -> when {
                    e.reason == "finance_disabled" -> "disabled"
                    e.reason == "owner_not_configured" -> "setup_required"
                    e.status == 401 -> "auth"
                    e.status == 403 -> "forbidden"
                    e.status == 409 -> "conflict"
                    e.status == 429 -> "rate_limited"
                    e.status in setOf(404, 405) -> "unsupported"
                    e.status in 400..499 && e.status != 408 -> "rejected"
                    else -> "offline"
                }
                is org.json.JSONException -> "invalid_response"
                is IllegalArgumentException, is IllegalStateException -> e.message?.takeIf { it in setOf("disabled", "paused", "permission_required", "account_changed", "origin_untrusted", "setup_required", "unsupported", "invalid_response") } ?: "invalid_response"
                else -> "offline"
            }
            val status = if (op == null && classified in setOf("conflict", "rejected")) "invalid_response" else classified
            if (op != null && status in setOf("conflict", "rejected")) store.fail(realm, op.getString("candidate_id"), status)
            val retryable = status in setOf("offline", "rate_limited")
            val attempts = if (retryable) (meta.optInt("attempts") + 1).coerceAtMost(6) else 0
            meta.put("status", status).put("attempts", attempts).put("next_attempt", if (retryable) now + (30000L * (1L shl attempts)).coerceAtMost(900000) else 0)
        }
        store.setMeta(realm, meta); return meta
    }
    companion object {
        private val userActionStatuses = setOf("auth", "forbidden", "disabled", "unsupported", "setup_required", "origin_untrusted", "account_changed", "invalid_response", "storage_error")
        fun shouldRetry(context: Context, store: FinanceStore, origin: String, owner: String): Boolean {
            FinanceSync(context, store).check(origin, owner)
            val realm = FinanceAccess.realm(origin, owner)
            if (store.meta(realm).optString("status") in userActionStatuses) return false
            return store.next(realm, FinanceAccess.enabled(context, realm) && FinanceAccess.permission(context)) != null
        }
        private val deadlines = java.util.concurrent.Executors.newSingleThreadScheduledExecutor { Thread(it, "finance-deadline").apply { isDaemon = true } }
    }
}
