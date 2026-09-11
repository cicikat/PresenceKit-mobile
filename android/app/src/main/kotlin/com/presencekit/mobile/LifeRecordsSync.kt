package com.presencekit.mobile

import android.content.Context
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.security.MessageDigest

class LifeRecordsHttpException(val status: Int, val response: JSONObject?) : Exception("http_$status")

/** Separate from chat ingest/poll: both UI and JobService use this identical transport. */
class LifeRecordsSync(private val context: Context, private val store: LifeRecordsStore,
    private val tokenProvider: (() -> String)? = null,
    private val transport: ((String, JSONObject?) -> JSONObject)? = null) {
    private val prefs = context.getSharedPreferences(BackendSecurityPolicy.PREFS_NAME, Context.MODE_PRIVATE)

    fun current(): Pair<String, String> = Pair(
        BackendSecurityPolicy.normalizeOrigin(prefs.getString("backendBaseUrl", "http://127.0.0.1:8080").orEmpty()) ?: "",
        BackendSecurityPolicy.ownerUserId(prefs)
    )

    fun realm(origin: String, owner: String): String = "$origin\n$owner"

    fun checkRealm(origin: String, owner: String): String {
        require(current() == Pair(origin, owner)) { "account_changed" }
        require(origin.isNotEmpty() && owner.matches(Regex("[A-Za-z0-9_-]+"))) { "setup_required" }
        return realm(origin, owner)
    }

    private fun request(origin: String, owner: String, path: String, body: JSONObject? = null): JSONObject {
        checkRealm(origin, owner)
        require(BackendSecurityPolicy.isAllowedBaseUrl(origin, prefs)) { "origin_untrusted" }
        val token = tokenProvider?.invoke() ?: BackendSecurityPolicy.adminToken(context, prefs)
        require(token.isNotBlank()) { "setup_required" }
        transport?.let { return it(path, body) }
        val connection = URL(origin + path).openConnection() as HttpURLConnection
        val deadline = deadlines.schedule({ connection.disconnect() }, 35, java.util.concurrent.TimeUnit.SECONDS)
        try {
            connection.instanceFollowRedirects = false
            connection.connectTimeout = 8000
            connection.readTimeout = 20000
            connection.setRequestProperty("Authorization", "Bearer $token")
            if (body != null) {
                connection.requestMethod = "POST"
                connection.doOutput = true
                connection.setRequestProperty("Content-Type", "application/json; charset=utf-8")
                val bytes = body.toString().toByteArray(Charsets.UTF_8)
                connection.setFixedLengthStreamingMode(bytes.size)
                connection.outputStream.use { it.write(bytes) }
            }
            val status = connection.responseCode
            val stream = if (status in 200..299) connection.inputStream else connection.errorStream
            val bytes = stream?.use { it.readBytesLimited(2 * 1024 * 1024) }
            val response = bytes?.let { runCatching { JSONObject(String(it, Charsets.UTF_8)) }.getOrNull() }
            if (status !in 200..299) throw LifeRecordsHttpException(status, response)
            return response ?: error("invalid_response")
        } finally { deadline.cancel(false); connection.disconnect() }
    }

    private fun java.io.InputStream.readBytesLimited(limit: Int): ByteArray {
        val output = java.io.ByteArrayOutputStream()
        val buffer = ByteArray(8192)
        while (true) {
            val size = read(buffer)
            if (size < 0) break
            require(output.size() + size <= limit) { "response_too_large" }
            output.write(buffer, 0, size)
        }
        return output.toByteArray()
    }

    fun run(origin: String, owner: String, manual: Boolean = false, background: Boolean = false): JSONObject {
        val realm = checkRealm(origin, owner)
        val meta = store.metadata(realm)
        val now = System.currentTimeMillis()
        val token = tokenProvider?.invoke() ?: BackendSecurityPolicy.adminToken(context, prefs)
        val fingerprint = MessageDigest.getInstance("SHA-256").digest(token.toByteArray()).joinToString("") { "%02x".format(it) }
        val credentialChanged = meta.has("credential") && meta.optString("credential") != fingerprint
        if (!manual && !credentialChanged && ((meta.optString("status") in setOf("auth", "forbidden") && meta.optString("credential") == fingerprint) || meta.optLong("next_attempt") > now)) return meta
        if (manual) store.retry(realm)
        var operation: JSONObject? = null
        try {
            val capability = request(origin, owner, "/life-records/capabilities?owner_id=${encode(owner)}")
            require(capability.optInt("schema_version") == 1) { "unsupported" }
            if (background && !capability.optBoolean("background_sync")) {
                meta.put("status", "foreground_only").put("next_attempt", now + 900_000)
            } else if (!capability.optBoolean("enabled")) {
                meta.put("status", "disabled").put("next_attempt", now + 900_000)
            } else {
                meta.put("recognition_available", capability.optBoolean("recognition_available"))
                operation = store.next(realm)
                if (operation != null) {
                    val response = request(origin, owner, "/life-records/sync", store.wire(realm, owner, operation))
                    store.acknowledge(realm, operation, response)
                    meta.put("last_ack", System.currentTimeMillis())
                }
                meta.put("status", "ready").put("next_attempt", 0).put("attempts", 0)
            }
        } catch (e: Exception) {
            val status = when (e) {
                is LifeRecordsHttpException -> when (e.status) {
                    401 -> "auth"
                    403 -> "forbidden"
                    404, 501 -> "unsupported"
                    409 -> "conflict"
                    429 -> "rate_limited"
                    in 400..499 -> "rejected"
                    else -> "offline"
                }
                is IllegalArgumentException, is IllegalStateException -> when (e.message) {
                    "setup_required", "origin_untrusted", "account_changed", "unsupported" -> e.message!!
                    else -> "invalid_response"
                }
                else -> "offline"
            }
            if (operation != null) store.fail(operation, when (status) {
                "conflict" -> "conflict"
                "rejected" -> "rejected"
                "invalid_response" -> "failed"
                else -> "retry"
            }, (e as? LifeRecordsHttpException)?.response?.optJSONObject("current_record"))
            val attempts = (meta.optInt("attempts") + 1).coerceAtMost(6)
            val delay = if (status in setOf("unsupported", "disabled")) 900_000L else (30_000L * (1L shl (attempts - 1))).coerceAtMost(900_000L)
            meta.put("status", status).put("attempts", attempts).put("next_attempt", now + delay).put("credential", fingerprint)
        }
        store.setMetadata(realm, meta)
        return meta
    }

    fun query(origin: String, owner: String, filters: JSONObject): JSONObject {
        val realm = checkRealm(origin, owner)
        val query = mutableListOf("owner_id=${encode(owner)}", "limit=50")
        listOf("category", "from", "to", "q", "cursor").forEach { key ->
            filters.optString(key).takeIf { it.isNotBlank() }?.let { query.add("$key=${encode(it)}") }
        }
        val response = request(origin, owner, "/life-records?${query.joinToString("&")}")
        store.merge(realm, response.getJSONArray("records"))
        return response
    }

    fun observe(origin: String, owner: String): JSONObject = request(origin, owner, "/life-records/observability?owner_id=${encode(owner)}")

    companion object {
        private val deadlines = java.util.concurrent.Executors.newSingleThreadScheduledExecutor { task ->
            Thread(task, "life-records-timeout").apply { isDaemon = true }
        }
        private fun encode(value: String): String = URLEncoder.encode(value, "UTF-8")
    }
}
