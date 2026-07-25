package com.presencekit.mobile

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Bitmap
import android.graphics.Path
import android.graphics.Rect
import android.hardware.HardwareBuffer
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Base64
import android.util.DisplayMetrics
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import java.io.ByteArrayOutputStream
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.Executor

class YexuanAccessibilityService : AccessibilityService() {
    private val handler = Handler(Looper.getMainLooper())
    private var searchScheduled = false
    private var snapshotDirty = true
    private var dirtyPackageName = ""
    private var lastSnapshotAt = 0L

    override fun onServiceConnected() {
        super.onServiceConnected()
        activeService = this
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        snapshotDirty = true
        dirtyPackageName = event?.packageName?.toString().orEmpty()
        if (!hasPendingCartRequest()) return
        val packageName = event?.packageName?.toString().orEmpty()
        if (packageName.isBlank() || packageName in pendingPackages) {
            scheduleCartSearch()
        }
    }

    override fun onInterrupt() {
        // No active spoken/audio feedback to interrupt yet.
    }

    override fun onDestroy() {
        if (activeService === this) {
            activeService = null
        }
        super.onDestroy()
    }

    private fun scheduleCartSearch() {
        if (searchScheduled) return
        searchScheduled = true
        handler.postDelayed(
            {
                searchScheduled = false
                val done = tryOpenCart()
                if (!done && hasPendingCartRequest()) {
                    scheduleCartSearch()
                }
            },
            450L,
        )
    }

    private fun tryOpenCart(): Boolean {
        if (!hasPendingCartRequest()) return false
        val root = rootInActiveWindow ?: return false
        val rootPackage = root.packageName?.toString().orEmpty()
        if (rootPackage !in pendingPackages) return false

        val candidate = findCartNode(root) ?: return false
        val clicked = clickNodeOrParent(candidate)
        if (clicked) {
            clearPendingCartRequest()
        }
        return clicked
    }

    private fun requestScreenContextCapture(
        allowDebugCapture: Boolean,
        callback: (Map<String, Any?>?) -> Unit,
    ) {
        if (!allowDebugCapture && !screenContextUploadEnabled()) {
            callback(null)
            return
        }
        handler.post {
            if (!allowDebugCapture && !screenContextUploadEnabled()) {
                callback(null)
                return@post
            }
            callback(captureScreenContextOnHandler())
        }
    }

    // 屏幕文本上传不再有独立的按 App 白名单——唯一闸是 screenContextUploadEnabled()
    // 主开关（在 requestScreenContextCapture() 里已经过一遍）；这里只保留敏感 App /
    // 密码输入框 / 敏感关键词三道内容拦截，跟 allowDebugCapture 是否为调试请求无关。
    private fun captureScreenContextOnHandler(): Map<String, Any?>? {
        val now = SystemClock.uptimeMillis()
        val root = rootInActiveWindow
        val packageName = root?.packageName?.toString()
            ?: dirtyPackageName
        val appLabel = appLabel(packageName)
        val cached = lastSnapshot
        if (cached != null &&
            cached["packageName"] == packageName &&
            (!snapshotDirty || now - lastSnapshotAt < SNAPSHOT_MIN_INTERVAL_MS)
        ) {
            return cached
        }

        sensitiveAppReason(packageName, appLabel)?.let { reason ->
            return storeSnapshot(blockedSnapshot(reason), now)
        }
        if (root != null && containsPasswordNode(root, 0)) {
            return storeSnapshot(
                blockedSnapshot("\u68c0\u6d4b\u5230\u5bc6\u7801\u8f93\u5165\u6846"),
                now,
            )
        }
        val className = root?.className?.toString().orEmpty()
        val windowTitle = root?.window?.title
            ?.toString()
            ?.trim()
            ?.take(120)
            .orEmpty()
        val visible = linkedSetOf<String>()
        val clickable = linkedSetOf<String>()
        if (root != null) {
            collectNodeText(root, visible, clickable, 0)
        }
        if (containsSensitiveKeyword(listOf(windowTitle) + visible + clickable)) {
            return storeSnapshot(
                blockedSnapshot("\u68c0\u6d4b\u5230\u654f\u611f\u5173\u952e\u8bcd"),
                now,
            )
        }
        return storeSnapshot(
            mapOf(
                "isBlocked" to false,
                "blockedReason" to "",
                "textUploadAllowed" to true,
                "packageName" to packageName,
                "appLabel" to appLabel,
                "className" to className,
                "windowTitle" to windowTitle,
                "visibleText" to visible.take(60),
                "clickableText" to clickable.take(40),
                "capturedAt" to (System.currentTimeMillis() / 1000.0),
            ),
            now,
        )
    }

