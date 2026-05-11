package com.kova.child

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.CountDownTimer
import android.util.Log
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.WindowManager
import android.widget.ImageView
import android.widget.ProgressBar
import android.widget.TextView
import androidx.localbroadcastmanager.content.LocalBroadcastManager

/**
 * BlockOverlayActivity — Blocks and displays message for restricted apps
 *
 * Shows when:
 * - Child tries to open a blocked app
 * - Harmful content detected in monitored app
 * - Parent triggers emergency block
 *
 * Features:
 * - Cannot be dismissed by back button, touch, or recents swipe
 * - 60-second countdown timer with smooth progress bar
 * - Persists block state to SharedPreferences so KovaForegroundService
 *   watchdog can re-launch this overlay if the OS kills it
 * - ONLY closes when: (1) countdown timer finishes, or (2) parent dismiss
 * - Shows the actual blocked app's icon dynamically
 */
class BlockOverlayActivity : Activity() {
    companion object {
        private const val TAG = "BlockOverlayActivity"
        const val ACTION_HIDE_OVERLAY = "com.kova.HIDE_OVERLAY"
        private const val PREFS_NAME = "com.example.kova"

        // ── Countdown duration: 20 minutes (1200 seconds) ──
        const val COUNTDOWN_SECONDS = 1200

        // ── Debounce: prevent infinite relaunch loop ──
        @Volatile
        private var lastLaunchTimestamp: Long = 0L
        private const val RELAUNCH_DEBOUNCE_MS = 1500L

        // ── Max relaunch attempts per block ──
        // Prevents watchdog from spamming overlay when user keeps dismissing
        private const val MAX_RELAUNCHES = 2
        private const val PREFS_KEY_RELAUNCH_COUNT = "overlay_relaunch_count"
        private const val PREFS_KEY_LAST_BLOCK_PKG = "overlay_last_block_pkg"

        @Volatile
        private var currentlyBlockedPackage: String? = null

        // Track if overlay is currently showing — prevents new launches while active
        @Volatile
        var isOverlayActive: Boolean = false
            private set

        /**
         * Launch or re-launch the block overlay.
         * Safe to call multiple times — debounce prevents infinite loops.
         * NEW: Limits relaunches to MAX_RELAUNCHES per block to prevent spam.
         */
        fun start(context: Context, packageName: String, reason: String?) {
            val now = System.currentTimeMillis()

            // Don't relaunch if already showing for this package within debounce window
            if (currentlyBlockedPackage == packageName &&
                now - lastLaunchTimestamp < RELAUNCH_DEBOUNCE_MS) {
                Log.d(TAG, "Skipping duplicate launch for $packageName (debounce)")
                return
            }

            // Don't relaunch if overlay is already active for this package
            if (isOverlayActive && currentlyBlockedPackage == packageName) {
                Log.d(TAG, "Overlay already active for $packageName — skipping")
                return
            }

            // Check relaunch limit — prevent watchdog from spamming overlay
            val relaunchCount = getRelaunchCount(context, packageName)
            if (relaunchCount >= MAX_RELAUNCHES) {
                Log.w(TAG, "Max relaunches ($MAX_RELAUNCHES) reached for $packageName — blocking silently without overlay")
                // Still persist block state so app remains blocked, but don't show overlay
                persistBlockState(context, packageName, reason ?: "App is blocked for your safety")
                return
            }

            lastLaunchTimestamp = now
            currentlyBlockedPackage = packageName
            incrementRelaunchCount(context, packageName)

            // Persist block state so the ForegroundService watchdog can detect and re-launch
            persistBlockState(context, packageName, reason ?: "App is blocked for your safety")

            val intent = Intent(context, BlockOverlayActivity::class.java).apply {
                putExtra("blocked_package", packageName)
                putExtra("reason", reason ?: "App is blocked for your safety")
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_NO_ANIMATION
                )
            }
            context.startActivity(intent)
        }

        /**
         * Get the number of times overlay has been launched for this package.
         * Resets when package changes or block expires.
         */
        private fun getRelaunchCount(context: Context, packageName: String): Int {
            val prefs = context.getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
            val lastPkg = prefs.getString(PREFS_KEY_LAST_BLOCK_PKG, null)
            // Reset count if different package
            if (lastPkg != packageName) {
                prefs.edit().putInt(PREFS_KEY_RELAUNCH_COUNT, 0).putString(PREFS_KEY_LAST_BLOCK_PKG, packageName).apply()
                return 0
            }
            return prefs.getInt(PREFS_KEY_RELAUNCH_COUNT, 0)
        }

