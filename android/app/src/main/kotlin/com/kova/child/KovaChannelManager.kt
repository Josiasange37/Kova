package com.kova.child

import android.util.Log
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.FlutterEngine

/**
 * KovaChannelManager — Singleton for all native → Flutter communication.
 *
 * Three channels (matching Dart side):
 *   'com.kova.child/notifications'  → incoming messages from NotificationListener
 *   'com.kova.child/keyboard'       → outgoing text from InputMethodService
 *   'com.kova.child/accessibility'  → metadata from AccessibilityService
 *
 * Services call KovaChannelManager.send(channelKey, payload) and
 * this class handles queueing if the engine isn't ready yet.
 */
object KovaChannelManager {

    private const val TAG = "KovaChannelManager"

    // Channel names — must match Dart MonitoringBridge
    private const val CHANNEL_NOTIFICATIONS = "com.kova.child/notifications"
    private const val CHANNEL_KEYBOARD      = "com.kova.child/keyboard"
    private const val CHANNEL_ACCESSIBILITY = "com.kova.child/accessibility"

    // Flutter channel instances (set when engine is available)
    private var notificationsChannel: MethodChannel? = null
    private var keyboardChannel: MethodChannel? = null
    private var accessibilityChannel: MethodChannel? = null

    // Queue for messages sent before the engine is ready
    private val pendingMessages = mutableListOf<Pair<String, Map<String, Any?>>>()
    private var isReady = false

    /**
     * Register channels once the FlutterEngine is ready.
     * Called from MainActivity.configureFlutterEngine()
     */
    fun register(engine: FlutterEngine) {
        val messenger = engine.dartExecutor.binaryMessenger

        notificationsChannel = MethodChannel(messenger, CHANNEL_NOTIFICATIONS)
        keyboardChannel      = MethodChannel(messenger, CHANNEL_KEYBOARD)
        accessibilityChannel = MethodChannel(messenger, CHANNEL_ACCESSIBILITY)

        isReady = true
        Log.d(TAG, "✅ Channels registered (${pendingMessages.size} pending)")

        // Flush pending messages
        val copy = pendingMessages.toList()
        pendingMessages.clear()
        for ((key, payload) in copy) {
            send(key, payload)
        }
    }

    /**
     * Unregister channels (when engine is detached)
     */
    fun unregister() {
        isReady = false
        notificationsChannel = null
        keyboardChannel = null
        accessibilityChannel = null
        Log.d(TAG, "❌ Channels unregistered")
    }

    /**
     * Send a payload to Flutter.
     *
     * @param channelKey One of: "notifications", "keyboard", "accessibility"
     * @param payload    Map of key-value data
     */
    fun send(channelKey: String, payload: Map<String, Any?>) {
        if (!isReady) {
            // Queue up to 100 messages while engine initialises
            if (pendingMessages.size < 100) {
                pendingMessages.add(channelKey to payload)
            }
            return
        }

        val channel = when (channelKey) {
            "notifications" -> notificationsChannel
            "keyboard"      -> keyboardChannel
            "accessibility" -> accessibilityChannel
            else -> {
                Log.e(TAG, "Unknown channel key: $channelKey")
                return
            }
        }

        if (channel == null) {
            Log.e(TAG, "Channel $channelKey is null")
            return
        }

        try {
            channel.invokeMethod("onData", payload)
        } catch (e: Exception) {
            Log.e(TAG, "Error sending on $channelKey: ${e.message}")
        }
    }
}
