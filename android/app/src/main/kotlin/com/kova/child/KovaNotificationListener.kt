package com.kova.child

import android.app.Notification
import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

/**
 * MODULE 1 — KovaNotificationListener
 *
 * Standard NotificationListenerService.
 * Captures incoming message previews from WhatsApp and other messaging apps.
 * Tags every message with direction = "incoming".
 * Sends structured data to Flutter via the shared FlutterEngine MethodChannel.
 */
class KovaNotificationListener : NotificationListenerService() {

    companion object {
        private const val TAG = "KovaNotificationListener"
        private const val PREFS_NAME = "com.example.kova"

        // Apps whose notifications we capture
        private val MONITORED_APPS = setOf(
            "com.whatsapp",
            "com.whatsapp.w4b",
            "com.facebook.katana",          // Facebook
            "com.facebook.orca",            // Messenger
            "com.facebook.mlite",           // Messenger Lite
            "com.instagram.android",
            "com.snapchat.android",
            "com.zhiliaoapp.musically",     // TikTok
            "com.ss.android.ugc.trill",     // TikTok (alt package)
            "org.telegram.messenger",
            "org.telegram.messenger.web",   // Telegram X
            "org.thoughtcrime.securesms",   // Signal
            "com.twitter.android",          // Twitter/X
            "com.twitter.android.lite",     // Twitter Lite
            "com.discord",                  // Discord
            "com.skype.raider",             // Skype
            "com.viber.voip",               // Viber
            "com.google.android.apps.messaging", // Google Messages
            "com.android.mms",              // Default SMS
            "com.samsung.android.messaging", // Samsung Messages
        )

        // Noise phrases to ignore
        private val NOISE_PHRASES = listOf(
            "Checking for new messages",
            "new messages",
            "Searching for",
            "Waiting for this message",
            "End-to-end encrypted",
            "Backup in progress",
            "messages from",
            "Missed voice call",
            "Missed video call",
        )
    }

    private var childId: String? = null

    // ─────────────────────────────────────────────
    // Lifecycle
    // ─────────────────────────────────────────────

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d(TAG, "✅ NotificationListener connected")

        val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        childId = prefs.getString("child_id", null)
        prefs.edit().putBoolean("notification_listener_enabled", true).apply()
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        Log.d(TAG, "❌ NotificationListener disconnected")

        val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        prefs.edit().putBoolean("notification_listener_enabled", false).apply()
    }

    // ─────────────────────────────────────────────
    // Notification handling
    // ─────────────────────────────────────────────

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return

        val packageName = sbn.packageName ?: return
        if (!MONITORED_APPS.contains(packageName)) return

        val notification = sbn.notification ?: return
        val extras = notification.extras ?: return

        // Extract title (sender or group name) and text (message content)
        val title = extras.getString(Notification.EXTRA_TITLE) ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""

        // Skip system / noise notifications
        if (text.isEmpty()) return
        if (NOISE_PHRASES.any { text.contains(it, ignoreCase = true) }) return

        // Try to get WhatsApp message lines (group chat support)
        val messageLines = extractMessageLines(extras)

        // Build conversation-id from sender + app
        val conversationId = "${packageName}_${title.hashCode()}"

        Log.d(TAG, "📩 [$packageName] $title: $text")

        // Send to Flutter via shared engine
        val payload = mapOf(
            "app"             to packageName,
            "text"            to text,
            "senderName"      to title,
            "direction"       to "incoming",
            "source"          to "notification",
            "conversationId"  to conversationId,
            "timestamp"       to System.currentTimeMillis(),
            "childId"         to (childId ?: "unknown"),
            "messageLines"    to messageLines,
        )

        KovaChannelManager.send("notifications", payload)
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        // We only care about posted notifications
    }

    // ─────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────

    /**
     * Extract individual lines from a WhatsApp MessagingStyle notification.
     * Returns all visible message texts or an empty list.
     */
    private fun extractMessageLines(extras: Bundle): List<String> {
        try {
            // EXTRA_TEXT_LINES contains the stacked preview lines
            val lines = extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)
            if (lines != null && lines.isNotEmpty()) {
                return lines.mapNotNull { it?.toString() }
            }

            // MessagingStyle messages (API 24+)
            val msgs = extras.getParcelableArray(Notification.EXTRA_MESSAGES)
            if (msgs != null && msgs.isNotEmpty()) {
                return msgs.mapNotNull { bundle ->
                    (bundle as? Bundle)?.getCharSequence("text")?.toString()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error extracting message lines: ${e.message}")
        }
        return emptyList()
    }
}
