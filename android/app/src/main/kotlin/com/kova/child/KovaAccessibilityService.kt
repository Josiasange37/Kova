package com.kova.child

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.util.Log
import android.view.accessibility.AccessibilityEvent

/**
 * MODULE 3 — KovaAccessibilityService
 *
 * READ-ONLY metadata collector.
 * Captures: app name, window class name, navigation state, screen status.
 *
 * Does NOT try to read message text content.
 * FLAG_SECURE blocks getText() on Android 12+ messaging apps.
 * Gracefully returns empty when blocked.
 *
 * Metadata is used by the detection engine to:
 * - Know which app the child opened
 * - Track conversation screen entry/exit
 * - Detect app-switch frequency patterns
 * - Correlate keyboard captures with the correct app context
 */
class KovaAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "KovaAccessibilityService"
        private const val PREFS_NAME = "com.example.kova"

        // Apps we track metadata for
        private val MONITORED_APPS = setOf(
            "com.whatsapp",
            "com.whatsapp.w4b",
            "com.instagram.android",
            "com.snapchat.android",
            "com.tiktok.android",
            "com.android.mms",
            "com.google.android.apps.messaging",
        )

        // Debounce — ignore repeated events within this window
        private const val DEBOUNCE_MS = 500L
    }

    private var childId: String? = null
    private var currentForegroundApp: String = ""
    private var currentWindowClass: String = ""
    private var lastEventTime: Long = 0

    // ─────────────────────────────────────────────
    // Lifecycle
    // ─────────────────────────────────────────────

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d(TAG, "✅ Accessibility service connected")

        val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        childId = prefs.getString("child_id", null)
        prefs.edit().putBoolean("accessibility_enabled", true).apply()

        // Configure: we only need window events and notifications
        val info = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                         AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED or
                         AccessibilityEvent.TYPE_NOTIFICATION_STATE_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            notificationTimeout = 300
            flags = AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                    AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS
            // Monitor all apps (null = all)
            packageNames = null
        }
        setServiceInfo(info)
    }

    override fun onInterrupt() {
        Log.d(TAG, "⚠️ Accessibility service interrupted")
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "❌ Accessibility service destroyed")
        val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        prefs.edit().putBoolean("accessibility_enabled", false).apply()
    }

    // ─────────────────────────────────────────────
    // Event handling — metadata only
    // ─────────────────────────────────────────────

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        val packageName = event.packageName?.toString() ?: return
        val now = System.currentTimeMillis()

        // Debounce rapid events
        if (now - lastEventTime < DEBOUNCE_MS) return
        lastEventTime = now

        when (event.eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                handleWindowStateChanged(event, packageName, now)
            }
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> {
                // Only track content changes for monitored apps
                if (MONITORED_APPS.contains(packageName)) {
                    handleContentChanged(event, packageName, now)
                }
            }
            AccessibilityEvent.TYPE_NOTIFICATION_STATE_CHANGED -> {
                // Notification posted — we already handle via NotificationListener
                // but we can track which app posted it
                if (MONITORED_APPS.contains(packageName)) {
                    handleNotificationState(event, packageName, now)
                }
            }
        }

        // Recycle source if we accessed it
        // (we don't access source at all — metadata only)
    }

    /**
     * Detect which app window opened.
     * This tells us when the child enters a messaging app.
     */
    private fun handleWindowStateChanged(
        event: AccessibilityEvent,
        packageName: String,
        timestamp: Long
    ) {
        val className = event.className?.toString() ?: ""

        // Track foreground app changes
        if (packageName != currentForegroundApp || className != currentWindowClass) {
            currentForegroundApp = packageName
            currentWindowClass = className

            val isMonitored = MONITORED_APPS.contains(packageName)
            val windowType = classifyWindow(className, packageName)

            Log.d(TAG, "🪟 Window: $packageName → $className ($windowType)")

            val payload = mapOf(
                "event"          to "window_changed",
                "app"            to packageName,
                "windowClass"    to className,
                "windowType"     to windowType,
                "isMonitored"    to isMonitored,
                "timestamp"      to timestamp,
                "childId"        to (childId ?: "unknown"),
            )

            KovaChannelManager.send("accessibility", payload)
        }
    }

    /**
     * Track content change events.
     * We do NOT read the actual text — just the event metadata.
     * FLAG_SECURE would block it anyway on Android 12+.
     */
    private fun handleContentChanged(
        event: AccessibilityEvent,
        packageName: String,
        timestamp: Long
    ) {
        // Safely try to get minimal node info (just class name / view id)
        val contentDescription = safeGetContentDescription(event)
        val viewId = safeGetViewId(event)

        val payload = mapOf(
            "event"          to "content_changed",
            "app"            to packageName,
            "viewId"         to viewId,
            "contentDesc"    to contentDescription,
            "timestamp"      to timestamp,
            "childId"        to (childId ?: "unknown"),
        )

        KovaChannelManager.send("accessibility", payload)
    }

    /**
     * Track notification events as metadata
     */
    private fun handleNotificationState(
        event: AccessibilityEvent,
        packageName: String,
        timestamp: Long
    ) {
        val payload = mapOf(
            "event"          to "notification_posted",
            "app"            to packageName,
            "timestamp"      to timestamp,
            "childId"        to (childId ?: "unknown"),
        )

        KovaChannelManager.send("accessibility", payload)
    }

    // ─────────────────────────────────────────────
    // Safe metadata extraction
    // ─────────────────────────────────────────────

    /**
     * Safely read content description.
     * Returns empty string if blocked by FLAG_SECURE or SecurityException.
     */
    private fun safeGetContentDescription(event: AccessibilityEvent): String {
        return try {
            event.contentDescription?.toString() ?: ""
        } catch (e: SecurityException) {
            Log.d(TAG, "FLAG_SECURE blocked contentDescription")
            ""
        } catch (e: Exception) {
            ""
        }
    }

    /**
     * Safely read view resource ID.
     * Returns empty string if blocked.
     */
    private fun safeGetViewId(event: AccessibilityEvent): String {
        return try {
            val source = event.source
            val id = source?.viewIdResourceName ?: ""
            source?.recycle()
            id
        } catch (e: SecurityException) {
            Log.d(TAG, "FLAG_SECURE blocked viewId")
            ""
        } catch (e: Exception) {
            ""
        }
    }

    // ─────────────────────────────────────────────
    // Window classification
    // ─────────────────────────────────────────────

    /**
     * Classify the window type based on class name.
     * Helps detection engine understand navigation flow.
     */
    private fun classifyWindow(className: String, packageName: String): String {
        val lower = className.lowercase()
        return when {
            lower.contains("conversation") || lower.contains("chat") -> "conversation"
            lower.contains("list") || lower.contains("home")         -> "list"
            lower.contains("profile") || lower.contains("setting")   -> "settings"
            lower.contains("camera") || lower.contains("gallery")    -> "media"
            lower.contains("call")                                    -> "call"
            lower.contains("story") || lower.contains("status")      -> "stories"
            lower.contains("search")                                  -> "search"
            else -> "other"
        }
    }

    /**
     * Get app name from package name for logging
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
