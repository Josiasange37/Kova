package com.kova.child

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import android.window.OnBackInvokedDispatcher
import androidx.localbroadcastmanager.content.LocalBroadcastManager

class BlockOverlayActivity : Activity() {

    companion object {
        private const val TAG = "BlockOverlayActivity"
        private const val BLOCK_DURATION_MINUTES = 30

        fun start(context: Context, pkg: String?, reason: String?) {
            val intent = Intent(context, BlockOverlayActivity::class.java).apply {
                putExtra("blocked_package", pkg ?: "")
                putExtra("reason", reason ?: "This content is not suitable.")
                putExtra("app_name", getAppName(context, pkg))
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                addFlags(Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS)
            }
            context.startActivity(intent)
            Log.d(TAG, "✅ [OVERLAY] BlockOverlayActivity.start() called for pkg=$pkg")
        }

        private fun getAppName(context: Context, packageName: String?): String {
            if (packageName == null) return "This app"
            return try {
                val pm = context.packageManager
                val appInfo = pm.getApplicationInfo(packageName, 0)
                pm.getApplicationLabel(appInfo).toString()
            } catch (e: Exception) {
                packageName.substringAfterLast(".")
            }
        }
    }

    private var blockedPackage: String? = null
    private var blockReason: String? = null
    private var appName: String = "This app"
    private var remainingSeconds: Int = BLOCK_DURATION_MINUTES * 60
    private val handler = Handler(Looper.getMainLooper())
    private var countdownRunnable: Runnable? = null

    private val hideReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            Log.d(TAG, "📩 [OVERLAY] HIDE_OVERLAY broadcast received")
            finishBlock(sendHome = false)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        blockedPackage = intent.getStringExtra("blocked_package")
        blockReason = intent.getStringExtra("reason") ?: "This content is not suitable."
        appName = intent.getStringExtra("app_name") ?: "This app"

