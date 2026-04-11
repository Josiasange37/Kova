package com.kova.child

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.util.Log
import android.view.MotionEvent
import android.widget.Button
import android.widget.FrameLayout
import android.widget.TextView
import androidx.core.content.ContextCompat

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
        
        // Go home to ensure the user doesn't just return to the blocked app
        try {
            val homeIntent = Intent(Intent.ACTION_MAIN)
            homeIntent.addCategory(Intent.CATEGORY_HOME)
            homeIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            startActivity(homeIntent)
        } catch (e: Exception) {
            Log.e(TAG, "Error returning to home: ${e.message}")
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
            val intent = Intent(this, BlockOverlayActivity::class.java)
            intent.putExtra("blocked_package", blockedPackage)
            intent.putExtra("reason", blockReason)
            intent.putExtra("force_on_screen", false)
            startActivity(intent)
        }
    }
}
