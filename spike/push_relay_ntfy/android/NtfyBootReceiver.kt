package com.presencekit.mobile.spike

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Restarts NtfyRelayService after device reboot.
 * Requires RECEIVE_BOOT_COMPLETED permission (see manifest_additions.xml).
 *
 * Read NTFY_HOST / NTFY_TOPIC from SharedPreferences so the values
 * survive the reboot without an Activity launch.
 */
class NtfyBootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return

        val prefs = context.getSharedPreferences("ntfy_spike", Context.MODE_PRIVATE)
        val host  = prefs.getString("host",  null) ?: return  // not configured — don't start
        val topic = prefs.getString("topic", null) ?: return

        Log.i("NtfyBootReceiver", "Boot complete — starting relay  host=$host  topic=$topic")
        NtfyRelayService.start(context, host, topic)
    }

    companion object {
        /** Call from NtfySpikeActivity when the user configures the relay. */
        fun persistConfig(context: Context, host: String, topic: String) {
            context.getSharedPreferences("ntfy_spike", Context.MODE_PRIVATE).edit()
                .putString("host", host)
                .putString("topic", topic)
                .apply()
        }
    }
}
