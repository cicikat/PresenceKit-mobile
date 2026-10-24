package com.presencekit.mobile

import org.junit.Assert.*
import org.junit.Test

class MobilePullRecoveryTest {
    @Test
    fun `failed wake pull retries without another signal then clears on success`() {
        var pending = true
        var attempts = 0
        val waits = ArrayList<Long>()
        MobilePullRecovery.run(
            current = { true },
            takePending = { pending.also { pending = false } },
            restorePending = { pending = true },
            poll = { ++attempts >= 3 },
            retryable = { true },
            wait = { waits.add(it) },
        )
        assertEquals(3, attempts)
        assertEquals(listOf(1000L, 2000L), waits)
        assertFalse(pending)
    }

    @Test
    fun `generation cancellation preserves retry intent and backoff is capped`() {
        var pending = true
        var active = true
        val waits = ArrayList<Long>()
        MobilePullRecovery.run(
            current = { active },
            takePending = { pending.also { pending = false } },
            restorePending = { pending = true },
            poll = { false }, retryable = { true },
            wait = { waits.add(it); if (waits.size == 8) active = false },
        )
        assertTrue(pending)
        assertEquals(listOf(1000L, 2000L, 4000L, 8000L, 16000L, 30000L, 30000L, 30000L), waits)
    }

    @Test
    fun `terminal auth failure does not retry while a second signal is coalesced`() {
        var pending = true
        var attempts = 0
        val waits = ArrayList<Long>()
        MobilePullRecovery.run(
            current = { true }, takePending = { pending.also { pending = false } },
            restorePending = { pending = true },
            poll = { attempts++; false }, retryable = { false }, wait = { waits.add(it) },
        )
        assertEquals(1, attempts)
        assertTrue(waits.isEmpty())
        pending = true
        attempts = 0
        MobilePullRecovery.run(
            current = { true }, takePending = { pending.also { pending = false } },
            restorePending = { pending = true },
            poll = { attempts++; if (attempts == 1) pending = true; true },
            retryable = { true }, wait = { waits.add(it) },
        )
        assertEquals(2, attempts)
    }
}
