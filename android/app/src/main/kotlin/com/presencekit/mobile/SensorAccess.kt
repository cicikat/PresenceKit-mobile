package com.presencekit.mobile

import android.content.Context
import android.content.SharedPreferences
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.media.MediaRecorder
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

// 供 W9（语音输入 + 传感器上报）使用的原生能力封装：电量读取、今日步数换算、麦克风录音。
object SensorAccess {
    private const val STEP_BASELINE_KEY = "stepBaselineCount"
    private const val STEP_BASELINE_DATE_KEY = "stepBaselineDate"

    fun readBatteryPercent(context: Context): Int? {
        val bm = context.getSystemService(Context.BATTERY_SERVICE) as? BatteryManager ?: return null
        val level = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
        return if (level in 0..100) level else null
    }

    // TYPE_STEP_COUNTER 是"自上次重启以来的累计步数"（push 型传感器，非同步读取），
    // 需要在本机记一个按天的 baseline 才能换算出"今日步数"；超时未取到数据时返回 null。
    fun readTodaySteps(
        context: Context,
        prefs: SharedPreferences,
        timeoutMs: Long,
        callback: (Int?) -> Unit,
    ) {
        val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        val sensor = sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        if (sensorManager == null || sensor == null) {
            callback(null)
            return
        }
        var delivered = false
        val handler = Handler(Looper.getMainLooper())
        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                if (delivered) return
                val totalSinceBoot = event.values.getOrNull(0)?.toInt()
                delivered = true
                sensorManager.unregisterListener(this)
                handler.removeCallbacksAndMessages(null)
                if (totalSinceBoot == null) {
                    callback(null)
                } else {
                    callback(todayStepsFromTotal(prefs, totalSinceBoot))
                }
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        }
        sensorManager.registerListener(listener, sensor, SensorManager.SENSOR_DELAY_NORMAL)
        handler.postDelayed({
            if (!delivered) {
                delivered = true
                sensorManager.unregisterListener(listener)
                callback(null)
            }
        }, timeoutMs)
    }

    private fun todayStepsFromTotal(prefs: SharedPreferences, totalSinceBoot: Int): Int {
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        val baselineDate = prefs.getString(STEP_BASELINE_DATE_KEY, null)
        if (baselineDate != today) {
            prefs.edit()
                .putString(STEP_BASELINE_DATE_KEY, today)
                .putInt(STEP_BASELINE_KEY, totalSinceBoot)
                .apply()
            return 0
        }
        val baseline = prefs.getInt(STEP_BASELINE_KEY, totalSinceBoot)
        // 设备重启会让 totalSinceBoot 归零/变小；baseline 失效时重新从当前值起算。
        if (totalSinceBoot < baseline) {
            prefs.edit().putInt(STEP_BASELINE_KEY, totalSinceBoot).apply()
            return 0
        }
        return totalSinceBoot - baseline
    }
}

// 一次一条录音；start/stop 成对调用，stop 返回 m4a 文件路径供 Dart 侧读取上传后自行删除。
class VoiceRecorder(private val context: Context) {
    private var recorder: MediaRecorder? = null
    private var outputFile: File? = null

    fun start(): Boolean {
        if (recorder != null) return false
        val file = File(context.cacheDir, "voice_input_${System.currentTimeMillis()}.m4a")
        val r = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(context)
        } else {
            @Suppress("DEPRECATION")
            MediaRecorder()
        }
        return try {
            r.setAudioSource(MediaRecorder.AudioSource.MIC)
            r.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            r.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            r.setAudioEncodingBitRate(96000)
            r.setAudioSamplingRate(44100)
            r.setOutputFile(file.absolutePath)
            r.prepare()
            r.start()
            recorder = r
            outputFile = file
            true
        } catch (e: Exception) {
            r.release()
            false
        }
    }

    fun stop(): String? {
        val r = recorder ?: return null
        return try {
            r.stop()
            r.release()
            recorder = null
            outputFile?.absolutePath
        } catch (e: Exception) {
            r.release()
            recorder = null
            outputFile?.delete()
            outputFile = null
            null
        }
    }

    fun cancel() {
        val r = recorder ?: return
        try {
            r.stop()
        } catch (e: Exception) {
            // 时长太短可能来不及产出有效数据，忽略
        }
        r.release()
        recorder = null
        outputFile?.delete()
        outputFile = null
    }
}