    private fun storeSnapshot(
        snapshot: Map<String, Any?>,
        capturedAt: Long,
    ): Map<String, Any?> {
        lastSnapshot = snapshot
        lastSnapshotAt = capturedAt
        snapshotDirty = false
        dirtyPackageName = ""
        return snapshot
    }

    private fun screenContextUploadEnabled(): Boolean {
        val prefs = getSharedPreferences(BackendSecurityPolicy.PREFS_NAME, MODE_PRIVATE)
        return BackendSecurityPolicy.screenContextUploadEnabled(prefs)
    }

    private fun blockedSnapshot(reason: String): Map<String, Any?> {
        return mapOf(
            "isBlocked" to true,
            "blockedReason" to reason,
            "textUploadAllowed" to false,
            "packageName" to "",
            "appLabel" to "",
            "className" to "",
            "windowTitle" to "",
            "visibleText" to emptyList<String>(),
            "clickableText" to emptyList<String>(),
            "capturedAt" to (System.currentTimeMillis() / 1000.0),
        )
    }

    private fun containsPasswordNode(node: AccessibilityNodeInfo, depth: Int): Boolean {
        if (depth > 12) return false
        if (node.isPassword) return true
        for (index in 0 until node.childCount) {
            val child = node.getChild(index) ?: continue
            if (containsPasswordNode(child, depth + 1)) return true
        }
        return false
    }

    private fun sensitiveAppReason(packageName: String, appLabel: String): String? {
        val packageLower = packageName.lowercase()
        if (sensitivePackageHints.any(packageLower::contains)) {
            return "\u654f\u611f\u5e94\u7528\u5df2\u8fc7\u6ee4"
        }
        if (sensitiveAppLabelHints.any(appLabel::contains)) {
            return "\u654f\u611f\u5e94\u7528\u5df2\u8fc7\u6ee4"
        }
        return null
    }

    private fun containsSensitiveKeyword(values: Iterable<String>): Boolean {
        return values.any { value -> sensitiveTextHints.any(value::contains) }
    }

    private fun collectNodeText(
        node: AccessibilityNodeInfo,
        visible: LinkedHashSet<String>,
        clickable: LinkedHashSet<String>,
        depth: Int,
    ) {
        if (depth > 8 || visible.size >= 80) return
        if (!node.isVisibleToUser) return
        val text = node.text?.toString()?.trim().orEmpty()
        val description = node.contentDescription?.toString()?.trim().orEmpty()
        val label = when {
            text.isNotBlank() -> text
            description.isNotBlank() -> description
            else -> ""
        }.replace(Regex("\\s+"), " ").take(80)
        if (label.isNotBlank()) {
            visible.add(label)
            if (node.isClickable || node.isFocusable) {
                clickable.add(label)
            }
        }
        for (index in 0 until node.childCount) {
            val child = node.getChild(index) ?: continue
            collectNodeText(child, visible, clickable, depth + 1)
        }
    }

    private fun appLabel(packageName: String): String {
        if (packageName.isBlank()) return ""
        return runCatching {
            val info = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(info).toString()
        }.getOrDefault("")
    }

