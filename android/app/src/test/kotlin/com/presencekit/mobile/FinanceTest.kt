package com.presencekit.mobile

import android.content.Context
import android.provider.Settings
import com.presencekit.mobile.finance.*
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

/** Public parser/store/sync entries: regression protection for money, privacy and durable receipts. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class FinanceTest {
    private lateinit var context: Context
    private val origin = "http://127.0.0.1:8080"
    private val realm = "$origin\nowner"
    @Before fun setup() {
        context = RuntimeEnvironment.getApplication()
        FinanceAccess.prefs(context).edit().clear().putString("backendBaseUrl", origin).putString("ownerUserId", "owner").commit()
        context.deleteDatabase("finance_v1.db")
    }
    private fun record(pkg: String = "com.tencent.mm", at: Long = 1000) = PaymentParser.parse(pkg, if (pkg == "com.tencent.mm") "微信支付" else "支付凭证", "支付成功16.00元 商户：测试店")!!.put("occurred_at", at).put("observed_at", at).put("timezone_offset_minutes", 480)
    private fun ack(op: JSONObject) = JSONObject().put("operation_id", op.getString("operation_id")).put("candidate_id", op.getString("candidate_id")).put("revision", op.getInt("base_revision") + 1).put("record", JSONObject(op.getJSONObject("record").toString()).put("linked_transaction_id", "transaction-a").put("revision", op.getInt("base_revision") + 1))
    @Test fun parserMoneyAndRefusals() {
        assertEquals(1600, record().getInt("amount_minor"))
        assertNull(PaymentParser.parse("com.eg.android.AlipayGphone", "支付宝", "支付成功20元 领券优惠"))
        assertNull(PaymentParser.parse("com.tencent.mm", "聊天好友", "已支付¥16.00"))
        assertNull(PaymentParser.parse("other.app", "微信支付", "支付成功16元"))
        assertNull(PaymentParser.parse("com.tencent.mm", "微信支付", "验证码16元"))
        for ((text, expected) in listOf("退款成功16元" to "refund", "转账成功16元" to "transfer", "还款成功16元" to "transfer", "红包已领取16元" to "unknown")) assertEquals(expected, PaymentParser.parse("com.tencent.mm", "微信支付", text)!!.getString("direction"))
        assertTrue(PaymentParser.parse("com.tencent.mm", "微信支付", "支付成功16...元")!!.isNull("amount_minor"))
        assertTrue(PaymentParser.parse("com.tencent.mm", "微信支付", "支付成功16.123元")!!.isNull("amount_minor"))
    }
    @Test fun sharedProtocolFixtureIsParsedWithoutFloatingPoint() {
        val fixture = JSONObject(javaClass.getResourceAsStream("/finance-v1.json")!!.bufferedReader().use { it.readText() })
        val input = fixture.getJSONObject("notification")
        val parsed = PaymentParser.parse(input.getString("package"), input.getString("title"), input.getString("text"))!!
        val expected = fixture.getJSONObject("operation").getJSONObject("record")
        assertEquals(expected.getLong("amount_minor"), parsed.getLong("amount_minor"))
        for (key in listOf("direction", "currency", "merchant")) assertEquals(expected.get(key), parsed.get(key))
    }
    @Test fun listenerEntryDeduplicatesUpdatesAndDropsSummaryOldAndRevoked() {
        Settings.Secure.putString(context.contentResolver, "enabled_notification_listeners", android.content.ComponentName(context, PaymentNotificationListenerService::class.java).flattenToString())
        FinanceAccess.setEnabled(context, realm, true)
        val at = FinanceAccess.since(context, realm) + 10
        val service = org.robolectric.Robolectric.buildService(PaymentNotificationListenerService::class.java).create().get()
        fun event(id: Int, time: Long = at, summary: Boolean = false): android.service.notification.StatusBarNotification {
            val notification = android.app.Notification.Builder(context, "fixture").setContentTitle("微信支付").setContentText("支付成功16.00元").setWhen(time).build()
            if (summary) notification.flags = notification.flags or android.app.Notification.FLAG_GROUP_SUMMARY
            return android.service.notification.StatusBarNotification("com.tencent.mm", "com.tencent.mm", id, "fixture", 1000, 1, 0, notification, android.os.Process.myUserHandle(), time)
        }
        service.onNotificationPosted(event(1)); service.onNotificationPosted(event(1))
        service.onNotificationPosted(event(2, summary = true)); service.onNotificationPosted(event(3, time = at - 60000))
        FinanceBridge.executor.submit {}.get()
        FinanceStore(context).use { assertEquals(1, it.snapshot(realm).getJSONArray("records").length()) }
        Settings.Secure.putString(context.contentResolver, "enabled_notification_listeners", "")
        service.onNotificationPosted(event(4)); FinanceBridge.executor.submit {}.get()
        FinanceStore(context).use { assertEquals(1, it.snapshot(realm).getJSONArray("records").length()) }
        service.onDestroy()
    }
    @Test fun eventDedupSurvivesReopenAndEqualPurchasesStaySeparate() {
        val id = FinanceStore(context).use { store ->
            val first = store.capture(realm, "event-one", record())
            assertEquals(first, store.capture(realm, "event-one", record()))
            first
        }
        FinanceStore(context).use { store ->
            assertEquals(id, store.capture(realm, "event-one", record()))
            store.capture(realm, "event-two", record(at = 121000))
            store.capture(realm, "event-bank", record("com.icbc", 122000))
            val rows = store.snapshot(realm).getJSONArray("records")
            assertEquals(3, rows.length())
            assertTrue(rows.getJSONObject(0).getJSONArray("reason_codes").toString().contains("possible_duplicate"))
            assertEquals(0, store.snapshot("$origin\nother").getJSONArray("records").length())
            assertEquals(0, store.snapshot("https://other.example\nowner").getJSONArray("records").length())
        }
    }
    @Test fun lostReceiptAndOfflineEditsKeepStableOperationAndTransaction() {
        val id = FinanceStore(context).use { it.capture(realm, "event", record()) }
        val initial = FinanceStore(context).use { it.next(realm)!! }
        FinanceStore(context).use { store ->
            store.edit(realm, id, JSONObject().put("status", "confirmed").put("amount_minor", 1700))
            assertEquals(initial.toString(), store.next(realm).toString())
            store.acknowledge(realm, initial, ack(initial))
            val correction = store.next(realm)!!
            assertEquals(1, correction.getInt("base_revision"))
            assertEquals("transaction-a", correction.getJSONObject("record").getString("linked_transaction_id"))
            store.acknowledge(realm, correction, ack(correction))
            assertNull(store.next(realm))
            assertEquals("synced", store.snapshot(realm).getJSONArray("records").getJSONObject(0).getString("sync_status"))
        }
    }
    @Test fun permissionDefaultOffAndRevocationStopsRequests() {
        assertFalse(FinanceAccess.enabled(context, realm))
        assertFalse(FinanceAccess.permission(context))
        assertThrows(IllegalArgumentException::class.java) { FinanceAccess.setEnabled(context, realm, true) }
        Settings.Secure.putString(context.contentResolver, "enabled_notification_listeners", android.content.ComponentName(context, PaymentNotificationListenerService::class.java).flattenToString())
        FinanceAccess.setEnabled(context, realm, true)
        Settings.Secure.putString(context.contentResolver, "enabled_notification_listeners", "")
        FinanceStore(context).use { store ->
            store.capture(realm, "event", record())
            var calls = 0
            val sync = FinanceSync(context, store) { _, _ -> calls++; JSONObject() }
            assertEquals("permission_required", sync.run(origin, "owner", true).getString("status"))
            assertEquals(0, calls)
            assertNotNull(store.next(realm))
        }
    }
    @Test fun timeoutRetriesSameOperationAndWrongAckCannotClearQueue() {
        FinanceStore(context).use { store ->
            val r = record().put("source_app", "manual")
            store.capture(realm, "event", r)
            val before = store.next(realm)!!.getString("operation_id")
            val sync = FinanceSync(context, store) { path, _ -> if (path == "/finance/capabilities") JSONObject().put("schema_version", 1).put("effective", true) else throw java.io.IOException("timeout") }
            assertEquals("offline", sync.run(origin, "owner", true).getString("status"))
            assertEquals(before, store.next(realm)!!.getString("operation_id"))
            val op = store.next(realm)!!
            assertThrows(IllegalArgumentException::class.java) { store.acknowledge(realm, op, ack(op).put("operation_id", "wrong")) }
            assertNotNull(store.next(realm))
        }
    }
    @Test fun serverFailuresAndDisabledCapabilityNeverAcknowledgeTheQueue() {
        FinanceStore(context).use { store ->
            store.capture(realm, "event", record().put("source_app", "manual"))
            val operation = store.next(realm)!!.getString("operation_id")
            for ((code, expected) in listOf(401 to "auth", 403 to "forbidden", 429 to "rate_limited", 500 to "offline")) {
                val sync = FinanceSync(context, store) { path, _ ->
                    if (path == "/finance/capabilities") JSONObject().put("schema_version", 1).put("effective", true)
                    else throw FinanceHttpError(code)
                }
                assertEquals(expected, sync.run(origin, "owner", true).getString("status"))
                assertEquals(operation, store.next(realm)!!.getString("operation_id"))
            }
            var uploads = 0
            val disabled = FinanceSync(context, store) { _, body ->
                if (body != null) uploads++
                JSONObject().put("schema_version", 1).put("effective", false)
            }
            assertEquals("disabled", disabled.run(origin, "owner", true).getString("status"))
            assertEquals(0, uploads)
            assertEquals(operation, store.next(realm)!!.getString("operation_id"))
        }
    }

    @Test fun pausedAutomaticRecordsDoNotBlockManualSync() {
        for (revoked in listOf(false, true)) {
            context.deleteDatabase("finance_v1.db")
            Settings.Secure.putString(context.contentResolver, "enabled_notification_listeners", android.content.ComponentName(context, PaymentNotificationListenerService::class.java).flattenToString())
            FinanceAccess.setEnabled(context, realm, revoked)
            if (revoked) Settings.Secure.putString(context.contentResolver, "enabled_notification_listeners", "")
            val original = FinanceStore(context).use { store ->
                store.capture(realm, "automatic", record())
                store.next(realm)!!.toString()
            }
            FinanceStore(context).use { store ->
                val manualId = store.capture(realm, "manual", record().put("source_app", "manual"))
                val uploaded = mutableListOf<String>()
                val sync = FinanceSync(context, store) { path, body ->
                    when {
                        path == "/finance/capabilities" -> JSONObject().put("schema_version", 1).put("effective", true)
                        body != null -> { uploaded.add(body.getString("candidate_id")); ack(body) }
                        else -> JSONObject().put("records", org.json.JSONArray())
                    }
                }
                sync.run(origin, "owner", true)
                assertEquals("Manual record must sync past a paused automatic head", listOf(manualId), uploaded)
                assertEquals(original, store.next(realm)!!.toString())
                val rows = store.snapshot(realm).getJSONArray("records")
                assertEquals("synced", (0 until rows.length()).map { rows.getJSONObject(it) }.single { it.getString("candidate_id") == manualId }.getString("sync_status"))
            }
        }
    }

    @Test fun userActionFailuresStopBackgroundRequestsAndJobsUntilExplicitSync() {
        for ((code, expected) in listOf(401 to "auth", 403 to "forbidden", 404 to "unsupported")) {
            context.deleteDatabase("finance_v1.db")
            val scheduler = context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as android.app.job.JobScheduler
            scheduler.cancelAll()
            val operation = FinanceStore(context).use { store ->
                store.capture(realm, "manual", record().put("source_app", "manual"))
                val sync = FinanceSync(context, store) { _, _ -> throw FinanceHttpError(code) }
                assertEquals(expected, sync.run(origin, "owner", true).getString("status"))
                assertEquals("User action must not receive a timed retry", 0L, store.meta(realm).getLong("next_attempt"))
                store.next(realm)!!.toString()
            }
            FinanceStore(context).use { store ->
                var calls = 0
                val sync = FinanceSync(context, store) { path, body ->
                    calls++
                    when {
                        path == "/finance/capabilities" -> JSONObject().put("schema_version", 1).put("effective", true)
                        body != null -> ack(body)
                        else -> JSONObject().put("records", org.json.JSONArray())
                    }
                }
                // Even a stale Android job must remain idle after reopening the database.
                sync.run(origin, "owner")
                assertEquals("Background must wait for the user", 0, calls)
                FinanceBridge.schedule(context)
                assertTrue("Blocked work must not be rescheduled", scheduler.allPendingJobs.isEmpty())
                assertEquals(operation, store.next(realm)!!.toString())
                assertEquals("ready", sync.run(origin, "owner", true).getString("status"))
                assertNull(store.next(realm))
            }
        }
    }
    @Test fun conflictAndRejectedRowsDoNotBlockOtherRecordsOrRetryForever() {
        for (code in listOf(409, 422)) {
            context.deleteDatabase("finance_v1.db")
            FinanceStore(context).use { store ->
                val bad = store.capture(realm, "bad", record().put("source_app", "manual"))
                val good = store.capture(realm, "good", record().put("source_app", "manual"))
                val uploaded = mutableListOf<String>()
                val sync = FinanceSync(context, store) { path, body ->
                    when {
                        path == "/finance/capabilities" -> JSONObject().put("schema_version", 1).put("effective", true)
                        body != null -> {
                            if (body.getString("candidate_id") == bad) throw FinanceHttpError(code)
                            uploaded.add(body.getString("candidate_id")); ack(body)
                        }
                        else -> JSONObject().put("records", org.json.JSONArray())
                    }
                }
                sync.run(origin, "owner", true)
                assertEquals("Only the invalid row should be held", listOf(good), uploaded)
                assertNull(store.next(realm))
                val failed = store.snapshot(realm).getJSONArray("records").let { rows -> (0 until rows.length()).map { rows.getJSONObject(it) }.single { it.getString("candidate_id") == bad } }
                assertEquals(if (code == 409) "conflict" else "rejected", failed.getString("sync_status"))
                FinanceBridge.schedule(context)
                val scheduler = context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as android.app.job.JobScheduler
                assertTrue(scheduler.allPendingJobs.isEmpty())
                if (code == 422) {
                    store.edit(realm, bad, JSONObject().put("amount_minor", 1800))
                    FinanceBridge.schedule(context)
                    assertEquals(1, scheduler.allPendingJobs.size)
                }
            }
            (context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as android.app.job.JobScheduler).cancelAll()
        }
    }
    @Test fun transientFailuresKeepTimedRetryButDisabledAndInvalidReceiptsPause() {
        for (status in listOf("offline", "rate_limited", "disabled", "invalid_response")) {
            context.deleteDatabase("finance_v1.db")
            val scheduler = context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as android.app.job.JobScheduler
            scheduler.cancelAll()
            FinanceStore(context).use { store ->
                store.capture(realm, "manual", record().put("source_app", "manual"))
                val op = store.next(realm)!!.toString()
                var calls = 0
                val sync = FinanceSync(context, store) { path, body ->
                    calls++
                    when {
                        status == "disabled" -> JSONObject().put("schema_version", 1).put("effective", false)
                        path == "/finance/capabilities" -> JSONObject().put("schema_version", 1).put("effective", true)
                        status == "offline" -> throw java.io.IOException("timeout")
                        status == "rate_limited" -> throw FinanceHttpError(429)
                        else -> ack(body!!).put("operation_id", "wrong")
                    }
                }
                assertEquals(status, sync.run(origin, "owner", true).getString("status"))
                val before = calls
                sync.run(origin, "owner")
                assertEquals(before, calls)
                assertEquals(op, store.next(realm)!!.toString())
                FinanceBridge.schedule(context)
                if (status in listOf("offline", "rate_limited")) {
                    assertTrue(store.meta(realm).getLong("next_attempt") > System.currentTimeMillis())
                    assertEquals(1, scheduler.allPendingJobs.size)
                    assertTrue(scheduler.allPendingJobs.single().minLatencyMillis > 0)
                } else {
                    assertEquals(0L, store.meta(realm).getLong("next_attempt"))
                    assertTrue(scheduler.allPendingJobs.isEmpty())
                }
            }
        }
    }

    @Test fun disabledDuringUploadUsesRealHttpReasonAndStopsRescheduling() {
        val server = java.net.ServerSocket(0, 2, java.net.InetAddress.getByName("127.0.0.1"))
        server.soTimeout = 10000
        val localOrigin = "http://127.0.0.1:" + server.localPort
        val localRealm = FinanceAccess.realm(localOrigin, "owner")
        val requests = java.util.concurrent.atomic.AtomicInteger()
        val worker = java.util.concurrent.Executors.newSingleThreadExecutor()
        val served = worker.submit {
            repeat(2) {
                server.accept().use { socket ->
                    socket.soTimeout = 10000
                    val input = socket.getInputStream().bufferedReader(Charsets.ISO_8859_1)
                    val capability = input.readLine().contains("/finance/capabilities")
                    var length = 0
                    while (true) {
                        val line = input.readLine() ?: break
                        if (line.isEmpty()) break
                        if (line.startsWith("Content-Length:", true)) length = line.substringAfter(':').trim().toInt()
                    }
                    repeat(length) { input.read() }
                    requests.incrementAndGet()
                    val body = if (capability) "{\"schema_version\":1,\"effective\":true}" else "{\"detail\":\"finance_disabled\"}"
                    val status = if (capability) "200 OK" else "503 Service Unavailable"
                    socket.getOutputStream().write(("HTTP/1.1 $status\r\nContent-Length: " + body.toByteArray(Charsets.UTF_8).size + "\r\nConnection: close\r\n\r\n" + body).toByteArray(Charsets.UTF_8))
                }
            }
        }
        try {
            FinanceAccess.prefs(context).edit().putString("backendBaseUrl", localOrigin).commit()
            FinanceStore(context).use { store ->
                store.capture(localRealm, "manual", record().put("source_app", "manual"))
                val sync = FinanceSync(context, store, tokenProvider = { "public-fixture-only" })
                assertEquals("disabled", sync.run(localOrigin, "owner", true).getString("status"))
                assertEquals(2, requests.get())
                sync.run(localOrigin, "owner")
                assertEquals(2, requests.get())
                FinanceBridge.schedule(context)
                assertTrue((context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as android.app.job.JobScheduler).allPendingJobs.isEmpty())
                assertNotNull(store.next(localRealm))
            }
            served.get(10, java.util.concurrent.TimeUnit.SECONDS)
        } finally { server.close(); worker.shutdownNow() }
    }
}
