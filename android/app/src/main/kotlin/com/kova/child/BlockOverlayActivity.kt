package com.kova.child

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.graphics.Typeface
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import android.window.OnBackInvokedDispatcher
import androidx.localbroadcastmanager.content.LocalBroadcastManager

class BlockOverlayActivity : Activity() {

    companion object {
        private const val TAG = "BlockOverlayActivity"

        fun start(context: Context, pkg: String?, reason: String?) {
            val intent = Intent(context, BlockOverlayActivity::class.java).apply {
                putExtra("blocked_package", pkg ?: "")
                putExtra("reason", reason ?: "Contenu bloqué pour votre sécurité")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            context.startActivity(intent)
            Log.d(TAG, "✅ [OVERLAY] BlockOverlayActivity.start() called for pkg=$pkg")
        }
    }

    private var blockedPackage: String? = null
    private var blockReason: String? = null

    private val hideReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            Log.d(TAG, "📩 [OVERLAY] HIDE_OVERLAY broadcast received")
            finishBlock(sendHome = false)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        blockedPackage = intent.getStringExtra("blocked_package")
        blockReason    = intent.getStringExtra("reason") ?: "Contenu bloqué"

        Log.d(TAG, "🚀 [OVERLAY] onCreate — pkg=$blockedPackage reason=$blockReason")

        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
        )

        setupFullscreen()
        setupBackIntercept()

        // ── Build UI 100% programmatically — zero XML, zero resource IDs ──
        buildUI()
    }

    private fun buildUI() {
        // Root: dark navy background
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity     = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#0F0F1E"))
            setPadding(60, 60, 60, 60)
        }

        // Shield emoji
        val shield = TextView(this).apply {
            text     = "🛡️"
            textSize = 72f
            gravity  = Gravity.CENTER
            setPadding(0, 0, 0, 24)
        }

        // KOVA label
        val kovaLabel = TextView(this).apply {
            text      = "KOVA"
            textSize  = 18f
            typeface  = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor("#6366F1"))
            gravity   = Gravity.CENTER
            letterSpacing = 0.3f
        }

        // Title
        val title = TextView(this).apply {
            text      = "Contenu bloqué"
            textSize  = 26f
            typeface  = Typeface.DEFAULT_BOLD
            setTextColor(Color.WHITE)
            gravity   = Gravity.CENTER
            setPadding(0, 12, 0, 16)
        }

        // Reason
        val reasonView = TextView(this).apply {
            text      = blockReason ?: "Ce contenu a été bloqué pour votre sécurité."
            textSize  = 15f
            setTextColor(Color.parseColor("#AAAACC"))
            gravity   = Gravity.CENTER
            setPadding(0, 0, 0, 48)
        }

        // Divider
        val divider = View(this).apply {
            setBackgroundColor(Color.parseColor("#222244"))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, 1
            ).apply { setMargins(0, 0, 0, 40) }
        }

        // OK Button
        val okButton = Button(this).apply {
            text      = "OK — Retour à l'accueil"
            textSize  = 16f
            typeface  = Typeface.DEFAULT_BOLD
            setTextColor(Color.WHITE)
            setBackgroundColor(Color.parseColor("#E53935"))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { setMargins(0, 0, 0, 16) }
            setPadding(0, 24, 0, 24)
            setOnClickListener {
                Log.d(TAG, "👆 [OVERLAY] OK button tapped")
                finishBlock(sendHome = true)
            }
        }

        // Report button
        val reportButton = Button(this).apply {
            text      = "Signaler à un parent"
            textSize  = 14f
            setTextColor(Color.parseColor("#AAAACC"))
            setBackgroundColor(Color.parseColor("#1A1A2E"))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            setPadding(0, 16, 0, 16)
            setOnClickListener {
                Log.d(TAG, "👆 [OVERLAY] Report button tapped")
                reportToParent()
            }
        }

        root.addView(shield)
        root.addView(kovaLabel)
        root.addView(title)
        root.addView(reasonView)
        root.addView(divider)
        root.addView(okButton)
        root.addView(reportButton)

        setContentView(root)
        Log.d(TAG, "✅ [OVERLAY] UI built and set — overlay is now visible")
    }

    private fun finishBlock(sendHome: Boolean = true) {
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
        finishBlock(sendHome = true)
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

    override fun onTouchEvent(event: MotionEvent?): Boolean = true

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
                View.SYSTEM_UI_FLAG_FULLSCREEN or
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            )
        }
    }
}
