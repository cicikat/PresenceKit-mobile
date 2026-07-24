package com.presencekit.mobile

import android.app.Service
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import android.text.TextUtils
import android.util.Log
import kotlin.math.abs

class FloatingBubbleService : Service() {
    private val tag = "FloatingBubbleService"
    private val prefsName = "yexuan_memery"
    private var windowManager: WindowManager? = null
    private var bubbleView: View? = null
    private var bubbleParams: WindowManager.LayoutParams? = null
    private val surface = Color.rgb(20, 39, 31)
    private val surfaceEdge = Color.rgb(31, 58, 46)
    private val characterOn = Color.rgb(241, 233, 214)
    private val characterMuted = Color.argb(178, 241, 233, 214)
    private val characterGhost = Color.argb(112, 241, 233, 214)
    private val danger = Color.rgb(139, 58, 43)
    private val warn = Color.rgb(184, 137, 58)
    private var bubbleCreatedAt = 0L
    private var lockConfirmPending = false

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) { stopSelf(); return START_NOT_STICKY }
        showBubble(intent)
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        removeBubble()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun removeBubble() {
        bubbleView?.let { view ->
            runCatching { windowManager?.removeView(view) }
        }
        bubbleView = null
        bubbleParams = null
    }

    private fun showBubble(intent: Intent?) {
        removeBubble()
        bubbleCreatedAt = System.currentTimeMillis()
        lockConfirmPending = false

        val mode = intent?.getStringExtra("mode").orEmpty()
        val target = intent?.getStringExtra("target").orEmpty().ifBlank { "meituan" }
        val message = intent?.getStringExtra("message").orEmpty()
        val taskId = intent?.getStringExtra("task_id").orEmpty()
        val task = intent?.getStringExtra("task").orEmpty()
        val isOrder = mode == "order"
        val isLock = mode == "lock"
        val isControl = mode == "control"

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(12), dp(10), dp(12), dp(12))
            background = GradientDrawable().apply {
                setColor(surface)
                cornerRadius = dp(1).toFloat()
                setStroke(dp(1), surfaceEdge)
            }
            elevation = dp(14).toFloat()
        }

        addFloatingHeader(
            root,
            when {
                isOrder -> "外卖 · 确认"
                isLock -> "锁屏 · 确认"
                isControl -> "手机自动化 · 确认"
                else -> "浮窗 · 拖动"
            },
        )

        when {
            isOrder -> addOrderContent(root, target)
            isLock -> addLockContent(root, message)
            isControl -> addControlContent(root, taskId, task)
            else -> addChatContent(root, message)
        }

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        val prefs = getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        val params = WindowManager.LayoutParams(
            if (isOrder) dp(318) else if (isLock) dp(286) else if (isControl) dp(318) else dp(244),
            WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = prefs.getInt("floatingBubbleX", dp(48))
            y = prefs.getInt("floatingBubbleY", dp(240))
        }

        var downRawX = 0f
        var downRawY = 0f
        var startX = 0
        var startY = 0
        root.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    downRawX = event.rawX
                    downRawY = event.rawY
                    startX = params.x
                    startY = params.y
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    params.x = (startX + (event.rawX - downRawX).toInt()).coerceAtLeast(0)
                    params.y = (startY + (event.rawY - downRawY).toInt()).coerceAtLeast(0)
                    windowManager?.updateViewLayout(root, params)
                    true
                }
                MotionEvent.ACTION_UP -> {
                    prefs.edit()
                        .putInt("floatingBubbleX", params.x)
                        .putInt("floatingBubbleY", params.y)
                        .apply()
                    if (abs(event.rawX - downRawX) < dp(8) &&
                        abs(event.rawY - downRawY) < dp(8)
                    ) {
                        openApp()
                    }
                    true
                }
                else -> false
            }
        }

        bubbleView = root
        bubbleParams = params
        try {
            windowManager?.addView(root, params)
            getSharedPreferences(prefsName, Context.MODE_PRIVATE)
                .edit()
                .remove("lastOverlayError")
                .remove("lastOverlayErrorAt")
                .apply()
        } catch (error: Exception) {
            // canDrawOverlays() 为 true 不等于 addView 一定成功——部分厂商 ROM
            // 对 TYPE_APPLICATION_OVERLAY 有额外限制，会在此抛出而不是权限检查阶段。
            // 不捕获会导致服务静默崩溃，悬浮窗表现为"从不触发"且没有任何线索。
            Log.e(tag, "addView failed mode=${intent?.getStringExtra("mode")}", error)
            getSharedPreferences(prefsName, Context.MODE_PRIVATE)
                .edit()
                .putString("lastOverlayError", error.message ?: error.javaClass.simpleName)
                .putLong("lastOverlayErrorAt", System.currentTimeMillis())
                .apply()
            bubbleView = null
            bubbleParams = null
            stopSelf()
        }
    }

    private fun addFloatingHeader(root: LinearLayout, label: String) {
        val header = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        header.addView(
            TextView(this).apply {
                text = "\u53f6"
                gravity = Gravity.CENTER
                setTextColor(characterOn)
                textSize = 11f
                typeface = Typeface.create(Typeface.SERIF, Typeface.ITALIC)
                includeFontPadding = false
                background = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    setColor(Color.TRANSPARENT)
                    setStroke(dp(1), characterOn)
                }
            },
            LinearLayout.LayoutParams(dp(18), dp(18)),
        )
        header.addView(
            TextView(this).apply {
                text = label
                setTextColor(characterMuted)
                textSize = 9f
                typeface = Typeface.MONOSPACE
                letterSpacing = 0.12f
                isSingleLine = true
                ellipsize = TextUtils.TruncateAt.END
                setPadding(dp(6), 0, 0, 0)
            },
            LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f),
        )
        header.addView(
            TextView(this).apply {
                text = "\u2212"
                setTextColor(characterGhost)
                textSize = 16f
                gravity = Gravity.CENTER
                setPadding(dp(10), 0, 0, 0)
                setOnClickListener {
                    if (System.currentTimeMillis() - bubbleCreatedAt < 800L) return@setOnClickListener
                    stopSelf()
                }
            },
        )
        root.addView(header)
    }

    private fun addChatContent(root: LinearLayout, message: String) {
        root.addView(
            TextView(this).apply {
                text = message.ifBlank { "\u6211\u5728\u3002\u8bfb\u5b8c\u56de\u6765\u8ddf\u6211\u8bf4\u4e00\u53e5\u3002" }
                setTextColor(characterOn)
                textSize = 14f
                typeface = Typeface.create(Typeface.SERIF, Typeface.NORMAL)
                setLineSpacing(dp(2).toFloat(), 1.0f)
                setPadding(0, dp(7), 0, dp(9))
            },
        )

        addDivider(root)
        val actions = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, dp(8), 0, 0)
        }
        actions.addView(actionText("\u6253\u5f00\u804a\u5929", true) { openApp() })
        actions.addView(actionText("\u7a0d\u540e", false) { stopSelf() })
        actions.addView(spacer())
        actions.addView(actionText("\u79fb\u5230\u89d2", false) { moveToCorner() })
        root.addView(actions)
    }

    private fun addLockContent(root: LinearLayout, message: String) {
        addTagRow(root, "ACTION \u00b7 LOCK", danger)
        addTitle(root, "\u4ed6\u60f3\u66ff\u4f60\u9501\u5c4f")
        addVoice(root, message.ifBlank { "\u5df2\u7ecf\u5f88\u665a\u4e86\u3002\u6211\u66ff\u4f60\u6309\u4e00\u4e0b\uff0c\u597d\u5417\u3002" })
        root.addView(
            TextView(this).apply {
                text = "\u203b \u53ea\u6709\u4f60\u70b9\u4e0b\u9762\u7684\u6309\u94ae\u540e\uff0c\u624d\u4f1a\u8c03\u7528\u7cfb\u7edf\u9501\u5c4f\u3002"
                setTextColor(characterGhost)
                textSize = 11f
                typeface = Typeface.MONOSPACE
                setPadding(0, dp(8), 0, dp(10))
            },
        )
        addDivider(root)
        val actions = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, dp(8), 0, 0)
        }
        var lockBtn: TextView? = null
        lockBtn = actionText("\u66ff\u6211\u9501\u5c4f", true) {
            if (!lockConfirmPending) {
                lockConfirmPending = true
                lockBtn?.text = "\u518d\u70b9\u786e\u8ba4\u9501\u5c4f"
            } else {
                lockNowOrOpenApp()
            }
        }
        actions.addView(lockBtn)
        actions.addView(actionText("\u6253\u5f00\u804a\u5929", false) { openApp() })
        actions.addView(actionText("\u7a0d\u540e", false) { stopSelf() })
        root.addView(actions)
    }

    private fun addOrderContent(root: LinearLayout, target: String) {
        val label = if (target == "taobao") "\u6dd8\u5b9d" else "\u7f8e\u56e2"
        addTagRow(root, "ACTION \u00b7 \u9700\u8981\u4f60\u786e\u8ba4", warn)
        addTitle(root, "\u662f\u5426\u6253\u5f00 $label \u67e5\u770b\u8d2d\u7269\u8f66\uff1f")
        addVoice(root, "\u5f53\u524d\u6ca1\u6709\u53ef\u4fe1\u7684\u5546\u54c1\u6216\u91d1\u989d\u6570\u636e\u3002\u6253\u5f00\u540e\u8bf7\u4f60\u81ea\u884c\u6838\u5bf9\uff0c\u5e94\u7528\u4e0d\u4f1a\u81ea\u52a8\u4e0b\u5355\u6216\u652f\u4ed8\u3002")
        root.addView(
            TextView(this).apply {
                text = "\u203b \u4e0d\u4f1a\u81ea\u52a8\u52a0\u8d2d\u3001\u63d0\u4ea4\u8ba2\u5355\u6216\u652f\u4ed8\u3002"
                setTextColor(characterGhost)
                textSize = 11f
                typeface = Typeface.MONOSPACE
                setPadding(0, dp(8), 0, dp(10))
            },
        )

        val actions = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, dp(8), 0, 0)
        }
        actions.addView(actionText("\u6253\u5f00 $label", true) { openShoppingTarget(target) })
        actions.addView(actionText("\u6253\u5f00\u804a\u5929", false) { openApp() })
        actions.addView(actionText("\u6682\u4e0d\u652f\u4ed8", false) { stopSelf() })
        root.addView(actions)
    }

    private fun addControlContent(root: LinearLayout, taskId: String, task: String) {
        addTagRow(root, "ACTION · 需要你确认", warn)
        addTitle(root, "要帮你操作手机？")
        addVoice(root, task.ifBlank { "没有任务描述。" })
        root.addView(
            TextView(this).apply {
                text = "※ 遇到密码/支付页面会自动停下，过程随时可取消。"
                setTextColor(characterGhost)
                textSize = 11f
                typeface = Typeface.MONOSPACE
                setPadding(0, dp(8), 0, dp(10))
            },
        )
        addDivider(root)
        val actions = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, dp(8), 0, 0)
        }
        actions.addView(
            actionText("开始", true) {
                if (taskId.isNotBlank()) {
                    PhoneControlService.start(this, taskId, task)
                }
                stopSelf()
            },
        )
        actions.addView(actionText("打开聊天", false) { openApp() })
        actions.addView(actionText("取消", false) { stopSelf() })
        root.addView(actions)
    }

    private fun addTagRow(root: LinearLayout, textValue: String, color: Int) {
        root.addView(
            TextView(this).apply {
                text = textValue
                setTextColor(color)
                textSize = 10f
                typeface = Typeface.MONOSPACE
                letterSpacing = 0.08f
                setPadding(0, dp(10), 0, dp(4))
            },
        )
    }

    private fun addTitle(root: LinearLayout, textValue: String) {
        root.addView(
            TextView(this).apply {
                text = textValue
                setTextColor(characterOn)
                textSize = 19f
                typeface = Typeface.create(Typeface.SERIF, Typeface.NORMAL)
                setLineSpacing(dp(2).toFloat(), 1.0f)
                setPadding(0, 0, 0, dp(7))
            },
        )
    }

    private fun addVoice(root: LinearLayout, textValue: String) {
        root.addView(
            TextView(this).apply {
                text = textValue
                setTextColor(characterOn)
                textSize = 14f
                typeface = Typeface.create(Typeface.SERIF, Typeface.ITALIC)
                setLineSpacing(dp(2).toFloat(), 1.0f)
                setPadding(0, dp(7), 0, dp(9))
            },
        )
    }

    private fun addSection(root: LinearLayout, textValue: String) {
        root.addView(
            TextView(this).apply {
                text = textValue
                setTextColor(characterGhost)
                textSize = 10f
                typeface = Typeface.MONOSPACE
                letterSpacing = 0.16f
                setPadding(0, dp(8), 0, dp(5))
            },
        )
    }

    private fun addDivider(root: LinearLayout) {
        root.addView(
            View(this).apply {
                setBackgroundColor(Color.argb(44, 245, 235, 210))
            },
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(1),
            ),
        )
    }

    private fun actionText(textValue: String, primary: Boolean, onClick: () -> Unit): TextView {
        return TextView(this).apply {
            text = textValue
            setTextColor(if (primary) characterOn else characterGhost)
            textSize = 9.5f
            typeface = Typeface.MONOSPACE
            letterSpacing = 0.12f
            setPadding(0, 0, dp(14), 0)
            setOnClickListener {
                if (System.currentTimeMillis() - bubbleCreatedAt < 800L) return@setOnClickListener
                onClick()
            }
        }
    }

    private fun spacer(): View {
        return View(this).apply {
            layoutParams = LinearLayout.LayoutParams(0, 1, 1f)
        }
    }

    private fun moveToCorner() {
        val view = bubbleView ?: return
        val params = bubbleParams ?: return
        val width = if (params.width > 0) params.width else dp(244)
        params.x = (resources.displayMetrics.widthPixels - width - dp(14)).coerceAtLeast(0)
        params.y = dp(96)
        windowManager?.updateViewLayout(view, params)
        getSharedPreferences(prefsName, Context.MODE_PRIVATE)
            .edit()
            .putInt("floatingBubbleX", params.x)
            .putInt("floatingBubbleY", params.y)
            .apply()
    }

    private fun openApp() {
        startActivity(
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
        )
    }

    private fun lockNowOrOpenApp() {
        val manager = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val component = ComponentName(this, YexuanDeviceAdminReceiver::class.java)
        if (manager.isAdminActive(component)) {
            manager.lockNow()
            stopSelf()
        } else {
            openApp()
        }
    }

    private fun openShoppingTarget(target: String) {
        val packages = when (target) {
            "taobao" -> listOf("com.taobao.taobao")
            else -> listOf("com.sankuai.meituan", "com.meituan.android.waimai")
        }
        for (packageName in packages) {
            val intent = packageManager.getLaunchIntentForPackage(packageName)
            if (intent != null) {
                YexuanAccessibilityService.requestOpenCart(target)
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                return
            }
        }
        openApp()
    }

    private fun dp(value: Int): Int {
        return (value * resources.displayMetrics.density).toInt()
    }
}