    private fun findCartNode(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        if (!node.isVisibleToUser) return null
        val text = node.text?.toString().orEmpty()
        val description = node.contentDescription?.toString().orEmpty()
        val viewId = node.viewIdResourceName.orEmpty().lowercase()
        val strictTextMatch = text == CART_TEXT || description == CART_TEXT
        val navCartIdMatch = viewId.contains("cart") && isNavigationNode(node, 0)
        if (strictTextMatch || navCartIdMatch) return node

        for (index in 0 until node.childCount) {
            val child = node.getChild(index) ?: continue
            val found = findCartNode(child)
            if (found != null) return found
        }
        return null
    }

    // 向上最多走 3 层，确认节点处于导航栏容器中（防止 "加入购物车" 按钮误命中）
    private fun isNavigationNode(node: AccessibilityNodeInfo, depth: Int): Boolean {
        if (depth > 3) return false
        val viewId = node.viewIdResourceName.orEmpty().lowercase()
        val className = node.className?.toString().orEmpty()
        if (viewId.contains("tab") || viewId.contains("nav") || viewId.contains("bottom") ||
            className.contains("BottomNavigationView", ignoreCase = true) ||
            className.contains("TabLayout", ignoreCase = true) ||
            className.contains("BottomBar", ignoreCase = true)
        ) return true
        val parent = node.parent ?: return false
        return isNavigationNode(parent, depth + 1)
    }

    private fun clickNodeOrParent(node: AccessibilityNodeInfo): Boolean {
        var current: AccessibilityNodeInfo? = node
        var depth = 0
        while (current != null && depth < 6) {
            if (current.isClickable && current.isEnabled) {
                return current.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            }
            current = current.parent
            depth += 1
        }
        return false
    }

    // \u2500\u2500 phone_control\uff1a\u901a\u7528\u89c2\u5bdf + \u6267\u884c\u539f\u8bed \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500
    //
    // \u8fd9\u5957\u8ddf\u4e0a\u9762\u7684\u88ab\u52a8\u5c4f\u5e55\u4e0a\u4e0b\u6587\u91c7\u96c6\uff08screenContext\uff09\u662f\u4e24\u5957\u72ec\u7acb\u673a\u5236\uff0c\u8fd9\u5957\u4e0d\u505a\u9690\u79c1\u8fc7\u6ee4\u2014\u2014
    // \u8c03\u7528\u65b9\uff08PhoneControlService\uff09\u5fc5\u987b\u5148\u7ecf\u8fc7\u540e\u7aef sensitive_filter \u5224\u65ad\uff0c\u518d\u52a0\u672c\u5730
    // isSensitiveObservation() \u4e8c\u6b21\u6821\u9a8c\uff0c\u4e24\u8fb9\u90fd\u8fc7\u4e86\u624d\u5141\u8bb8\u6267\u884c\u3002
    //
    // \u5173\u952e\u8bbe\u8ba1\uff1atarget_node_id \u4e0d\u8de8\u8bf7\u6c42\u7f13\u5b58 AccessibilityNodeInfo \u5f15\u7528\uff08\u90a3\u73a9\u610f\u513f\u5728 UI \u7a0d\u5fae
    // \u4e00\u53d8\u5c31\u5931\u6548\uff09\u3002\u89c2\u5bdf\u9636\u6bb5\u628a\u6bcf\u4e2a\u8282\u70b9\u7684\u5c4f\u5e55\u5750\u6807 bounds \u4e00\u8d77\u4ea4\u7ed9\u8c03\u7528\u65b9\uff1b\u8c03\u7528\u65b9\u51b3\u5b9a\u8981\u70b9\u54ea\u4e2a
    // node \u4e4b\u540e\uff0c\u53ea\u9700\u8981\u628a\u8fd9\u4e2a bounds \u6362\u7b97\u6210\u7684\u5f52\u4e00\u5316\u5750\u6807\u4f20\u56de\u6765\uff0c\u6267\u884c\u9636\u6bb5\u5168\u90e8\u8d70\u5750\u6807\uff08tap \u7528
    // dispatchGesture\uff0ctype \u7528\u5750\u6807\u73b0\u67e5\u5f53\u524d\u6811\u4e0a\u5bf9\u5e94\u4f4d\u7f6e\u7684\u53ef\u7f16\u8f91\u8282\u70b9\uff09\uff0c\u4e0d\u4f9d\u8d56\u65e7\u8282\u70b9\u5f15\u7528\u3002

