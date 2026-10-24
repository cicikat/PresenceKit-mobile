package com.presencekit.mobile

/** A wake remains pending until an authenticated pull succeeds. One worker only. */
internal object MobilePullRecovery {
    fun run(
        current: () -> Boolean,
        takePending: () -> Boolean,
        restorePending: () -> Unit,
        poll: () -> Boolean,
        retryable: () -> Boolean,
        wait: (Long) -> Unit,
    ) {
        var delay = 1000L
        while (current() && takePending()) {
            if (poll()) {
                delay = 1000L
            } else {
                if (!retryable()) return
                restorePending()
                if (!current()) return
                wait(delay)
                delay = (delay * 2).coerceAtMost(30_000L)
            }
        }
    }
}
