package com.presencekit.mobile

import android.content.SharedPreferences
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Production settings-channel adapter for delivery state.
 * MainActivity and unit tests share this dispatcher so A4 can exercise
 * real handler + store IO without launching FlutterActivity.
 */
object MobileDeliveryChannel {
    fun dispatch(call: MethodCall, prefs: SharedPreferences, result: MethodChannel.Result): Boolean {
        val store = MobileDeliveryStateStore.of(prefs)
        when (call.method) {
            "getSeenMobileMessageIds" -> result.success(store.loadSeen())
            "setSeenMobileMessageIds" -> {
                val ids = call.argument<List<String>>("ids").orEmpty()
                runCatching {
                    if (scopeMatches(call, prefs)) store.mergeSeen(ids)
                }
                    .onSuccess { result.success(null) }
                    .onFailure { error ->
                        result.error(
                            "prefs_write_failed",
                            error.message ?: "Could not persist seen mobile message ids",
                            null,
                        )
                    }
            }
            "getLastAckedMobileSeq" -> result.success(store.lastAckedSeq())
            "setLastAckedMobileSeq" -> {
                val value = call.argument<Number>("value")?.toLong()
                if (value == null) {
                    result.error("invalid_ack_seq", "Missing last acked mobile seq", null)
                } else {
                    runCatching {
                        if (scopeMatches(call, prefs)) store.advanceAck(value)
                    }
                        .onSuccess { result.success(null) }
                        .onFailure { error ->
                            result.error(
                                "prefs_write_failed",
                                error.message ?: "Could not persist last acked mobile seq",
                                null,
                            )
                        }
                }
            }
            "bindMobileDeliveryScope" -> {
                val origin = BackendSecurityPolicy.originFor(
                    call.argument<String>("origin").orEmpty(),
                ) ?: call.argument<String>("origin")?.trim()?.ifEmpty { null }
                val owner = call.argument<String>("owner")?.trim()?.ifEmpty { null }
                    ?: BackendSecurityPolicy.ownerUserId(prefs).ifBlank { null }
                runCatching { store.bindCursorScope(origin, owner) }
                    .onSuccess { result.success(null) }
                    .onFailure { error ->
                        result.error(
                            "prefs_write_failed",
                            error.message ?: "Could not bind delivery cursor scope",
                            null,
                        )
                    }
            }
            "consumePendingMobileContents" -> consume(call, prefs, result, contentsOnly = true)
            "consumePendingMobileEnvelopes" -> consume(call, prefs, result, contentsOnly = false)
            else -> return false
        }
        return true
    }

    private fun consume(
        call: MethodCall,
        prefs: SharedPreferences,
        result: MethodChannel.Result,
        contentsOnly: Boolean,
    ) {
        val rawOrigin = call.argument<String>("origin")
        val origin = BackendSecurityPolicy.originFor(rawOrigin.orEmpty())
            ?: rawOrigin?.trim()?.ifEmpty { null }
            ?: BackendSecurityPolicy.originFor(prefs.getString("backendBaseUrl", null).orEmpty())
        val owner = call.argument<String>("owner")?.trim()?.ifEmpty { null }
            ?: BackendSecurityPolicy.ownerUserId(prefs).ifBlank { null }
        val charId = call.argument<String>("charId") ?: call.argument<String>("char_id")
        runCatching { MobileDeliveryStateStore.of(prefs).consumePending(origin, owner, charId) }
            .onSuccess { consumed ->
                result.success(
                    if (contentsOnly) {
                        consumed.envelopes.map { it.content }
                    } else {
                        consumed.envelopes.map { it.toMap() }
                    },
                )
            }
            .onFailure { error ->
                result.error(
                    "prefs_write_failed",
                    error.message ?: "Could not consume pending mobile envelopes",
                    null,
                )
            }
    }

    private fun scopeMatches(call: MethodCall, prefs: SharedPreferences): Boolean {
        val claimedOrigin = call.argument<String>("origin")?.trim().orEmpty()
        val claimedOwner = call.argument<String>("owner")?.trim().orEmpty()
        if (claimedOrigin.isEmpty() && claimedOwner.isEmpty()) return true
        val currentOrigin = prefs.getString(MobileDeliveryStateStore.CURSOR_ORIGIN_KEY, null).orEmpty()
        val currentOwner = prefs.getString(MobileDeliveryStateStore.CURSOR_OWNER_KEY, null).orEmpty()
        if (claimedOrigin.isNotEmpty() && currentOrigin.isNotEmpty() && claimedOrigin != currentOrigin) {
            return false
        }
        if (claimedOwner.isNotEmpty() && currentOwner.isNotEmpty() && claimedOwner != currentOwner) {
            return false
        }
        return true
    }
}
