package com.kova.child

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.MotionEvent
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView
import android.window.OnBackInvokedDispatcher
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
 * - Cannot be dismissed by back button
 * - Floating on top of all apps
 * - Shows customizable message
 * - "Report to Parent" button for user-reported content
 */
class BlockOverlayActivity : Activity() {
    companion object {
        private const val TAG = "BlockOverlayActivity"
    }

    private var blockedPackage: String? = null
    private var blockReason: String? = null

    // ─── Unlock Broadcast Receiver ───────────────────────────────────────────
    // Listens for the "com.kova.HIDE_OVERLAY" broadcast sent by KovaForegroundService
    // when the parent remotely unlocks. This replaces the broken SharedPreference polling.
    private val hideReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val targetPackage = intent.getStringExtra("package")
            // If no package specified, dismiss any overlay. Otherwise check it matches.
            if (targetPackage == null || targetPackage == blockedPackage) {
                finishBlock(sendHome = false) // Parent unlocked — don't force home
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Get block parameters
        blockedPackage = intent.getStringExtra("blocked_package")
        blockReason = intent.getStringExtra("reason") ?: "App is blocked for your safety"

        Log.d(TAG, "[OVERLAY PIPELINE] BlockOverlayActivity.onCreate() - Package: $blockedPackage")
        Log.d(TAG, "[OVERLAY PIPELINE] Block overlay shown for: $blockedPackage")

        // Keep screen on and show over lock screen
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
        )

        setupFullscreen()
        setupBackIntercept()
        setupUI()
        logBlockEvent()
    }

    // ─── Android 13+ Back Gesture Fix ────────────────────────────────────────
    // onBackPressed() is deprecated in API 33. This covers both old and new APIs.
    private fun setupBackIntercept() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            onBackInvokedDispatcher.registerOnBackInvokedCallback(
                OnBackInvokedDispatcher.PRIORITY_OVERLAY
            ) {
                // Do nothing — back gesture is completely blocked
            }
        }
        // For API < 33, onBackPressed() override below handles it
    }

    @Suppress("DEPRECATION")
    @Deprecated("Deprecated in API 33 — handled by OnBackInvokedCallback above for 33+")
    override fun onBackPressed() {
        // Intentionally blocked — do not call super
    }

    // ─── Lifecycle: Register / Unregister Receiver ───────────────────────────
    override fun onResume() {
        super.onResume()
        LocalBroadcastManager.getInstance(this).registerReceiver(
            hideReceiver,
            IntentFilter("com.kova.HIDE_OVERLAY")
        )
    }

    override fun onPause() {
        super.onPause()
        // Always unregister to prevent leaks
        LocalBroadcastManager.getInstance(this).unregisterReceiver(hideReceiver)
    }

    // ─── Fullscreen ──────────────────────────────────────────────────────────
    private fun setupFullscreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.insetsController?.let {
                it.hide(WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars())
                it.systemBarsBehavior =
                    WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (
                android.view.View.SYSTEM_UI_FLAG_FULLSCREEN or
                android.view.View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                android.view.View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            )
        }
    }

    /**
     * Setup block screen UI
     */
    private fun setupUI() {
        setContentView(R.layout.activity_block_overlay)
        
        // Get block message
        val appName = getAppName(blockedPackage ?: "Unknown")
        val message = "$appName is blocked.\n\n$blockReason"
        
        // Set message
        val messageText = findViewById<TextView>(R.id.block_message)
        messageText.text = message
        
        // Setup "OK" button - closes overlay and re-locks
        val okButton = findViewById<Button>(R.id.block_ok_button)
        okButton.setOnClickListener {
            finishBlock()
        }
        
        // Setup "Report" button - for user reporting
        val reportButton = findViewById<Button>(R.id.block_report_button)
        reportButton.setOnClickListener {
            reportToParent()
        }
    }

    // ─── Dismiss Block ───────────────────────────────────────────────────────
    // sendHome = true  → goes home (child tapped OK)
    // sendHome = false → just dismisses overlay (parent unlocked remotely)
    private fun finishBlock(sendHome: Boolean = true) {
        if (sendHome) {
            // Go home — AccessibilityService will re-trigger overlay if child reopens the app
            // Note: killBackgroundProcesses() is intentionally NOT used here — it's restricted
            // on Android 8+ for third-party apps and only kills your own process.
            val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(homeIntent)
        }
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
        
        // Close overlay
        finishBlock(sendHome = true)
    }

    /**
     * Get app name from package name
     */
    private fun getAppName(packageName: String): String {
        return try {
            val ai = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(ai).toString()
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
     * Prevent touch outside from dismissing
     */
    override fun onTouchEvent(event: MotionEvent?): Boolean {
        return true // Consume touch event
    }
}
