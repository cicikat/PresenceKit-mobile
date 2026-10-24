package com.presencekit.mobile

import android.content.Context
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.NetworkCapabilities
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
    fun `bandwidth-only and repeated link updates must not cancel a healthy receive`() {
        val context = RuntimeEnvironment.getApplication()
        val manager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        var changes = 0
        val observer = MobileNetworkObserver(context) { changes++ }
        observer.start()
        try {
            val callback = shadowOf(manager).networkCallbacks.last()
            val network = ShadowNetwork.newInstance(7)
            fun change(caps: NetworkCapabilities, method: String, value: Int): NetworkCapabilities = caps.apply {
                javaClass.getMethod(method, Integer.TYPE).invoke(this, value)
            }
            val caps = NetworkCapabilities()
            change(caps, "addTransportType", NetworkCapabilities.TRANSPORT_WIFI)
            change(caps, "addCapability", NetworkCapabilities.NET_CAPABILITY_INTERNET)
            change(caps, "addCapability", NetworkCapabilities.NET_CAPABILITY_VALIDATED)
            callback.onAvailable(network)
            callback.onCapabilitiesChanged(network, caps)
            shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(160))
            assertEquals(1, changes)
            callback.onCapabilitiesChanged(network, change(NetworkCapabilities(caps), "setLinkDownstreamBandwidthKbps", 4321))
            shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(160))
            assertEquals(1, changes)
            callback.onCapabilitiesChanged(network, change(NetworkCapabilities(caps), "removeCapability", NetworkCapabilities.NET_CAPABILITY_VALIDATED))
            shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(160))
            assertEquals(2, changes)
            callback.onLinkPropertiesChanged(network, LinkProperties())
            shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(160))
            assertEquals(3, changes)
            callback.onLinkPropertiesChanged(network, LinkProperties())
            shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(160))
            assertEquals(3, changes)
        } finally { observer.stop() }
    }

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
