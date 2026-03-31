package com.kova.child

import android.app.Service
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * KovaForegroundService — Persistent background protection
 *
 * Runs continuously to:
 * - Monitor accessibility events
 * - Broadcast alerts
 * - Keep KOVA active even when app is closed
 * - Survives app uninstall attempts (device admin)
 */
class KovaForegroundService : Service() {
    companion object {
        private const val TAG = "KovaForegroundService"
        private const val CHANNEL_ID = "kova_protection"
        private const val NOTIFICATION_ID = 1
    }

    private var isRunning = false

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Foreground service created")
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "Foreground service started")
        
        if (!isRunning) {
            isRunning = true
            startForegroundNotification()
        }

        return START_STICKY // Restart if killed
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "Foreground service destroyed")
        isRunning = false
        
        // Attempt to restart
        val restartIntent = Intent(this, KovaForegroundService::class.java)
        startService(restartIntent)
    }

    /**
     * Create and start foreground notification
     */
    private fun startForegroundNotification() {
        try {
            val notification = NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("KOVA Protection Active")
                .setContentText("Monitoring for child safety")
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setOngoing(true)
                .build()

            startForeground(NOTIFICATION_ID, notification)
            Log.d(TAG, "Foreground notification started")
        } catch (e: Exception) {
            Log.e(TAG, "Error starting foreground notification: ${e.message}")
        }
    }

    /**
     * Create notification channel (Android 8+)
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "KOVA Protection",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Child safety monitoring"
                setShowBadge(false)
            }

            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
            Log.d(TAG, "Notification channel created")
        }
    }

    /**
     * Post an alert notification
     */
    fun postAlertNotification(title: String, message: String, severity: String) {
        try {
            val importance = when (severity) {
                "critical" -> NotificationManager.IMPORTANCE_MAX
                "high" -> NotificationManager.IMPORTANCE_HIGH
                "medium" -> NotificationManager.IMPORTANCE_DEFAULT
                else -> NotificationManager.IMPORTANCE_LOW
            }

            val channel = NotificationChannel(
                "kova_alerts",
                "KOVA Alerts",
                importance
            ).apply {
                description = "Child safety alerts"
            }

            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)

            val notification = NotificationCompat.Builder(this, "kova_alerts")
                .setContentTitle(title)
                .setContentText(message)
                .setSmallIcon(android.R.drawable.ic_dialog_alert)
                .setAutoCancel(true)
                .setPriority(importance - 1)
                .build()

            manager.notify(System.currentTimeMillis().toInt(), notification)
            Log.d(TAG, "Alert notification posted: $title")
        } catch (e: Exception) {
            Log.e(TAG, "Error posting alert notification: ${e.message}")
        }
    }

    /**
     * Check if a specific app is currently in foreground
     */
    fun isForegroundApp(packageName: String): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                // API 29+: Use ActivityManager
                val manager = getSystemService(android.app.ActivityManager::class.java)
                val tasks = manager.appTasks
                if (tasks.isNotEmpty()) {
                    tasks[0].taskInfo.topActivity?.packageName == packageName
                } else {
                    false
                }
            } else {
                // Fallback for older versions
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking foreground app: ${e.message}")
            false
        }
    }

    /**
     * Monitor service health and restart if needed
     */
    fun ensureRunning() {
        if (!isRunning) {
            Log.d(TAG, "Service not running, restarting...")
            startForegroundNotification()
            isRunning = true
        }
    }
}
