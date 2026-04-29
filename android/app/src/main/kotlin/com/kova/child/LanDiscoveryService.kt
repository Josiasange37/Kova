package com.kova.child

import android.app.Service
import android.content.Intent
import android.net.wifi.WifiManager
import android.os.IBinder
import android.util.Log
import kotlinx.coroutines.*
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress

/**
 * LanDiscoveryService — UDP broadcast/multicast discovery for LAN pairing
 *
 * This service handles device discovery on local WiFi networks. It requires
 * a MulticastLock to function correctly — without it, Android silently drops
 * all incoming broadcast/multicast UDP packets at the kernel level.
 *
 * The socket will open fine but receive nothing without the lock.
 */
class LanDiscoveryService : Service() {

    companion object {
        private const val TAG = "LanDiscoveryService"
        private const val DISCOVERY_PORT = 5353
        private const val BROADCAST_INTERVAL_MS = 3000L
        private const val MULTICAST_LOCK_TAG = "kova_discovery"
    }

    private var multicastLock: WifiManager.MulticastLock? = null
    private var socket: DatagramSocket? = null
    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var isRunning = false

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "LAN discovery service created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!isRunning) {
            isRunning = true
            startDiscovery()
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        stopDiscovery()
        serviceScope.cancel()
    }

    /**
     * Start the discovery process.
     * Acquires MulticastLock before opening UDP socket — critical for WiFi operation.
     */
    private fun startDiscovery() {
        serviceScope.launch {
            try {
                // ─── CRITICAL: Acquire MulticastLock ──────────────────────────────
                // Without this lock, Android silently drops all incoming multicast/broadcast
                // UDP packets at the kernel level. The socket opens fine but receives nothing.
                acquireMulticastLock()

                // Now safe to open UDP socket
                socket = DatagramSocket(DISCOVERY_PORT).apply {
                    broadcast = true
                    reuseAddress = true
                }

                Log.d(TAG, "Discovery socket opened on port $DISCOVERY_PORT")

                // Start receive loop
                launch { receiveLoop() }

                // Start broadcast loop
                launch { broadcastLoop() }

            } catch (e: Exception) {
                Log.e(TAG, "Failed to start discovery: ${e.message}")
                releaseMulticastLock()
            }
        }
    }

    /**
     * Stop discovery and release resources.
     * MulticastLock MUST be released to allow WiFi power saving.
     */
    private fun stopDiscovery() {
        isRunning = false
        socket?.close()
        socket = null
        releaseMulticastLock()
        Log.d(TAG, "Discovery stopped")
    }

    /**
     * Acquire WiFi MulticastLock for UDP broadcast/multicast reception.
     * This is the magic that makes discovery work on Android WiFi.
     */
    private fun acquireMulticastLock() {
        try {
            val wifiManager = applicationContext.getSystemService(WIFI_SERVICE) as WifiManager
            multicastLock = wifiManager.createMulticastLock(MULTICAST_LOCK_TAG).apply {
                setReferenceCounted(true)
                acquire()
            }
            Log.d(TAG, "MulticastLock acquired: $MULTICAST_LOCK_TAG")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to acquire MulticastLock: ${e.message}")
        }
    }

    /**
     * Release MulticastLock to allow WiFi power saving.
     * Call this when discovery stops.
     */
    private fun releaseMulticastLock() {
        try {
            multicastLock?.let {
                if (it.isHeld) {
                    it.release()
                    Log.d(TAG, "MulticastLock released")
                }
            }
            multicastLock = null
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing MulticastLock: ${e.message}")
        }
    }

    /**
     * Listen for incoming discovery broadcasts from other devices.
     */
    private suspend fun receiveLoop() {
        val buffer = ByteArray(1024)
        val packet = DatagramPacket(buffer, buffer.size)

        while (isRunning && socket != null) {
            try {
                withContext(Dispatchers.IO) {
                    socket?.receive(packet)
                }

                val message = String(packet.data, 0, packet.length)
                val sender = packet.address

                Log.d(TAG, "Received from $sender: $message")
                handleDiscoveryMessage(message, sender)

            } catch (e: Exception) {
                if (isRunning) {
                    Log.e(TAG, "Receive error: ${e.message}")
                }
                delay(100)
            }
        }
    }

    /**
     * Broadcast this device's presence on the LAN.
     */
    private suspend fun broadcastLoop() {
        val broadcastAddr = InetAddress.getByName("255.255.255.255")
        val deviceInfo = buildDeviceInfo()

        while (isRunning) {
            try {
                val data = deviceInfo.toByteArray()
                val packet = DatagramPacket(
                    data,
                    data.size,
                    broadcastAddr,
                    DISCOVERY_PORT
                )

                withContext(Dispatchers.IO) {
                    socket?.send(packet)
                }

                Log.d(TAG, "Broadcast sent: $deviceInfo")
                delay(BROADCAST_INTERVAL_MS)

            } catch (e: Exception) {
                Log.e(TAG, "Broadcast error: ${e.message}")
                delay(BROADCAST_INTERVAL_MS)
            }
        }
    }

    /**
     * Handle incoming discovery messages from other devices.
     */
    private fun handleDiscoveryMessage(message: String, sender: InetAddress) {
        // Parse and respond to discovery protocol
        // This is where you'd handle pairing requests from parent device
        when {
            message.startsWith("KOVA_DISCOVER:") -> {
                val childId = message.removePrefix("KOVA_DISCOVER:")
                Log.d(TAG, "Discovery request from child: $childId at $sender")
                // Notify Flutter layer of discovered device
                notifyDiscoveryEvent("discovered", childId, sender.hostAddress)
            }
            message.startsWith("KOVA_PAIR_REQUEST:") -> {
                val requestData = message.removePrefix("KOVA_PAIR_REQUEST:")
                Log.d(TAG, "Pair request: $requestData from $sender")
                notifyDiscoveryEvent("pair_request", requestData, sender.hostAddress)
            }
        }
    }

    /**
     * Build device info string for broadcast.
     */
    private fun buildDeviceInfo(): String {
        val prefs = getSharedPreferences("com.example.kova", MODE_PRIVATE)
        val childId = prefs.getString("child_id", "unknown") ?: "unknown"
        val deviceName = android.os.Build.MODEL
        return "KOVA_ANNOUNCE:$childId:$deviceName"
    }

    /**
     * Send discovery event to Flutter via KovaChannelManager.
     */
    private fun notifyDiscoveryEvent(event: String, data: String, address: String) {
        val payload = mapOf(
            "event" to event,
            "data" to data,
            "address" to address,
            "timestamp" to System.currentTimeMillis()
        )
        KovaChannelManager.send("discovery", payload)
    }
}
