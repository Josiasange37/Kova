package com.kova.child

import android.content.Intent
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  private val SETUP_CHANNEL = "com.kova.child/setup"
  private val BLOCKER_CHANNEL = "com.kova.child/blocker"
  private val ACCESSIBILITY_CHANNEL = "com.kova.child/accessibility"

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    // ── Setup Channel ──
    // Handles child device setup (hide icon, activate device admin, etc.)
    MethodChannel(
      flutterEngine.dartExecutor.binaryMessenger,
      SETUP_CHANNEL
    ).setMethodCallHandler { call, result ->
      when (call.method) {
        "hideIcon" -> {
          hideAppIcon()
          result.success(true)
        }
        "activateDeviceAdmin" -> {
          activateDeviceAdmin()
          result.success(true)
        }
        "startProtection" -> {
          startForegroundService()
          result.success(true)
        }
        "isAccessibilityEnabled" -> {
          val enabled = isAccessibilityServiceEnabled()
          result.success(enabled)
        }
        else -> result.notImplemented()
      }
    }

    // ── Blocker Channel ──
    // Handles app blocking overlay
    MethodChannel(
      flutterEngine.dartExecutor.binaryMessenger,
      BLOCKER_CHANNEL
    ).setMethodCallHandler { call, result ->
      when (call.method) {
        "blockApp" -> {
          val pkg = call.argument<String>("pkg")
          if (pkg != null) {
            showBlockOverlay(pkg)
            result.success(true)
          } else {
            result.error("INVALID_PKG", "Package name required", null)
          }
        }
        "unblockApp" -> {
          hideBlockOverlay()
          result.success(true)
        }
        else -> result.notImplemented()
      }
    }

    // ── Accessibility Channel ──
    // Checks accessibility service status
    MethodChannel(
      flutterEngine.dartExecutor.binaryMessenger,
      ACCESSIBILITY_CHANNEL
    ).setMethodCallHandler { call, result ->
      when (call.method) {
        "isEnabled" -> {
          val enabled = isAccessibilityServiceEnabled()
          result.success(enabled)
        }
        "openSettings" -> {
          openAccessibilitySettings()
          result.success(true)
        }
        else -> result.notImplemented()
      }
    }
  }

  /// Hide the app icon from launcher
  private fun hideAppIcon() {
    try {
      val componentName =
        ComponentName(this, MainActivity::class.java)
      packageManager.setComponentEnabledSetting(
        componentName,
        PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
        PackageManager.DONT_KILL_APP
      )
    } catch (e: Exception) {
      e.printStackTrace()
    }
  }

  /// Activate device admin for app protection
  private fun activateDeviceAdmin() {
    try {
      val dpmIntent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
      dpmIntent.putExtra(
        DevicePolicyManager.EXTRA_DEVICE_ADMIN,
        ComponentName(this, KovaDeviceAdmin::class.java)
      )
      dpmIntent.putExtra(
        DevicePolicyManager.EXTRA_ADD_EXPLANATION,
        "KOVA needs device admin for full protection"
      )
      startActivity(dpmIntent)
    } catch (e: Exception) {
      e.printStackTrace()
    }
  }

  /// Start foreground protection service
  private fun startForegroundService() {
    try {
      val serviceIntent = Intent(this, KovaForegroundService::class.java)
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        startForegroundService(serviceIntent)
      } else {
        startService(serviceIntent)
      }
    } catch (e: Exception) {
      e.printStackTrace()
    }
  }

  /// Check if AccessibilityService is enabled
  private fun isAccessibilityServiceEnabled(): Boolean {
    return try {
      val prefManager = getSharedPreferences("com.example.kova", 0)
      prefManager.getBoolean("accessibility_enabled", false)
    } catch (e: Exception) {
      false
    }
  }

  /// Open accessibility settings
  private fun openAccessibilitySettings() {
    try {
      val intent = Intent(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS)
      startActivity(intent)
    } catch (e: Exception) {
      e.printStackTrace()
    }
  }

  /// Show block overlay for an app
  private fun showBlockOverlay(pkg: String) {
    try {
      val intent = Intent(this, BlockOverlayActivity::class.java)
      intent.putExtra("blocked_package", pkg)
      intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
      startActivity(intent)
    } catch (e: Exception) {
      e.printStackTrace()
    }
  }

  /// Hide block overlay
  private fun hideBlockOverlay() {
    try {
      val prefManager = getSharedPreferences("com.example.kova", 0)
      prefManager.edit().putBoolean("hide_overlay", true).apply()
    } catch (e: Exception) {
      e.printStackTrace()
    }
  }

  // BroadcastReceiver to forward messages to Flutter
  private val messageReceiver = object : android.content.BroadcastReceiver() {
    override fun onReceive(context: android.content.Context, intent: Intent) {
      if (intent.action == "com.kova.accessibility.MESSAGE" || intent.action == "com.kova.notification.MESSAGE") {
        val childId = intent.getStringExtra("childId")
        val app = intent.getStringExtra("app")
        val messageText = intent.getStringExtra("messageText")
        val senderName = intent.getStringExtra("senderName")
        val imagePaths = intent.getStringArrayExtra("imagePaths")?.toList() ?: emptyList<String>()

        val args = mapOf(
          "childId" to childId,
          "app" to app,
          "messageText" to messageText,
          "senderName" to senderName,
          "imagePaths" to imagePaths
        )

        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
          MethodChannel(messenger, "com.kova.app/accessibility").invokeMethod("onMessage", args)
        }
      } else if (intent.action == "com.kova.accessibility.CONVERSATION") {
        val childId = intent.getStringExtra("childId")
        val app = intent.getStringExtra("app")
        val senderName = intent.getStringExtra("senderName")
        val messagesArray = intent.getStringArrayExtra("messages") ?: arrayOfNulls<String>(0)
        
        val messagesList = messagesArray.filterNotNull().map { text ->
           mapOf("text" to text, "sender" to "unknown", "timestamp" to System.currentTimeMillis())
        }

        val args = mapOf(
          "childId" to childId,
          "app" to app,
          "senderName" to senderName,
          "messages" to messagesList
        )

        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
          MethodChannel(messenger, "com.kova.app/accessibility").invokeMethod("onConversation", args)
        }
      }
    }
  }

  override fun onResume() {
    super.onResume()
    val filter = android.content.IntentFilter().apply {
        addAction("com.kova.accessibility.MESSAGE")
        addAction("com.kova.notification.MESSAGE")
        addAction("com.kova.accessibility.CONVERSATION")
    }
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        registerReceiver(messageReceiver, filter, android.content.Context.RECEIVER_NOT_EXPORTED)
    } else {
        registerReceiver(messageReceiver, filter)
    }
  }

  override fun onPause() {
    super.onPause()
    try {
        unregisterReceiver(messageReceiver)
    } catch (e: Exception) {}
  }
}
