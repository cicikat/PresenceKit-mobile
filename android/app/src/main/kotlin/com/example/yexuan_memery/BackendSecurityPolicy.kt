package com.example.yexuan_memery

import android.content.SharedPreferences
import java.net.URL

object BackendSecurityPolicy {
    const val PREFS_NAME = "yexuan_memery"
    const val ADMIN_TOKEN_KEY = "adminToken"
    const val SCREEN_CONTEXT_UPLOAD_ENABLED_KEY = "screenContextUploadEnabled"
    const val SCREEN_TEXT_UPLOAD_ALLOWED_PACKAGES_KEY = "screenTextUploadAllowedPackages"
    const val TRUSTED_CLEARTEXT_ORIGINS_KEY = "trustedCleartextOrigins"
    const val RELAY_BASE_URL_KEY = "relayBaseUrl"
    const val RELAY_TOKEN_KEY = "relayToken"
    const val RELAY_TOPIC_KEY = "relayTopic"
    const val OWNER_USER_ID_KEY = "ownerUserId"

    fun adminToken(prefs: SharedPreferences): String {
        return prefs.getString(ADMIN_TOKEN_KEY, null)?.trim().orEmpty()
    }

    fun ownerUserId(prefs: SharedPreferences): String {
        return prefs.getString(OWNER_USER_ID_KEY, null)?.trim().orEmpty()
    }

    fun screenContextUploadEnabled(prefs: SharedPreferences): Boolean {
        return prefs.getBoolean(SCREEN_CONTEXT_UPLOAD_ENABLED_KEY, false)
    }

    fun screenTextUploadAllowedPackages(prefs: SharedPreferences): Set<String> {
        return prefs.getStringSet(SCREEN_TEXT_UPLOAD_ALLOWED_PACKAGES_KEY, emptySet())
            ?.map(String::trim)
            ?.filter(String::isNotBlank)
            ?.toSet()
            .orEmpty()
    }

    fun screenTextUploadAllowed(prefs: SharedPreferences, packageName: String): Boolean {
        return packageName.isNotBlank() && packageName in screenTextUploadAllowedPackages(prefs)
    }

    fun trustedCleartextOrigins(prefs: SharedPreferences): Set<String> {
        return prefs.getStringSet(TRUSTED_CLEARTEXT_ORIGINS_KEY, emptySet())
            ?.mapNotNull(::originFor)
            ?.filter(::isConfirmablePrivateCleartextOrigin)
            ?.toSet()
            .orEmpty()
    }

    fun addTrustedCleartextOrigin(prefs: SharedPreferences, raw: String): Boolean {
        val origin = originFor(raw) ?: return false
        if (!isConfirmablePrivateCleartextOrigin(origin)) return false
        val updated = trustedCleartextOrigins(prefs).toMutableSet().apply { add(origin) }
        prefs.edit().putStringSet(TRUSTED_CLEARTEXT_ORIGINS_KEY, updated).apply()
        return true
    }

    fun isAllowedBaseUrl(raw: String, prefs: SharedPreferences): Boolean {
        val origin = originFor(raw) ?: return false
        if (origin.startsWith("https://")) return true
        return isBuiltInCleartextOrigin(origin) ||
            isConfirmablePrivateCleartextOrigin(origin) && origin in trustedCleartextOrigins(prefs)
    }

    fun relayBaseUrl(prefs: SharedPreferences): String? =
        prefs.getString(RELAY_BASE_URL_KEY, null)?.trim()?.ifEmpty { null }

    fun relayToken(prefs: SharedPreferences): String? =
        prefs.getString(RELAY_TOKEN_KEY, null)?.trim()?.ifEmpty { null }

    fun relayTopic(prefs: SharedPreferences): String? =
        prefs.getString(RELAY_TOPIC_KEY, null)?.trim()?.ifEmpty { null }

    // 中继地址复用后端 origin 信任策略，私网 HTTP 同样要求用户确认。
    fun isAllowedRelayUrl(raw: String, prefs: SharedPreferences): Boolean =
        isAllowedBaseUrl(raw, prefs)

    fun normalizeOrigin(raw: String): String? = originFor(raw)

    fun originFor(raw: String): String? {
        val value = raw.trim()
        if (value.isBlank()) return null
        return runCatching {
            val url = URL(value)
            val protocol = url.protocol.lowercase()
            if (protocol != "http" && protocol != "https") return null
            if (url.userInfo != null || url.query != null || url.ref != null) return null
            if (url.host.isBlank() || (url.path.isNotBlank() && url.path != "/")) return null
            val defaultPort = if (protocol == "https") 443 else 80
            val port = if (url.port == -1 || url.port == defaultPort) "" else ":${url.port}"
            "$protocol://${url.host.lowercase()}$port"
        }.getOrNull()
    }

    private fun isBuiltInCleartextOrigin(origin: String): Boolean {
        val host = runCatching { URL(origin).host.lowercase() }.getOrNull() ?: return false
        if (host == "127.0.0.1" || host == "localhost") return true
        val parts = ipv4Parts(host) ?: return false
        return parts[0] == 100 &&
            parts[1] in 64..127
    }

    fun isConfirmablePrivateCleartextOrigin(origin: String): Boolean {
        val host = runCatching { URL(origin).host.lowercase() }.getOrNull() ?: return false
        val parts = ipv4Parts(host) ?: return false
        return parts[0] == 10 ||
            (parts[0] == 172 && parts[1] in 16..31) ||
            (parts[0] == 192 && parts[1] == 168)
    }

    private fun ipv4Parts(host: String): List<Int>? {
        val parts = host.split('.').map { it.toIntOrNull() }
        if (parts.size != 4 || parts.any { it == null || it !in 0..255 }) return null
        return parts.filterNotNull()
    }
}
