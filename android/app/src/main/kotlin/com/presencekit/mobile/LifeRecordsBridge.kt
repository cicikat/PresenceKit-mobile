package com.presencekit.mobile

import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.ComponentName
import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

object LifeRecordsBridge {
    private const val jobId = 17301
    val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    fun register(context: Context, messenger: BinaryMessenger) {
        val app = context.applicationContext
        MethodChannel(messenger, "presence_mobile/life_records").setMethodCallHandler { call, result ->
            executor.execute {
                try {
                    val answer = LifeRecordsStore(app).use { store ->
                        val sync = LifeRecordsSync(app, store)
                        val origin = BackendSecurityPolicy.normalizeOrigin(call.argument<String>("origin").orEmpty()).orEmpty()
                        val owner = call.argument<String>("owner").orEmpty()
                        val realm = sync.checkRealm(origin, owner)
                        when (call.method) {
                            "snapshot" -> store.snapshot(realm).toString()
                            "save" -> {
                                val id = store.save(realm, JSONObject(call.argument<String>("record")!!), call.argument<ByteArray>("image"))
                                schedule(app); id
                            }
                            "delete" -> { store.delete(realm, call.argument<String>("id")!!); schedule(app); null }
                            "image" -> store.image(realm, call.argument<String>("id")!!)
                            "acceptServer" -> { store.acceptServer(realm, call.argument<String>("id")!!); schedule(app); null }
                            "sync" -> { val value = sync.run(origin, owner, call.argument<Boolean>("manual") == true); schedule(app); value.toString() }
                            "query" -> sync.query(origin, owner, JSONObject(call.argument<String>("filters") ?: "{}")).toString()
                            "observe" -> sync.observe(origin, owner).toString()
                            else -> throw IllegalArgumentException("unsupported")
                        }
                    }
                    main.post { result.success(answer) }
                } catch (e: Exception) {
                    // Only stable error codes cross the channel; no image, token, URL or body in logs.
                    val code = when (e) {
                        is LifeRecordsHttpException -> "http_${e.status}"
                        is IllegalArgumentException, is IllegalStateException -> e.message?.takeIf { it.matches(Regex("[a-z_]+")) } ?: "storage_error"
                        else -> "storage_error"
                    }
                    main.post { result.error(code, code, null) }
                }
            }
        }
    }

    fun schedule(context: Context) {
        // Scheduling failure must not turn a successful durable save into a failed save.
        runCatching {
            val scheduler = context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
            if (scheduler.getPendingJob(jobId) == null) scheduler.schedule(
                JobInfo.Builder(jobId, ComponentName(context, LifeRecordsJobService::class.java))
                    .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
                    .setPersisted(true)
                    .setBackoffCriteria(30_000, JobInfo.BACKOFF_POLICY_EXPONENTIAL)
                    .build())
        }
    }
}

class LifeRecordsJobService : JobService() {
    private var stopped = AtomicBoolean(false)
    override fun onStartJob(params: JobParameters): Boolean {
        val cancellation = AtomicBoolean(false)
        stopped = cancellation
        LifeRecordsBridge.executor.execute {
            var retry = false
            try {
                LifeRecordsStore(applicationContext).use { store ->
                    val sync = LifeRecordsSync(applicationContext, store)
                    val (origin, owner) = sync.current()
                    val realm = sync.realm(origin, owner)
                    if (!cancellation.get() && owner.isNotBlank() && store.next(realm) != null) {
                        sync.run(origin, owner, background = true)
                        retry = store.next(realm) != null
                    }
                }
            } catch (_: Exception) { retry = true }
            if (!cancellation.get()) Handler(Looper.getMainLooper()).post {
                jobFinished(params, retry)
                // A save can have been queued just after the worker's final snapshot.
                if (!retry) LifeRecordsBridge.executor.execute {
                    runCatching {
                        LifeRecordsStore(applicationContext).use { store ->
                            val sync = LifeRecordsSync(applicationContext, store)
                            val (origin, owner) = sync.current()
                            if (owner.isNotBlank() && store.next(sync.realm(origin, owner)) != null) {
                                LifeRecordsBridge.schedule(applicationContext)
                            }
                        }
                    }
                }
            }
        }
        return true
    }
    override fun onStopJob(params: JobParameters): Boolean { stopped.set(true); return true }
}
