package com.crashbot

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * MainActivity with Dual Network Plugin.
 *
 * Uses Android ConnectivityManager to keep both WiFi and Cellular networks
 * active simultaneously, enabling redundant data sending through both paths.
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val METHOD_CHANNEL = "com.crashbot/dual_network"
        private const val EVENT_CHANNEL = "com.crashbot/network_status"
    }

    private var wifiNetwork: Network? = null
    private var cellularNetwork: Network? = null
    private var wifiCallback: ConnectivityManager.NetworkCallback? = null
    private var cellularCallback: ConnectivityManager.NetworkCallback? = null
    private val executor = Executors.newFixedThreadPool(4)
    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private val isActive = AtomicBoolean(false)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Method Channel for commands
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startDualNetwork" -> {
                        startDualNetwork()
                        result.success(true)
                    }
                    "stopDualNetwork" -> {
                        stopDualNetwork()
                        result.success(true)
                    }
                    "sendViaWifi" -> {
                        val url = call.argument<String>("url") ?: ""
                        val body = call.argument<String>("body") ?: ""
                        sendViaNetwork(wifiNetwork, url, body, "wifi", result)
                    }
                    "sendViaCellular" -> {
                        val url = call.argument<String>("url") ?: ""
                        val body = call.argument<String>("body") ?: ""
                        sendViaNetwork(cellularNetwork, url, body, "cellular", result)
                    }
                    "sendViaBoth" -> {
                        val url = call.argument<String>("url") ?: ""
                        val body = call.argument<String>("body") ?: ""
                        sendViaBothNetworks(url, body, result)
                    }
                    "pingWifi" -> {
                        measurePing(wifiNetwork, "wifi", result)
                    }
                    "pingCellular" -> {
                        measurePing(cellularNetwork, "cellular", result)
                    }
                    "getNetworkStatus" -> {
                        result.success(getNetworkStatusMap())
                    }
                    else -> result.notImplemented()
                }
            }

        // Event Channel for real-time status updates
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
    }

    /**
     * Request both WiFi and Cellular networks to stay active simultaneously.
     * By default Android drops cellular when WiFi is available —
     * this prevents that behavior.
     */
    private fun startDualNetwork() {
        if (isActive.get()) return
        isActive.set(true)

        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

        // Request WiFi network
        val wifiRequest = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()

        wifiCallback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                wifiNetwork = network
                emitStatus()
            }
            override fun onLost(network: Network) {
                if (wifiNetwork == network) {
                    wifiNetwork = null
                    emitStatus()
                }
            }
            override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) {
                wifiNetwork = network
                emitStatus()
            }
        }

        // Request Cellular network
        val cellularRequest = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_CELLULAR)
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()

        cellularCallback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                cellularNetwork = network
                emitStatus()
            }
            override fun onLost(network: Network) {
                if (cellularNetwork == network) {
                    cellularNetwork = null
                    emitStatus()
                }
            }
            override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) {
                cellularNetwork = network
                emitStatus()
            }
        }

        try {
            cm.requestNetwork(wifiRequest, wifiCallback!!)
            cm.requestNetwork(cellularRequest, cellularCallback!!)
        } catch (e: SecurityException) {
            // Missing permission — fall back silently
            e.printStackTrace()
        }
    }

    /**
     * Release both network requests.
     */
    private fun stopDualNetwork() {
        if (!isActive.get()) return
        isActive.set(false)

        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        try {
            wifiCallback?.let { cm.unregisterNetworkCallback(it) }
            cellularCallback?.let { cm.unregisterNetworkCallback(it) }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        wifiNetwork = null
        cellularNetwork = null
        wifiCallback = null
        cellularCallback = null
        emitStatus()
    }

    /**
     * Send HTTP PATCH request bound to a specific network interface.
     * This is the core of dual-network: we bind the socket to a chosen
     * network so the OS routes traffic through that specific interface.
     */
    private fun sendViaNetwork(
        network: Network?,
        url: String,
        body: String,
        networkName: String,
        result: MethodChannel.Result
    ) {
        if (network == null) {
            mainHandler.post { result.success(mapOf("success" to false, "error" to "$networkName not available")) }
            return
        }

        executor.execute {
            try {
                val conn = network.openConnection(URL(url)) as HttpURLConnection
                conn.requestMethod = "PATCH"
                conn.setRequestProperty("Content-Type", "application/json")
                conn.connectTimeout = 3000
                conn.readTimeout = 3000
                conn.doOutput = true

                val startTime = System.currentTimeMillis()

                OutputStreamWriter(conn.outputStream).use {
                    it.write(body)
                    it.flush()
                }

                val responseCode = conn.responseCode
                val elapsed = System.currentTimeMillis() - startTime
                conn.disconnect()

                mainHandler.post {
                    result.success(mapOf(
                        "success" to (responseCode in 200..299),
                        "network" to networkName,
                        "latencyMs" to elapsed,
                        "statusCode" to responseCode
                    ))
                }
            } catch (e: Exception) {
                mainHandler.post {
                    result.success(mapOf(
                        "success" to false,
                        "network" to networkName,
                        "error" to (e.message ?: "Unknown error")
                    ))
                }
            }
        }
    }

    /**
     * Send through BOTH networks simultaneously — "latency racing".
     * Whichever arrives first wins, giving the robot the fastest response.
     */
    private fun sendViaBothNetworks(
        url: String,
        body: String,
        result: MethodChannel.Result
    ) {
        val responded = AtomicBoolean(false)
        val results = mutableListOf<Map<String, Any>>()

        fun trySend(network: Network?, name: String) {
            if (network == null) {
                synchronized(results) {
                    results.add(mapOf("success" to false, "network" to name, "error" to "not available"))
                    if (results.size == 2 && !responded.get()) {
                        responded.set(true)
                        mainHandler.post { result.success(mapOf("results" to results)) }
                    }
                }
                return
            }

            executor.execute {
                try {
                    val conn = network.openConnection(URL(url)) as HttpURLConnection
                    conn.requestMethod = "PATCH"
                    conn.setRequestProperty("Content-Type", "application/json")
                    conn.connectTimeout = 3000
                    conn.readTimeout = 3000
                    conn.doOutput = true

                    val startTime = System.currentTimeMillis()

                    OutputStreamWriter(conn.outputStream).use {
                        it.write(body)
                        it.flush()
                    }

                    val responseCode = conn.responseCode
                    val elapsed = System.currentTimeMillis() - startTime
                    conn.disconnect()

                    val res = mapOf(
                        "success" to (responseCode in 200..299),
                        "network" to name,
                        "latencyMs" to elapsed,
                        "statusCode" to responseCode
                    )

                    synchronized(results) {
                        results.add(res)
                        if (results.size == 2 && !responded.get()) {
                            responded.set(true)
                            mainHandler.post { result.success(mapOf("results" to results)) }
                        }
                    }
                } catch (e: Exception) {
                    synchronized(results) {
                        results.add(mapOf(
                            "success" to false,
                            "network" to name,
                            "error" to (e.message ?: "Unknown error")
                        ))
                        if (results.size == 2 && !responded.get()) {
                            responded.set(true)
                            mainHandler.post { result.success(mapOf("results" to results)) }
                        }
                    }
                }
            }
        }

        trySend(wifiNetwork, "wifi")
        trySend(cellularNetwork, "cellular")
    }

    /**
     * Measure ping latency by performing a lightweight HTTP HEAD request
     * bound to a specific network interface.
     */
    private fun measurePing(
        network: Network?,
        networkName: String,
        result: MethodChannel.Result
    ) {
        if (network == null) {
            mainHandler.post {
                result.success(mapOf("network" to networkName, "pingMs" to -1, "available" to false))
            }
            return
        }

        executor.execute {
            try {
                val url = URL("https://www.google.com")
                val conn = network.openConnection(url) as HttpURLConnection
                conn.requestMethod = "HEAD"
                conn.connectTimeout = 3000
                conn.readTimeout = 3000

                val startTime = System.currentTimeMillis()
                conn.connect()
                val responseCode = conn.responseCode
                val elapsed = System.currentTimeMillis() - startTime
                conn.disconnect()

                mainHandler.post {
                    result.success(mapOf(
                        "network" to networkName,
                        "pingMs" to elapsed,
                        "available" to true
                    ))
                }
            } catch (e: Exception) {
                mainHandler.post {
                    result.success(mapOf(
                        "network" to networkName,
                        "pingMs" to -1,
                        "available" to false
                    ))
                }
            }
        }
    }

    private fun getNetworkStatusMap(): Map<String, Any> {
        return mapOf(
            "wifiAvailable" to (wifiNetwork != null),
            "cellularAvailable" to (cellularNetwork != null),
            "dualActive" to isActive.get()
        )
    }

    /**
     * Emit network status update to Flutter via EventChannel.
     */
    private fun emitStatus() {
        mainHandler.post {
            eventSink?.success(getNetworkStatusMap())
        }
    }

    override fun onDestroy() {
        stopDualNetwork()
        executor.shutdownNow()
        super.onDestroy()
    }
}
