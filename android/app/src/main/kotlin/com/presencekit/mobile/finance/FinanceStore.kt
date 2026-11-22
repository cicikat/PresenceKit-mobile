package com.presencekit.mobile.finance

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

/** App-private minimal structured data; never stores notification bodies or credentials. */
class FinanceStore(context: Context) : SQLiteOpenHelper(context, "finance_v1.db", null, 1), java.io.Closeable {
    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("CREATE TABLE candidates(realm TEXT NOT NULL,id TEXT NOT NULL,event TEXT NOT NULL,data TEXT NOT NULL,occurred_at INTEGER NOT NULL,revision INTEGER NOT NULL DEFAULT 0,operation TEXT,error TEXT,PRIMARY KEY(realm,id),UNIQUE(realm,event))")
        db.execSQL("CREATE TABLE metadata(realm TEXT PRIMARY KEY,data TEXT NOT NULL)")
    }
    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) { error("unsupported_schema") }
    private fun <T> transaction(block: (SQLiteDatabase) -> T): T {
        val db = writableDatabase; db.beginTransaction()
        try { val answer = block(db); db.setTransactionSuccessful(); return answer } finally { db.endTransaction() }
    }
    fun meta(realm: String): JSONObject = readableDatabase.rawQuery("SELECT data FROM metadata WHERE realm=?", arrayOf(realm)).use { if (it.moveToFirst()) JSONObject(it.getString(0)) else JSONObject() }
    fun setMeta(realm: String, data: JSONObject) { writableDatabase.insertWithOnConflict("metadata", null, ContentValues().apply { put("realm", realm); put("data", data.toString()) }, SQLiteDatabase.CONFLICT_REPLACE) }
    fun snapshot(realm: String): JSONObject {
        val rows = JSONArray()
        readableDatabase.rawQuery("SELECT data,revision,operation,error FROM candidates WHERE realm=? ORDER BY occurred_at DESC,rowid DESC LIMIT 1000", arrayOf(realm)).use {
            while (it.moveToNext()) rows.put(JSONObject(it.getString(0)).put("revision", it.getInt(1)).put("sync_status", if (!it.isNull(3)) it.getString(3) else if (it.isNull(2)) "synced" else "pending"))
        }
        return JSONObject().put("records", rows).put("sync", meta(realm))
    }
    fun capture(realm: String, event: String, record: JSONObject): String = transaction { db ->
        db.rawQuery("SELECT id FROM candidates WHERE realm=? AND event=?", arrayOf(realm, event)).use { if (it.moveToFirst()) return@transaction it.getString(0) }
        require(android.database.DatabaseUtils.longForQuery(db, "SELECT count(*) FROM candidates WHERE realm=?", arrayOf(realm)) < 10000) { "queue_full" }
        val id = UUID.randomUUID().toString()
        record.put("candidate_id", id).put("source_event_key", event).put("fingerprint", PaymentParser.hash(record.toString()))
        // Amount/time alone cannot prove a duplicate. Preserve both candidates for user review.
        val suspect = db.rawQuery("SELECT data FROM candidates WHERE realm=? ORDER BY rowid DESC LIMIT 100", arrayOf(realm)).use { cursor ->
            var result = false
            while (cursor.moveToNext()) {
                val old = JSONObject(cursor.getString(0))
                if (!record.isNull("amount_minor") && old.optString("source_app") != record.optString("source_app") && old.optLong("amount_minor", -1) == record.optLong("amount_minor", -2) && old.optString("direction") == record.optString("direction") && kotlin.math.abs(old.optLong("occurred_at") - record.optLong("occurred_at")) <= 180000) result = true
            }; result
        }
        if (suspect) record.getJSONArray("reason_codes").put("possible_duplicate")
        db.insertOrThrow("candidates", null, ContentValues().apply { put("realm", realm); put("id", id); put("event", event); put("occurred_at", record.getLong("occurred_at")); put("data", record.toString()); put("operation", operation(record, 0).toString()) })
        id
    }
    private fun operation(record: JSONObject, revision: Int) = JSONObject().put("operation_id", UUID.randomUUID().toString()).put("candidate_id", record.getString("candidate_id")).put("base_revision", revision).put("record", JSONObject(record.toString()))
    fun edit(realm: String, id: String, patch: JSONObject) = transaction { db ->
        val cursor = db.rawQuery("SELECT data,revision,operation,error FROM candidates WHERE realm=? AND id=?", arrayOf(realm, id))
        cursor.use {
            require(it.moveToFirst()) { "not_found" }
            require(it.isNull(3) || it.getString(3) != "conflict") { "conflict" }
            val record = JSONObject(it.getString(0)); val revision = it.getInt(1)
            listOf("amount_minor", "currency", "direction", "merchant", "category", "status").forEach { key -> if (patch.has(key)) record.put(key, patch.get(key)) }
            require(record.optString("status") in setOf("candidate", "confirmed", "ignored", "duplicate", "deleted")) { "invalid_record" }
            require(record.optString("direction") in setOf("expense", "income", "refund", "transfer", "unknown")) { "invalid_record" }
            if (record.optString("status") == "confirmed") require(!record.isNull("amount_minor") && record.getLong("amount_minor") > 0 && record.optString("currency") == "CNY" && record.optString("direction") != "unknown") { "invalid_record" }
            db.update("candidates", ContentValues().apply { put("data", record.toString()); if (it.isNull(2) || (!it.isNull(3) && it.getString(3) == "rejected")) put("operation", operation(record, revision).toString()); putNull("error") }, "realm=? AND id=?", arrayOf(realm, id))
        }
    }
    fun next(realm: String, includeAutomatic: Boolean = true): JSONObject? = readableDatabase.rawQuery("SELECT operation FROM candidates WHERE realm=? AND operation IS NOT NULL AND error IS NULL ORDER BY rowid", arrayOf(realm)).use {
        while (it.moveToNext()) {
            val op = JSONObject(it.getString(0))
            if (includeAutomatic || op.getJSONObject("record").optString("source_app") == "manual") return@use op
        }
        null
    }
    fun acknowledge(realm: String, op: JSONObject, ack: JSONObject) = transaction { db ->
        require(ack.getString("operation_id") == op.getString("operation_id") && ack.getString("candidate_id") == op.getString("candidate_id") && ack.getInt("revision") == op.getInt("base_revision") + 1) { "invalid_response" }
        val id = op.getString("candidate_id")
        db.rawQuery("SELECT data,operation FROM candidates WHERE realm=? AND id=?", arrayOf(realm, id)).use {
            require(it.moveToFirst() && JSONObject(it.getString(1)).getString("operation_id") == op.getString("operation_id")) { "invalid_response" }
            val desired = JSONObject(it.getString(0)); val sent = op.getJSONObject("record")
            val changed = desired.toString() != sent.toString()
            val server = ack.getJSONObject("record")
            // Transaction ID survives all future corrections.
            desired.put("linked_transaction_id", server.opt("linked_transaction_id") ?: JSONObject.NULL)
            db.update("candidates", ContentValues().apply {
                put("revision", ack.getInt("revision")); put("data", (if (changed) desired else server).toString()); putNull("error")
                if (changed) put("operation", operation(desired, ack.getInt("revision")).toString()) else putNull("operation")
            }, "realm=? AND id=?", arrayOf(realm, id))
        }
    }
    fun fail(realm: String, id: String, error: String) { writableDatabase.execSQL("UPDATE candidates SET error=? WHERE realm=? AND id=?", arrayOf(error, realm, id)) }
    fun merge(realm: String, rows: JSONArray) = transaction { db ->
        for (i in 0 until rows.length()) {
            val row = rows.getJSONObject(i); val id = row.getString("candidate_id")
            db.rawQuery("SELECT operation,revision FROM candidates WHERE realm=? AND id=?", arrayOf(realm, id)).use {
                if (it.moveToFirst()) {
                    if (it.isNull(0) && row.getInt("revision") >= it.getInt(1)) db.update("candidates", ContentValues().apply { put("data", row.toString()); put("revision", row.getInt("revision")) }, "realm=? AND id=?", arrayOf(realm, id))
                } else db.insertOrThrow("candidates", null, ContentValues().apply { put("realm", realm); put("id", id); put("event", row.getString("source_event_key")); put("occurred_at", row.getLong("occurred_at")); put("data", row.toString()); put("revision", row.getInt("revision")) })
            }
        }
    }
    fun acceptServer(realm: String, row: JSONObject) = transaction { db ->
        db.update("candidates", ContentValues().apply { put("data", row.toString()); put("revision", row.getInt("revision")); putNull("operation"); putNull("error") }, "realm=? AND id=?", arrayOf(realm, row.getString("candidate_id")))
    }
}
