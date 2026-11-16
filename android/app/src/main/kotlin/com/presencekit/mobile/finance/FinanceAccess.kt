package com.presencekit.mobile.finance

import android.content.ComponentName
import android.content.Context
import android.provider.Settings
import com.presencekit.mobile.BackendSecurityPolicy

object FinanceAccess {
    fun prefs(context: Context) = context.getSharedPreferences(BackendSecurityPolicy.PREFS_NAME, Context.MODE_PRIVATE)
    fun current(context: Context): Pair<String, String> {
        val prefs = prefs(context)
        return Pair(BackendSecurityPolicy.normalizeOrigin(prefs.getString("backendBaseUrl", "").orEmpty()).orEmpty(), BackendSecurityPolicy.ownerUserId(prefs))
    }
    fun realm(origin: String, owner: String) = "$origin\n$owner"
    fun permission(context: Context): Boolean {
        val expected = ComponentName(context, PaymentNotificationListenerService::class.java)
        return Settings.Secure.getString(context.contentResolver, "enabled_notification_listeners").orEmpty().split(':').any { ComponentName.unflattenFromString(it) == expected }
    }
    fun enabled(context: Context, realm: String) = prefs(context).getBoolean("finance_enabled_" + PaymentParser.hash(realm), false)
    fun since(context: Context, realm: String) = prefs(context).getLong("finance_since_" + PaymentParser.hash(realm), Long.MAX_VALUE)
    fun setEnabled(context: Context, realm: String, enabled: Boolean) {
        require(!enabled || permission(context)) { "permission_required" }
        val prefs = prefs(context); val key = PaymentParser.hash(realm)
        val edit = prefs.edit().putBoolean("finance_enabled_$key", enabled)
        if (enabled && !prefs.getBoolean("finance_enabled_$key", false)) edit.putLong("finance_since_$key", System.currentTimeMillis())
        require(edit.commit()) { "storage_error" }
    }
}
