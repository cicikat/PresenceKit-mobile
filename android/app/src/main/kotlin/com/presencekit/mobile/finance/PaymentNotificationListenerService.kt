package com.presencekit.mobile.finance

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class PaymentNotificationListenerService : NotificationListenerService() {
    // Never enumerate activeNotifications on connection/reconnection.
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (sbn.packageName !in PaymentParser.packages) return
        val (origin, owner) = FinanceAccess.current(this)
        val realm = FinanceAccess.realm(origin, owner)
        if (origin.isEmpty() || owner.isEmpty() || !FinanceAccess.enabled(this, realm) || !FinanceAccess.permission(this)) return
        val notification = sbn.notification
        if (notification.flags and Notification.FLAG_GROUP_SUMMARY != 0) return
        val at = notification.`when`.takeIf { it > 0 && it <= System.currentTimeMillis() + 60000 } ?: sbn.postTime
        if (at < FinanceAccess.since(this, realm)) return
        val extras = notification.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val text = (extras.getCharSequence(Notification.EXTRA_BIG_TEXT) ?: extras.getCharSequence(Notification.EXTRA_TEXT))?.toString().orEmpty()
        val parsed = PaymentParser.parse(sbn.packageName, title, text) ?: return
        parsed.put("occurred_at", at).put("observed_at", System.currentTimeMillis()).put("timezone_offset_minutes", java.util.TimeZone.getDefault().getOffset(at) / 60000)
        val event = PaymentParser.hash("${sbn.packageName}|${sbn.key}|$at")
        FinanceBridge.executor.execute {
            try {
                if (FinanceAccess.current(this) != Pair(origin, owner) || !FinanceAccess.enabled(this, realm) || !FinanceAccess.permission(this)) return@execute
                FinanceStore(this).use { it.capture(realm, event, parsed) }
                FinanceBridge.schedule(this)
            } catch (_: Exception) {
                FinanceStore(this).use { it.setMeta(realm, org.json.JSONObject().put("status", "storage_error")) }
            }
        }
    }
}
