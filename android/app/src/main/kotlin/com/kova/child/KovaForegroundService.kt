package com.kova.child

import android.app.Service
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * KovaForegroundService — Persistent background protection
 *
 * Runs continuously to:
 * - Keep KOVA alive even when app is closed (START_STICKY)
 * - Periodic health-check watchdog: verifies accessibility, notification
 *   listener, keyboard, and device admin are all still active
 * - Sends tamper alerts to the parent if any service is disabled
 * - Survives process kill via self-restart in onDestroy + onTaskRemoved
 */
class KovaForegroundService : Service() {
    companion object {
        private const val TAG = "KovaForegroundService"
        private const val CHANNEL_ID = "kova_protection"
        private const val NOTIFICATION_ID = 1
        private const val WATCHDOG_INTERVAL_MS = 30_000L  // Check every 30 seconds
        private const val PREFS_NAME = "com.example.kova"
    }

    private var isRunning = false
    private val handler = Handler(Looper.getMainLooper())

    // ── Track previous states to only alert on transitions ──
    private var prevAccessibility = true
    private var prevNotifListener = true
    private var prevKeyboard = true
    private var prevDeviceAdmin = true

    // ─────────────────────────────────────────────
    // Watchdog runnable — checks all services every 30s
    // ─────────────────────────────────────────────

    private val watchdogRunnable = object : Runnable {
        override fun run() {
            try {
                checkServiceHealth()
            } catch (e: Exception) {
                Log.e(TAG, "Watchdog error: ${e.message}")
            }
            handler.postDelayed(this, WATCHDOG_INTERVAL_MS)
        }
    }

    // ─────────────────────────────────────────────
    // Lifecycle
    // ─────────────────────────────────────────────

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "✅ Foreground service created")
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "✅ Foreground service started")

        if (!isRunning) {
            isRunning = true
            startForegroundNotification()
            // Start watchdog
            handler.postDelayed(watchdogRunnable, WATCHDOG_INTERVAL_MS)
        }

        return START_STICKY // Restart if killed by system
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        Log.w(TAG, "⚠️ Foreground service destroyed — scheduling restart")
        isRunning = false
        handler.removeCallbacks(watchdogRunnable)

        // Self-restart: schedule via broadcast
        scheduleRestart()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        Log.w(TAG, "⚠️ Task removed — scheduling restart")
        scheduleRestart()
    }

    // ─────────────────────────────────────────────
    // Foreground notification
    // ─────────────────────────────────────────────

    private fun startForegroundNotification() {
        try {
            val notification = NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("Protection Active")
                .setContentText("Your device is being monitored for safety")
                .setSmallIcon(android.R.drawable.ic_lock_lock)
                .setPriority(NotificationCompat.PRIORITY_MIN)
                .setOngoing(true)
                .setSilent(true)
                .build()

            startForeground(NOTIFICATION_ID, notification)
            Log.d(TAG, "Foreground notification started")
        } catch (e: Exception) {
            Log.e(TAG, "Error starting foreground notification: ${e.message}")
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "KOVA Protection",
                NotificationManager.IMPORTANCE_MIN
            ).apply {
                description = "Child safety monitoring"
                setShowBadge(false)
                setSound(null, null)
            }

            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    // ─────────────────────────────────────────────
    // Watchdog — service health checks
    // ─────────────────────────────────────────────

    private fun checkServiceHealth() {
        val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        val isEnabled = prefs.getBoolean("kova_enabled", false)
        if (!isEnabled) return  // Not configured as child device

        val accOk = isAccessibilityEnabled()
        val notifOk = isNotificationListenerEnabled()
        val kbOk = isKeyboardEnabled()
        val adminOk = isDeviceAdminActive()

        // ── Alert on state transitions (was OK → now disabled) ──

        if (prevAccessibility && !accOk) {
            Log.w(TAG, "🛡️ TAMPER: Accessibility service was disabled!")
            sendTamperAlert("accessibility_disabled", "Accessibility service was disabled")
        }
        if (prevNotifListener && !notifOk) {
            Log.w(TAG, "🛡️ TAMPER: Notification listener was disabled!")
            sendTamperAlert("notification_listener_disabled", "Notification listener was disabled")
        }
        if (prevKeyboard && !kbOk) {
            Log.w(TAG, "🛡️ TAMPER: KOVA keyboard was disabled!")
            sendTamperAlert("keyboard_disabled", "KOVA keyboard was disabled or switched")
        }
        if (prevDeviceAdmin && !adminOk) {
            Log.w(TAG, "🛡️ TAMPER: Device admin was deactivated!")
            sendTamperAlert("device_admin_disabled", "Device admin was deactivated")
        }

        // Update previous states
        prevAccessibility = accOk
        prevNotifListener = notifOk
        prevKeyboard = kbOk
        prevDeviceAdmin = adminOk

        Log.d(TAG, "🩺 Watchdog: acc=$accOk notif=$notifOk kb=$kbOk admin=$adminOk")
    }

    // ── Individual service checks ──

    private fun isAccessibilityEnabled(): Boolean {
        return try {
            val enabledServices = Settings.Secure.getString(
                contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            ) ?: ""
            enabledServices.contains(packageName)
        } catch (_: Exception) { false }
    }

    private fun isNotificationListenerEnabled(): Boolean {
        return try {
            val enabledListeners = Settings.Secure.getString(
                contentResolver,
                "enabled_notification_listeners"
            ) ?: ""
            enabledListeners.contains(packageName)
        } catch (_: Exception) { false }
    }

    private fun isKeyboardEnabled(): Boolean {
        return try {
            val imeId = "${packageName}/${KovaInputMethodService::class.java.canonicalName}"
            val currentIme = Settings.Secure.getString(
                contentResolver,
                Settings.Secure.DEFAULT_INPUT_METHOD
            ) ?: ""
            currentIme.contains(imeId)
        } catch (_: Exception) { false }
    }

    private fun isDeviceAdminActive(): Boolean {
        return try {
            val dpm = getSystemService(DEVICE_POLICY_SERVICE) as DevicePolicyManager
            dpm.isAdminActive(ComponentName(this, KovaDeviceAdmin::class.java))
        } catch (_: Exception) { false }
    }

    // ─────────────────────────────────────────────
    // Tamper alert — send to parent via channel
    // ─────────────────────────────────────────────

    private fun sendTamperAlert(type: String, message: String) {
        val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        val childId = prefs.getString("child_id", "unknown") ?: "unknown"

        val payload = mapOf(
            "event"     to "tamper_detected",
            "app"       to packageName,
            "type"      to type,
            "message"   to message,
            "timestamp" to System.currentTimeMillis(),
            "childId"   to childId,
        )
        KovaChannelManager.send("accessibility", payload)
    }

    // ─────────────────────────────────────────────
    // Self-restart on kill
    // ─────────────────────────────────────────────

    private fun scheduleRestart() {
        try {
            val restartIntent = Intent(this, KovaForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(restartIntent)
            } else {
                startService(restartIntent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to schedule restart: ${e.message}")
        }
    }
}
