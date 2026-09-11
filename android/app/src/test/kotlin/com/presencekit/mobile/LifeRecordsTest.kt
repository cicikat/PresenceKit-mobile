package com.presencekit.mobile

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.io.IOException

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class LifeRecordsTest {
    private lateinit var context: Context
    private val origin = "http://127.0.0.1:8080"
    private val realm = "$origin\nowner"
    private val image = byteArrayOf(1, 2, 3, 4)

    @Before fun setup() {
        context = RuntimeEnvironment.getApplication()
        context.getSharedPreferences(BackendSecurityPolicy.PREFS_NAME, Context.MODE_PRIVATE).edit()
            .putString("backendBaseUrl", origin).putString("ownerUserId", "owner").commit()
    }

    private fun body(title: String = "Lunch") = JSONObject().put("category", "diet")
        .put("occurred_on", "2026-09-11").put("captured_at", "2026-09-11T04:00:00Z")
        .put("title", title).put("note", "").put("items", JSONArray())
        .put("recognition_status", "pending").put("image_mime", "image/jpeg")

    private fun ack(op: JSONObject, revision: Long, title: String = "Recognized") = JSONObject()
        .put("operation_id", op.getString("operation_id")).put("record_id", op.getString("record_id"))
        .put("revision", revision).put("deleted", op.getString("action") == "delete")
        .put("record", body(title).put("id", op.getString("record_id")).put("revision", revision))

    @Test fun `queue and exact uncertain request survive reopen`() {
        val first: String
        val id: String
        LifeRecordsStore(context).use { store ->
            id = store.save(realm, body(), image)
            first = store.wire(realm, "owner", store.next(realm)!!).toString()
        }
        LifeRecordsStore(context).use { store ->
            assertEquals(first, store.wire(realm, "owner", store.next(realm)!!).toString())
            assertArrayEquals(image, store.image(realm, id))
            assertEquals(0, store.snapshot("$origin\nother").getJSONArray("records").length())
        }
    }

    @Test fun `edit during uncertain upload preserves intent and uses acknowledged revision`() {
        LifeRecordsStore(context).use { store ->
            val id = store.save(realm, body(), image)
            val first = store.next(realm)!!
            val firstRequest = store.wire(realm, "owner", first).toString()
            store.save(realm, body("Corrected").put("id", id), null)
            assertEquals(firstRequest, store.wire(realm, "owner", store.next(realm)!!).toString())
            store.acknowledge(realm, first, ack(first, 1))
            assertEquals("Corrected", store.snapshot(realm).getJSONArray("records").getJSONObject(0).getString("title"))
            val second = store.next(realm)!!
            assertEquals(1, store.wire(realm, "owner", second).getLong("base_revision"))
            assertFalse(store.wire(realm, "owner", second).has("image_base64"))
            store.acknowledge(realm, second, ack(second, 2, "Corrected"))
            assertNull(store.next(realm))
            assertNull(store.image(realm, id))
        }
    }

    @Test fun `delete unsent record removes image and queue without network`() {
        LifeRecordsStore(context).use { store ->
            val id = store.save(realm, body(), image)
            store.delete(realm, id)
            assertNull(store.next(realm))
            assertNull(store.image(realm, id))
            assertEquals(0, store.snapshot(realm).getJSONArray("records").length())
        }
    }

    @Test fun `delete uncertain create waits for create ack then sends tombstone`() {
        LifeRecordsStore(context).use { store ->
            val id = store.save(realm, body(), image)
            val create = store.next(realm)!!
            store.wire(realm, "owner", create)
            store.delete(realm, id)
            assertEquals("upsert", store.next(realm)!!.getString("action"))
            store.acknowledge(realm, create, ack(create, 1))
            val delete = store.next(realm)!!
            assertEquals("delete", delete.getString("action"))
            assertEquals(1, store.wire(realm, "owner", delete).getLong("base_revision"))
            store.acknowledge(realm, delete, ack(delete, 2))
            assertEquals(0, store.snapshot(realm).getJSONArray("records").length())
        }
    }

    @Test fun `wrong ack keeps original image and pending operation`() {
        LifeRecordsStore(context).use { store ->
            val id = store.save(realm, body(), image)
            val op = store.next(realm)!!
            try { store.acknowledge(realm, op, ack(op, 1).put("operation_id", "wrong")); fail() }
            catch (_: IllegalArgumentException) { }
            assertNotNull(store.next(realm)); assertArrayEquals(image, store.image(realm, id))
        }
    }

    @Test fun `remote query cannot overwrite pending correction or regress revision`() {
        LifeRecordsStore(context).use { store ->
            val id = store.save(realm, body("Local"), image)
            store.merge(realm, JSONArray().put(body("Remote").put("id", id).put("revision", 9)))
            assertEquals("Local", store.snapshot(realm).getJSONArray("records").getJSONObject(0).getString("title"))
            store.merge(realm, JSONArray().put(body("New").put("id", "remote").put("revision", 5)))
            store.merge(realm, JSONArray().put(body("Old").put("id", "remote").put("revision", 2)))
            val rows = store.snapshot(realm).getJSONArray("records")
            assertEquals("New", rows.getJSONObject(1).getString("title"))
        }
    }

    @Test fun `conflict retains local copy and does not block unrelated records`() {
        LifeRecordsStore(context).use { store ->
            val id = store.save(realm, body("Local"), image)
            store.fail(store.next(realm)!!, "conflict", body("Server").put("id", id).put("revision", 4))
            val other = store.save(realm, body("Other"), image)
            assertEquals(other, store.next(realm)!!.getString("record_id"))
            store.acceptServer(realm, id)
            assertFalse(store.hasPending(realm, id))
            assertNull(store.image(realm, id))
        }
    }

    @Test fun `missing capability sends no image and retains queue`() {
        LifeRecordsStore(context).use { store ->
            store.save(realm, body(), image)
            val calls = mutableListOf<String>()
            val sync = LifeRecordsSync(context, store, { "test" }) { path, _ ->
                calls.add(path); throw LifeRecordsHttpException(404, null)
            }
            assertEquals("unsupported", sync.run(origin, "owner").getString("status"))
            assertEquals(1, calls.size)
            assertNotNull(store.next(realm))
        }
    }

    @Test fun `offline retry uses same operation and authorization failures pause`() {
        LifeRecordsStore(context).use { store ->
            store.save(realm, body(), image)
            val sent = mutableListOf<String>()
            var fail = true
            val sync = LifeRecordsSync(context, store, { "test" }) { path, request ->
                if (path.contains("capabilities")) JSONObject().put("schema_version", 1).put("enabled", true)
                else { sent.add(request!!.toString()); if (fail) throw IOException("offline")
                    ack(store.next(realm)!!, 1) }
            }
            assertEquals("offline", sync.run(origin, "owner").getString("status"))
            fail = false
            assertEquals("ready", sync.run(origin, "owner", true).getString("status"))
            assertEquals(sent[0], sent[1])
            assertNull(store.next(realm))
            var calls = 0
            val auth = LifeRecordsSync(context, store, { "revoked" }) { _, _ -> calls++; throw LifeRecordsHttpException(401, null) }
            auth.run(origin, "owner", true); auth.run(origin, "owner")
            assertEquals(1, calls)
        }
    }

    @Test fun `account switch prevents old realm transmission`() {
        LifeRecordsStore(context).use { store ->
            store.save(realm, body(), image)
            context.getSharedPreferences(BackendSecurityPolicy.PREFS_NAME, Context.MODE_PRIVATE).edit()
                .putString("ownerUserId", "new_owner").commit()
            val sync = LifeRecordsSync(context, store, { "test" }) { _, _ -> error("must_not_send") }
            try { sync.run(origin, "owner"); fail() } catch (_: IllegalArgumentException) { }
            assertNotNull(store.next(realm))
        }
    }

    @Test fun `correcting a definitive rejection creates a fresh operation`() {
        LifeRecordsStore(context).use { store ->
            val id = store.save(realm, body(), image)
            val rejected = store.next(realm)!!
            store.wire(realm, "owner", rejected)
            store.fail(rejected, "rejected")
            assertNull(store.next(realm))
            store.save(realm, body("Corrected").put("id", id), null)
            val corrected = store.next(realm)!!
            assertNotEquals(rejected.getString("operation_id"), corrected.getString("operation_id"))
            assertEquals("Corrected", store.wire(realm, "owner", corrected).getJSONObject("record").getString("title"))
            store.fail(corrected, "rejected")
            store.delete(realm, id)
            assertEquals(0, store.snapshot(realm).getJSONArray("records").length())
        }
    }

    @Test fun `backend can disable background uploads without losing records`() {
        LifeRecordsStore(context).use { store ->
            store.save(realm, body(), image)
            val sync = LifeRecordsSync(context, store, { "test" }) { path, _ ->
                assertTrue(path.contains("capabilities"))
                JSONObject().put("schema_version", 1).put("enabled", true).put("background_sync", false)
            }
            assertEquals("foreground_only", sync.run(origin, "owner", background = true).getString("status"))
            assertNotNull(store.next(realm))
        }
    }

    @Test fun `newer server tombstone removes cached record but not pending correction`() {
        LifeRecordsStore(context).use { store ->
            store.merge(realm, JSONArray().put(body().put("id", "remote").put("revision", 3)))
            store.merge(realm, JSONArray().put(JSONObject().put("id", "remote").put("revision", 4).put("deleted", true)))
            assertEquals(0, store.snapshot(realm).getJSONArray("records").length())
            val id = store.save(realm, body(), image)
            store.merge(realm, JSONArray().put(JSONObject().put("id", id).put("revision", 5).put("deleted", true)))
            assertEquals(1, store.snapshot(realm).getJSONArray("records").length())
        }
    }

    @Test fun `oversized image is rejected without creating an operation`() {
        LifeRecordsStore(context).use { store ->
            try { store.save(realm, body(), ByteArray(10 * 1024 * 1024 + 1)); fail() }
            catch (_: IllegalArgumentException) { }
            assertNull(store.next(realm))
            assertEquals(0, store.snapshot(realm).getJSONArray("records").length())
        }
    }
}
