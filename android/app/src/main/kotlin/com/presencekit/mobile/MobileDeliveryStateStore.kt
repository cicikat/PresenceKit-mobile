package com.presencekit.mobile

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException

/**
 * Process-wide serial writer for mobile delivery state.
 *
 * Cursor is node-wide (backend origin + owner), not per character. Character
 * is only a pending-envelope display scope. Flutter merges seen ids; it does
 * not replace the native snapshot.
 */
class MobileDeliveryStateStore private constructor(private val prefs: SharedPreferences) {
    data class PendingEnvelope(
        val content: String,
        val id: String? = null,
        val seq: Long? = null,
        val timestamp: Double? = null,
        val turnId: String? = null,
        val requestId: String? = null,
        val origin: String? = null,
        val owner: String? = null,
        val charId: String? = null,
        val displayText: String? = null,
        val replayable: Boolean = false,
    ) {
        fun toMap(): Map<String, Any?> = linkedMapOf(
            "content" to content,
            "id" to id,
            "seq" to seq,
            "timestamp" to timestamp,
            "turn_id" to turnId,
            "request_id" to requestId,
            "origin" to origin,
            "owner" to owner,
            "char_id" to charId,
            "display_text" to displayText,
            "replayable" to replayable,
        )

        fun toJson(): JSONObject = JSONObject().apply {
            put("content", content)
            put("v", ENVELOPE_VERSION)
            put("replayable", replayable)
            id?.let { put("id", it) }
            seq?.let { put("seq", it) }
            timestamp?.let { put("timestamp", it) }
            turnId?.let { put("turn_id", it) }
            requestId?.let { put("request_id", it) }
            origin?.let { put("origin", it) }
            owner?.let { put("owner", it) }
            charId?.let { put("char_id", it) }
            displayText?.let { put("display_text", it) }
        }
    }

    data class ConsumeResult(
        val envelopes: List<PendingEnvelope>,
        val discardedLegacy: Int,
        val discardedUnscoped: Int,
    )

    fun mergeSeen(ids: Collection<String>): List<String> = locked {
        val seen = readSeenLocked()
        for (raw in ids) {
            val id = raw.trim()
            if (id.isEmpty() || !seen.add(id)) continue
            while (seen.size > SEEN_CAP) {
                val iterator = seen.iterator()
                if (!iterator.hasNext()) break
                iterator.next()
                iterator.remove()
            }
        }
        persistSeenLocked(seen)
        seen.toList()
    }

    fun loadSeen(): List<String> = locked { readSeenLocked().toList() }

    fun lastAckedSeq(): Long? = locked {
        if (prefs.contains(ACK_KEY)) prefs.getLong(ACK_KEY, 0L) else null
    }

    fun advanceAck(value: Long): Long? = locked {
        val current = if (prefs.contains(ACK_KEY)) prefs.getLong(ACK_KEY, Long.MIN_VALUE) else Long.MIN_VALUE
        if (value <= current) {
            return@locked if (prefs.contains(ACK_KEY)) current else null
        }
        if (!prefs.edit().putLong(ACK_KEY, value).commit()) {
            throw IOException("could not persist last acked mobile seq")
        }
        value
    }

    fun appendPending(item: JSONObject, origin: String?, owner: String?): Boolean {
        val content = item.optString("content").trim()
        if (content.isEmpty()) return false
        val envelope = envelopeFromQueueItem(item, origin, owner)
        locked {
            val pending = readPendingLocked()
            pending.put(envelope.toJson())
            while (pending.length() > PENDING_CAP) pending.remove(0)
            persistPendingLocked(pending)
        }
        return true
    }

    fun acceptIncoming(item: JSONObject, origin: String?, owner: String?): Boolean {
        val content = item.optString("content").trim()
        if (content.isEmpty()) return false
        val id = item.optString("id").trim()
        val envelope = envelopeFromQueueItem(item, origin, owner)
        return locked {
            val seen = readSeenLocked()
            if (id.isNotEmpty() && !seen.add(id)) return@locked false
            if (id.isNotEmpty()) {
                while (seen.size > SEEN_CAP) {
                    val iterator = seen.iterator()
                    if (!iterator.hasNext()) break
                    iterator.next()
                    iterator.remove()
                }
                persistSeenLocked(seen)
            }
            val pending = readPendingLocked()
            pending.put(envelope.toJson())
            while (pending.length() > PENDING_CAP) pending.remove(0)
            persistPendingLocked(pending)
            true
        }
    }

