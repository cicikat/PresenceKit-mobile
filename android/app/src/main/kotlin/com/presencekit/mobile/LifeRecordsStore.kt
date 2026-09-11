package com.presencekit.mobile

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.UUID

/** Single executor (LifeRecordsBridge) owns all access, including background jobs. */
class LifeRecordsStore(context: Context) : AutoCloseable {
    private val directory = File(context.noBackupFilesDir, "life_records").apply { mkdirs() }
    private val db = SQLiteDatabase.openOrCreateDatabase(File(directory, "queue.db"), null)

    init {
        db.execSQL("CREATE TABLE IF NOT EXISTS records (realm TEXT NOT NULL, id TEXT NOT NULL, body TEXT NOT NULL, revision INTEGER NOT NULL DEFAULT 0, image TEXT, deleted INTEGER NOT NULL DEFAULT 0, PRIMARY KEY(realm,id))")
        db.execSQL("CREATE TABLE IF NOT EXISTS operations (seq INTEGER PRIMARY KEY AUTOINCREMENT, realm TEXT NOT NULL, id TEXT NOT NULL, operation_id TEXT NOT NULL UNIQUE, action TEXT NOT NULL, body TEXT, request TEXT, state TEXT NOT NULL DEFAULT 'queued', conflict TEXT)")
        db.execSQL("CREATE TABLE IF NOT EXISTS metadata (realm TEXT PRIMARY KEY, body TEXT NOT NULL)")
        val referenced = mutableSetOf<String>()
        db.rawQuery("SELECT image FROM records WHERE image IS NOT NULL", null).use {
            while (it.moveToNext()) referenced.add(it.getString(0))
        }
        directory.listFiles()?.filter { it.extension == "image" && it.name !in referenced }?.forEach { it.delete() }
    }

    private fun values(vararg pairs: Pair<String, Any?>) = ContentValues().apply {
        pairs.forEach { (key, value) -> when (value) {
            null -> putNull(key)
            is Int -> put(key, value)
            is Long -> put(key, value)
            else -> put(key, value.toString())
        } }
    }

    private fun <T> transaction(block: () -> T): T {
        db.beginTransaction()
        try { val value = block(); db.setTransactionSuccessful(); return value }
        finally { db.endTransaction() }
    }

    fun metadata(realm: String): JSONObject = db.rawQuery("SELECT body FROM metadata WHERE realm=?", arrayOf(realm)).use {
        if (it.moveToFirst()) JSONObject(it.getString(0)) else JSONObject()
    }

    fun setMetadata(realm: String, body: JSONObject) {
        db.insertWithOnConflict("metadata", null, values("realm" to realm, "body" to body), SQLiteDatabase.CONFLICT_REPLACE)
    }

    fun snapshot(realm: String): JSONObject {
        val records = JSONArray()
        db.rawQuery("SELECT body,revision,deleted,id FROM records WHERE realm=?", arrayOf(realm)).use { rows ->
            while (rows.moveToNext()) {
                val body = JSONObject(rows.getString(0)).put("revision", rows.getLong(1)).put("local_deleted", rows.getInt(2) == 1)
                val ops = JSONArray()
                db.rawQuery("SELECT state,action FROM operations WHERE realm=? AND id=? ORDER BY seq", arrayOf(realm, rows.getString(3))).use { pending ->
                    while (pending.moveToNext()) ops.put(JSONObject().put("state", pending.getString(0)).put("action", pending.getString(1)))
                }
                body.put("local_operations", ops)
                records.put(body)
            }
        }
        val counts = JSONObject()
        db.rawQuery("SELECT state,COUNT(*) FROM operations WHERE realm=? GROUP BY state", arrayOf(realm)).use {
            while (it.moveToNext()) counts.put(it.getString(0), it.getInt(1))
        }
        return JSONObject().put("records", records).put("queue", counts).put("sync", metadata(realm))
    }

    private fun record(realm: String, id: String): JSONObject? = db.rawQuery("SELECT body,revision,image FROM records WHERE realm=? AND id=?", arrayOf(realm, id)).use {
        if (!it.moveToFirst()) null else JSONObject(it.getString(0)).put("revision", it.getLong(1)).put("local_image", it.getString(2))
    }

    fun image(realm: String, id: String): ByteArray? = record(realm, id)?.optString("local_image")?.takeIf { it.isNotEmpty() }?.let { File(directory, it).readBytes() }

