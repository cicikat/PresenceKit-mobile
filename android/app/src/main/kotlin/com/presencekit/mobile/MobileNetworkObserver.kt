package com.presencekit.mobile

import android.content.Context
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel

/** Coalesced default-network changes. Never binds traffic or bypasses a VPN. */
internal class MobileNetworkObserver(context: Context, private val changed: () -> Unit) {
    private val manager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    private val handler = Handler(Looper.getMainLooper())
    private val dispatch = Runnable { if (started) changed() }
    @Volatile private var started = false
    private var capabilitiesKey: List<Any?>? = null
    private var linkKey: List<Any?>? = null
    private val callback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) = schedule()
        override fun onLost(network: Network) = schedule()
        override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) {
            // Signal strength / estimated bandwidth updates do not change the route.
            val key = listOf(network,
                caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET),
                caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED),
                caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN),
                caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI),
                caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR),
                caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET),
            )
            synchronized(this@MobileNetworkObserver) {
                if (key == capabilitiesKey) return
                capabilitiesKey = key
            }
            schedule()
        }
        override fun onLinkPropertiesChanged(network: Network, properties: LinkProperties) {
            val key = listOf(network, properties.interfaceName, properties.dnsServers.toList(),
                properties.routes.toList(), properties.httpProxy, properties.mtu)
            synchronized(this@MobileNetworkObserver) {
                if (key == linkKey) return
                linkKey = key
            }
            schedule()
        }
    }

    private fun schedule() {
        handler.removeCallbacks(dispatch)
        handler.postDelayed(dispatch, 150L)
    }

    fun start() {
        if (started) return
        started = true
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                manager.registerDefaultNetworkCallback(callback)
            } else {
                manager.registerNetworkCallback(
                    NetworkRequest.Builder().addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET).build(),
                    callback,
                )
            }
        } catch (error: RuntimeException) {
            started = false
            throw error
        }
    }

    fun stop() {
        if (!started) return
        started = false
        handler.removeCallbacks(dispatch)
        runCatching { manager.unregisterNetworkCallback(callback) }
    }

    companion object {
        fun register(context: Context, messenger: BinaryMessenger) {
            EventChannel(messenger, "presence_mobile/network").setStreamHandler(object : EventChannel.StreamHandler {
                private var observer: MobileNetworkObserver? = null
                private var epoch = 0L
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    observer?.stop()
                    observer = MobileNetworkObserver(context) { events.success(++epoch) }
                    runCatching { observer?.start() }.onFailure {
                        events.error("network_observer_unavailable", "Network observer unavailable", null)
                    }
                }
                override fun onCancel(arguments: Any?) {
                    observer?.stop()
                    observer = null
                }
            })
        }
    }
}
