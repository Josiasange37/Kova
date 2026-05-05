package com.kova.child

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/**
 * MODULE 3 — KovaAccessibilityService (UPGRADED)
 *
 * FULL TEXT READING mode.
 * canRetrieveWindowContent = true (set in XML config)
 *
 * This service reads the UI widget tree text nodes from ALL apps.
 * FLAG_SECURE blocks screenshots — it does NOT block the accessibility
 * tree. This is by Android design (accessibility must work for
 * visually impaired users even in secure apps).
 *
 * Captures:
 * - Chat messages from messaging apps (WhatsApp, Facebook, Messenger,
 *   Telegram, Instagram, Snapchat, TikTok, Signal, etc.)
 * - Browser URLs and page titles (Chrome, Firefox, Brave, etc.)
 * - Incognito/Private mode browsing (URL bar is still readable)
 * - Search queries in Google, YouTube, etc.
 * - Text typed into any app's input fields
 *
 * Sends data to Flutter via KovaChannelManager on the
 * 'accessibility' channel with different event types.
 */
data class AppParsingRule(
    val packageName: String,
    val messageContainerId: String,
    val messageTextClass: String,
    val excludeRegex: String
)

class KovaAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "KovaAccessibilityService"
        private const val PREFS_NAME = "com.example.kova"

        // ═══════════════════════════════════════════
        // ALL monitored apps — messaging + social + browsers
        // ═══════════════════════════════════════════
        private val MESSAGING_APPS = setOf(
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

        private val BROWSER_APPS = setOf(
            "com.android.chrome",           // Chrome
            "com.chrome.beta",              // Chrome Beta
            "com.chrome.canary",            // Chrome Canary
            "com.google.android.googlequicksearchbox", // Google app
            "org.mozilla.firefox",          // Firefox
            "org.mozilla.firefox_beta",     // Firefox Beta
            "org.mozilla.fenix",            // Firefox Nightly
            "com.brave.browser",            // Brave
            "com.opera.browser",            // Opera
            "com.opera.mini.native",        // Opera Mini
            "com.microsoft.emmx",           // Edge
            "com.duckduckgo.mobile.android", // DuckDuckGo
            "com.sec.android.app.sbrowser", // Samsung Internet
            "com.kiwibrowser.browser",      // Kiwi Browser
            "com.UCMobile.intl",            // UC Browser
        )

        private val SEARCH_APPS = setOf(
            "com.google.android.youtube",   // YouTube
            "com.google.android.apps.searchlite", // Google Go
            "com.google.android.googlequicksearchbox",
        )

        // Combined set for quick lookup
        private val ALL_MONITORED_APPS = MESSAGING_APPS + BROWSER_APPS + SEARCH_APPS

        // Debounce — prevent flooding
        private const val DEBOUNCE_MS = 400L
        private const val TEXT_DEBOUNCE_MS = 1500L  // Longer debounce for text extraction
        private const val MAX_TEXT_LENGTH = 2000     // Limit extracted text size

        private var dynamicRules: List<AppParsingRule> = emptyList()

        fun updateRules(jsonString: String) {
            try {
                val array = org.json.JSONArray(jsonString)
                val newRules = mutableListOf<AppParsingRule>()
                for (i in 0 until array.length()) {
                    val obj = array.getJSONObject(i)
                    newRules.add(AppParsingRule(
                        packageName = obj.optString("packageName", ""),
                        messageContainerId = obj.optString("messageContainerId", ""),
                        messageTextClass = obj.optString("messageTextClass", "TextView"),
                        excludeRegex = obj.optString("excludeRegex", "")
                    ))
                }
                dynamicRules = newRules
                Log.d(TAG, "Applied ${newRules.size} dynamic rules")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to parse dynamic rules: ${e.message}")
            }
        }
    }

    private var childId: String? = null
    private var currentForegroundApp: String = ""
    private var currentWindowClass: String = ""
    private var lastEventTime: Long = 0
    private var lastTextExtractTime: Long = 0
    private var lastExtractedTextHash: Int = 0  // Avoid sending duplicate content

    // ─────────────────────────────────────────────
    // Lifecycle
    // ─────────────────────────────────────────────

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d(TAG, "✅ Accessibility service connected — FULL TEXT MODE")

        val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        childId = prefs.getString("child_id", null)
        prefs.edit().putBoolean("accessibility_enabled", true).apply()

        // Configure: full text reading + all event types
        val info = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                         AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED or
                         AccessibilityEvent.TYPE_NOTIFICATION_STATE_CHANGED or
                         AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            notificationTimeout = 200
            flags = AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                    AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS or
                    AccessibilityServiceInfo.FLAG_REQUEST_FILTER_KEY_EVENTS
            // Monitor ALL apps (null = everything)
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
    // Event handling — FULL TEXT + METADATA
    // ─────────────────────────────────────────────

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        val packageName = event.packageName?.toString() ?: return
        val now = System.currentTimeMillis()

        when (event.eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                // Debounce window events
                if (now - lastEventTime < DEBOUNCE_MS) return
                lastEventTime = now
                handleWindowStateChanged(event, packageName, now)
            }
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> {
                if (!isAppMonitored(packageName)) return
                // Debounce text extraction (expensive)
                if (now - lastTextExtractTime < TEXT_DEBOUNCE_MS) return
                lastTextExtractTime = now
                handleContentChanged(event, packageName, now)
            }
            AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED -> {
                if (!isAppMonitored(packageName)) return
                handleTextInputChanged(event, packageName, now)
            }
            AccessibilityEvent.TYPE_NOTIFICATION_STATE_CHANGED -> {
                if (isAppMonitored(packageName)) {
                    handleNotificationState(event, packageName, now)
                }
            }
        }
    }

    // ─────────────────────────────────────────────
    // Window state — app switch detection
    // ─────────────────────────────────────────────

    private fun handleWindowStateChanged(
        event: AccessibilityEvent,
        packageName: String,
        timestamp: Long
    ) {
        val className = event.className?.toString() ?: ""

        // ══════════════════════════════════════════
        // SELF-DEFENSE: Intercept uninstall attempts
        // ══════════════════════════════════════════
        if (detectUninstallAttempt(packageName, className, event)) {
            Log.w(TAG, "🛡️ UNINSTALL ATTEMPT BLOCKED — navigating home")
            goHome()
            sendTamperAlert("uninstall_attempt", "Child attempted to uninstall KOVA via $packageName")
            return  // Don't process further
        }

        // ══════════════════════════════════════════
        // SELF-DEFENSE: Intercept service disable attempts
        // ══════════════════════════════════════════
        if (detectServiceDisableAttempt(packageName, className, event)) {
            Log.w(TAG, "🛡️ SERVICE DISABLE ATTEMPT BLOCKED — navigating home")
            goHome()
            sendTamperAlert("service_disable_attempt", "Child attempted to disable KOVA services via Settings")
            return
        }

        if (packageName != currentForegroundApp || className != currentWindowClass) {
            currentForegroundApp = packageName
            currentWindowClass = className

            val isMonitored = isAppMonitored(packageName)
            val isBrowser = BROWSER_APPS.contains(packageName)
            val isMessaging = MESSAGING_APPS.contains(packageName)
            val windowType = classifyWindow(className, packageName)

            Log.d(TAG, "🪟 Window: $packageName → $className ($windowType)")

            val payload = mapOf(
                "event"          to "window_changed",
                "app"            to packageName,
                "windowClass"    to className,
                "windowType"     to windowType,
                "isMonitored"    to isMonitored,
                "isBrowser"      to isBrowser,
                "isMessaging"    to isMessaging,
                "timestamp"      to timestamp,
                "childId"        to (childId ?: "unknown"),
            )

            KovaChannelManager.send("accessibility", payload)

            // When entering a monitored app, do an immediate text extraction
            if (isMonitored) {
                extractAndSendVisibleText(packageName, "window_entry", timestamp)
            }
        }
    }

    // ─────────────────────────────────────────────
    // Self-defense helpers
    // ─────────────────────────────────────────────

    /**
     * Detect if the child is trying to uninstall KOVA.
     * Covers: Settings → Apps → KOVA app detail → Uninstall,
     *         Package installer dialogs,
     *         Third-party uninstaller apps.
     */
    private fun detectUninstallAttempt(packageName: String, className: String, event: AccessibilityEvent): Boolean {
        val myPackage = applicationContext.packageName
        val lowerClass = className.lowercase()

        // 1. Android package installer / uninstaller dialog
        if (packageName == "com.android.packageinstaller" ||
            packageName == "com.google.android.packageinstaller" ||
            packageName == "com.android.permissioncontroller") {
            // Check if the visible text mentions our app
            val nodeText = extractNodeTexts(event.source)
            val mentionsKova = nodeText.any {
                it.contains("kova", ignoreCase = true) ||
                it.contains(myPackage, ignoreCase = true)
            }
            if (mentionsKova) return true
        }

        // 2. Samsung/OEM uninstaller
        if (lowerClass.contains("uninstall") || lowerClass.contains("deleteapp")) {
            return true
        }

        // 3. Settings → App Info or Storage for our package
        if (isSettingsPackage(packageName)) {
            val nodeText = extractNodeTexts(event.source)
            val mentionsKova = nodeText.any {
                it.contains("kova", ignoreCase = true) ||
                it.contains(myPackage, ignoreCase = true)
            }
            
            if (mentionsKova) {
                // If it's explicitly the AppInfo activity
                if (lowerClass.contains("appinfo") || lowerClass.contains("installedappdetails")) {
                    return true
                }
                
                // Or if the screen contains danger keywords (Clear Data, Storage, Uninstall, Force Stop)
                val hasDangerKeywords = nodeText.any {
                    val txt = it.lowercase()
                    txt.contains("uninstall") || txt.contains("désinstaller") ||
                    txt.contains("clear data") || txt.contains("vider les données") || txt.contains("effacer les données") ||
                    txt.contains("storage") || txt.contains("stockage") ||
                    txt.contains("clear cache") || txt.contains("vider le cache") ||
                    txt.contains("force stop") || txt.contains("forcer l'arrêt")
                }
                
                if (hasDangerKeywords) return true
            }
        }

        return false
    }

    /**
     * Detect attempts to disable KOVA's accessibility service or notification listener.
     */
    private fun detectServiceDisableAttempt(packageName: String, className: String, event: AccessibilityEvent): Boolean {
        if (!isSettingsPackage(packageName)) return false
        val lowerClass = className.lowercase()

        // Check if in accessibility settings or notification listener settings
        val isServiceSettings = lowerClass.contains("accessibilitydetails") ||
                                lowerClass.contains("accessibilitysettings") ||
                                lowerClass.contains("notificationaccesssettings") ||
                                lowerClass.contains("notificationlistener")

        if (isServiceSettings) {
            val nodeText = extractNodeTexts(event.source)
            return nodeText.any {
                it.contains("kova", ignoreCase = true)
            }
        }

        return false
    }

    private fun isSettingsPackage(packageName: String): Boolean {
        return packageName == "com.android.settings" ||
               packageName == "com.samsung.android.app.settings" ||
               packageName == "com.miui.securitycenter" ||    // Xiaomi
               packageName == "com.coloros.safecenter" ||     // OPPO
               packageName == "com.huawei.systemmanager" ||   // Huawei
               packageName.startsWith("com.android.settings")
    }

    private fun isAppMonitored(packageName: String): Boolean {
        // Skip our own app
        if (packageName == applicationContext.packageName) return false
        // Skip system UI and launcher
        if (packageName == "com.android.systemui") return false
        if (packageName == "android") return false
        if (packageName.startsWith("com.sec.android.app.launcher")) return false
        if (packageName.startsWith("com.google.android.apps.nexuslauncher")) return false
        // Skip settings apps
        if (isSettingsPackage(packageName)) return false
        
        return true
    }

    /**
     * Extract text from an AccessibilityNodeInfo tree for self-defense checks.
     */
    private fun extractNodeTexts(node: AccessibilityNodeInfo?): List<String> {
        val texts = mutableListOf<String>()
        if (node == null) return texts
        try {
            node.text?.toString()?.let { texts.add(it) }
            node.contentDescription?.toString()?.let { texts.add(it) }
            for (i in 0 until node.childCount) {
                val child = node.getChild(i)
                if (child != null) {
                    child.text?.toString()?.let { texts.add(it) }
                    child.contentDescription?.toString()?.let { texts.add(it) }
                    child.recycle()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error extracting node texts: ${e.message}")
        }
        return texts
    }

    /**
     * Navigate the user to the Home screen.
     */
    private fun goHome() {
        try {
            val homeIntent = android.content.Intent(android.content.Intent.ACTION_MAIN)
            homeIntent.addCategory(android.content.Intent.CATEGORY_HOME)
            homeIntent.flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK
            startActivity(homeIntent)
        } catch (e: Exception) {
            // Fallback: use the global BACK action
            performGlobalAction(GLOBAL_ACTION_HOME)
        }
    }

    /**
     * Send a tamper alert to the parent device.
     */
    private fun sendTamperAlert(type: String, message: String) {
        val payload = mapOf(
            "event"     to "tamper_detected",
            "app"       to applicationContext.packageName,
            "type"      to type,
            "message"   to message,
            "timestamp" to System.currentTimeMillis(),
            "childId"   to (childId ?: "unknown"),
        )
        KovaChannelManager.send("accessibility", payload)
    }

    // ─────────────────────────────────────────────
    // Content changed — extract visible text
    // ─────────────────────────────────────────────

    private fun handleContentChanged(
        event: AccessibilityEvent,
        packageName: String,
        timestamp: Long
    ) {
        // Only extract text for monitored apps
        if (!isAppMonitored(packageName)) return

        extractAndSendVisibleText(packageName, "content_changed", timestamp)
    }

    // ─────────────────────────────────────────────
    // Text input changed — real-time typing detection
    // ─────────────────────────────────────────────

    private fun handleTextInputChanged(
        event: AccessibilityEvent,
        packageName: String,
        timestamp: Long
    ) {
        val text = event.text?.joinToString(" ") ?: return
        if (text.isBlank() || text.length < 3) return

        // This captures text typed into search bars, URL bars, chat inputs
        val isBrowser = BROWSER_APPS.contains(packageName)

        val payload = mapOf(
            "event"          to if (isBrowser) "browser_input" else "text_input",
            "app"            to packageName,
            "text"           to text.take(MAX_TEXT_LENGTH),
            "source"         to "accessibility_input",
            "direction"      to "outgoing",
            "timestamp"      to timestamp,
            "childId"        to (childId ?: "unknown"),
        )

        KovaChannelManager.send("accessibility", payload)
    }

    // ─────────────────────────────────────────────
    // Notification events
    // ─────────────────────────────────────────────

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

    // ═══════════════════════════════════════════════
    // CORE: Extract visible text from the widget tree
    // ═══════════════════════════════════════════════

    /**
     * Walk the accessibility node tree and extract ALL visible text.
     * This works on FLAG_SECURE protected apps because we're reading
     * the widget tree, not taking a screenshot.
     *
     * For messaging apps: extracts chat message text
     * For browsers: extracts URL bar, page title, search queries
     */
    private fun extractAndSendVisibleText(
        packageName: String,
        trigger: String,
        timestamp: Long
    ) {
        try {
            val rootNode = rootInActiveWindow ?: return

            val isBrowser = BROWSER_APPS.contains(packageName)
            val isMessaging = MESSAGING_APPS.contains(packageName)

            if (isBrowser) {
                extractBrowserContent(rootNode, packageName, trigger, timestamp)
            } else if (isMessaging) {
                extractMessagingContent(rootNode, packageName, trigger, timestamp)
            } else {
                // Generic text extraction for other monitored apps
                extractGenericContent(rootNode, packageName, trigger, timestamp)
            }

            rootNode.recycle()
        } catch (e: Exception) {
            Log.e(TAG, "Error extracting text: ${e.message}")
        }
    }

    /**
     * Extract browser-specific content:
     * - URL bar text (works even in incognito)
     * - Page title
     * - Search query text
     * - Visible page text
     */
    private fun extractBrowserContent(
        rootNode: AccessibilityNodeInfo,
        packageName: String,
        trigger: String,
        timestamp: Long
    ) {
        val urlBarText = findUrlBarText(rootNode)
        val pageTitle = findPageTitle(rootNode)
        val isIncognito = detectIncognitoMode(rootNode)
        val visibleText = collectVisibleText(rootNode, maxDepth = 8, maxChars = 1000)

        // Skip if same content
        val contentHash = (urlBarText + pageTitle + visibleText.take(200)).hashCode()
        if (contentHash == lastExtractedTextHash) return
        lastExtractedTextHash = contentHash

        if (urlBarText.isNotBlank() || visibleText.isNotBlank()) {
            Log.d(TAG, "🌐 Browser [$packageName] URL=$urlBarText incognito=$isIncognito")

            val payload = mapOf(
                "event"          to "browser_content",
                "app"            to packageName,
                "url"            to urlBarText,
                "pageTitle"      to pageTitle,
                "visibleText"    to visibleText.take(MAX_TEXT_LENGTH),
                "isIncognito"    to isIncognito,
                "source"         to "accessibility_tree",
                "direction"      to "browsing",
                "trigger"        to trigger,
                "conversationId" to "${packageName}_browser",
                "timestamp"      to timestamp,
                "childId"        to (childId ?: "unknown"),
            )

            KovaChannelManager.send("accessibility", payload)
        }
    }

    /**
     * Extract messaging app content:
     * - Chat messages visible on screen
     * - Sender names
     * - Conversation text
     */
    private fun extractMessagingContent(
        rootNode: AccessibilityNodeInfo,
        packageName: String,
        trigger: String,
        timestamp: Long
    ) {
        val chatMessages = collectChatMessages(rootNode, packageName)
        val visibleText = collectVisibleText(rootNode, maxDepth = 10, maxChars = MAX_TEXT_LENGTH)

        // Skip if same content
        val contentHash = visibleText.take(500).hashCode()
        if (contentHash == lastExtractedTextHash) return
        lastExtractedTextHash = contentHash

        if (chatMessages.isNotEmpty() || visibleText.length > 10) {
            Log.d(TAG, "💬 Chat [$packageName] messages=${chatMessages.size} text=${visibleText.length}chars")

            val payload = mapOf(
                "event"          to "chat_content",
                "app"            to packageName,
                "text"           to visibleText.take(MAX_TEXT_LENGTH),
                "messages"       to chatMessages.take(20),  // Last 20 visible messages
                "source"         to "accessibility_tree",
                "direction"      to "incoming",
                "trigger"        to trigger,
                "conversationId" to "${packageName}_chat",
                "timestamp"      to timestamp,
                "childId"        to (childId ?: "unknown"),
            )

            KovaChannelManager.send("accessibility", payload)
        }
    }

    /**
     * Generic content extraction for YouTube, Search, etc.
     */
    private fun extractGenericContent(
        rootNode: AccessibilityNodeInfo,
        packageName: String,
        trigger: String,
        timestamp: Long
    ) {
        val visibleText = collectVisibleText(rootNode, maxDepth = 6, maxChars = 500)

        val contentHash = visibleText.take(300).hashCode()
        if (contentHash == lastExtractedTextHash) return
        lastExtractedTextHash = contentHash

        if (visibleText.length > 20) {
            val payload = mapOf(
                "event"          to "app_content",
                "app"            to packageName,
                "text"           to visibleText.take(MAX_TEXT_LENGTH),
                "source"         to "accessibility_tree",
                "direction"      to "viewing",
                "trigger"        to trigger,
                "conversationId" to "${packageName}_content",
                "timestamp"      to timestamp,
                "childId"        to (childId ?: "unknown"),
            )

            KovaChannelManager.send("accessibility", payload)
        }
    }

    // ═══════════════════════════════════════════════
    // Node tree walkers
    // ═══════════════════════════════════════════════

    /**
     * Recursively collect all visible text from the node tree.
     */
    private fun collectVisibleText(
        node: AccessibilityNodeInfo,
        maxDepth: Int = 10,
        maxChars: Int = MAX_TEXT_LENGTH,
        currentDepth: Int = 0
    ): String {
        if (currentDepth > maxDepth) return ""

        val sb = StringBuilder()

        // Get text from this node
        val nodeText = node.text?.toString()?.trim() ?: ""
        val contentDesc = node.contentDescription?.toString()?.trim() ?: ""

        if (nodeText.isNotBlank() && nodeText.length > 1) {
            sb.append(nodeText).append(" ")
        } else if (contentDesc.isNotBlank() && contentDesc.length > 1 && !contentDesc.startsWith("Navigate")) {
            sb.append(contentDesc).append(" ")
        }

        // Recurse into children
        for (i in 0 until node.childCount) {
            if (sb.length >= maxChars) break
            try {
                val child = node.getChild(i) ?: continue
                sb.append(collectVisibleText(child, maxDepth, maxChars - sb.length, currentDepth + 1))
                child.recycle()
            } catch (e: Exception) {
                // Skip inaccessible nodes
            }
        }

        return sb.toString().take(maxChars)
    }

    /**
     * Extract individual chat messages from a messaging app.
     * Looks for list-like structures with text views.
     */
    private fun collectChatMessages(node: AccessibilityNodeInfo, packageName: String, depth: Int = 0): List<Map<String, String>> {
        if (depth > 12) return emptyList()

        val messages = mutableListOf<Map<String, String>>()

        val text = node.text?.toString()?.trim() ?: ""
        val className = node.className?.toString() ?: ""
        val viewId = node.viewIdResourceName ?: ""

        val rule = dynamicRules.find { it.packageName == packageName }

        var isMessageView = false
        if (rule != null && (rule.messageContainerId.isNotBlank() || rule.excludeRegex.isNotBlank() || rule.messageTextClass.isNotBlank())) {
            // Apply dynamic rule
            val matchesClass = rule.messageTextClass.isBlank() || className.contains(rule.messageTextClass, ignoreCase = true)
            val matchesId = rule.messageContainerId.isBlank() || viewId.contains(rule.messageContainerId, ignoreCase = true)
            var isExcluded = false
            if (rule.excludeRegex.isNotBlank()) {
                try {
                    isExcluded = Regex(rule.excludeRegex, RegexOption.IGNORE_CASE).containsMatchIn(text)
                } catch (e: Exception) {
                   // Invalid regex, fail safe
                }
            }
            isMessageView = matchesClass && matchesId && !isExcluded && text.length > 1
        } else {
            // Fallback to strict generic heuristics
            isMessageView = className.contains("TextView") &&
                text.length > 3 &&
                !text.startsWith("WhatsApp") &&
                !text.startsWith("Chat") &&
                !text.contains("online") &&
                !text.contains("typing") &&
                !text.matches(Regex("^\\d{1,2}:\\d{2}.*"))  // Skip timestamps
        }

        if (isMessageView) {
            messages.add(mapOf(
                "text" to text.take(500),
                "viewId" to viewId,
            ))
        }

        // Recurse
        for (i in 0 until node.childCount) {
            try {
                val child = node.getChild(i) ?: continue
                messages.addAll(collectChatMessages(child, packageName, depth + 1))
                child.recycle()
            } catch (e: Exception) {
                // Skip
            }
        }

        return messages
    }

    /**
     * Find URL bar text in browser apps.
     * Common view IDs across browsers:
     * - Chrome: "com.android.chrome:id/url_bar"
     * - Firefox: "org.mozilla.firefox:id/url_bar_title"
     * - Edge: "com.microsoft.emmx:id/url_bar"
     * - Brave: "com.brave.browser:id/url_bar"
     * - Samsung: "com.sec.android.app.sbrowser:id/location_bar_edit_text"
     */
    private fun findUrlBarText(node: AccessibilityNodeInfo, depth: Int = 0): String {
        if (depth > 8) return ""

        val viewId = node.viewIdResourceName ?: ""
        val text = node.text?.toString()?.trim() ?: ""

        // Match known URL bar IDs
        if (viewId.contains("url_bar") || viewId.contains("search_bar") ||
            viewId.contains("location_bar") || viewId.contains("address_bar") ||
            viewId.contains("omnibox") || viewId.contains("search_edit_text") ||
            viewId.contains("mozac_browser_toolbar_url_view")) {
            if (text.isNotBlank()) return text
        }

        // Also check for EditText with URL-like content
        val className = node.className?.toString() ?: ""
        if (className.contains("EditText") && text.contains(".") && text.length > 5) {
            // Likely a URL
            if (text.contains("http") || text.contains("www") || text.contains(".com") ||
                text.contains(".org") || text.contains(".net") || text.contains("/")) {
                return text
            }
        }

        // Recurse
        for (i in 0 until node.childCount) {
            try {
                val child = node.getChild(i) ?: continue
                val result = findUrlBarText(child, depth + 1)
                child.recycle()
                if (result.isNotBlank()) return result
            } catch (e: Exception) {
                // Skip
            }
        }

        return ""
    }

    /**
     * Find page title in browser apps.
     */
    private fun findPageTitle(node: AccessibilityNodeInfo, depth: Int = 0): String {
        if (depth > 6) return ""

        val viewId = node.viewIdResourceName ?: ""
        val text = node.text?.toString()?.trim() ?: ""

        if (viewId.contains("title") && text.isNotBlank() && text.length > 2) {
            return text
        }

        for (i in 0 until node.childCount) {
            try {
                val child = node.getChild(i) ?: continue
                val result = findPageTitle(child, depth + 1)
                child.recycle()
                if (result.isNotBlank()) return result
            } catch (e: Exception) {
                // Skip
            }
        }

        return ""
    }

    /**
     * Detect if browser is in incognito/private mode.
     * Checks for known incognito indicators in the UI tree.
     */
    private fun detectIncognitoMode(node: AccessibilityNodeInfo, depth: Int = 0): Boolean {
        if (depth > 6) return false

        val viewId = node.viewIdResourceName ?: ""
        val contentDesc = node.contentDescription?.toString()?.lowercase() ?: ""
        val text = node.text?.toString()?.lowercase() ?: ""

        // Check for incognito indicators
        if (viewId.contains("incognito") || viewId.contains("private") ||
            contentDesc.contains("incognito") || contentDesc.contains("private browsing") ||
            contentDesc.contains("navigation privée") || contentDesc.contains("privé") ||
            text.contains("incognito") || text.contains("you've gone incognito") ||
            text.contains("private browsing") || text.contains("navigation privée")) {
            return true
        }

        for (i in 0 until node.childCount) {
            try {
                val child = node.getChild(i) ?: continue
                if (detectIncognitoMode(child, depth + 1)) {
                    child.recycle()
                    return true
                }
                child.recycle()
            } catch (e: Exception) {
                // Skip
            }
        }

        return false
    }

    // ─────────────────────────────────────────────
    // Window classification
    // ─────────────────────────────────────────────

    private fun classifyWindow(className: String, packageName: String): String {
        val lower = className.lowercase()
        return when {
            BROWSER_APPS.contains(packageName)                            -> "browser"
            lower.contains("conversation") || lower.contains("chat")     -> "conversation"
            lower.contains("list") || lower.contains("home")             -> "list"
            lower.contains("profile") || lower.contains("setting")       -> "settings"
            lower.contains("camera") || lower.contains("gallery")        -> "media"
            lower.contains("call")                                        -> "call"
            lower.contains("story") || lower.contains("status")          -> "stories"
            lower.contains("search")                                      -> "search"
            else -> "other"
        }
    }
}