        /**
         * Increment relaunch counter.
         */
        private fun incrementRelaunchCount(context: Context, packageName: String) {
            val prefs = context.getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
            val current = getRelaunchCount(context, packageName)
            prefs.edit()
                .putInt(PREFS_KEY_RELAUNCH_COUNT, current + 1)
                .putString(PREFS_KEY_LAST_BLOCK_PKG, packageName)
                .apply()
        }

        /**
         * Save block state to SharedPreferences.
         * The ForegroundService watchdog reads this to re-launch the overlay
         * if the OS kills this Activity while the block is still active.
         */
        fun persistBlockState(context: Context, pkg: String, reason: String) {
            val prefs = context.getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
            prefs.edit()
                .putString("active_block_package", pkg)
                .putString("active_block_reason", reason)
                .putLong("active_block_expiry", System.currentTimeMillis() + (COUNTDOWN_SECONDS * 1000L))
                .apply()
        }

        /**
         * Clear block state — called when block is legitimately finished.
         * Also clears relaunch counter so next block starts fresh.
         */
        fun clearBlockState(context: Context) {
            val prefs = context.getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
            prefs.edit()
                .remove("active_block_package")
                .remove("active_block_reason")
                .remove("active_block_expiry")
                .remove(PREFS_KEY_RELAUNCH_COUNT)
                .remove(PREFS_KEY_LAST_BLOCK_PKG)
                .apply()
        }

