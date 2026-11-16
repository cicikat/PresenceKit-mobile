package com.presencekit.mobile

import android.content.Context
import com.presencekit.mobile.finance.*
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

/** Opt-in live contract source set. Requires the disposable localhost fixture service, never production. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class FinanceBackendContractTest {
    private fun jsonValue(value: Any?): Any? = when(value) {
        is JSONObject -> value.keys().asSequence().associateWith { jsonValue(value.get(it)) }
        is org.json.JSONArray -> (0 until value.length()).map { jsonValue(value.get(it)) }
        JSONObject.NULL -> null
        else -> value
    }
    @Test fun parsedNoticeReachesRealBackendOnceAndCorrectionKeepsTransaction() {
        val context: Context = RuntimeEnvironment.getApplication()
        val origin = "http://127.0.0.1:18730"
        FinanceAccess.prefs(context).edit().clear().putString("backendBaseUrl", origin).putString("ownerUserId", "fixture-owner").commit()
        context.deleteDatabase("finance_v1.db")
        val realm = FinanceAccess.realm(origin, "fixture-owner")
        val fixture = JSONObject(javaClass.getResourceAsStream("/finance-v1.json")!!.bufferedReader().use { it.readText() })
        val notice = fixture.getJSONObject("notification")
        val parsed = PaymentParser.parse(notice.getString("package"), notice.getString("title"), notice.getString("text"))!!
        val template = fixture.getJSONObject("operation").getJSONObject("record")
        for (key in listOf("occurred_at", "observed_at", "timezone_offset_minutes")) parsed.put(key, template.get(key))
        // Exercise real HTTP and SQLite persistence, with synthetic device identity and explicit collection grant.
        android.provider.Settings.Secure.putString(context.contentResolver, "enabled_notification_listeners", android.content.ComponentName(context, PaymentNotificationListenerService::class.java).flattenToString())
        FinanceAccess.setEnabled(context, realm, true)
        FinanceStore(context).use { store ->
            val id = store.capture(realm, PaymentParser.hash(java.util.UUID.randomUUID().toString()), parsed)
            val sync = FinanceSync(context, store, tokenProvider = { "emt_fixture_finance_mobile_330" })
            assertEquals("ready", sync.run(origin, "fixture-owner", true).getString("status"))
            assertNull(store.next(realm))
            val candidate = sync.request(origin, "fixture-owner", "/finance/candidates/$id").getJSONObject("record")
            assertEquals(1600, candidate.getInt("amount_minor"))
            assertEquals("candidate", candidate.getString("status"))
            store.edit(realm, id, JSONObject().put("status", "confirmed"))
            val op = store.next(realm)!!
            // Simulate lost HTTP receipt after server commit, then use the original operation again.
            val first = sync.request(origin, "fixture-owner", "/finance/candidates/sync", op)
            assertEquals(jsonValue(first), jsonValue(sync.request(origin, "fixture-owner", "/finance/candidates/sync", op)))
            assertEquals("ready", sync.run(origin, "fixture-owner", true).getString("status"))
            val transaction = first.getJSONObject("record").getString("linked_transaction_id")
            store.edit(realm, id, JSONObject().put("amount_minor", 1700))
            assertEquals("ready", sync.run(origin, "fixture-owner", true).getString("status"))
            val detail = sync.request(origin, "fixture-owner", "/finance/candidates/$id")
            assertEquals(transaction, detail.getJSONObject("record").getString("linked_transaction_id"))
            assertEquals(1700, detail.getJSONObject("record").getInt("amount_minor"))
            assertEquals(3, detail.getJSONArray("history").length())
            java.io.File("../../build/finance-native-live-receipt.json").apply { parentFile!!.mkdirs(); writeText(detail.toString()) }
        }
    }
}
