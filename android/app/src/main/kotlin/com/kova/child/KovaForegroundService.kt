package com.kova.child

import android.app.Service
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.admin.DevicePolicyManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.localbroadcastmanager.content.LocalBroadcastManager

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
        const val CHANNEL_ID = "kova_protection_channel"
        const val NOTIFICATION_ID = 1001
        const val ACTION_REMOTE_UNLOCK = "com.kova.ACTION_REMOTE_UNLOCK"
        const val ACTION_BLOCK_APP = "com.kova.ACTION_BLOCK_APP"
        const val EXTRA_UNLOCK_PACKAGE = "unlock_package"
        const val EXTRA_BLOCK_PACKAGE = "block_package"
        const val EXTRA_BLOCK_REASON = "block_reason"

        // ─── Watchdog reduced to 10 seconds ──────────────────────────────────
        // 30s was too wide — child had 30s of unmonitored activity after disabling services.
        // 10s battery impact is negligible since checkServiceHealth() does no network I/O.
        private const val WATCHDOG_INTERVAL_MS = 10_000L
        private const val PREFS_NAME = "com.example.kova"
    }

    // ─── Remote Unlock Receiver ───────────────────────────────────────────────
    // Handles unlock commands sent via FCM/WebSocket even when Flutter engine is dead.
    // This is the correct layer for unlock — not MainActivity MethodChannel which
    // requires an active Flutter engine and fails on backgrounded/low-RAM devices.
    private val remoteUnlockReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == ACTION_REMOTE_UNLOCK) {
                val pkg = intent.getStringExtra(EXTRA_UNLOCK_PACKAGE)
                handleRemoteUnlock(pkg)
            }
        }
    }

    private var isRunning = false
    private val handler = Handler(Looper.getMainLooper())

    // ── Track previous states to only alert on transitions ──
    private var prevAccessibility = false
    private var prevNotifListener = false
    private var prevKeyboard = false
    private var prevDeviceAdmin = false

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
        startForeground(NOTIFICATION_ID, buildForegroundNotification())

        // Register remote unlock receiver
        registerReceiver(
            remoteUnlockReceiver,
            IntentFilter(ACTION_REMOTE_UNLOCK),
            // Android 13+ requires RECEIVER_NOT_EXPORTED for internal broadcasts
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU)
                RECEIVER_NOT_EXPORTED else 0
        )

        checkSafeMode()
        handler.post(watchdogRunnable)
    }

    // ─── Android 13+ Background Survival ─────────────────────────────────────
    // START_STICKY ensures the OS restarts the service after killing it.
    // On Android 13+ the OS is more aggressive about killing background services.
    // The foreground notification + BOOT_COMPLETED receiver together keep KOVA alive.
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "✅ Foreground service started")

        // Handle block app action
        if (intent?.action == ACTION_BLOCK_APP) {
            val pkg = intent.getStringExtra(EXTRA_BLOCK_PACKAGE)
            val reason = intent.getStringExtra(EXTRA_BLOCK_REASON) ?: "App is blocked for your safety"
            if (pkg != null) {
                Log.d(TAG, "[OVERLAY PIPELINE] Service launching block overlay for: $pkg")
                launchBlockOverlay(pkg, reason)
            }
        }

        // Handle remote unlock action
        if (intent?.action == ACTION_REMOTE_UNLOCK) {
            val pkg = intent.getStringExtra(EXTRA_UNLOCK_PACKAGE)
            handleRemoteUnlock(pkg)
        }

        // Re-post watchdog in case the service was restarted mid-cycle
        handler.removeCallbacks(watchdogRunnable)
        handler.post(watchdogRunnable)
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        Log.w(TAG, "⚠️ Foreground service destroyed — scheduling restart")
        handler.removeCallbacks(watchdogRunnable)
        unregisterReceiver(remoteUnlockReceiver)

        // Immediately reschedule restart
        val restartIntent = Intent(applicationContext, KovaForegroundService::class.java)
        startService(restartIntent)
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // Reschedule restart when app is swiped from recents
        val restartIntent = Intent(applicationContext, KovaForegroundService::class.java)
        restartIntent.setPackage(packageName)
        val pendingIntent = PendingIntent.getService(
            this, 1, restartIntent,
            PendingIntent.FLAG_ONE_SHOT or
            PendingIntent.FLAG_IMMUTABLE
        )
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
        alarmManager.set(
            android.app.AlarmManager.ELAPSED_REALTIME,
            SystemClock.elapsedRealtime() + 1000,
            pendingIntent
        )
        super.onTaskRemoved(rootIntent)
    }

    // ─── Notification Channel (required Android 8+) ───────────────────────────
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "KOVA Child Protection",
                NotificationManager.IMPORTANCE_LOW // Low = no sound, but persistent
            ).apply {
                description = "Keeps KOVA protection active"
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    private fun buildForegroundNotification(): android.app.Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("KOVA Protection Active")
            .setContentText("Your device is being monitored for safety")
            .setSmallIcon(R.drawable.ic_kova_notification)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true) // Cannot be swiped away
            .setSilent(true)
            .build()
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
            // Show high-priority local notification to child device to re-enable (DIRECTIVE 3)
            showReEnableAccessibilityNotification()
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

        // ─── ADB / USB Debugging Detection ───────────────────────────────────
        // ADB uninstall bypasses all AccessibilityService-based anti-uninstall logic.
        // Alert parent immediately if USB debugging is turned on.
        val adbEnabled = Settings.Global.getInt(
            contentResolver, Settings.Global.ADB_ENABLED, 0
        ) == 1
        if (adbEnabled) {
            sendTamperAlert("adb_enabled", "USB debugging (ADB) is active on child device")
        }

        // Update previous states
        prevAccessibility = accOk
        prevNotifListener = notifOk
        prevKeyboard = kbOk
        prevDeviceAdmin = adminOk

        Log.d(TAG, "🩺 Watchdog: acc=$accOk notif=$notifOk kb=$kbOk admin=$adminOk adb=$adbEnabled")
    }

    // ─── Safe Mode Detection ──────────────────────────────────────────────────
    // Safe Mode disables all third-party services including AccessibilityService,
    // making KOVA completely blind. Detect and alert parent immediately on boot.
    private fun checkSafeMode() {
        // Safe mode flag is set in system properties on boot
        val safeMode = packageManager.isSafeMode

        if (safeMode) {
            sendTamperAlert(
                "safe_mode_boot",
                "Device was booted in Safe Mode — all KOVA protections are disabled"
            )
            // Schedule a persistent notification so it's visible on screen
            showSafeModeWarningNotification()
        }
    }

    private fun showSafeModeWarningNotification() {
        val nm = getSystemService(NotificationManager::class.java)
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("⚠️ KOVA Protection Disabled")
            .setContentText("Device is in Safe Mode. Child protections are inactive.")
            .setSmallIcon(R.drawable.ic_kova_notification)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setOngoing(true)
            .build()
        nm.notify(1002, notification)
    }

    /// Show notification when accessibility service is disabled (EMUI / Huawei workaround)
    /// Tapping notification opens accessibility settings to re-enable (DIRECTIVE 3)
    private fun showReEnableAccessibilityNotification() {
        Log.d(TAG, "[WATCHDOG] Showing re-enable accessibility notification")

        // Create intent to open accessibility settings
        val settingsIntent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, settingsIntent, PendingIntent.FLAG_IMMUTABLE
        )

        val nm = getSystemService(NotificationManager::class.java)
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("🛡️ KOVA needs your attention")
            .setContentText("Tap to re-enable protection — accessibility service was turned off")
            .setSmallIcon(R.drawable.ic_kova_notification)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(pendingIntent)
            .build()

        nm.notify(1003, notification)
        Log.d(TAG, "[WATCHDOG] Re-enable accessibility notification shown")
    }

    // ─── Remote Unlock Handler ─────────────────────────────────────────────────
    // Public method called by MainActivity or broadcast receiver to handle unlock
    fun handleRemoteUnlock(packageName: String?) {
        // Broadcast to BlockOverlayActivity (if it's open) via LocalBroadcast
        val unlockIntent = Intent("com.kova.HIDE_OVERLAY").apply {
            if (packageName != null) putExtra("package", packageName)
        }
        LocalBroadcastManager.getInstance(this).sendBroadcast(unlockIntent)
    }

    // ─── Block Overlay Launcher ──────────────────────────────────────────────
    // Launches the block overlay from the service layer so it works even when
    // the Flutter engine/MainActivity are dead (background monitoring).
    private fun launchBlockOverlay(packageName: String, reason: String = "App is blocked for your safety") {
        try {
            val intent = Intent(this, BlockOverlayActivity::class.java).apply {
                putExtra("blocked_package", packageName)
                putExtra("reason", reason)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            startActivity(intent)
            Log.d(TAG, "[OVERLAY PIPELINE] Block overlay launched for $packageName from ForegroundService")
        } catch (e: Exception) {
            Log.e(TAG, "[OVERLAY PIPELINE] Failed to launch overlay from service: ${e.message}")
        }
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

}
