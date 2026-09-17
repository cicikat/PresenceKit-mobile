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
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class MobileDeliveryStateStoreTest {
    private lateinit var context: Context
    private lateinit var store: MobileDeliveryStateStore

    @Before
    fun setup() {
        context = RuntimeEnvironment.getApplication()
        context.getSharedPreferences(BackendSecurityPolicy.PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .clear()
            .commit()
        store = MobileDeliveryStateStore.of(context)
    }

    private fun item(
        id: String,
        content: String,
        seq: Long = 1,
        charId: String? = "char-a",
        turnId: String? = null,
    ) = JSONObject()
        .put("id", id)
        .put("seq", seq)
        .put("content", content)
        .put("timestamp", 1_780_000_000.0)
        .put("char_id", charId)
        .apply { if (turnId != null) put("turn_id", turnId) }

    @Test
    fun `mergeSeen unions and keeps insertion order with cap`() {
        store.mergeSeen(listOf("a", "b", "a", "c"))
        assertEquals(listOf("a", "b", "c"), store.loadSeen())
        store.mergeSeen(listOf("d"))
        assertEquals(listOf("a", "b", "c", "d"), store.loadSeen())
        store.mergeSeen((1..200).map { "n$it" })
        val seen = store.loadSeen()
        assertEquals(200, seen.size)
        assertFalse(seen.contains("a"))
        assertEquals("n200", seen.last())
    }

    @Test
    fun `advanceAck is monotonic and survives reopen`() {
        assertNull(store.lastAckedSeq())
        assertEquals(4L, store.advanceAck(4))
        assertEquals(4L, store.advanceAck(3))
        assertEquals(4L, store.lastAckedSeq())
        assertEquals(9L, store.advanceAck(9))
        val reopened = MobileDeliveryStateStore.of(context)
        assertEquals(9L, reopened.lastAckedSeq())
        assertEquals(9L, reopened.advanceAck(8))
    }

    @Test
    fun `acceptIncoming writes identity envelope and skips duplicates`() {
        val origin = "http://127.0.0.1:8080"
        val owner = "owner"
        assertTrue(store.acceptIncoming(item("m1", "hello", seq = 7), origin, owner))
        assertFalse(store.acceptIncoming(item("m1", "hello again", seq = 8), origin, owner))
        val first = store.consumePending(origin, owner, "char-a")
        assertEquals(1, first.envelopes.size)
        assertEquals("m1", first.envelopes.single().id)
        assertEquals("m1", first.envelopes.single().turnId)
        assertEquals(7L, first.envelopes.single().seq)
        assertTrue(first.envelopes.single().replayable)
        val second = store.consumePending(origin, owner, "char-a")
        assertTrue(second.envelopes.isEmpty())
    }

    @Test
    fun `legacy pending strings are discarded and never replayed`() {
        val prefs = context.getSharedPreferences(BackendSecurityPolicy.PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putString(
                MobileDeliveryStateStore.LEGACY_PENDING_KEY,
                JSONArray().put("old body").put("second").toString(),
            )
            .commit()
        val consumed = store.consumePending("http://127.0.0.1:8080", "owner", "char-a")
        assertTrue(consumed.envelopes.isEmpty())
        assertEquals(2, consumed.discardedLegacy)
        assertNull(prefs.getString(MobileDeliveryStateStore.LEGACY_PENDING_KEY, null))
        assertTrue(store.consumePending("http://127.0.0.1:8080", "owner", "char-a").envelopes.isEmpty())
    }

    @Test
    fun `pending for another origin or character stays queued`() {
        val origin = "http://127.0.0.1:8080"
        store.acceptIncoming(item("m1", "alpha"), origin, "owner")
        store.acceptIncoming(item("m2", "beta", charId = "char-b"), origin, "owner")
        val otherNode = store.consumePending("http://10.0.0.2:8080", "owner", "char-a")
        assertTrue(otherNode.envelopes.isEmpty())
        val otherChar = store.consumePending(origin, "owner", "char-a")
        assertEquals(listOf("m1"), otherChar.envelopes.map { it.id })
        val remaining = store.consumePending(origin, "owner", "char-b")
        assertEquals(listOf("m2"), remaining.envelopes.map { it.id })
    }

    @Test
    fun `backend origin change clears cursor seen and pending`() {
        val origin = "http://127.0.0.1:8080"
        store.bindCursorScope(origin, "owner")
        store.mergeSeen(listOf("m1"))
        store.advanceAck(12)
        store.acceptIncoming(item("m2", "keep"), origin, "owner")
        store.bindCursorScope("http://10.0.0.2:8080", "owner")
        assertNull(store.lastAckedSeq())
        assertTrue(store.loadSeen().isEmpty())
        assertTrue(store.consumePending("http://10.0.0.2:8080", "owner", "char-a").envelopes.isEmpty())
    }

    @Test
    fun `character switch does not reset node-wide cursor`() {
        store.bindCursorScope("http://127.0.0.1:8080", "owner")
        store.advanceAck(5)
        store.mergeSeen(listOf("m1"))
        store.bindCursorScope("http://127.0.0.1:8080", "owner")
        assertEquals(5L, store.lastAckedSeq())
        assertEquals(listOf("m1"), store.loadSeen())
    }

    @Test
    fun `concurrent mergeSeen does not lose ids and cursor does not rewind`() {
        val executor = Executors.newFixedThreadPool(2)
        val start = CountDownLatch(1)
        val done = CountDownLatch(2)
        executor.execute {
            start.await()
            store.mergeSeen((1..120).map { "a$it" })
            store.advanceAck(20)
            done.countDown()
        }
        executor.execute {
            start.await()
            store.mergeSeen((1..120).map { "b$it" })
            store.advanceAck(15)
            done.countDown()
        }
        start.countDown()
        assertTrue(done.await(5, TimeUnit.SECONDS))
        executor.shutdown()
        val seen = store.loadSeen()
        assertEquals(200, seen.size)
        assertTrue(seen.any { it.startsWith("a") })
        assertTrue(seen.any { it.startsWith("b") })
        assertEquals(20L, store.lastAckedSeq())
    }

    @Test
    fun `appendPending is serial with consume and keeps identity envelopes`() {
        val origin = "http://127.0.0.1:8080"
        store.appendPending(item("m9", "queued", seq = 9), origin, "owner")
        val consumed = store.consumePending(origin, "owner", "char-a")
        assertEquals(listOf("m9"), consumed.envelopes.map { it.id })
        assertTrue(store.consumePending(origin, "owner", "char-a").envelopes.isEmpty())
    }

    @Test
    fun `seq and content hash are not treated as identity`() {
        val envelope = MobileDeliveryStateStore.envelopeFromQueueItem(
            JSONObject().put("seq", 9).put("content", "hello"),
            "http://127.0.0.1:8080",
            "owner",
        )
        assertNull(envelope.id)
        assertNull(envelope.turnId)
        assertFalse(envelope.replayable)
    }
}
