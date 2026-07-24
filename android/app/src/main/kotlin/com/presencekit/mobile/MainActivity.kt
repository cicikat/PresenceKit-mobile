package com.presencekit.mobile

import android.Manifest
import android.app.NotificationManager
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.OpenableColumns
import android.provider.Settings
import android.text.TextUtils
import android.util.Log
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val tag = "CompanionMainActivity"
    private val settingsChannel = "presence_mobile/settings"
    private val pickProfileImageRequest = 9101
    private val pickUploadFileRequest = 9102
    private val pickUploadImagesRequest = 9103
    private val pickPdfFileRequest = 9104
    private var pendingImagePickResult: MethodChannel.Result? = null
    private var pendingFilePickResult: MethodChannel.Result? = null
    private var pendingImagesPickResult: MethodChannel.Result? = null
    private var pendingPdfPickResult: MethodChannel.Result? = null
    private val voiceRecorder by lazy { VoiceRecorder(this) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enterFullscreen()
    }

    override fun onResume() {
        super.onResume()
        val prefs = getSharedPreferences(BackendSecurityPolicy.PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putBoolean("mobileAppInForeground", true).apply()
        stopService(Intent(this, MobileNotificationService::class.java))
        MobileNotificationService.cancelScheduledFallback(this)
        prefs.edit().putBoolean("backgroundNotificationServiceRunning", false).apply()
        enterFullscreen()
    }

    override fun onStop() {
        super.onStop()
        val prefs = getSharedPreferences(BackendSecurityPolicy.PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putBoolean("mobileAppInForeground", false).apply()
        val backendBaseUrl = prefs.getString("backendBaseUrl", null)?.trim().orEmpty()
            .ifEmpty { "http://127.0.0.1:8080" }
        if (prefs.getBoolean("backgroundNotificationsEnabled", true) &&
            BackendSecurityPolicy.adminToken(prefs).isNotBlank() &&
            BackendSecurityPolicy.isAllowedBaseUrl(backendBaseUrl, prefs)
        ) {
            startMobileNotificationService()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, settingsChannel)
            .setMethodCallHandler { call, result ->
                val prefs = getSharedPreferences(BackendSecurityPolicy.PREFS_NAME, Context.MODE_PRIVATE)
                when (call.method) {
                    "getAppLanguage" -> {
                        result.success(prefs.getString("appLanguage", null))
                    }
                    "setAppLanguage" -> {
                        val value = call.argument<String>("value").orEmpty()
                        if (value in setOf("system", "zh-CN", "en-US")) {
                            prefs.edit().putString("appLanguage", value).apply()
                            result.success(null)
                        } else {
                            result.error("invalid_language", "Unsupported app language", null)
                        }
                    }
                    "getBackendBaseUrl" -> {
                        result.success(prefs.getString("backendBaseUrl", null))
                    }
                    "setBackendBaseUrl" -> {
                        val value = call.argument<String>("value").orEmpty()
                        if (BackendSecurityPolicy.isAllowedBaseUrl(value, prefs)) {
                            prefs.edit().putString("backendBaseUrl", value).apply()
                            result.success(null)
                        } else {
                            result.error("untrusted_backend", "Backend URL is not trusted", null)
                        }
                    }
                    "getAdminToken" -> {
                        result.success(BackendSecurityPolicy.adminToken(prefs).ifBlank { null })
                    }
                    "setAdminToken" -> {
                        val value = call.argument<String>("value").orEmpty().trim()
                        if (value.isBlank()) {
                            prefs.edit().remove(BackendSecurityPolicy.ADMIN_TOKEN_KEY).apply()
                        } else {
                            prefs.edit().putString(BackendSecurityPolicy.ADMIN_TOKEN_KEY, value).apply()
                        }
                        result.success(null)
                    }
                    "getOwnerUserId" -> {
                        result.success(BackendSecurityPolicy.ownerUserId(prefs).ifBlank { null })
                    }
                    "setOwnerUserId" -> {
                        val value = call.argument<String>("value").orEmpty().trim()
                        if (value.isBlank()) {
                            prefs.edit().remove(BackendSecurityPolicy.OWNER_USER_ID_KEY).apply()
                        } else {
                            prefs.edit().putString(BackendSecurityPolicy.OWNER_USER_ID_KEY, value).apply()
                        }
                        result.success(null)
                    }
                    "getTrustedCleartextOrigins" -> {
                        result.success(BackendSecurityPolicy.trustedCleartextOrigins(prefs).toList())
                    }
                    "addTrustedCleartextOrigin" -> {
                        val value = call.argument<String>("value").orEmpty()
                        result.success(BackendSecurityPolicy.addTrustedCleartextOrigin(prefs, value))
                    }
                    "getScreenContextUploadEnabled" -> {
                        result.success(BackendSecurityPolicy.screenContextUploadEnabled(prefs))
                    }
                    "setScreenContextUploadEnabled" -> {
                        val value = call.argument<Boolean>("value") ?: false
                        prefs.edit()
                            .putBoolean(BackendSecurityPolicy.SCREEN_CONTEXT_UPLOAD_ENABLED_KEY, value)
                            .apply()
                        result.success(null)
                    }
                    "getScreenTextUploadAllowedPackages" -> {
                        result.success(
                            BackendSecurityPolicy.screenTextUploadAllowedPackages(prefs).toList(),
                        )
                    }
                    "setScreenTextUploadAllowedPackages" -> {
                        val values = call.argument<List<String>>("values")
                            .orEmpty()
                            .map(String::trim)
                            .filter(String::isNotBlank)
                            .toSet()
                        prefs.edit()
                            .putStringSet(
                                BackendSecurityPolicy.SCREEN_TEXT_UPLOAD_ALLOWED_PACKAGES_KEY,
                                values,
                            )
                            .apply()
                        result.success(null)
                    }
                    "getScreenTextUploadAppOptions" -> {
                        result.success(screenTextUploadAppOptions())
                    }
                    "getCustomThemePalette" -> {
                        result.success(prefs.getString("customThemePalette", null))
                    }
                    "setCustomThemePalette" -> {
                        val value = call.argument<String>("value").orEmpty()
                        prefs.edit().putString("customThemePalette", value).apply()
                        result.success(null)
                    }
                    "deleteCustomThemePalette" -> {
                        prefs.edit().remove("customThemePalette").apply()
                        result.success(null)
                    }
                    "getProfileDisplayName" -> {
                        result.success(prefs.getString("profileDisplayName", null))
                    }
                    "setProfileDisplayName" -> {
                        val value = call.argument<String>("value").orEmpty().trim()
                        if (value.isBlank()) {
                            prefs.edit().remove("profileDisplayName").apply()
                        } else {
                            prefs.edit().putString("profileDisplayName", value).apply()
                        }
                        result.success(null)
                    }
                    "cacheCharacterDisplayName" -> {
                        // Fully-resolved display name (local override, else backend character
                        // name, else neutral fallback — resolved in Dart's
                        // resolveCharacterDisplayName()). Distinct from the raw
                        // "profileDisplayName" override above; this is what
                        // MobileNotificationService titles background push notifications with.
                        val value = call.argument<String>("value").orEmpty().trim()
                        if (value.isBlank()) {
                            prefs.edit().remove("cachedCharacterDisplayName").apply()
                        } else {
                            prefs.edit().putString("cachedCharacterDisplayName", value).apply()
                        }
                        result.success(null)
                    }
                    "pickProfileImage" -> {
                        pickProfileImage(result)
                    }
                    "pickUploadFile" -> {
                        pickUploadFile(result)
                    }
                    "pickPdfFile" -> {
                        pickPdfFile(result)
                    }
                    "pickUploadImages" -> {
                        pickUploadImages(result)
                    }
                    "loadProfileAvatar" -> {
                        result.success(loadProfileAvatar())
                    }
                    "saveProfileAvatar" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        if (bytes == null) {
                            result.success(false)
                        } else {
                            result.success(saveProfileAvatar(bytes))
                        }
                    }
                    "deleteProfileAvatar" -> {
                        avatarFile().delete()
                        result.success(null)
                    }
                    "getBackgroundNotificationsEnabled" -> {
                        result.success(prefs.getBoolean("backgroundNotificationsEnabled", true))
                    }
                    "setBackgroundNotificationsEnabled" -> {
                        val value = call.argument<Boolean>("value") ?: true
                        prefs.edit().putBoolean("backgroundNotificationsEnabled", value).apply()
                        if (!value) {
                            stopService(Intent(this, MobileNotificationService::class.java))
                            MobileNotificationService.cancelScheduledFallback(this)
                            prefs.edit().putBoolean("backgroundNotificationServiceRunning", false).apply()
                        }
                        result.success(null)
                    }
                    "startBackgroundNotifications" -> {
                        if (!prefs.getBoolean("mobileAppInForeground", true) &&
                            shouldRunRelayService(prefs)
                        ) {
                            startMobileNotificationService()
                        }
                        result.success(null)
                    }
                    "debugBackgroundDelivery" -> {
                        val content = call.argument<String>("content").orEmpty()
                        val behavior = call.argument<String>("behavior").orEmpty()
                        debugBackgroundDelivery(content, behavior)
                        result.success(true)
                    }
                    "stopBackgroundNotifications" -> {
                        stopService(Intent(this, MobileNotificationService::class.java))
                        MobileNotificationService.cancelScheduledFallback(this)
                        result.success(null)
                    }
                    "areNotificationsEnabled" -> {
                        result.success(areNotificationsEnabled())
                    }
                    "requestNotificationPermission" -> {
                        requestNotificationPermission()
                        openNotificationSettings()
                        result.success(null)
                    }
                    "isBackgroundNotificationServiceRunning" -> {
                        result.success(MobileNotificationService.isServiceRunning)
                    }
                    "getBackgroundNotificationServiceStartError" -> {
                        result.success(prefs.getString("backgroundNotificationServiceStartError", null))
                    }
                    "getBackgroundPollStatus" -> {
                        result.success(
                            mapOf(
                                "lastBackgroundPollAt" to prefs.getLong("lastBackgroundPollAt", 0L),
                                "lastBackgroundError" to
                                    prefs.getString("lastBackgroundError", null),
                            ),
                        )
                    }
                    "getRelayConnectionStatus" -> {
                        result.success(
                            mapOf(
                                "connectionStatus" to
                                    prefs.getString("relayConnectionStatus", "unconfigured"),
                                "lastDeliveredAt" to prefs.getLong("lastRelayDeliveredAt", 0L),
                                "lastHeartbeatAt" to prefs.getLong("lastRelayHeartbeatAt", 0L),
                                "lastError" to prefs.getString("lastRelayError", null),
                            ),
                        )
                    }
                    "getLastOverlayError" -> {
                        result.success(
                            mapOf(
                                "lastOverlayError" to prefs.getString("lastOverlayError", null),
                                "lastOverlayErrorAt" to prefs.getLong("lastOverlayErrorAt", 0L),
                            ),
                        )
                    }
                    "getNotificationGateStatus" -> {
                        result.success(
                            mapOf(
                                "suppressedCount" to
                                    prefs.getInt("suppressedMessageNotifications", 0),
                                "lastSuppressReason" to
                                    prefs.getString("lastNotificationSuppressReason", null),
                                "testModeEnabled" to
                                    prefs.getBoolean("notificationTestMode", false),
                            ),
                        )
                    }
                    "setNotificationTestMode" -> {
                        val value = call.argument<Boolean>("value") ?: false
                        prefs.edit().putBoolean("notificationTestMode", value).apply()
                        result.success(null)
                    }
                    "isIgnoringBatteryOptimizations" -> {
                        result.success(isIgnoringBatteryOptimizations())
                    }
                    "requestIgnoreBatteryOptimizations" -> {
                        requestIgnoreBatteryOptimizations()
                        result.success(null)
                    }
                    "canDrawOverlays" -> {
                        result.success(canDrawOverlays())
                    }
                    "requestOverlayPermission" -> {
                        requestOverlayPermission()
                        result.success(null)
                    }
                    "showFloatingBubble" -> {
                        if (!canDrawOverlays()) {
                            requestOverlayPermission()
                            result.success(false)
                        } else {
                            startService(Intent(this, FloatingBubbleService::class.java))
                            result.success(true)
                        }
                    }
                    "showOrderBubble" -> {
                        if (!canDrawOverlays()) {
                            requestOverlayPermission()
                            result.success(false)
                        } else {
                            val target = call.argument<String>("target").orEmpty().ifBlank { "meituan" }
                            startService(
                                Intent(this, FloatingBubbleService::class.java).apply {
                                    putExtra("mode", "order")
                                    putExtra("target", target)
                                },
                            )
                            result.success(true)
                        }
                    }
                    "hideFloatingBubble" -> {
                        stopService(Intent(this, FloatingBubbleService::class.java))
                        result.success(null)
                    }
                    "isDeviceAdminActive" -> {
                        result.success(isDeviceAdminActive())
                    }
                    "requestDeviceAdmin" -> {
                        requestDeviceAdmin()
                        result.success(null)
                    }
                    "lockScreen" -> {
                        if (isDeviceAdminActive()) {
                            val manager = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
                            manager.lockNow()
                            result.success(true)
                        } else {
                            requestDeviceAdmin()
                            result.success(false)
                        }
                    }
                    "isAccessibilityServiceEnabled" -> {
                        result.success(isAccessibilityServiceEnabled())
                    }
                    "captureScreenContext" -> {
                        val scheduled = YexuanAccessibilityService.captureScreenContextForDebug {
                            snapshot -> result.success(snapshot)
                        }
                        if (!scheduled) {
                            result.success(null)
                        }
                    }
                    "captureScreenContextForUpload" -> {
                        val scheduled = YexuanAccessibilityService.captureScreenContextForUpload {
                            snapshot -> result.success(snapshot)
                        }
                        if (!scheduled) {
                            result.success(null)
                        }
                    }
                    "requestAccessibilityPermission" -> {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(null)
                    }
                    "openShoppingApp" -> {
                        val target = call.argument<String>("target").orEmpty()
                        result.success(openShoppingApp(target))
                    }
                    "getSeenMobileMessageIds" -> {
                        val raw = prefs.getString("seenMobileMessageIds", null)
                        val ids = runCatching {
                            val array = org.json.JSONArray(raw ?: "[]")
                            (0 until array.length()).map { array.getString(it) }
                        }.getOrElse { emptyList() }
                        result.success(ids)
                    }
                    "setSeenMobileMessageIds" -> {
                        val ids = call.argument<List<String>>("ids").orEmpty().takeLast(200)
                        val saved = prefs.edit()
                            .putString("seenMobileMessageIds", org.json.JSONArray(ids).toString())
                            .commit()
                        if (saved) {
                            result.success(null)
                        } else {
                            result.error(
                                "prefs_write_failed",
                                "Could not persist seen mobile message ids",
                                null,
                            )
                        }
                    }
                    "getLastAckedMobileSeq" -> {
                        result.success(
                            if (prefs.contains("lastAckedSeq")) {
                                prefs.getLong("lastAckedSeq", 0L)
                            } else {
                                null
                            },
                        )
                    }
                    "setLastAckedMobileSeq" -> {
                        val value = call.argument<Number>("value")?.toLong()
                        if (value == null) {
                            result.error("invalid_ack_seq", "Missing last acked mobile seq", null)
                        } else {
                            val current = prefs.getLong("lastAckedSeq", Long.MIN_VALUE)
                            val saved =
                                value <= current ||
                                    prefs.edit().putLong("lastAckedSeq", value).commit()
                            if (saved) {
                                result.success(null)
                            } else {
                                result.error(
                                    "prefs_write_failed",
                                    "Could not persist last acked mobile seq",
                                    null,
                                )
                            }
                        }
                    }
                    "isAllowedBaseUrl" -> {
                        val value = call.argument<String>("value").orEmpty()
                        result.success(BackendSecurityPolicy.isAllowedBaseUrl(value, prefs))
                    }
                    "normalizeOrigin" -> {
                        val value = call.argument<String>("value").orEmpty()
                        result.success(BackendSecurityPolicy.normalizeOrigin(value))
                    }
                    "isConfirmablePrivateCleartextOrigin" -> {
                        val value = call.argument<String>("value").orEmpty()
                        result.success(BackendSecurityPolicy.isConfirmablePrivateCleartextOrigin(value))
                    }
                    "getRelayBaseUrl" -> {
                        result.success(BackendSecurityPolicy.relayBaseUrl(prefs))
                    }
                    "setRelayBaseUrl" -> {
                        val value = call.argument<String>("value").orEmpty()
                        if (value.isBlank()) {
                            prefs.edit().remove(BackendSecurityPolicy.RELAY_BASE_URL_KEY).apply()
                            result.success(null)
                        } else if (BackendSecurityPolicy.isAllowedRelayUrl(value, prefs)) {
                            prefs.edit().putString(BackendSecurityPolicy.RELAY_BASE_URL_KEY, value).apply()
                            result.success(null)
                        } else {
                            result.error("untrusted_relay", "Relay URL is not trusted", null)
                        }
                    }
                    "getRelayToken" -> {
                        result.success(BackendSecurityPolicy.relayToken(prefs))
                    }
                    "setRelayToken" -> {
                        val value = call.argument<String>("value").orEmpty().trim()
                        if (value.isBlank()) {
                            prefs.edit().remove(BackendSecurityPolicy.RELAY_TOKEN_KEY).apply()
                        } else {
                            prefs.edit().putString(BackendSecurityPolicy.RELAY_TOKEN_KEY, value).apply()
                        }
                        result.success(null)
                    }
                    "getRelayTopic" -> {
                        result.success(BackendSecurityPolicy.relayTopic(prefs))
                    }
                    "setRelayTopic" -> {
                        val value = call.argument<String>("value").orEmpty().trim()
                        if (value.isBlank()) {
                            prefs.edit().remove(BackendSecurityPolicy.RELAY_TOPIC_KEY).apply()
                        } else {
                            prefs.edit().putString(BackendSecurityPolicy.RELAY_TOPIC_KEY, value).apply()
                        }
                        result.success(null)
                    }
                    // ── W9：语音输入 ──────────────────────────────────────────────
                    "hasRecordAudioPermission" -> {
                        result.success(
                            checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
                                PackageManager.PERMISSION_GRANTED,
                        )
                    }
                    "requestRecordAudioPermission" -> {
                        requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), 2402)
                        result.success(null)
                    }
                    "startVoiceRecording" -> {
                        result.success(voiceRecorder.start())
                    }
                    "stopVoiceRecording" -> {
                        result.success(voiceRecorder.stop())
                    }
                    "cancelVoiceRecording" -> {
                        voiceRecorder.cancel()
                        result.success(null)
                    }
                    // ── W9：传感器上报 ────────────────────────────────────────────
                    "readBatteryPercent" -> {
                        result.success(SensorAccess.readBatteryPercent(this))
                    }
                    "hasActivityRecognitionPermission" -> {
                        val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) ==
                                PackageManager.PERMISSION_GRANTED
                        } else {
                            true
                        }
                        result.success(granted)
                    }
                    "requestActivityRecognitionPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            requestPermissions(
                                arrayOf(Manifest.permission.ACTIVITY_RECOGNITION),
                                2403,
                            )
                        }
                        result.success(null)
                    }
                    "readTodaySteps" -> {
                        SensorAccess.readTodaySteps(this, prefs, 2500L) { steps ->
                            result.success(steps)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == pickProfileImageRequest) {
            val callback = pendingImagePickResult
            pendingImagePickResult = null
            if (callback == null) {
                super.onActivityResult(requestCode, resultCode, data)
                return
            }
            if (resultCode != RESULT_OK || data?.data == null) {
                callback.success(null)
                return
            }
            val uri = data.data ?: run {
                callback.success(null)
                return
            }
            val bytes = runCatching {
                contentResolver.openInputStream(uri)?.use { it.readBytes() }
            }.getOrNull()
            callback.success(bytes)
            return
        }
        if (requestCode == pickUploadFileRequest) {
            val callback = pendingFilePickResult
            pendingFilePickResult = null
            if (callback == null) {
                super.onActivityResult(requestCode, resultCode, data)
                return
            }
            if (resultCode != RESULT_OK || data?.data == null) {
                callback.success(null)
                return
            }
            val uri = data.data ?: run {
                callback.success(null)
                return
            }
            val bytes = runCatching {
                contentResolver.openInputStream(uri)?.use { it.readBytes() }
            }.getOrNull()
            if (bytes == null) {
                callback.success(null)
                return
            }
            callback.success(
                mapOf(
                    "name" to displayNameFor(uri),
                    "bytes" to bytes,
                ),
            )
            return
        }
        if (requestCode == pickPdfFileRequest) {
            val callback = pendingPdfPickResult
            pendingPdfPickResult = null
            if (callback == null) {
                super.onActivityResult(requestCode, resultCode, data)
                return
            }
            if (resultCode != RESULT_OK || data?.data == null) {
                callback.success(null)
                return
            }
            val uri = data.data ?: run {
                callback.success(null)
                return
            }
            val bytes = runCatching {
                contentResolver.openInputStream(uri)?.use { it.readBytes() }
            }.getOrNull()
            if (bytes == null) {
                callback.success(null)
                return
            }
            callback.success(
                mapOf(
                    "name" to displayNameFor(uri),
                    "bytes" to bytes,
                ),
            )
            return
        }
        if (requestCode == pickUploadImagesRequest) {
            val callback = pendingImagesPickResult
            pendingImagesPickResult = null
            if (callback == null) {
                super.onActivityResult(requestCode, resultCode, data)
                return
            }
            if (resultCode != RESULT_OK || data == null) {
                callback.success(null)
                return
            }
            val uris = mutableListOf<Uri>()
            data.clipData?.let { clip ->
                for (index in 0 until clip.itemCount) {
                    clip.getItemAt(index).uri?.let { uris.add(it) }
                }
            }
            data.data?.let { uri ->
                if (!uris.contains(uri)) uris.add(uri)
            }
            val files = uris.mapNotNull { uri ->
                val bytes = runCatching {
                    contentResolver.openInputStream(uri)?.use { it.readBytes() }
                }.getOrNull() ?: return@mapNotNull null
                mapOf(
                    "name" to displayNameFor(uri),
                    "bytes" to bytes,
                )
            }
            callback.success(files.ifEmpty { null })
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            enterFullscreen()
        }
    }

    private fun enterFullscreen() {
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT
        window.setFlags(
            WindowManager.LayoutParams.FLAG_FULLSCREEN,
            WindowManager.LayoutParams.FLAG_FULLSCREEN,
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val attrs = window.attributes
            attrs.layoutInDisplayCutoutMode =
                WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            window.attributes = attrs
        }

        @Suppress("DEPRECATION")
        window.decorView.systemUiVisibility =
            View.SYSTEM_UI_FLAG_FULLSCREEN or
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
                View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.insetsController?.let { controller ->
                controller.hide(WindowInsets.Type.statusBars())
                controller.systemBarsBehavior =
                    WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
        }
    }

    private fun startMobileNotificationService() {
        val intent = Intent(this, MobileNotificationService::class.java)
        val prefs = getSharedPreferences(BackendSecurityPolicy.PREFS_NAME, Context.MODE_PRIVATE)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            prefs.edit().remove("backgroundNotificationServiceStartError").apply()
        } catch (error: Exception) {
            val detail = error.message?.trim().orEmpty()
            val reason = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                error.javaClass.simpleName == "ForegroundServiceStartNotAllowedException"
            ) {
                "\u7cfb\u7edf\u4e0d\u5141\u8bb8\u5e94\u7528\u4ece\u540e\u53f0\u542f\u52a8\u524d\u53f0\u670d\u52a1"
            } else {
                "\u542f\u52a8\u540e\u53f0\u901a\u77e5\u670d\u52a1\u5931\u8d25"
            }
            val readableError = if (detail.isBlank()) {
                "$reason (${error.javaClass.simpleName})"
            } else {
                "$reason: $detail"
            }
            prefs.edit()
                .putBoolean("backgroundNotificationServiceRunning", false)
                .putString("backgroundNotificationServiceStartError", readableError)
                .apply()
            Log.e(tag, readableError, error)
        }
    }

    private fun shouldRunRelayService(prefs: android.content.SharedPreferences): Boolean {
        val relayBaseUrl = BackendSecurityPolicy.relayBaseUrl(prefs) ?: return false
        return prefs.getBoolean("backgroundNotificationsEnabled", true) &&
            BackendSecurityPolicy.adminToken(prefs).isNotBlank() &&
            BackendSecurityPolicy.relayTopic(prefs) != null &&
            BackendSecurityPolicy.isAllowedRelayUrl(relayBaseUrl, prefs)
    }

    private fun debugBackgroundDelivery(content: String, behavior: String) {
        val intent = Intent(this, MobileNotificationService::class.java).apply {
            putExtra("debugDeliveryContent", content.ifBlank { "\u6211\u5728\u8fd9\u513f\u3002" })
            if (behavior.isNotBlank()) {
                putExtra("debugDeliveryBehavior", behavior)
            }
        }
        startService(intent)
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 2401)
        }
    }

    private fun areNotificationsEnabled(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            return false
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val manager = getSystemService(NotificationManager::class.java)
            return manager.areNotificationsEnabled()
        }
        return true
    }

    private fun openNotificationSettings() {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            }
        } else {
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
            }
        }
        runCatching { startActivity(intent) }
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val manager = getSystemService(PowerManager::class.java)
        return manager.isIgnoringBatteryOptimizations(packageName)
    }

    private fun requestIgnoreBatteryOptimizations() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            isIgnoringBatteryOptimizations()
        ) {
            return
        }
        val requestIntent = Intent(
            Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
            Uri.parse("package:$packageName"),
        )
        runCatching {
            startActivity(requestIntent)
        }.onFailure { error ->
            Log.w(tag, "direct battery optimization exemption request unavailable", error)
            runCatching {
                startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
            }.onFailure { fallbackError ->
                Log.e(tag, "battery optimization settings unavailable", fallbackError)
            }
        }
    }

    private fun pickProfileImage(result: MethodChannel.Result) {
        if (pendingImagePickResult != null) {
            result.success(null)
            return
        }
        pendingImagePickResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "image/*"
        }
        runCatching {
            startActivityForResult(intent, pickProfileImageRequest)
        }.onFailure {
            pendingImagePickResult = null
            result.success(null)
        }
    }

    private fun pickUploadFile(result: MethodChannel.Result) {
        if (pendingFilePickResult != null) {
            result.success(null)
            return
        }
        pendingFilePickResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf(
                    "text/plain",
                    "text/markdown",
                    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                ),
            )
        }
        runCatching {
            startActivityForResult(intent, pickUploadFileRequest)
        }.onFailure {
            pendingFilePickResult = null
            result.success(null)
        }
    }

    // W7：活动系统 · 阅读 — 从书库挑一本 PDF 上传。
    private fun pickPdfFile(result: MethodChannel.Result) {
        if (pendingPdfPickResult != null) {
            result.success(null)
            return
        }
        pendingPdfPickResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/pdf"
        }
        runCatching {
            startActivityForResult(intent, pickPdfFileRequest)
        }.onFailure {
            pendingPdfPickResult = null
            result.success(null)
        }
    }

    private fun pickUploadImages(result: MethodChannel.Result) {
        if (pendingImagesPickResult != null) {
            result.success(null)
            return
        }
        pendingImagesPickResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "image/*"
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
        }
        runCatching {
            startActivityForResult(intent, pickUploadImagesRequest)
        }.onFailure {
            pendingImagesPickResult = null
            result.success(null)
        }
    }

    private fun displayNameFor(uri: Uri): String {
        contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index >= 0 && cursor.moveToFirst()) {
                val value = cursor.getString(index)
                if (!value.isNullOrBlank()) return value
            }
        }
        return uri.lastPathSegment?.substringAfterLast('/')?.ifBlank { null } ?: "file"
    }

    private fun avatarFile(): File {
        return File(filesDir, "profile_avatar.png")
    }

    private fun loadProfileAvatar(): ByteArray? {
        val file = avatarFile()
        return if (file.exists()) file.readBytes() else null
    }

    private fun saveProfileAvatar(bytes: ByteArray): Boolean {
        return runCatching {
            avatarFile().writeBytes(bytes)
            true
        }.getOrDefault(false)
    }

    private fun canDrawOverlays(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(this)
    }

    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(this)) return
        startActivity(
            Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName"),
            ),
        )
    }

    private fun adminComponent(): ComponentName {
        return ComponentName(this, YexuanDeviceAdminReceiver::class.java)
    }

    private fun isDeviceAdminActive(): Boolean {
        val manager = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        return manager.isAdminActive(adminComponent())
    }

    private fun requestDeviceAdmin() {
        val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
            putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponent())
            putExtra(
                DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                "\u53ea\u6709\u5728\u4f60\u786e\u8ba4\u540e\uff0c\u624d\u4f1a\u8c03\u7528\u7cfb\u7edf\u9501\u5c4f\u3002",
            )
        }
        startActivity(intent)
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val expected = ComponentName(this, YexuanAccessibilityService::class.java).flattenToString()
        val enabled = Settings.Secure.getInt(
            contentResolver,
            Settings.Secure.ACCESSIBILITY_ENABLED,
            0,
        )
        if (enabled != 1) return false

        val services = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false
        val splitter = TextUtils.SimpleStringSplitter(':')
        splitter.setString(services)
        for (service in splitter) {
            if (service.equals(expected, ignoreCase = true)) {
                return true
            }
        }
        return false
    }

    private fun screenTextUploadAppOptions(): List<Map<String, String>> {
        val launcherIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return packageManager.queryIntentActivities(launcherIntent, PackageManager.MATCH_ALL)
            .map { resolveInfo ->
                val packageName = resolveInfo.activityInfo.packageName
                mapOf(
                    "packageName" to packageName,
                    "appLabel" to resolveInfo.loadLabel(packageManager).toString().ifBlank {
                        packageName
                    },
                )
            }
            .distinctBy { it["packageName"] }
            .sortedBy { it["appLabel"]?.lowercase() }
    }

    private fun openShoppingApp(target: String): Boolean {
        val packages = when (target) {
            "meituan" -> listOf("com.sankuai.meituan", "com.meituan.android.waimai")
            "taobao" -> listOf("com.taobao.taobao")
            else -> emptyList()
        }
        for (packageName in packages) {
            val intent = packageManager.getLaunchIntentForPackage(packageName)
            if (intent != null) {
                YexuanAccessibilityService.requestOpenCart(target)
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                return true
            }
        }
        return false
    }
}
