package com.presencekit.mobile

import android.content.SharedPreferences
import android.util.Log
import org.json.JSONObject
import java.security.MessageDigest

internal object MobileDeliveryTrace {
    fun mark(
        prefs: SharedPreferences,
        item: JSONObject,
        stage: String,
        atMs: Long = System.currentTimeMillis(),
        outcome: String = "ok",
    ) {
        val id = item.optString("id")
        if (id.isEmpty() || id.length > 256) return
        prefs.edit().putString("lastDeliveryStage", stage).apply()
        if (!prefs.getBoolean("notificationTestMode", false)) return
        val digest = MessageDigest.getInstance("SHA-256").digest(id.toByteArray(Charsets.UTF_8))
        val hash = digest.take(8).joinToString("") { "%02x".format(it) }
        Log.i("PresenceDelivery", "id_hash=$hash stage=$stage at_ms=$atMs outcome=$outcome")
    }
}
