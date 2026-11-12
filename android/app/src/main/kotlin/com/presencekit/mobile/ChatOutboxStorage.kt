
package com.presencekit.mobile

import android.content.Context
import android.util.AtomicFile
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileNotFoundException
import java.util.concurrent.Executors

internal object ChatOutboxStorage {
    private val executor = Executors.newSingleThreadExecutor()
    private const val maxSnapshotBytes = 64 * 1024 * 1024

    fun dispatch(context: Context, call: MethodCall, result: MethodChannel.Result): Boolean {
        if (call.method != "loadChatOutbox" && call.method != "saveChatOutbox") return false
        val file = AtomicFile(File(context.noBackupFilesDir, "mobile-chat-outbox-v1.json"))
        executor.execute {
            try {
                if (call.method == "loadChatOutbox") {
                    val snapshot = try {
                        file.openRead().use { stream ->
                            check(stream.channel.size() <= maxSnapshotBytes)
                            stream.readBytes().toString(Charsets.UTF_8)
                        }
                    } catch (error: FileNotFoundException) {
                        if (file.baseFile.exists()) throw error
                        null
                    }
                    result.success(snapshot)
                } else {
                    val data = requireNotNull(call.argument<String>("value")).toByteArray(Charsets.UTF_8)
                    require(data.size <= maxSnapshotBytes)
                    val output = file.startWrite()
                    try {
                        output.write(data)
                        output.fd.sync()
                        file.finishWrite(output)
                    } catch (error: Exception) {
                        file.failWrite(output)
                        throw error
                    }
                    result.success(null)
                }
            } catch (error: Exception) {
                result.error("chat_outbox_io", "Could not access the local chat outbox", null)
            }
        }
        return true
    }
}
