package com.presencekit.mobile

import android.accessibilityservice.AccessibilityService
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

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
            val snapshot = captureScreenContextOnHandler(allowDebugCapture)
            callback(
                if (allowDebugCapture) snapshot else snapshot?.let(::snapshotForUpload),
            )
        }
    }

    private fun captureScreenContextOnHandler(allowDebugCapture: Boolean): Map<String, Any?>? {
        val now = SystemClock.uptimeMillis()
        val root = rootInActiveWindow
        val packageName = root?.packageName?.toString()
            ?: dirtyPackageName
        val appLabel = appLabel(packageName)
        val textUploadAllowed = screenTextUploadAllowed(packageName)
        val cached = lastSnapshot
        if (cached != null &&
            cached["packageName"] == packageName &&
            (!allowDebugCapture || cached["textUploadAllowed"] == true) &&
            (!snapshotDirty || now - lastSnapshotAt < SNAPSHOT_MIN_INTERVAL_MS)
        ) {
            return cached
        }

        if (!allowDebugCapture && !textUploadAllowed) {
            return storeSnapshot(
                metadataOnlySnapshot(packageName, appLabel, textUploadAllowed = false),
                now,
            )
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
                "textUploadAllowed" to textUploadAllowed,
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

    private fun screenTextUploadAllowed(packageName: String): Boolean {
        val prefs = getSharedPreferences(BackendSecurityPolicy.PREFS_NAME, MODE_PRIVATE)
        return BackendSecurityPolicy.screenTextUploadAllowed(prefs, packageName)
    }

    private fun snapshotForUpload(snapshot: Map<String, Any?>): Map<String, Any?> {
        val packageName = snapshot["packageName"]?.toString().orEmpty()
        if (snapshot["isBlocked"] == true || screenTextUploadAllowed(packageName)) {
            return snapshot
        }
        return metadataOnlySnapshot(
            packageName,
            snapshot["appLabel"]?.toString().orEmpty(),
            textUploadAllowed = false,
            capturedAt = snapshot["capturedAt"],
        )
    }

    private fun metadataOnlySnapshot(
        packageName: String,
        appLabel: String,
        textUploadAllowed: Boolean,
        capturedAt: Any? = System.currentTimeMillis() / 1000.0,
    ): Map<String, Any?> {
        return mapOf(
            "isBlocked" to false,
            "blockedReason" to "",
            "textUploadAllowed" to textUploadAllowed,
            "packageName" to packageName,
            "appLabel" to appLabel,
            "className" to "",
            "windowTitle" to "",
            "visibleText" to emptyList<String>(),
            "clickableText" to emptyList<String>(),
            "capturedAt" to capturedAt,
        )
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

    companion object {
        private const val CART_TEXT = "\u8d2d\u7269\u8f66"
        private const val CART_REQUEST_WINDOW_MS = 16_000L
        private const val SNAPSHOT_MIN_INTERVAL_MS = 5_000L
        private const val SNAPSHOT_WAIT_TIMEOUT_MS = 3_000L
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