        /**
         * Check if there's a currently active block that hasn't expired.
         * Used by the ForegroundService watchdog to decide whether to re-launch.
         * Also resets relaunch count if block has expired.
         */
        fun getActiveBlock(context: Context): Triple<String, String, Long>? {
            val prefs = context.getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
            val pkg = prefs.getString("active_block_package", null) ?: return null
            val reason = prefs.getString("active_block_reason", "App is blocked for your safety") ?: "App is blocked for your safety"
            val expiry = prefs.getLong("active_block_expiry", 0L)
            val now = System.currentTimeMillis()

            if (now >= expiry) {
                // Block has expired — clean up including relaunch count
                clearBlockState(context)
                return null
            }

            return Triple(pkg, reason, expiry)
        }
    }

    private var blockedPackage: String? = null
    private var blockReason: String? = null
    private var countdownTimer: CountDownTimer? = null
    private var timerFinished = false
    private var parentDismissed = false
    private var remainingMs: Long = COUNTDOWN_SECONDS * 1000L

    private val hideReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == ACTION_HIDE_OVERLAY) {
                Log.d(TAG, "Parent dismiss received — closing overlay")
                parentDismissed = true
                finishBlock()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        isOverlayActive = true

        // Make the overlay appear over the lock screen
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
        )

        // Get block parameters
        blockedPackage = intent.getStringExtra("blocked_package")
        blockReason = intent.getStringExtra("reason") ?: "App is blocked for your safety"

        // Calculate remaining time from persisted expiry
        val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        val expiry = prefs.getLong("active_block_expiry", 0L)
        val now = System.currentTimeMillis()
        if (expiry > now) {
            remainingMs = expiry - now
        } else {
            remainingMs = COUNTDOWN_SECONDS * 1000L
            // Re-persist since this is a fresh launch
            if (blockedPackage != null) {
                persistBlockState(this, blockedPackage!!, blockReason!!)
            }
        }

        Log.d(TAG, "Block overlay shown for: $blockedPackage (remaining: ${remainingMs / 1000}s)")

        // Set up UI
        setupUI()

        // Start the countdown timer
        startCountdownTimer()

        // Log block event
        logBlockEvent()

        // Register receiver for remote unlock (parent dismiss)
        val filter = IntentFilter(ACTION_HIDE_OVERLAY)
        LocalBroadcastManager.getInstance(this).registerReceiver(hideReceiver, filter)
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        // Activity is already showing — just update if needed
        Log.d(TAG, "onNewIntent: overlay already active")
    }

    override fun onDestroy() {
        super.onDestroy()
        countdownTimer?.cancel()
        countdownTimer = null
        isOverlayActive = false

        try {
            LocalBroadcastManager.getInstance(this).unregisterReceiver(hideReceiver)
        } catch (e: Exception) {
            Log.e(TAG, "Error unregistering receiver: ${e.message}")
        }

        // If the overlay was destroyed but the block hasn't legitimately finished,
        // the ForegroundService watchdog will detect and re-launch it.
        if (!timerFinished && !parentDismissed) {
            Log.w(TAG, "Overlay destroyed prematurely — watchdog will re-launch")
        }
    }

    /**
     * Setup block screen UI
     */
    private fun setupUI() {
        setContentView(R.layout.activity_block_overlay)

        // Get app name
        val appName = getAppName(blockedPackage ?: "Unknown")
        val title = "$appName is temporarily unavailable"

        // Set title and subtitle
        val titleText = findViewById<TextView>(R.id.block_title)
        titleText?.text = title

        val subtitleText = findViewById<TextView>(R.id.block_subtitle)
        subtitleText?.text = blockReason

        // Load the ACTUAL blocked app's icon
        val appIconView = findViewById<ImageView>(R.id.app_icon)
        try {
            if (blockedPackage != null) {
                val icon = packageManager.getApplicationIcon(blockedPackage!!)
                appIconView?.setImageDrawable(icon)
                appIconView?.clearColorFilter() // Remove the default tint
            }
        } catch (e: PackageManager.NameNotFoundException) {
            Log.w(TAG, "Could not load icon for $blockedPackage — using default")
        } catch (e: Exception) {
            Log.e(TAG, "Error loading app icon: ${e.message}")
        }

        // Setup "Notify my parent" button
        val reportButton = findViewById<android.view.View>(R.id.block_report_button)
        reportButton?.setOnClickListener {
            reportToParent()
        }

        // Initialize timer display with remaining time
        val remainingSeconds = remainingMs / 1000
        val timerText = findViewById<TextView>(R.id.block_time)
        timerText?.text = formatTime(remainingSeconds)

        // Initialize progress bar
        val totalMs = COUNTDOWN_SECONDS * 1000
        val progressBar = findViewById<ProgressBar>(R.id.block_progress)
        progressBar?.max = totalMs
        progressBar?.progress = remainingMs.toInt().coerceAtMost(totalMs)

        // Set the "Available in" label with actual time
        val returnText = findViewById<TextView>(R.id.block_return_text)
        val unblockTimeMs = System.currentTimeMillis() + remainingMs
        val sdf = java.text.SimpleDateFormat("h:mm a", java.util.Locale.getDefault())
        returnText?.text = "Returns automatically at ${sdf.format(java.util.Date(unblockTimeMs))}"
    }

    /**
     * Start the countdown timer using remaining time.
     * The overlay ONLY closes when this timer finishes or parent sends a dismiss.
     */
    private fun startCountdownTimer() {
        val timerText = findViewById<TextView>(R.id.block_time)
        val progressBar = findViewById<ProgressBar>(R.id.block_progress)

        countdownTimer = object : CountDownTimer(
            remainingMs,
            50L  // Update every 50ms for smooth progress bar
        ) {
            override fun onTick(millisUntilFinished: Long) {
                val seconds = (millisUntilFinished / 1000L)
                timerText?.text = formatTime(seconds)
                progressBar?.progress = millisUntilFinished.toInt()
            }

            override fun onFinish() {
                Log.d(TAG, "Countdown timer finished — unblocking")
                timerFinished = true
                timerText?.text = formatTime(0)
                progressBar?.progress = 0
                finishBlock()
            }
        }.start()

        Log.d(TAG, "Countdown timer started: ${remainingMs / 1000}s remaining")
    }

    /**
     * Format seconds into "MM : SS" display format
     */
    private fun formatTime(totalSeconds: Long): String {
        val minutes = totalSeconds / 60
        val seconds = totalSeconds % 60
        return String.format("%02d : %02d", minutes, seconds)
    }

    /**
     * Finish block and return to home — only called when timer finishes or parent dismisses.
     */
    private fun finishBlock() {
        Log.d(TAG, "Block dismissed (timer=$timerFinished, parent=$parentDismissed)")

        // Cancel timer if still running (parent dismiss case)
        countdownTimer?.cancel()
        countdownTimer = null

        // Clear static tracking so new blocks can launch
        currentlyBlockedPackage = null
        isOverlayActive = false

        // Clear persisted block state — block is legitimately finished
        clearBlockState(this)

        // Kill the blocked app's background processes
        if (blockedPackage != null) {
            try {
                val am = getSystemService(ACTIVITY_SERVICE) as android.app.ActivityManager
                am.killBackgroundProcesses(blockedPackage)
                Log.d(TAG, "Blocked app killed: $blockedPackage")
            } catch (e: Exception) {
                Log.e(TAG, "Error killing app: ${e.message}")
            }
        }

        // Close this overlay
        finish()
    }

    /**
     * Report harmful content to parent
     */
    private fun reportToParent() {
        Log.d(TAG, "Reporting to parent: $blockedPackage")

        val intent = Intent("com.kova.user_report").apply {
            putExtra("package", blockedPackage)
            putExtra("reason", blockReason)
        }
        sendBroadcast(intent)

        showToast("Report sent to parent")

        // DON'T close the overlay — child must wait for timer or parent dismiss
    }

    /**
     * Get app name from package name
     */
    private fun getAppName(packageName: String): String {
        return try {
            val ai = this.packageManager.getApplicationInfo(packageName, 0)
            this.packageManager.getApplicationLabel(ai).toString()
        } catch (e: Exception) {
            packageName
        }
    }

    /**
     * Show toast message
     */
    private fun showToast(message: String) {
        android.widget.Toast.makeText(this, message, android.widget.Toast.LENGTH_SHORT).show()
    }

    /**
     * Log block event for analytics
     */
    private fun logBlockEvent() {
        try {
            val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
            val eventLog = (prefs.getStringSet("block_events", mutableSetOf()) ?: mutableSetOf()).toMutableSet()
            eventLog.add("${System.currentTimeMillis()}: $blockedPackage - $blockReason")
            prefs.edit().putStringSet("block_events", eventLog).apply()
            Log.d(TAG, "Block event logged")
        } catch (e: Exception) {
            Log.e(TAG, "Error logging block event: ${e.message}")
        }
    }

    // ─────────────────────────────────────────────
    // Input Blocking — prevent ALL escape routes
    // ─────────────────────────────────────────────

    /** Prevent back button from dismissing */
    override fun onBackPressed() {
        Log.d(TAG, "Back button pressed — blocked (timer still running)")
        // Do nothing — block stays
    }

    /** Block all key events (Home is handled by taskAffinity + excludeFromRecents) */
    override fun dispatchKeyEvent(event: KeyEvent?): Boolean {
        if (event?.keyCode == KeyEvent.KEYCODE_BACK ||
            event?.keyCode == KeyEvent.KEYCODE_HOME ||
            event?.keyCode == KeyEvent.KEYCODE_APP_SWITCH) {
            return true // Consume — don't propagate
        }
        return super.dispatchKeyEvent(event)
    }

    /** Prevent touch outside from dismissing */
    override fun onTouchEvent(event: MotionEvent?): Boolean {
        return true // Consume touch event
    }

    /**
     * Re-show block overlay if swiped away from recents.
     * Uses the ForegroundService as a more reliable launcher than self-relaunch.
     */
    override fun onPause() {
        super.onPause()

        // Don't relaunch if timer has finished or parent dismissed
        if (timerFinished || parentDismissed) return

        Log.w(TAG, "onPause: overlay was paused while block active — service will re-launch")
        // The ForegroundService watchdog will detect that the overlay is not active
        // but the block state is still persisted, and will re-launch it.
    }

    /**
     * If the activity is stopped (user went home or recents),
     * ask the ForegroundService to re-launch immediately.
     */
    override fun onStop() {
        super.onStop()

        if (timerFinished || parentDismissed) return

        Log.w(TAG, "onStop: overlay stopped — requesting immediate re-launch via service")
        // Trigger the service to re-launch the overlay
        try {
            val relaunchIntent = Intent(this, KovaForegroundService::class.java).apply {
                action = "com.kova.ACTION_RELAUNCH_OVERLAY"
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(relaunchIntent)
            } else {
                startService(relaunchIntent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to request overlay relaunch: ${e.message}")
        }
    }
}