    data class PhoneControlNode(
        val id: String,
        val text: String,
        val contentDesc: String,
        val clickable: Boolean,
        val bounds: Rect,
    )

    data class PhoneControlObservation(
        val packageName: String,
        val screenTitle: String,
        val nodes: List<PhoneControlNode>,
        val screenWidth: Int,
        val screenHeight: Int,
        val screenshotBase64: String?,
    )

    private fun capturePhoneControlObservationOnHandler(
        callback: (PhoneControlObservation?) -> Unit,
    ) {
        val root = rootInActiveWindow
        if (root == null) {
            callback(null)
            return
        }
        val packageName = root.packageName?.toString().orEmpty()
        val screenTitle = root.window?.title?.toString()?.trim()?.take(120).orEmpty()
        val nodes = mutableListOf<PhoneControlNode>()
        collectActionableNodes(root, nodes, 0)
        val metrics = resources.displayMetrics
        captureScreenshotBase64 { screenshot ->
            callback(
                PhoneControlObservation(
                    packageName = packageName,
                    screenTitle = screenTitle,
                    nodes = nodes,
                    screenWidth = metrics.widthPixels,
                    screenHeight = metrics.heightPixels,
                    screenshotBase64 = screenshot,
                ),
            )
        }
    }

    private fun collectActionableNodes(
        node: AccessibilityNodeInfo,
        out: MutableList<PhoneControlNode>,
        depth: Int,
    ) {
        if (depth > 14 || out.size >= 120) return
        if (node.isVisibleToUser) {
            val text = node.text?.toString()?.trim().orEmpty()
            val description = node.contentDescription?.toString()?.trim().orEmpty()
            val actionable = node.isClickable || node.isEditable || node.isScrollable || node.isFocusable
            if (actionable && (text.isNotBlank() || description.isNotBlank())) {
                val bounds = Rect()
                node.getBoundsInScreen(bounds)
                if (!bounds.isEmpty) {
                    out.add(
                        PhoneControlNode(
                            id = "n${out.size}",
                            text = text.take(60),
                            contentDesc = description.take(60),
                            clickable = node.isClickable,
                            bounds = Rect(bounds),
                        ),
                    )
                }
            }
        }
        for (index in 0 until node.childCount) {
            val child = node.getChild(index) ?: continue
            collectActionableNodes(child, out, depth + 1)
        }
    }

