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
import android.view.MotionEvent
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
 * - Cannot be dismissed by back button or touch
 * - Floating on top of all apps
 * - Shows the ACTUAL blocked app's icon at the top
 * - Working 20-second countdown timer with progress bar
 * - ONLY closes when: (1) countdown timer finishes, or (2) parent sends dismiss via ping
 * - "Notify my parent" button to report content
 */
class BlockOverlayActivity : Activity() {
    companion object {
        private const val TAG = "BlockOverlayActivity"
        const val ACTION_HIDE_OVERLAY = "com.kova.HIDE_OVERLAY"

        // Countdown duration in seconds
        const val COUNTDOWN_SECONDS = 20

        // Debounce: prevent infinite relaunch loop from onPause
        @Volatile
        private var lastLaunchTimestamp: Long = 0L
        private const val RELAUNCH_DEBOUNCE_MS = 2000L

        @Volatile
        private var currentlyBlockedPackage: String? = null

        // Track if overlay is currently active — prevents new launches while showing
        @Volatile
        private var isOverlayActive: Boolean = false

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

            lastLaunchTimestamp = now
            currentlyBlockedPackage = packageName

            val intent = Intent(context, BlockOverlayActivity::class.java).apply {
                putExtra("blocked_package", packageName)
                putExtra("reason", reason ?: "App is blocked for your safety")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            }
            context.startActivity(intent)
        }
    }

    private var blockedPackage: String? = null
    private var blockReason: String? = null
    private var countdownTimer: CountDownTimer? = null
    private var timerFinished = false
    private var parentDismissed = false

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

        // Get block parameters
        blockedPackage = intent.getStringExtra("blocked_package")
        blockReason = intent.getStringExtra("reason") ?: "App is blocked for your safety"

        Log.d(TAG, "Block overlay shown for: $blockedPackage")

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

    override fun onDestroy() {
        super.onDestroy()
        isOverlayActive = false
        countdownTimer?.cancel()
        countdownTimer = null
        try {
            LocalBroadcastManager.getInstance(this).unregisterReceiver(hideReceiver)
        } catch (e: Exception) {
            Log.e(TAG, "Error unregistering receiver: ${e.message}")
        }
    }

    /**
     * Setup block screen UI
     */
    private fun setupUI() {
        setContentView(R.layout.activity_block_overlay)

        // Get block message
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
            // Keep the default icon if package icon can't be loaded
        } catch (e: Exception) {
            Log.e(TAG, "Error loading app icon: ${e.message}")
        }

        // Setup "Notify my parent" button
        val reportButton = findViewById<android.view.View>(R.id.block_report_button)
        reportButton?.setOnClickListener {
            reportToParent()
        }

        // Initialize timer display
        val timerText = findViewById<TextView>(R.id.block_time)
        timerText?.text = formatTime(COUNTDOWN_SECONDS.toLong())

        // Initialize progress bar
        val progressBar = findViewById<ProgressBar>(R.id.block_progress)
        progressBar?.max = COUNTDOWN_SECONDS * 1000
        progressBar?.progress = COUNTDOWN_SECONDS * 1000

        // Set the "Available in" label
        // (Already set in XML, but update return text)
        val returnText = findViewById<TextView>(R.id.block_return_text)
        val unblockTimeMs = System.currentTimeMillis() + (COUNTDOWN_SECONDS * 1000L)
        val sdf = java.text.SimpleDateFormat("h:mm a", java.util.Locale.getDefault())
        returnText?.text = "Returns automatically at ${sdf.format(java.util.Date(unblockTimeMs))}"
    }

    /**
     * Start the 20-second countdown timer.
     * The overlay ONLY closes when this timer finishes or parent sends a dismiss.
     */
    private fun startCountdownTimer() {
        val timerText = findViewById<TextView>(R.id.block_time)
        val progressBar = findViewById<ProgressBar>(R.id.block_progress)

        countdownTimer = object : CountDownTimer(
            COUNTDOWN_SECONDS * 1000L,
            50L  // Update every 50ms for smooth progress bar
        ) {
            override fun onTick(millisUntilFinished: Long) {
                // Update the countdown display (MM : SS format)
                val seconds = (millisUntilFinished / 1000L)
                timerText?.text = formatTime(seconds)

                // Update the progress bar (smooth animation)
                progressBar?.progress = millisUntilFinished.toInt()
            }

            override fun onFinish() {
                Log.d(TAG, "Countdown timer finished — unblocking")
                timerFinished = true
                timerText?.text = formatTime(0)
                progressBar?.progress = 0

                // Timer finished — close the overlay
                finishBlock()
            }
        }.start()

        Log.d(TAG, "Countdown timer started: ${COUNTDOWN_SECONDS}s")
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

        // Kill the blocked app
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

        // Send broadcast to Flutter
        val intent = Intent("com.kova.user_report").apply {
            putExtra("package", blockedPackage)
            putExtra("reason", blockReason)
        }
        sendBroadcast(intent)

        // Show confirmation
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
            val prefs = getSharedPreferences("com.example.kova", MODE_PRIVATE)
            val eventLog = (prefs.getStringSet("block_events", mutableSetOf()) ?: mutableSetOf()).toMutableSet()
            eventLog.add("${System.currentTimeMillis()}: $blockedPackage - $blockReason")
            prefs.edit().putStringSet("block_events", eventLog).apply()

            Log.d(TAG, "Block event logged")
        } catch (e: Exception) {
            Log.e(TAG, "Error logging block event: ${e.message}")
        }
    }

    /**
     * Prevent back button from dismissing — overlay stays until timer or parent dismiss
     */
    override fun onBackPressed() {
        Log.d(TAG, "Back button pressed — blocked (timer still running)")
        // Do nothing — block stays
    }

    /**
     * Prevent touch outside from dismissing
     */
    override fun onTouchEvent(event: MotionEvent?): Boolean {
        return true // Consume touch event
    }

    /**
     * Re-show block overlay if swiped away from recents, with debounce.
     * The overlay MUST persist until timer finishes or parent dismisses.
     */
    override fun onPause() {
        super.onPause()

        // Don't relaunch if timer has finished or parent dismissed
        if (timerFinished || parentDismissed) return

        val now = System.currentTimeMillis()
        if (blockedPackage != null &&
            currentlyBlockedPackage == blockedPackage &&
            now - lastLaunchTimestamp > RELAUNCH_DEBOUNCE_MS) {
            Log.d(TAG, "onPause: re-showing block for $blockedPackage (timer still active)")
            start(this, blockedPackage!!, blockReason)
        }
    }
}