    fun consumePending(origin: String?, owner: String?, charId: String?): ConsumeResult = locked {
        migrateLegacyContentsLocked()
        val pending = readPendingLocked()
        val kept = JSONArray()
        val envelopes = ArrayList<PendingEnvelope>()
        var discardedLegacy = 0
        var discardedUnscoped = 0
        for (i in 0 until pending.length()) {
            val raw = pending.optJSONObject(i) ?: continue
            val envelope = envelopeFromStored(raw)
            when {
                !envelope.replayable -> {
                    discardedLegacy += 1
                    discardedUnscoped += 1
                }
                !matchesScope(envelope, origin, owner) -> kept.put(raw)
                charIdMismatch(envelope, charId) -> kept.put(raw)
                else -> envelopes.add(envelope)
            }
        }
        persistPendingLocked(kept)
        ConsumeResult(envelopes, discardedLegacy, discardedUnscoped)
    }

    fun bindCursorScope(origin: String?, owner: String?) = locked {
        val nextOrigin = origin?.trim().orEmpty()
        val nextOwner = owner?.trim().orEmpty()
        val currentOrigin = prefs.getString(CURSOR_ORIGIN_KEY, null).orEmpty()
        val currentOwner = prefs.getString(CURSOR_OWNER_KEY, null).orEmpty()
        if (currentOrigin.isEmpty() && currentOwner.isEmpty()) {
            persistCursorScopeLocked(nextOrigin, nextOwner)
            return@locked
        }
        if (currentOrigin == nextOrigin && currentOwner == nextOwner) return@locked
        clearCursorLocked()
        persistCursorScopeLocked(nextOrigin, nextOwner)
    }

    fun clearCursorForScopeChange() = locked { clearCursorLocked() }

    private fun persistCursorScopeLocked(origin: String, owner: String) {
        val editor = prefs.edit()
        if (origin.isEmpty()) editor.remove(CURSOR_ORIGIN_KEY) else editor.putString(CURSOR_ORIGIN_KEY, origin)
        if (owner.isEmpty()) editor.remove(CURSOR_OWNER_KEY) else editor.putString(CURSOR_OWNER_KEY, owner)
        if (!editor.commit()) throw IOException("could not persist delivery cursor scope")
    }

    private fun clearCursorLocked() {
        val editor = prefs.edit()
            .remove(ACK_KEY)
            .remove(SEEN_KEY)
            .remove(PENDING_KEY)
            .remove(LEGACY_PENDING_KEY)
        if (!editor.commit()) throw IOException("could not clear delivery cursor")
    }

    private fun migrateLegacyContentsLocked() {
        val raw = prefs.getString(LEGACY_PENDING_KEY, null) ?: return
        val legacy = runCatching { JSONArray(raw) }.getOrElse { JSONArray() }
        val pending = readPendingLocked()
        for (i in 0 until legacy.length()) {
            val content = when (val value = legacy.opt(i)) {
                is String -> value.trim()
                is JSONObject -> value.optString("content").trim()
                else -> ""
            }
            if (content.isEmpty()) continue
            pending.put(
                JSONObject()
                    .put("content", content)
                    .put("v", ENVELOPE_VERSION)
                    .put("replayable", false),
            )
        }
        while (pending.length() > PENDING_CAP) pending.remove(0)
        persistPendingLocked(pending)
        if (!prefs.edit().remove(LEGACY_PENDING_KEY).commit()) {
            throw IOException("could not migrate legacy pending contents")
        }
    }

    private fun readSeenLocked(): LinkedHashSet<String> {
        val json = prefs.getString(SEEN_KEY, null) ?: return LinkedHashSet()
        return runCatching {
            val array = JSONArray(json)
            (0 until array.length()).mapNotNullTo(LinkedHashSet()) { index ->
                array.optString(index).trim().takeIf { it.isNotEmpty() }
            }
        }.getOrElse { LinkedHashSet() }
    }

    private fun persistSeenLocked(seen: LinkedHashSet<String>) {
        if (!prefs.edit().putString(SEEN_KEY, JSONArray(seen.toList()).toString()).commit()) {
            throw IOException("could not persist seen mobile message ids")
        }
    }

    private fun readPendingLocked(): JSONArray {
        val raw = prefs.getString(PENDING_KEY, null) ?: return JSONArray()
        return runCatching { JSONArray(raw) }.getOrElse { JSONArray() }
    }

