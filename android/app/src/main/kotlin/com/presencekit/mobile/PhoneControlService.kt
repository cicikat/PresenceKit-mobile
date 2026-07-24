package com.presencekit.mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.os.Build
import android.os.IBinder
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

// 手机自动化循环协调服务：观察（读屏幕/截屏）→ 上报后端 /phone_control/step → 拿下一步动作 →
// 本地二次拦截 → 执行 → 循环，直到 done/need_confirmation/refused/取消/步数超限。
// 后端已经过一遍 core/phone_control/sensitive_filter.py，这里的本地校验是防御性的第二道闸，
// 不是"后端说了算"——两边独立判断，任一方拦截即停，参见 docs/protocols/phone-control-protocol.md。
class PhoneControlService : Service() {
    private val tag = "PhoneControlService"
    private val channelId = "yexuan_phone_control"
    private val notificationId = 10436

    @Volatile private var running = false
    @Volatile private var cancelRequested = false
    @Volatile private var currentTaskId: String? = null
    private var loopThread: Thread? = null

    private val cancelReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != ACTION_CANCEL) return
            val taskId = intent.getStringExtra("task_id")
            if (taskId != null && taskId == currentTaskId) {
                requestCancel("user tapped cancel")
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        val filter = IntentFilter(ACTION_CANCEL)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(cancelReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(cancelReceiver, filter)
        }
    }

    override fun onDestroy() {
        runCatching { unregisterReceiver(cancelReceiver) }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val taskId = intent?.getStringExtra("task_id").orEmpty()
        val task = intent?.getStringExtra("task").orEmpty()
        // 系统要求 startForegroundService() 启动的服务必须尽快调用 startForeground()，
        // 即便随后立即校验失败要退出——先占位调用，避免 5 秒未提权触发系统异常。
        startForeground(notificationId, buildOngoingNotification("正在准备手机自动化…", taskId))
        if (taskId.isBlank()) {
            stopForeground(true)
            stopSelf(startId)
            return START_NOT_STICKY
        }
        if (running) {
            // 一次只跑一个任务；不静默覆盖正在跑的循环，避免两条循环同时抢辅助功能操作。
            Log.w(tag, "ignoring task=$taskId while task=$currentTaskId is still running")
            stopForeground(true)
            stopSelf(startId)
            return START_NOT_STICKY
        }
        currentTaskId = taskId
        cancelRequested = false
        running = true
        updateOngoingNotification("正在操作：${task.ifBlank { "手机任务" }}", taskId)
        startLoop(taskId, task, startId)
        return START_NOT_STICKY
    }

    private fun startLoop(taskId: String, task: String, startId: Int) {
        loopThread = Thread {
            val outcome = try {
                runLoop(taskId, task)
            } catch (error: Exception) {
                Log.e(tag, "phone control loop crashed task=$taskId", error)
                LoopOutcome("任务已停止", "内部错误：${error.javaClass.simpleName}")
            }
            notifyResult(taskId, task, outcome.title, outcome.message)
            running = false
            currentTaskId = null
            stopForeground(true)
            stopSelf(startId)
        }.apply {
            name = "phone-control-loop"
            start()
        }
    }

    private fun runLoop(taskId: String, task: String): LoopOutcome {
        val prefs = servicePrefs()
        val token = BackendSecurityPolicy.adminToken(prefs)
        val baseUrl = backendBaseUrl(prefs)
        if (token.isBlank() || baseUrl == null) {
            return LoopOutcome("任务已停止", "后端未连接，没法继续操作")
        }

        var step = 1
        var lastAction: JSONObject? = null
        var lastActionResult: String? = null

        while (step <= MAX_STEPS) {
            if (cancelRequested) return LoopOutcome("已取消", "你取消了这次操作")

            val observation = YexuanAccessibilityService.capturePhoneControlObservation()
                ?: return LoopOutcome("任务已停止", "读取屏幕失败，已停止")

            if (isSensitiveObservation(observation)) {
                return LoopOutcome("需要你确认", "识别到敏感页面，已本地拦截并停下")
            }

            val response = try {
                postStep(baseUrl, token, taskId, step, observation, lastAction, lastActionResult)
            } catch (error: Exception) {
                Log.w(tag, "phone control step request failed task=$taskId step=$step", error)
                return LoopOutcome("任务已停止", "和后端通信失败，已停止")
            }

            when (response.optString("status")) {
                "continue" -> {
                    val action = response.optJSONObject("action")
                        ?: return LoopOutcome("任务已停止", "后端没有给出下一步动作")
                    if (isSensitiveAction(action)) {
                        return LoopOutcome("需要你确认", "下一步动作命中本地敏感词，已拦截")
                    }
                    lastAction = action
                    lastActionResult = executeAction(action, observation)
                    updateOngoingNotification("正在操作（第 $step 步）：${task.ifBlank { "手机任务" }}", taskId)
                }
                "done" -> return LoopOutcome("手机任务完成", "已经完成")
                "need_confirmation" -> return LoopOutcome(
                    "需要你确认",
                    response.optString("message").ifBlank { "需要你确认一下" },
                )
                "refused" -> return LoopOutcome(
                    "任务已停止",
                    response.optString("message").ifBlank { "任务被拒绝" },
                )
                else -> return LoopOutcome("任务已停止", "后端返回了无法识别的状态")
            }

            step += 1
            if (cancelRequested) return LoopOutcome("已取消", "你取消了这次操作")
            Thread.sleep(STEP_INTERVAL_MS)
        }
        return LoopOutcome("任务已停止", "步数超限，已停止")
    }

    private fun requestCancel(reason: String) {
        cancelRequested = true
        Log.d(tag, "phone control cancel requested: $reason")
    }

    // 复用无障碍服务里被动屏幕采集已有的敏感包名/文案关键词表——两条判断路径共用同一份
    // "什么算敏感"的定义。这里额外把节点文本、辅助描述和窗口标题一起丢进去判断。
    private fun isSensitiveObservation(observation: YexuanAccessibilityService.PhoneControlObservation): Boolean {
        val texts = observation.nodes.flatMap { listOf(it.text, it.contentDesc) } + observation.screenTitle
        return YexuanAccessibilityService.isSensitiveObservation(observation.packageName, texts)
    }

    private fun isSensitiveAction(action: JSONObject): Boolean {
        val texts = mutableListOf<String>()
        action.optString("text").takeIf { it.isNotBlank() }?.let(texts::add)
        return YexuanAccessibilityService.isSensitiveObservation("", texts)
    }

    private fun executeAction(
        action: JSONObject,
        observation: YexuanAccessibilityService.PhoneControlObservation,
    ): String {
        return when (action.optString("type")) {
            "tap" -> {
                val ratio = ratioForAction(action, observation) ?: return "no_target"
                if (YexuanAccessibilityService.performTapAtRatio(ratio.first, ratio.second)) "ok" else "failed"
            }
            "type" -> {
                val ratio = ratioForAction(action, observation) ?: return "no_target"
                val text = action.optString("text")
                if (YexuanAccessibilityService.performTypeAtRatio(ratio.first, ratio.second, text)) {
                    "ok"
                } else {
                    "failed"
                }
            }
            "scroll" -> {
                val direction = action.optString("direction", "down")
                if (YexuanAccessibilityService.performScroll(direction)) "ok" else "failed"
            }
            else -> "unsupported_action_type"
        }
    }

    // target_node_id 优先，用最近一次观察里的节点坐标换算成归一化比例；模型给不出精确节点匹配
    // 时退化为协议里的 target_point（0~1 比例坐标），与后端契约一致。
    private fun ratioForAction(
        action: JSONObject,
        observation: YexuanAccessibilityService.PhoneControlObservation,
    ): Pair<Float, Float>? {
        val nodeId = action.optString("target_node_id")
        if (nodeId.isNotBlank()) {
            val node = observation.nodes.firstOrNull { it.id == nodeId }
            if (node != null && observation.screenWidth > 0 && observation.screenHeight > 0) {
                val cx = (node.bounds.left + node.bounds.right) / 2f
                val cy = (node.bounds.top + node.bounds.bottom) / 2f
                return Pair(cx / observation.screenWidth, cy / observation.screenHeight)
            }
        }
        val point = action.optJSONArray("target_point")
        if (point != null && point.length() == 2) {
            return Pair(point.optDouble(0).toFloat(), point.optDouble(1).toFloat())
        }
        return null
    }

    private fun postStep(
        baseUrl: String,
        token: String,
        taskId: String,
        step: Int,
        observation: YexuanAccessibilityService.PhoneControlObservation,
        lastAction: JSONObject?,
        lastActionResult: String?,
    ): JSONObject {
        val nodesJson = JSONArray()
        for (node in observation.nodes) {
            nodesJson.put(
                JSONObject().apply {
                    put("id", node.id)
                    put("text", node.text)
                    put("content_desc", node.contentDesc)
                    put("clickable", node.clickable)
                    put(
                        "bounds",
                        JSONArray(
                            listOf(
                                node.bounds.left,
                                node.bounds.top,
                                node.bounds.right,
                                node.bounds.bottom,
                            ),
                        ),
                    )
                },
            )
        }
        val payload = JSONObject().apply {
            put("task_id", taskId)
            put("step", step)
            put("package_name", observation.packageName)
            put("screen_title", observation.screenTitle)
            put("nodes", nodesJson)
            observation.screenshotBase64?.let { put("screenshot_base64", it) }
            lastAction?.let { put("last_action", it) }
            lastActionResult?.let { put("last_action_result", it) }
        }
        return postJsonForResult("$baseUrl/phone_control/step", payload.toString(), token)
    }

    private fun postJsonForResult(endpoint: String, payload: String, token: String): JSONObject {
        val bytes = payload.toByteArray(Charsets.UTF_8)
        val connection = (URL(endpoint).openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            instanceFollowRedirects = false
            connectTimeout = 8000
            readTimeout = 30000
            doOutput = true
            setRequestProperty("Authorization", "Bearer $token")
            setRequestProperty("Content-Type", "application/json; charset=utf-8")
        }
        try {
            connection.outputStream.use { it.write(bytes) }
            val statusCode = connection.responseCode
            val stream = if (statusCode in 200..299) connection.inputStream else connection.errorStream
            val body = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
            if (statusCode !in 200..299) throw IOException("HTTP $statusCode")
            return JSONObject(body)
        } finally {
            connection.disconnect()
        }
    }

    private fun servicePrefs(): SharedPreferences =
        getSharedPreferences(BackendSecurityPolicy.PREFS_NAME, Context.MODE_PRIVATE)

    private fun backendBaseUrl(prefs: SharedPreferences): String? {
        val stored = prefs.getString("backendBaseUrl", null)?.trim().orEmpty()
        val value = (stored.ifEmpty { "http://127.0.0.1:8080" }).trimEnd('/')
        return if (BackendSecurityPolicy.isAllowedBaseUrl(value, prefs)) value else null
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            channelId,
            "手机自动化",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "手机自动化任务进行中和结果提示"
        }
        manager.createNotificationChannel(channel)
    }

    private fun notificationBuilder(): android.app.Notification.Builder {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            android.app.Notification.Builder(this, channelId)
        } else {
            @Suppress("DEPRECATION")
            android.app.Notification.Builder(this)
        }
    }

    private fun buildOngoingNotification(text: String, taskId: String) =
        notificationBuilder()
            .setSmallIcon(android.R.drawable.ic_menu_manage)
            .setContentTitle("PresenceKit 手机自动化")
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setLocalOnly(true)
            .setCategory(android.app.Notification.CATEGORY_SERVICE)
            .setPriority(android.app.Notification.PRIORITY_LOW)
            .setContentIntent(openAppIntent())
            .addAction(0, "取消", cancelPendingIntent(taskId))
            .build()

    private fun updateOngoingNotification(text: String, taskId: String) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(notificationId, buildOngoingNotification(text, taskId))
    }

    private fun notifyResult(taskId: String, task: String, title: String, message: String) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val notification = notificationBuilder()
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText("${task.ifBlank { "手机任务" }}：$message")
            .setAutoCancel(true)
            .setContentIntent(openAppIntent())
            .build()
        manager.notify(taskId.hashCode(), notification)
    }

    private fun cancelPendingIntent(taskId: String): PendingIntent {
        val intent = Intent(ACTION_CANCEL).apply {
            setPackage(packageName)
            putExtra("task_id", taskId)
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        return PendingIntent.getBroadcast(this, taskId.hashCode(), intent, flags)
    }

    private fun openAppIntent(): PendingIntent {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        return PendingIntent.getActivity(this, 0, intent, flags)
    }

    private data class LoopOutcome(val title: String, val message: String)

    companion object {
        private const val ACTION_CANCEL = "com.presencekit.mobile.action.PHONE_CONTROL_CANCEL"
        private const val MAX_STEPS = 20
        private const val STEP_INTERVAL_MS = 600L

        fun start(context: Context, taskId: String, task: String) {
            val intent = Intent(context, PhoneControlService::class.java).apply {
                putExtra("task_id", taskId)
                putExtra("task", task)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun cancel(context: Context, taskId: String) {
            context.sendBroadcast(
                Intent(ACTION_CANCEL).apply {
                    setPackage(context.packageName)
                    putExtra("task_id", taskId)
                },
            )
        }
    }
}
