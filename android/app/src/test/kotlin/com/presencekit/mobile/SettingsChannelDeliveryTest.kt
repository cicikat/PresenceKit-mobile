package com.presencekit.mobile

import android.content.Context
import android.content.SharedPreferences
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class SettingsChannelDeliveryTest {
    private lateinit var context: Context
    private lateinit var prefs: SharedPreferences

    @Before
    fun setup() {
        context = RuntimeEnvironment.getApplication()
        prefs = context.getSharedPreferences(BackendSecurityPolicy.PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .clear()
            .putString("backendBaseUrl", "http://127.0.0.1:8080")
            .putString("ownerUserId", "owner")
            .commit()
    }

    private fun invoke(method: String, arguments: Map<String, Any?> = emptyMap()): ChannelResult {
        var value: Any? = null
        var errorCode: String? = null
        var handled = false
        handled = MobileDeliveryChannel.dispatch(
            MethodCall(method, arguments),
            prefs,
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    value = result
                }

                override fun error(code: String, message: String?, details: Any?) {
                    errorCode = code
                }

                override fun notImplemented() {
                    errorCode = "not_implemented"
                }
            },
        )
        if (!handled && errorCode == null) {
            errorCode = "not_implemented"
        }
        return ChannelResult(value, errorCode)
    }

    @Test
    fun `consumePendingMobileEnvelopes reads identity envelopes from the store`() {
        val store = MobileDeliveryStateStore.of(prefs)
        store.bindCursorScope("http://127.0.0.1:8080", "owner")
        assertTrue(
            store.acceptIncoming(
                JSONObject()
                    .put("id", "m1")
                    .put("seq", 4)
                    .put("content", "hello")
                    .put("timestamp", 1_780_000_000.0)
                    .put("char_id", "char-a"),
                "http://127.0.0.1:8080",
                "owner",
            ),
        )

        val first = invoke(
            "consumePendingMobileEnvelopes",
            mapOf(
                "origin" to "http://127.0.0.1:8080",
                "owner" to "owner",
                "charId" to "char-a",
            ),
        )
        assertNull(first.errorCode)
        @Suppress("UNCHECKED_CAST")
        val envelopes = first.value as List<Map<String, Any?>>
        assertEquals(1, envelopes.size)
        assertEquals("m1", envelopes.single()["id"])
        assertEquals(true, envelopes.single()["replayable"])

        val second = invoke(
            "consumePendingMobileEnvelopes",
            mapOf(
                "origin" to "http://127.0.0.1:8080",
                "owner" to "owner",
                "charId" to "char-a",
            ),
        )
        @Suppress("UNCHECKED_CAST")
        assertTrue((second.value as List<*>).isEmpty())
    }

    @Test
    fun `setSeenMobileMessageIds merges instead of replacing`() {
        invoke("bindMobileDeliveryScope", mapOf("origin" to "http://127.0.0.1:8080", "owner" to "owner"))
        invoke("setSeenMobileMessageIds", mapOf("ids" to listOf("a", "b")))
        invoke("setSeenMobileMessageIds", mapOf("ids" to listOf("b", "c")))
        val seen = invoke("getSeenMobileMessageIds")
        assertEquals(listOf("a", "b", "c"), seen.value)
    }

    @Test
    fun `stale persist after origin change does not write the new cursor`() {
        invoke("bindMobileDeliveryScope", mapOf("origin" to "http://127.0.0.1:8080", "owner" to "owner"))
        invoke("setLastAckedMobileSeq", mapOf("value" to 4L))
        invoke("bindMobileDeliveryScope", mapOf("origin" to "http://10.0.0.2:8080", "owner" to "owner"))
        invoke(
            "setLastAckedMobileSeq",
            mapOf(
                "value" to 9L,
                "origin" to "http://127.0.0.1:8080",
                "owner" to "owner",
            ),
        )
        assertNull(invoke("getLastAckedMobileSeq").value)
        invoke(
            "setLastAckedMobileSeq",
            mapOf(
                "value" to 11L,
                "origin" to "http://10.0.0.2:8080",
                "owner" to "owner",
            ),
        )
        assertEquals(11L, invoke("getLastAckedMobileSeq").value)
    }

    @Test
    fun `legacy consumePendingMobileContents still dispatches`() {
        val result = invoke("consumePendingMobileContents")
        assertNull(result.errorCode)
        assertTrue(result.value is List<*>)
    }

    private data class ChannelResult(val value: Any?, val errorCode: String?)
}
