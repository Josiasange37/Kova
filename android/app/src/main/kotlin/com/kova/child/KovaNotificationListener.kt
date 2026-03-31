package com.kova.child

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.content.Intent
import android.util.Log

/**
 * KovaNotificationListener — Monitors notifications from messaging apps
 * 
 * Extracts text and sender info from incoming notifications
 * (WhatsApp, etc.) while the apps are in the background or device is locked.
 */
class KovaNotificationListener : NotificationListenerService() {
    companion object {
        private const val TAG = "KovaNotificationListener"
        private const val PREFS_NAME = "com.example.kova"
        
        // Monitored apps for notifications
        private val MONITORED_APPS = setOf(
            "com.whatsapp",
            "com.whatsapp.w4b",
            "com.instagram.android",
            "com.snapchat.android",
            "com.tiktok.android",
            "com.android.mms",
            "com.google.android.apps.messaging",
        )
    }

    private var childId: String? = null

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d(TAG, "Notification Listener connected")
        
        // Read child ID
        val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        childId = prefs.getString("child_id", null)
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null || childId == null) return
        
        val packageName = sbn.packageName
        if (!MONITORED_APPS.contains(packageName)) return
        
        val notification = sbn.notification
        val extras = notification.extras
        
        val title = extras.getString("android.title") ?: ""
        val text = extras.getCharSequence("android.text")?.toString() ?: ""
        
        // Ignore "checking for new messages" and empty texts
        if (text.isEmpty() || text.contains("Checking for new messages") || text.contains("new messages")) return
        
        Log.d(TAG, "Notification from $packageName: $title - $text")
        
        // Send to Flutter for analysis
        sendMessageToFlutter(
            childId = childId ?: "unknown",
            app = packageName,
            messageText = text,
            senderName = title,
            imagePaths = emptyList()
        )
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        // We only care about posted notifications
    }

    private fun sendMessageToFlutter(
        childId: String,
        app: String,
        messageText: String,
        senderName: String?,
        imagePaths: List<String>
    ) {
        try {
            val intent = Intent("com.kova.notification.MESSAGE").apply {
                putExtra("childId", childId)
                putExtra("app", app)
                putExtra("messageText", messageText)
                putExtra("senderName", senderName)
                putExtra("imagePaths", imagePaths.toTypedArray())
            }
            sendBroadcast(intent)
            Log.d(TAG, "Notification sent to Flutter")
        } catch (e: Exception) {
            Log.e(TAG, "Error sending notification to Flutter: ${e.message}")
        }
    }
}
