package com.presencekit.mobile

import android.content.Context
import android.net.ConnectivityManager
import android.os.Looper
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowNetwork
import java.time.Duration

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class MobileNetworkObserverTest {
    @Test
    fun `network changes coalesce and stop unregisters callbacks`() {
        val context = RuntimeEnvironment.getApplication()
        val manager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val shadow = shadowOf(manager)
        val baseline = shadow.networkCallbacks.size
        var changes = 0
        val observer = MobileNetworkObserver(context) { changes++ }
        observer.start()
        observer.start()
        assertEquals(baseline + 1, shadow.networkCallbacks.size)
        val callback = shadow.networkCallbacks.last()
        callback.onAvailable(ShadowNetwork.newInstance(1))
        callback.onLost(ShadowNetwork.newInstance(1))
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(160))
        assertEquals(1, changes)
        callback.onAvailable(ShadowNetwork.newInstance(2))
        observer.stop()
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(160))
        assertEquals(1, changes)
        assertEquals(baseline, shadow.networkCallbacks.size)
        assertTrue(changes > 0)
    }
}
