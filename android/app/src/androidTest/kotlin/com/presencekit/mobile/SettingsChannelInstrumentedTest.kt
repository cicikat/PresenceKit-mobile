package com.presencekit.mobile

import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class SettingsChannelInstrumentedTest {
    @Test
    fun settingsChannel_preserves_method_arguments_and_error_codes() {
        val allowed = invoke("isAllowedBaseUrl", mapOf("value" to "https://fixture.invalid"))
        assertEquals(true, allowed.value)
        assertEquals(null, allowed.errorCode)

        val invalidLanguage = invoke("setAppLanguage", mapOf("value" to "fixture-invalid"))
        assertEquals(null, invalidLanguage.value)
        assertEquals("invalid_language", invalidLanguage.errorCode)
    }

    private fun invoke(method: String, arguments: Map<String, Any?>): ChannelResult {
        var value: Any? = null
        var errorCode: String? = null
        val scenario = ActivityScenario.launch(MainActivity::class.java)
        scenario.onActivity { activity ->
            activity.handleSettingsMethodCallForTesting(
                method,
                arguments,
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
        }
        scenario.close()
        return ChannelResult(value, errorCode)
    }

    private data class ChannelResult(val value: Any?, val errorCode: String?)
}
