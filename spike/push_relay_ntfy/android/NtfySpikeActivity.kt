package com.presencekit.mobile.spike

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.widget.*
import androidx.appcompat.app.AppCompatActivity

/**
 * Minimal test harness Activity.
 * Lets you start/stop NtfyRelayService and request battery exemption without
 * touching the main app flow.
 *
 * To wire up: add this to AndroidManifest.xml (see manifest_additions.xml),
 * then launch via:
 *   adb shell am start -n com.presencekit.mobile/.spike.NtfySpikeActivity
 */
class NtfySpikeActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val prefs = getSharedPreferences("ntfy_spike", MODE_PRIVATE)
        val savedHost  = prefs.getString("host",  "http://192.168.1.x:8080") ?: ""
        val savedTopic = prefs.getString("topic", "mychar-spike")            ?: ""

        // Build a trivial programmatic UI — no XML layout dependency
        val root    = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(32,32,32,32) }
        val etHost  = EditText(this).apply { setText(savedHost);  hint = "ntfy host e.g. http://192.168.1.5:8080" }
        val etTopic = EditText(this).apply { setText(savedTopic); hint = "topic" }
        val btnStart   = Button(this).apply { text = "Start Relay" }
        val btnStop    = Button(this).apply { text = "Stop Relay"  }
        val btnBattery = Button(this).apply { text = "Request Battery Exemption" }
        val tvStatus   = TextView(this).apply { text = "idle" }

        root.addView(TextView(this).apply { text = "ntfy Relay Spike" })
        root.addView(etHost)
        root.addView(etTopic)
        root.addView(btnStart)
        root.addView(btnStop)
        root.addView(btnBattery)
        root.addView(tvStatus)
        setContentView(root)

        btnStart.setOnClickListener {
            val host  = etHost.text.toString().trimEnd('/')
            val topic = etTopic.text.toString().trim()
            NtfyBootReceiver.persistConfig(this, host, topic)
            NtfyRelayService.start(this, host, topic)
            tvStatus.text = "Started → $host/$topic"
        }

        btnStop.setOnClickListener {
            NtfyRelayService.stop(this)
            tvStatus.text = "Stopped"
        }

        btnBattery.setOnClickListener {
            // Opens system Battery Optimization settings for this app.
            // User must manually switch to "Unrestricted" — we cannot do it programmatically.
            val pm = getSystemService(POWER_SERVICE) as PowerManager
            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                startActivity(Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:$packageName")
                })
            } else {
                tvStatus.text = "Already battery-unrestricted"
            }
        }
    }
}
