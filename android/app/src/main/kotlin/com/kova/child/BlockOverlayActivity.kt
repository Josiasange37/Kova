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
 * - Cannot be dismissed by back button
 * - Floating on top of all apps
 * - Shows customizable message
 * - "Report to Parent" button for user-reported content
 */
class BlockOverlayActivity : Activity() {
    companion object {
        private const val TAG = "BlockOverlayActivity"
        const val ACTION_HIDE_OVERLAY = "com.kova.HIDE_OVERLAY"

        fun start(context: Context, packageName: String, reason: String?) {
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

    private val hideReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == ACTION_HIDE_OVERLAY) {
                Log.d(TAG, "Hide overlay broadcast received. Finishing activity.")
                finishBlock()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Get block parameters
        blockedPackage = intent.getStringExtra("blocked_package")
        blockReason = intent.getStringExtra("reason") ?: "App is blocked for your safety"
        
        Log.d(TAG, "Block overlay shown for: $blockedPackage")
        
        // Set up UI
        setupUI()
        
        // Log block event
        logBlockEvent()

        // Register receiver for remote unlock
        val filter = IntentFilter(ACTION_HIDE_OVERLAY)
        LocalBroadcastManager.getInstance(this).registerReceiver(hideReceiver, filter)
    }

    override fun onDestroy() {
        super.onDestroy()
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
        
        // Try to load the actual app icon
        val appIconView = findViewById<android.widget.ImageView>(R.id.app_icon)
        try {
            if (blockedPackage != null) {
                val icon = packageManager.getApplicationIcon(blockedPackage!!)
                appIconView?.setImageDrawable(icon)
                appIconView?.clearColorFilter() // Remove the tint if we load the actual icon
            }
        } catch (e: Exception) {
            // Keep the default tinted icon if loading fails
        }
        
        // Setup "Report" button - for user reporting
        val reportButton = findViewById<android.view.View>(R.id.block_report_button)
        reportButton?.setOnClickListener {
            reportToParent()
        }
    }

    /**
     * Finish block and return to parent app
     */
    private fun finishBlock() {
        Log.d(TAG, "Block dismissed")
        
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
        
        // Close overlay
        finishBlock()
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
     * Prevent back button from dismissing
     */
    override fun onBackPressed() {
        Log.d(TAG, "Back button pressed - blocked")
        // Do nothing - block stays
    }

    /**
     * Prevent touch outside from dismissing
     */
    override fun onTouchEvent(event: MotionEvent?): Boolean {
        return true // Consume touch event
    }

    /**
     * Disable swiping away from recent apps
     */
    override fun onPause() {
        super.onPause()
        // Prevent app from being minimized
        if (intent.getBooleanExtra("force_on_screen", true)) {
            val intent = Intent(this, BlockOverlayActivity::class.java).apply {
                putExtra("blocked_package", blockedPackage)
                putExtra("reason", blockReason)
                putExtra("force_on_screen", false)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            }
            startActivity(intent)
        }
    }
}