    fun save(realm: String, body: JSONObject, image: ByteArray?): String {
        require(body.optString("category") in setOf("diet", "bill", "cart"))
        require(body.optString("occurred_on").matches(Regex("\\d{4}-\\d{2}-\\d{2}")))
        require(body.toString().length <= 100_000) { "record_too_large" }
        val existingId = body.optString("id")
        val id = if (existingId.isEmpty()) UUID.randomUUID().toString() else existingId
        val old = if (existingId.isEmpty()) null else record(realm, id) ?: error("record_missing")
        require(old == null || body.optLong("revision", -1) == old.optLong("revision")) { "stale_revision" }
        require(old == null || image == null) { "image_immutable" }
        if (old == null) require(image != null && image.isNotEmpty()) { "image_required" }
        if (image != null) require(image.size <= 10 * 1024 * 1024) { "image_too_large" }
        val count = db.rawQuery("SELECT COUNT(*) FROM operations", null).use { it.moveToFirst(); it.getInt(0) }
        require(count < 200) { "queue_full" }
        val file = if (image != null) File(directory, "${UUID.randomUUID()}.image") else null
        if (file != null) {
            val bytes = directory.listFiles()?.filter { it.extension == "image" }?.sumOf { it.length() } ?: 0L
            require(bytes + image!!.size <= 100L * 1024 * 1024) { "queue_full" }
        }
        try {
            if (file != null) file.outputStream().use { it.write(image!!); it.fd.sync() }
            transaction {
                val clean = JSONObject(body.toString()).put("id", id).put("revision", old?.optLong("revision") ?: 0)
                clean.remove("local_operations"); clean.remove("local_deleted"); clean.remove("local_image")
                // A definitive 4xx rejection did not commit. A corrected draft gets a new ID.
                // Uncertain requests (timeouts or invalid acks) must keep their original identity.
                db.delete("operations", "realm=? AND id=? AND state='rejected'", arrayOf(realm, id))
                db.insertWithOnConflict("records", null, values("realm" to realm, "id" to id, "body" to clean, "revision" to clean.getLong("revision"), "image" to (file?.name ?: old?.optString("local_image")?.takeIf { it.isNotEmpty() }), "deleted" to 0), SQLiteDatabase.CONFLICT_REPLACE)
                enqueue(realm, id, "upsert", clean)
            }
        } catch (e: Exception) { file?.delete(); throw e }
        return id
    }

    private fun enqueue(realm: String, id: String, action: String, body: JSONObject?) {
        db.insertOrThrow("operations", null, values("realm" to realm, "id" to id, "operation_id" to UUID.randomUUID().toString(), "action" to action, "body" to body))
    }

    fun delete(realm: String, id: String) {
        val old = record(realm, id) ?: return
        val unattempted = db.rawQuery("SELECT COUNT(*) FROM operations WHERE realm=? AND id=? AND request IS NOT NULL AND state!='rejected'", arrayOf(realm, id)).use { it.moveToFirst(); it.getInt(0) == 0 }
        transaction {
            if (old.optLong("revision") == 0L && unattempted) {
                db.delete("operations", "realm=? AND id=?", arrayOf(realm, id))
                db.delete("records", "realm=? AND id=?", arrayOf(realm, id))
            } else {
                db.delete("operations", "realm=? AND id=? AND state='rejected'", arrayOf(realm, id))
                db.update("records", values("deleted" to 1), "realm=? AND id=?", arrayOf(realm, id))
                enqueue(realm, id, "delete", null)
            }
        }
        if (old.optLong("revision") == 0L && unattempted) old.optString("local_image").takeIf { it.isNotEmpty() }?.let { File(directory, it).delete() }
    }

    fun next(realm: String): JSONObject? = db.rawQuery("SELECT seq,id,operation_id,action,body,request,state FROM operations o WHERE realm=? AND state IN ('queued','retry') AND NOT EXISTS (SELECT 1 FROM operations prior WHERE prior.realm=o.realm AND prior.id=o.id AND prior.seq<o.seq) ORDER BY seq LIMIT 1", arrayOf(realm)).use {
        if (!it.moveToFirst() || it.getString(6) !in setOf("queued", "retry")) null
        else JSONObject().put("seq", it.getLong(0)).put("record_id", it.getString(1)).put("operation_id", it.getString(2)).put("action", it.getString(3)).put("record", it.getString(4)?.let(::JSONObject)).put("request", it.getString(5)?.let(::JSONObject))
    }

    /** Persist the exact wire body BEFORE network I/O. An uncertain result never changes it. */
    fun prepare(realm: String, owner: String, operation: JSONObject): JSONObject {
        operation.optJSONObject("request")?.let { return it }
        val old = record(realm, operation.getString("record_id")) ?: error("record_missing")
        val request = JSONObject().put("owner_id", owner).put("operation_id", operation.getString("operation_id")).put("record_id", operation.getString("record_id")).put("action", operation.getString("action")).put("base_revision", old.getLong("revision"))
        if (operation.getString("action") == "upsert") {
            request.put("record", operation.getJSONObject("record"))
            if (old.getLong("revision") == 0L) {
                request.put("image_mime", old.optString("image_mime", "image/jpeg"))
            }
        }
        // Image bytes remain in a private file; the immutable request stores metadata only.
        val persisted = JSONObject(request.toString()).apply { remove("image_base64") }
        db.update("operations", values("request" to persisted), "seq=?", arrayOf(operation.getLong("seq").toString()))
        return request
    }

