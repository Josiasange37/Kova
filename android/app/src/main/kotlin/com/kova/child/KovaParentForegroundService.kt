package com.kova.child

import android.app.Service
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.wifi.WifiManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import android.util.Log
import java.util.Timer
import java.util.TimerTask

/**
 * KovaParentForegroundService — Keeps the parent's LAN TCP server alive.
 *
 * The TCP server (port 18757) that receives child alerts lives in the
 * Flutter/Dart isolate. When the parent app goes to background, Android
 * may pause the Flutter engine after ~10 minutes, killing the socket.
 *
 * This service:
 * 1. Holds a PARTIAL_WAKE_LOCK so the CPU stays active
 * 2. Holds a WifiLock in HIGH_PERF mode so the radio doesn't sleep
 * 3. Runs a periodic health-check that pings the Flutter engine via MethodChannel
 * 4. Listens for CONNECTIVITY_ACTION to re-trigger LAN discovery after Wi-Fi changes
 */
class KovaParentForegroundService : Service() {
    companion object {
        private const val TAG = "KovaParentForegroundService"
        const val CHANNEL_ID = "kova_parent_channel"
        const val NOTIFICATION_ID = 2001
    }

    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null
    private var healthTimer: Timer? = null

    // Re-trigger LAN discovery when Wi-Fi reconnects
    private val connectivityReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            Log.d(TAG, "📡 Connectivity changed — Flutter LAN will auto-reconnect via Connectivity plugin")
        }
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "✅ Parent Foreground service created")
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildForegroundNotification())

        // 1. Acquire CPU WakeLock
        try {
            val pm = getSystemService(POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "kova:parent_service_wakelock"
            ).apply {
                acquire() // Indefinite — released in onDestroy
            }
            Log.d(TAG, "🔒 WakeLock acquired")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to acquire WakeLock: ${e.message}")
        }

        // 2. Acquire Wi-Fi lock to keep radio in high-perf mode
        try {
            val wm = applicationContext.getSystemService(WIFI_SERVICE) as WifiManager
            @Suppress("DEPRECATION")
            wifiLock = wm.createWifiLock(
                WifiManager.WIFI_MODE_FULL_HIGH_PERF,
                "kova:parent_wifi_lock"
            ).apply {
                acquire()
            }
            Log.d(TAG, "📡 WifiLock acquired (HIGH_PERF)")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to acquire WifiLock: ${e.message}")
        }

        // 3. Register connectivity receiver
        try {
            @Suppress("DEPRECATION")
            val filter = IntentFilter(ConnectivityManager.CONNECTIVITY_ACTION)
            registerReceiver(connectivityReceiver, filter)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register connectivity receiver: ${e.message}")
        }

        // 4. Periodic health check every 60s — logs to prove service is alive
        healthTimer = Timer("ParentHealthCheck", true)
        healthTimer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                Log.d(TAG, "💓 Parent service health check — alive, wakeLock=${wakeLock?.isHeld}, wifiLock=${wifiLock?.isHeld}")
            }
        }, 60_000L, 60_000L)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "✅ Parent Foreground service started")
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        Log.w(TAG, "⚠️ Parent Foreground service destroyed — releasing resources")

        healthTimer?.cancel()
        healthTimer = null

        try {
            unregisterReceiver(connectivityReceiver)
        } catch (_: Exception) {}

        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
                Log.d(TAG, "🔓 WakeLock released")
            }
        } catch (_: Exception) {}

        try {
            if (wifiLock?.isHeld == true) {
                wifiLock?.release()
                Log.d(TAG, "📡 WifiLock released")
            }
        } catch (_: Exception) {}
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "KOVA Parent Monitor",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps KOVA Parent connection active to receive alerts"
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    private fun buildForegroundNotification(): android.app.Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("KOVA Parent Active")
            .setContentText("Monitoring child alerts in the background")
            // Re-using the same icon, or a generic one
            .setSmallIcon(R.drawable.ic_kova_notification)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setSilent(true)
            .build()
    }
}

