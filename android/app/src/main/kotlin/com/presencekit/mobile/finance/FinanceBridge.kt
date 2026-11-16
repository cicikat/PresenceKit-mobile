package com.presencekit.mobile.finance

import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

object FinanceBridge {
    val executor = Executors.newSingleThreadExecutor()
    private const val jobId = 17330
    fun register(context: Context, messenger: BinaryMessenger) {
        val app = context.applicationContext; val main = Handler(Looper.getMainLooper())
        MethodChannel(messenger, "presence_mobile/finance").setMethodCallHandler { call, result ->
            if (call.method == "permissionSettings") {
                try { context.startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)); result.success(null) }
                catch (_: Exception) { result.error("unsupported", "unsupported", null) }
                return@setMethodCallHandler
            }
            executor.execute {
                try {
                    val answer = FinanceStore(app).use { store ->
                        val origin = call.argument<String>("origin").orEmpty(); val owner = call.argument<String>("owner").orEmpty()
                        val sync = FinanceSync(app, store); val realm = sync.check(origin, owner)
                        when (call.method) {
                            "snapshot" -> store.snapshot(realm).put("permission", FinanceAccess.permission(app)).put("enabled", FinanceAccess.enabled(app, realm)).toString()
                            "setEnabled" -> { FinanceAccess.setEnabled(app, realm, call.argument<Boolean>("enabled") == true); schedule(app); null }
                            "edit" -> { store.edit(realm, call.argument<String>("id")!!, JSONObject(call.argument<String>("patch")!!)); schedule(app); null }
                            "manual" -> {
                                val record = JSONObject(call.argument<String>("record")!!).put("source_app", "manual").put("status", "candidate").put("confidence", "user").put("reason_codes", org.json.JSONArray().put("manual"))
                                store.capture(realm, PaymentParser.hash(java.util.UUID.randomUUID().toString()), record); schedule(app); null
                            }
                            "acceptServer" -> {
                                val id = call.argument<String>("id")!!
                                require(id.matches(Regex("[A-Za-z0-9_-]+"))) { "invalid_record" }
                                store.acceptServer(realm, sync.request(origin, owner, "/finance/candidates/$id").getJSONObject("record")); null
                            }
                            "detail" -> {
                                val id = call.argument<String>("id")!!
                                require(id.matches(Regex("[A-Za-z0-9_-]+"))) { "invalid_record" }
                                sync.request(origin, owner, "/finance/candidates/$id").toString()
                            }
                            "sync" -> { val value = sync.run(origin, owner, manual = true); schedule(app); value.toString() }
                            else -> error("unsupported")
                        }
                    }
                    main.post { result.success(answer) }
                } catch (e: Exception) {
                    val code = when (e) { is FinanceHttpError -> "http_${e.status}"; else -> e.message?.takeIf { it.matches(Regex("[a-z_]+")) } ?: "storage_error" }
                    main.post { result.error(code, code, null) }
                }
            }
        }
    }
    fun schedule(context: Context) { runCatching {
        val scheduler = context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
        if (scheduler.allPendingJobs.none { it.id == jobId }) scheduler.schedule(JobInfo.Builder(jobId, ComponentName(context, FinanceJobService::class.java)).setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY).setPersisted(true).setBackoffCriteria(30000, JobInfo.BACKOFF_POLICY_EXPONENTIAL).build())
    } }
}

class FinanceJobService : JobService() {
    private var stopped = AtomicBoolean(false)
    override fun onStartJob(params: JobParameters): Boolean {
        val cancellation = AtomicBoolean(false); stopped = cancellation
        FinanceBridge.executor.execute {
            var retry = false
            try {
                val (origin, owner) = FinanceAccess.current(this)
                FinanceStore(this).use { store ->
                    if (!cancellation.get() && store.next(FinanceAccess.realm(origin, owner)) != null) {
                        FinanceSync(this, store).run(origin, owner, cancelled = { cancellation.get() })
                        retry = store.next(FinanceAccess.realm(origin, owner)) != null
                    }
                }
            } catch (_: Exception) { retry = true }
            if (!cancellation.get()) Handler(Looper.getMainLooper()).post {
                jobFinished(params, retry)
                if (!retry) FinanceBridge.executor.execute {
                    runCatching {
                        val (origin, owner) = FinanceAccess.current(this)
                        FinanceStore(this).use { store -> if (store.next(FinanceAccess.realm(origin, owner)) != null) FinanceBridge.schedule(this) }
                    }
                }
            }
        }
        return true
    }
    override fun onStopJob(params: JobParameters): Boolean { stopped.set(true); return true }
}