    private fun persistPendingLocked(pending: JSONArray) {
        val editor = prefs.edit()
        if (pending.length() == 0) editor.remove(PENDING_KEY) else editor.putString(PENDING_KEY, pending.toString())
        if (!editor.commit()) throw IOException("could not persist pending mobile envelopes")
    }

    private fun <T> locked(block: () -> T): T = synchronized(LOCK) { block() }

    companion object {
        const val SEEN_KEY = "seenMobileMessageIds"
        const val ACK_KEY = "lastAckedSeq"
        const val PENDING_KEY = "pendingMobileEnvelopes"
        const val LEGACY_PENDING_KEY = "pendingMobileContents"
        const val CURSOR_ORIGIN_KEY = "deliveryCursorOrigin"
        const val CURSOR_OWNER_KEY = "deliveryCursorOwner"
        const val SEEN_CAP = 200
        const val PENDING_CAP = 20
        const val ENVELOPE_VERSION = 1

        private val LOCK = Any()

        fun of(context: Context): MobileDeliveryStateStore =
            of(context.getSharedPreferences(BackendSecurityPolicy.PREFS_NAME, Context.MODE_PRIVATE))

        fun of(prefs: SharedPreferences): MobileDeliveryStateStore = MobileDeliveryStateStore(prefs)

        fun envelopeFromQueueItem(item: JSONObject, origin: String?, owner: String?): PendingEnvelope {
            val id = item.optString("id").trim().ifEmpty { null }
            val turnId = item.optString("turn_id").trim().ifEmpty { id }
            val seq = if (item.has("seq") && !item.isNull("seq")) {
                item.optLong("seq", Long.MIN_VALUE).takeIf { it != Long.MIN_VALUE }
            } else {
                null
            }
            val timestamp = if (item.has("timestamp") && !item.isNull("timestamp")) {
                item.optDouble("timestamp").takeIf { !it.isNaN() }
            } else {
                null
            }
            val charId = item.optString("char_id").trim().ifEmpty { null }
            val displayText = item.optString("display_text").trim().ifEmpty { null }
            val scopedOrigin = origin?.trim().orEmpty().ifEmpty { null }
            val scopedOwner = owner?.trim().orEmpty().ifEmpty { null }
            return PendingEnvelope(
                content = item.optString("content").trim(),
                id = id,
                seq = seq,
                timestamp = timestamp,
                turnId = turnId,
                requestId = item.optString("request_id").trim().ifEmpty { null },
                origin = scopedOrigin,
                owner = scopedOwner,
                charId = charId,
                displayText = displayText,
                replayable = id != null && scopedOrigin != null && scopedOwner != null,
            )
        }

        fun envelopeFromStored(raw: JSONObject): PendingEnvelope {
            val id = raw.optString("id").trim().ifEmpty { null }
            val turnId = raw.optString("turn_id").trim().ifEmpty { null }
            val seq = if (raw.has("seq") && !raw.isNull("seq")) {
                raw.optLong("seq", Long.MIN_VALUE).takeIf { it != Long.MIN_VALUE }
            } else {
                null
            }
            val timestamp = if (raw.has("timestamp") && !raw.isNull("timestamp")) {
                raw.optDouble("timestamp").takeIf { !it.isNaN() }
            } else {
                null
            }
            return PendingEnvelope(
                content = raw.optString("content").trim(),
                id = id,
                seq = seq,
                timestamp = timestamp,
                turnId = turnId,
                requestId = raw.optString("request_id").trim().ifEmpty { null },
                origin = raw.optString("origin").trim().ifEmpty { null },
                owner = raw.optString("owner").trim().ifEmpty { null },
                charId = raw.optString("char_id").trim().ifEmpty { null },
                displayText = raw.optString("display_text").trim().ifEmpty { null },
                replayable = raw.optBoolean("replayable", false),
            )
        }

        fun matchesScope(envelope: PendingEnvelope, origin: String?, owner: String?): Boolean {
            val expectedOrigin = origin?.trim().orEmpty()
            val expectedOwner = owner?.trim().orEmpty()
            return !expectedOrigin.isEmpty() &&
                !expectedOwner.isEmpty() &&
                envelope.origin == expectedOrigin &&
                envelope.owner == expectedOwner
        }

        fun charIdMismatch(envelope: PendingEnvelope, charId: String?): Boolean {
            val actual = envelope.charId.orEmpty()
            if (actual.isEmpty()) return false
            return actual != charId?.trim().orEmpty()
        }
    }
}
