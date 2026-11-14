package com.presencekit.mobile

import android.content.Context
import androidx.work.Worker
import androidx.work.WorkerParameters
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class PresenceFirebaseService : FirebaseMessagingService() {
    override fun onMessageReceived(message: RemoteMessage) {
        FcmPush.receive(this, message.data)
    }

    override fun onNewToken(token: String) {
        FcmPush.newToken(this, token)
    }
}

class FcmReconcileWorker(context: Context, parameters: WorkerParameters) : Worker(context, parameters) {
    override fun doWork(): Result {
        val id = inputData.getString("id") ?: return Result.failure()
        val installation = inputData.getString("installation") ?: return Result.failure()
        val wake = FcmPush.Wake(id, inputData.getLong("seq", 0), installation, inputData.getLong("generation", -1))
        return runCatching { FcmPush.reconcile(applicationContext, wake) }
            .fold({ Result.success() }, { Result.failure() })
    }
}