        Log.d(TAG, "🚀 [OVERLAY] onCreate — pkg=$blockedPackage app=$appName")

        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
        )

        setupBackIntercept()
        buildUI()
        setupFullscreen()
        startCountdown()
    }

    private fun buildUI() {
        // Root: light gray/off-white background (#F5F5F7)
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setBackgroundColor(Color.parseColor("#F5F5F7"))
            setPadding(48, 80, 48, 48)
        }

        // App icon container (gray rounded square with music note placeholder)
        val iconContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(120, 120).apply {
                setMargins(0, 0, 0, 32)
            }
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = 24f
                setColor(Color.parseColor("#E5E5EA"))
            }
        }

        // Music note icon (🎵)
        val musicIcon = TextView(this).apply {
            text = "🎵"
            textSize = 48f
            gravity = Gravity.CENTER
        }
        iconContainer.addView(musicIcon)

        // Lock icon circle (lavender/purple circle with lock)
        val lockCircle = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(100, 100).apply {
                setMargins(0, 0, 0, 32)
            }
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#E8E4F3"))
            }
        }

        val lockIcon = TextView(this).apply {
            text = "🔒"
            textSize = 40f
            gravity = Gravity.CENTER
        }
        lockCircle.addView(lockIcon)

        // Title: "TikTok is temporarily unavailable"
        val title = TextView(this).apply {
            text = "$appName is temporarily unavailable"
            textSize = 22f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor("#1C1C1E"))
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 8)
        }

        // Subtitle: "This content is not suitable."
        val subtitle = TextView(this).apply {
            text = blockReason
            textSize = 15f
            setTextColor(Color.parseColor("#8E8E93"))
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 48)
        }

        // Large time display
        val timeDisplay = TextView(this).apply {
            text = formatTime(remainingSeconds)
            textSize = 56f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor("#1C1C1E"))
            gravity = Gravity.CENTER
            letterSpacing = 0.1f
            setPadding(0, 0, 0, 8)
        }

        // "Available in" label
        val availableLabel = TextView(this).apply {
            text = "Available in"
            textSize = 14f
            setTextColor(Color.parseColor("#8E8E93"))
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 16)
        }

        // Progress bar
        val progressBar = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                6
            ).apply { setMargins(0, 0, 0, 48) }
            max = BLOCK_DURATION_MINUTES * 60
            progress = remainingSeconds
            progressDrawable = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = 3f
                setColor(Color.parseColor("#D1D1D6"))
            }
        }

        // Notify my parent button
        val notifyButton = Button(this).apply {
            text = "✈️ Notify my parent"
            textSize = 16f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor("#1C1C1E"))
            gravity = Gravity.CENTER
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = 12f
                setColor(Color.TRANSPARENT)
                setStroke(2, Color.parseColor("#8E8E93"))
            }
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { setMargins(0, 0, 0, 16) }
            setPadding(0, 20, 0, 20)
            setOnClickListener {
                Log.d(TAG, "👆 [OVERLAY] Notify parent tapped")
                reportToParent()
            }
        }

        // Footer: "Returns automatically at 10:40 PM"
        val returnTime = calculateReturnTime()
        val footer = TextView(this).apply {
            text = "Returns automatically at $returnTime"
            textSize = 13f
            setTextColor(Color.parseColor("#8E8E93"))
            gravity = Gravity.CENTER
        }

        root.addView(iconContainer)
        root.addView(lockCircle)
        root.addView(title)
        root.addView(subtitle)
        root.addView(timeDisplay)
        root.addView(availableLabel)
        root.addView(progressBar)
        root.addView(notifyButton)
        root.addView(footer)

        // Store reference for countdown updates
        root.tag = timeDisplay

        setContentView(root)
        Log.d(TAG, "✅ [OVERLAY] UI built and set — overlay is now visible")
    }

    private fun startCountdown() {
        val timeDisplay = (findViewById<LinearLayout>(android.R.id.content)?.tag as? TextView)
            ?: return

        countdownRunnable = object : Runnable {
            override fun run() {
                if (remainingSeconds > 0) {
                    remainingSeconds--
                    timeDisplay.text = formatTime(remainingSeconds)
                    handler.postDelayed(this, 1000)
                } else {
                    finishBlock(sendHome = true)
                }
            }
        }
        handler.postDelayed(countdownRunnable!!, 1000)
    }

    private fun formatTime(seconds: Int): String {
        val minutes = seconds / 60
        val secs = seconds % 60
        return String.format("%02d:%02d", minutes, secs)
    }

    private fun calculateReturnTime(): String {
        val calendar = java.util.Calendar.getInstance()
        calendar.add(java.util.Calendar.MINUTE, BLOCK_DURATION_MINUTES)
        val hour = calendar.get(java.util.Calendar.HOUR)
        val minute = calendar.get(java.util.Calendar.MINUTE)
        val amPm = if (calendar.get(java.util.Calendar.AM_PM) == java.util.Calendar.AM) "AM" else "PM"
        return String.format("%d:%02d %s", hour, minute, amPm)
    }

    private fun finishBlock(sendHome: Boolean = true) {
        countdownRunnable?.let { handler.removeCallbacks(it) }
        if (sendHome) {
            val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(homeIntent)
        }
        finish()
    }

    private fun reportToParent() {
        val intent = Intent("com.kova.user_report").apply {
            putExtra("package", blockedPackage)
            putExtra("reason", blockReason)
        }
        sendBroadcast(intent)
        // Don't finish — let parent decide
    }

    private fun setupBackIntercept() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            onBackInvokedDispatcher.registerOnBackInvokedCallback(
                OnBackInvokedDispatcher.PRIORITY_OVERLAY
            ) { /* block back */ }
        }
    }

    @Suppress("DEPRECATION")
    @Deprecated("Handled by OnBackInvokedCallback on API 33+")
    override fun onBackPressed() { /* intentionally blocked */ }

    override fun onResume() {
        super.onResume()
        LocalBroadcastManager.getInstance(this).registerReceiver(
            hideReceiver, IntentFilter("com.kova.HIDE_OVERLAY")
        )
        Log.d(TAG, "▶️ [OVERLAY] onResume — overlay active")
    }

    override fun onPause() {
        super.onPause()
        LocalBroadcastManager.getInstance(this).unregisterReceiver(hideReceiver)
    }

    override fun onDestroy() {
        super.onDestroy()
        countdownRunnable?.let { handler.removeCallbacks(it) }
    }

    override fun onTouchEvent(event: MotionEvent?): Boolean = true

    private fun setupFullscreen() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                window.insetsController?.let {
                    it.hide(WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars())
                    it.systemBarsBehavior =
                        WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                }
            } else {
                @Suppress("DEPRECATION")
                window.decorView.systemUiVisibility = (
                    View.SYSTEM_UI_FLAG_FULLSCREEN or
                    View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                    View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                )
            }
        } catch (e: Exception) {
            Log.w(TAG, "⚠️ setupFullscreen failed (non-fatal): ${e.message}")
            // Overlay still shows — fullscreen is cosmetic only
        }
    }
}
