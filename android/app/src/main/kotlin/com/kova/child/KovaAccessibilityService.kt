package com.kova.child

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.view.accessibility.AccessibilityEvent
import android.util.Log

/**
 * KovaAccessibilityService — Main accessibility service for child device monitoring
 * 
 * Monitors:
 * - All text input in messaging apps (WhatsApp, SMS, etc.)
 * - Images shared in apps
 * - User interactions and app launches
 * 
 * Sends detected threats to Flutter via MethodChannel for analysis
 */
class KovaAccessibilityService : AccessibilityService() {
    companion object {
        private const val TAG = "KovaAccessibilityService"
        private const val PREFS_NAME = "com.example.kova"
        
        // Monitored apps package names
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
    private val messageBuffer = mutableMapOf<String, MutableList<String>>()

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d(TAG, "Accessibility Service connected")
        
        // Read child ID from preferences
        val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        childId = prefs.getString("child_id", null)
        
        // Configure accessibility service
        val info = AccessibilityServiceInfo()
        info.apply {
            eventTypes = AccessibilityEvent.TYPES_ALL_MASK
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            notificationTimeout = 100
            packageNames = MONITORED_APPS.toTypedArray()
        }
        setServiceInfo(info)
        
        // Mark as enabled
        prefs.edit().putBoolean("accessibility_enabled", true).apply()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || childId == null) return
        
        val source = event.source ?: return
        val packageName = event.packageName?.toString() ?: return
        
        // Only process monitored apps
        if (!MONITORED_APPS.contains(packageName)) return
        
        when (event.eventType) {
            // Text input detected in message field
            AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED -> {
                handleTextInput(event, packageName)
            }
            
            // App window changed (conversation opened)
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                handleWindowChange(event, packageName)
            }
            
            // Button/control activated (send message)
            AccessibilityEvent.TYPE_VIEW_CLICKED -> {
                handleViewClicked(event, packageName)
            }
            
            // Content changed (new message received)
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> {
                handleContentChanged(event, packageName)
            }
        }
        
        source.recycle()
    }

    override fun onInterrupt() {
        Log.d(TAG, "Accessibility Service interrupted")
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "Accessibility Service destroyed")
        
        val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        prefs.edit().putBoolean("accessibility_enabled", false).apply()
    }

    /**
     * Handle text input in message fields
     * Extract: text content, sender info, timestamp
     */
    private fun handleTextInput(event: AccessibilityEvent, packageName: String) {
        try {
            val text = event.text?.joinToString() ?: ""
            if (text.isEmpty()) return
            
            // Buffer the message
            messageBuffer.getOrPut(packageName) { mutableListOf() }.add(text)
            
            Log.d(TAG, "Text input detected: $text from $packageName")
            
            // Send to Flutter for real-time analysis
            sendMessageToFlutter(
                childId = childId ?: "unknown",
                app = packageName,
                messageText = text,
                senderName = null, // Accessibility API doesn't provide sender info easily
                imagePaths = emptyList()
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error handling text input: ${e.message}")
        }
    }

    /**
     * Handle window state changes
     * Used to detect conversation opens for batch analysis
     */
    private fun handleWindowChange(event: AccessibilityEvent, packageName: String) {
        try {
            val className = event.className?.toString() ?: return
            
            // Detect conversation window opens
            if (className.contains("ConversationList") || 
                className.contains("ChatActivity") ||
                className.contains("Message")) {
                
                // Clear buffer for new conversation
                val conversationMessages = messageBuffer.remove(packageName) ?: mutableListOf()
                
                if (conversationMessages.isNotEmpty()) {
                    Log.d(TAG, "Conversation detected with ${conversationMessages.size} messages")
                    
                    // Send conversation for analysis
                    sendConversationToFlutter(
                        childId = childId ?: "unknown",
                        app = packageName,
                        senderName = null,
                        messages = conversationMessages,
                    )
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error handling window change: ${e.message}")
        }
    }

    /**
     * Handle view clicked events
     * Detect send button, delete button, etc.
     */
    private fun handleViewClicked(event: AccessibilityEvent, packageName: String) {
        try {
            val text = event.text?.joinToString() ?: ""
            
            // Detect "Send" button or similar
            if (text.toLowerCase().contains("send")) {
                Log.d(TAG, "Send action detected in $packageName")
                // Message sent - clear current buffer
                messageBuffer.remove(packageName)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error handling view clicked: ${e.message}")
        }
    }

    /**
     * Handle content changes
     * Detect new incoming messages
     */
    private fun handleContentChanged(event: AccessibilityEvent, packageName: String) {
        // Incoming messages detected here - could trigger analysis
        // For now, rely on TYPE_VIEW_TEXT_CHANGED
    }

    /**
     * Send single message to Flutter for analysis
     */
    private fun sendMessageToFlutter(
        childId: String,
        app: String,
        messageText: String,
        senderName: String?,
        imagePaths: List<String>
    ) {
        try {
            // Create intent to call Flutter via MethodChannel
            val intent = Intent("com.kova.accessibility.MESSAGE").apply {
                putExtra("childId", childId)
                putExtra("app", app)
                putExtra("messageText", messageText)
                putExtra("senderName", senderName)
                putExtra("imagePaths", imagePaths.toTypedArray())
            }
            sendBroadcast(intent)
            
            Log.d(TAG, "Message sent to Flutter: $messageText")
        } catch (e: Exception) {
            Log.e(TAG, "Error sending message to Flutter: ${e.message}")
        }
    }

    /**
     * Send conversation batch to Flutter for analysis
     */
    private fun sendConversationToFlutter(
        childId: String,
        app: String,
        senderName: String?,
        messages: List<String>
    ) {
        try {
            // Create intent to call Flutter
            val intent = Intent("com.kova.accessibility.CONVERSATION").apply {
                putExtra("childId", childId)
                putExtra("app", app)
                putExtra("senderName", senderName)
                putExtra("messages", messages.toTypedArray())
            }
            sendBroadcast(intent)
            
            Log.d(TAG, "Conversation sent to Flutter: ${messages.size} messages")
        } catch (e: Exception) {
            Log.e(TAG, "Error sending conversation to Flutter: ${e.message}")
        }
    }

    /**
     * Get app name from package name for display
     */
    private fun getAppName(packageName: String): String {
        return try {
            val ai = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(ai).toString()
        } catch (e: Exception) {
            packageName
        }
    }
}