    // API 30+ \u4e13\u7528\uff1b\u4f4e\u7248\u672c\u8bbe\u5907\u76f4\u63a5\u56de\u8c03 null\uff08\u89c6\u89c9\u6a21\u578b\u9000\u5316\u4e3a\u53ea\u9760\u8282\u70b9\u6587\u672c\u5224\u65ad\uff0c\u8986\u76d6\u4e0d\u5230\u7eaf\u56fe\u6807
    // \u6309\u94ae\uff0c\u4f46\u4e0d\u963b\u65ad\u529f\u80fd\uff09\u3002\u56de\u8c03\u7ecf executor \u8f6c\u56de\u4e3b Handler\uff0c\u4e0d\u5728\u8fd9\u91cc\u505a\u4efb\u4f55\u963b\u585e\u7b49\u5f85\u3002
    private fun captureScreenshotBase64(callback: (String?) -> Unit) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            callback(null)
            return
        }
        val executor = Executor { command -> handler.post(command) }
        val dispatched = runCatching {
            takeScreenshot(
                android.view.Display.DEFAULT_DISPLAY,
                executor,
                object : AccessibilityService.TakeScreenshotCallback {
                    override fun onSuccess(result: AccessibilityService.ScreenshotResult) {
                        val bitmap = runCatching {
                            Bitmap.wrapHardwareBuffer(result.hardwareBuffer, result.colorSpace)
                        }.getOrNull()
                        result.hardwareBuffer.close()
                        val encoded = bitmap?.let { hwBitmap ->
                            runCatching {
                                val software = hwBitmap.copy(Bitmap.Config.ARGB_8888, false)
                                val stream = ByteArrayOutputStream()
                                software.compress(Bitmap.CompressFormat.JPEG, 70, stream)
                                Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
                            }.getOrNull()
                        }
                        callback(encoded)
                    }

                    override fun onFailure(errorCode: Int) {
                        callback(null)
                    }
                },
            )
            true
        }.getOrDefault(false)
        if (!dispatched) callback(null)
    }

    // dispatchGesture \u672c\u8eab\u662f\u5f02\u6b65\u56de\u8c03\uff08onCompleted/onCancelled \u7ecf\u540c\u4e00\u4e2a\u4e3b\u7ebf\u7a0b Handler \u6295\u9012\uff09\u3002
    // \u8fd9\u4e2a\u65b9\u6cd5\u4e0d\u505a\u4efb\u4f55\u963b\u585e\u7b49\u5f85\uff0c\u76f4\u63a5\u628a\u7ed3\u679c\u4e22\u7ed9 callback\u2014\u2014\u963b\u585e\u7b49\u5f85\u7559\u7ed9\u8c03\u7528\u65b9\uff08companion \u91cc\u7684
    // performTapAtRatio\uff09\u5728\u540e\u53f0\u7ebf\u7a0b\u4e0a\u505a\uff0c\u907f\u514d\u5728\u4e3b\u7ebf\u7a0b\u91cc\u7b49\u4e00\u4e2a\u53ea\u80fd\u9760\u4e3b\u7ebf\u7a0b\u5904\u7406\u6d88\u606f\u624d\u4f1a\u89e6\u53d1\u7684\u56de\u8c03\uff0c
    // \u90a3\u6837\u4f1a\u6b7b\u9501\u3002
    private fun performTapOnHandler(xRatio: Float, yRatio: Float, callback: (Boolean) -> Unit) {
        val metrics = resources.displayMetrics
        val x = (xRatio.coerceIn(0f, 1f) * metrics.widthPixels)
        val y = (yRatio.coerceIn(0f, 1f) * metrics.heightPixels)
        val path = Path().apply { moveTo(x, y) }
        val stroke = GestureDescription.StrokeDescription(path, 0, 80)
        val gesture = GestureDescription.Builder().addStroke(stroke).build()
        val dispatched = dispatchGesture(
            gesture,
            object : AccessibilityService.GestureResultCallback() {
                override fun onCompleted(gestureDescription: GestureDescription?) {
                    callback(true)
                }

                override fun onCancelled(gestureDescription: GestureDescription?) {
                    callback(false)
                }
            },
            handler,
        )
        if (!dispatched) callback(false)
    }

    // \u65e0\u969c\u788d\u5199\u6587\u672c\u6ca1\u6709\u5f02\u6b65\u56de\u8c03\uff0c\u76f4\u63a5\u540c\u6b65\u8fd4\u56de\uff0c\u4e0d\u9700\u8981\u8d70\u4e0a\u9762 performTapOnHandler \u90a3\u5957\u3002
    private fun performTypeOnHandler(xRatio: Float, yRatio: Float, text: String): Boolean {
        val root = rootInActiveWindow ?: return false
        val metrics = resources.displayMetrics
        val x = (xRatio.coerceIn(0f, 1f) * metrics.widthPixels).toInt()
        val y = (yRatio.coerceIn(0f, 1f) * metrics.heightPixels).toInt()
        val target = findEditableNodeAtPoint(root, x, y) ?: return false
        val arguments = Bundle().apply {
            putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
        }
        target.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
        return target.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, arguments)
    }

    private fun findEditableNodeAtPoint(
        node: AccessibilityNodeInfo,
        x: Int,
        y: Int,
    ): AccessibilityNodeInfo? {
        val bounds = Rect()
        node.getBoundsInScreen(bounds)
        if (!bounds.contains(x, y)) return null
        for (index in 0 until node.childCount) {
            val child = node.getChild(index) ?: continue
            findEditableNodeAtPoint(child, x, y)?.let { return it }
        }
        return if (node.isEditable) node else null
    }

    private fun performScrollOnHandler(direction: String): Boolean {
        val root = rootInActiveWindow ?: return false
        val target = findScrollableNode(root, 0) ?: return false
        val action = if (direction == "up" || direction == "left") {
            AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD
        } else {
            AccessibilityNodeInfo.ACTION_SCROLL_FORWARD
        }
        return target.performAction(action)
    }

    private fun findScrollableNode(node: AccessibilityNodeInfo, depth: Int): AccessibilityNodeInfo? {
        if (depth > 14) return null
        if (node.isScrollable) return node
        for (index in 0 until node.childCount) {
            val child = node.getChild(index) ?: continue
            findScrollableNode(child, depth + 1)?.let { return it }
        }
        return null
    }

    companion object {
        private const val CART_TEXT = "\u8d2d\u7269\u8f66"
        private const val CART_REQUEST_WINDOW_MS = 16_000L
        private const val SNAPSHOT_MIN_INTERVAL_MS = 5_000L
        private const val SNAPSHOT_WAIT_TIMEOUT_MS = 3_000L
        private const val PHONE_CONTROL_CAPTURE_TIMEOUT_MS = 4_000L
        private const val GESTURE_WAIT_TIMEOUT_MS = 1_500L
        private val sensitivePackageHints = listOf(
            "alipay",
            "unionpay",
            "bank",
            "cmb",
            "icbc",
            "ccb",
            "abchina",
            "boc",
            "psbc",
            "health",
            "medical",
            "hospital",
            "weixin",
            "wechat",
            "com.tencent.mm",
        )
        private val sensitiveAppLabelHints = listOf(
            "\u94f6\u884c",
            "\u652f\u4ed8\u5b9d",
            "\u5fae\u4fe1",
            "\u4e91\u95ea\u4ed8",
            "\u533b\u9662",
            "\u533b\u7597",
            "\u5065\u5eb7",
            "\u6302\u53f7",
        )
        private val sensitiveTextHints = listOf(
            "\u9a8c\u8bc1\u7801",
            "\u6821\u9a8c\u7801",
            "\u52a8\u6001\u7801",
            "\u652f\u4ed8\u5bc6\u7801",
            "\u767b\u5f55\u5bc6\u7801",
            "\u5bc6\u7801",
            "\u94f6\u884c\u5361",
            "\u94f6\u884c\u8d26\u6237",
            "\u4fe1\u7528\u5361",
            "\u8f6c\u8d26",
            "\u6536\u6b3e",
            "\u4ed8\u6b3e",
            "\u652f\u4ed8",
            "\u75c5\u5386",
            "\u5904\u65b9",
            "\u5c31\u8bca",
            "\u6302\u53f7",
            "\u533b\u4fdd",
            "\u68c0\u67e5\u62a5\u544a",
            "\u8bca\u65ad",
            "\u5316\u9a8c",
            "\u4e91\u95ea\u4ed8",
            "\u5fae\u4fe1\u652f\u4ed8",
            "\u652f\u4ed8\u5b9d",
        )

        @Volatile
        private var activeService: YexuanAccessibilityService? = null

        @Volatile
        private var pendingPackages: Set<String> = emptySet()

        @Volatile
        private var pendingUntil = 0L

        @Volatile
        private var lastSnapshot: Map<String, Any?>? = null

        fun captureScreenContext(): Map<String, Any?>? {
            val service = activeService ?: return null
            val latch = CountDownLatch(1)
            var result: Map<String, Any?>? = null
            service.requestScreenContextCapture(allowDebugCapture = false) {
                result = it
                latch.countDown()
            }
            return if (latch.await(SNAPSHOT_WAIT_TIMEOUT_MS, TimeUnit.MILLISECONDS)) {
                result
            } else {
                null
            }
        }

        fun captureScreenContextForDebug(callback: (Map<String, Any?>?) -> Unit): Boolean {
            val service = activeService ?: return false
            service.requestScreenContextCapture(allowDebugCapture = true, callback = callback)
            return true
        }

        fun captureScreenContextForUpload(callback: (Map<String, Any?>?) -> Unit): Boolean {
            val service = activeService ?: return false
            service.requestScreenContextCapture(allowDebugCapture = false, callback = callback)
            return true
        }

        fun capturePhoneControlObservation(): PhoneControlObservation? {
            val service = activeService ?: return null
            val latch = CountDownLatch(1)
            var result: PhoneControlObservation? = null
            service.handler.post {
                service.capturePhoneControlObservationOnHandler {
                    result = it
                    latch.countDown()
                }
            }
            return if (latch.await(PHONE_CONTROL_CAPTURE_TIMEOUT_MS, TimeUnit.MILLISECONDS)) {
                result
            } else {
                null
            }
        }

        fun performTapAtRatio(xRatio: Float, yRatio: Float): Boolean {
            val service = activeService ?: return false
            val latch = CountDownLatch(1)
            var ok = false
            service.handler.post {
                service.performTapOnHandler(xRatio, yRatio) { result ->
                    ok = result
                    latch.countDown()
                }
            }
            return latch.await(GESTURE_WAIT_TIMEOUT_MS, TimeUnit.MILLISECONDS) && ok
        }

        fun performTypeAtRatio(xRatio: Float, yRatio: Float, text: String): Boolean {
            val service = activeService ?: return false
            val latch = CountDownLatch(1)
            var ok = false
            service.handler.post {
                ok = service.performTypeOnHandler(xRatio, yRatio, text)
                latch.countDown()
            }
            return latch.await(SNAPSHOT_WAIT_TIMEOUT_MS, TimeUnit.MILLISECONDS) && ok
        }

        fun performScroll(direction: String): Boolean {
            val service = activeService ?: return false
            val latch = CountDownLatch(1)
            var ok = false
            service.handler.post {
                ok = service.performScrollOnHandler(direction)
                latch.countDown()
            }
            return latch.await(SNAPSHOT_WAIT_TIMEOUT_MS, TimeUnit.MILLISECONDS) && ok
        }

        // 复用被动屏幕采集已有的敏感包名/文案关键词表——两条判断路径共用同一份"什么算敏感"的
        // 定义，不重复维护第二份清单。这是 phone_control 的本地二次校验，后端已经拦过一遍，
        // 这里是防御性的第二道闸，不是"后端说了算"。
        fun isSensitiveObservation(packageName: String, texts: List<String>): Boolean {
            val label = activeService?.appLabel(packageName).orEmpty()
            if (sensitivePackageHints.any(packageName.lowercase()::contains)) return true
            if (sensitiveAppLabelHints.any(label::contains)) return true
            return texts.any { value -> sensitiveTextHints.any(value::contains) }
        }

        fun requestOpenCart(target: String): Boolean {
            pendingPackages = packagesForTarget(target).toSet()
            pendingUntil = SystemClock.uptimeMillis() + CART_REQUEST_WINDOW_MS
            activeService?.scheduleCartSearch()
            return activeService != null
        }

        private fun hasPendingCartRequest(): Boolean {
            if (pendingPackages.isEmpty()) return false
            if (SystemClock.uptimeMillis() <= pendingUntil) return true
            clearPendingCartRequest()
            return false
        }

        private fun clearPendingCartRequest() {
            pendingPackages = emptySet()
            pendingUntil = 0L
        }

        private fun packagesForTarget(target: String): List<String> {
            return when (target) {
                "taobao" -> listOf("com.taobao.taobao")
                else -> listOf("com.sankuai.meituan", "com.meituan.android.waimai")
            }
        }
    }
}