    fun wire(realm: String, owner: String, operation: JSONObject): JSONObject {
        val request = prepare(realm, owner, operation)
        if (request.getString("action") == "upsert" && request.getLong("base_revision") == 0L && !request.has("image_base64")) {
            request.put("image_base64", android.util.Base64.encodeToString(image(realm, operation.getString("record_id")) ?: error("image_missing"), android.util.Base64.NO_WRAP))
        }
        return request
    }

    fun acknowledge(realm: String, operation: JSONObject, response: JSONObject) {
        val id = operation.getString("record_id")
        require(response.optString("operation_id") == operation.getString("operation_id") && response.optString("record_id") == id) { "invalid_ack" }
        val revision = response.optLong("revision", -1)
        val old = record(realm, id) ?: error("record_missing")
        require(revision > old.getLong("revision")) { "invalid_ack" }
        val deleting = operation.getString("action") == "delete"
        if (deleting) require(response.optBoolean("deleted")) { "invalid_ack" }
        val remote = response.optJSONObject("record")
        if (!deleting) require(remote != null && remote.optString("id") == id && remote.optLong("revision") == revision) { "invalid_ack" }
        transaction {
            db.delete("operations", "seq=?", arrayOf(operation.getLong("seq").toString()))
            val pending = hasPending(realm, id)
            if (deleting && !pending) db.delete("records", "realm=? AND id=?", arrayOf(realm, id))
            else {
                val update = values("revision" to revision)
                if (!pending && remote != null) update.put("body", remote.toString())
                db.update("records", update, "realm=? AND id=?", arrayOf(realm, id))
            }
        }
        // Keep the source until no operation can need it. Synced originals live on the backend.
        if (!hasPending(realm, id)) {
            old.optString("local_image").takeIf { it.isNotEmpty() }?.let { File(directory, it).delete() }
            db.update("records", values("image" to null), "realm=? AND id=?", arrayOf(realm, id))
        }
    }

    fun hasPending(realm: String, id: String): Boolean = db.rawQuery("SELECT 1 FROM operations WHERE realm=? AND id=? LIMIT 1", arrayOf(realm, id)).use { it.moveToFirst() }

    fun fail(operation: JSONObject, state: String, conflict: JSONObject? = null) {
        db.update("operations", values("state" to state, "conflict" to conflict), "seq=?", arrayOf(operation.getLong("seq").toString()))
    }

    fun merge(realm: String, records: JSONArray) = transaction {
        for (i in 0 until records.length()) {
            val body = records.getJSONObject(i)
            val id = body.getString("id")
            require(body.getLong("revision") > 0)
            val old = record(realm, id)
            if (!hasPending(realm, id) && body.getLong("revision") >= (old?.optLong("revision") ?: 0)) {
                if (body.optBoolean("deleted")) db.delete("records", "realm=? AND id=?", arrayOf(realm, id))
                else db.insertWithOnConflict("records", null, values("realm" to realm, "id" to id, "body" to body, "revision" to body.getLong("revision")), SQLiteDatabase.CONFLICT_REPLACE)
            }
        }
    }

    /** Explicitly accept server copy after conflict; discard only this record's local intentions. */
    fun acceptServer(realm: String, id: String) {
        val remote = db.rawQuery("SELECT conflict FROM operations WHERE realm=? AND id=? AND state='conflict' LIMIT 1", arrayOf(realm, id)).use {
            require(it.moveToFirst() && !it.isNull(0)) { "conflict_unavailable" }; JSONObject(it.getString(0))
        }
        require(remote.optString("id") == id && remote.optLong("revision") > 0)
        val old = record(realm, id)
        transaction {
            db.delete("operations", "realm=? AND id=?", arrayOf(realm, id))
            if (remote.optBoolean("deleted")) db.delete("records", "realm=? AND id=?", arrayOf(realm, id))
            else db.insertWithOnConflict("records", null, values("realm" to realm, "id" to id, "body" to remote, "revision" to remote.getLong("revision")), SQLiteDatabase.CONFLICT_REPLACE)
        }
        old?.optString("local_image")?.takeIf { it.isNotEmpty() }?.let { File(directory, it).delete() }
    }

    fun retry(realm: String) { db.update("operations", values("state" to "queued"), "realm=? AND state IN ('retry','failed','rejected')", arrayOf(realm)) }
    override fun close() = db.close()
}
