package com.kova.child

import android.app.Activity
import android.app.AlertDialog
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

/**
 * OnboardingHelper — Runtime permission flow for critical permissions
 *
 * Several permissions required for background survival cannot be granted
 * automatically — they need user interaction. These must be requested during
 * onboarding before the service starts.
 */
class OnboardingHelper(private val activity: Activity) {

    companion object {
        private const val TAG = "OnboardingHelper"
        private const val PREFS_NAME = "com.example.kova"
        private const val RC_NOTIFICATIONS = 1001
    }

    /**
     * Request all critical permissions in sequence.
     * Call this during onboarding before starting protection services.
     */
    fun requestAllPermissions() {
        requestNotificationPermission()
        requestBatteryOptimizationExemption()
        requestAccessibilityIfNeeded()
        requestDeviceAdminIfNeeded()
    }

    /**
     * Check if all critical permissions are granted.
     * Use this to gate the "Setup Complete" button in onboarding.
     */
    fun allCriticalPermissionsGranted(): Boolean {
        val notificationsOk = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                activity,
                android.Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true // Not required below API 33
        }

        val batteryOk = isBatteryOptimizationExempt()
        val accessibilityOk = isAccessibilityEnabled()

        Log.d(TAG, "Permissions check: notifications=$notificationsOk, battery=$batteryOk, accessibility=$accessibilityOk")

        return notificationsOk && batteryOk && accessibilityOk
    }

    /**
     * Request POST_NOTIFICATIONS permission (required API 33+).
     * Without this, the foreground notification cannot be shown,
     * and the service will be killed by Android.
     */
    fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val permission = android.Manifest.permission.POST_NOTIFICATIONS
            if (ContextCompat.checkSelfPermission(activity, permission) != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(
                    activity,
                    arrayOf(permission),
                    RC_NOTIFICATIONS
                )
            }
        }
    }

    /**
     * Request battery optimization exemption.
     * This is the most important permission — without it, Doze mode
     * kills the service on idle devices, leaving the child unprotected.
     */
    fun requestBatteryOptimizationExemption() {
        if (!isBatteryOptimizationExempt()) {
            try {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:${activity.packageName}")
                }
                activity.startActivity(intent)
            } catch (e: Exception) {
                Log.e(TAG, "Error requesting battery exemption: ${e.message}")
                // Fallback to general settings
                try {
                    activity.startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                } catch (e2: Exception) {
                    Log.e(TAG, "Fallback also failed: ${e2.message}")
                }
            }
        }
    }

    /**
     * Check if battery optimization is exempt.
     */
    private fun isBatteryOptimizationExempt(): Boolean {
        return try {
            val pm = activity.getSystemService(Context.POWER_SERVICE) as PowerManager
            pm.isIgnoringBatteryOptimizations(activity.packageName)
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Open accessibility settings if not enabled.
     * Accessibility service is required for app monitoring and blocking.
     */
    fun requestAccessibilityIfNeeded() {
        if (!isAccessibilityEnabled()) {
            try {
                activity.startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
            } catch (e: Exception) {
                Log.e(TAG, "Error opening accessibility settings: ${e.message}")
            }
        }
    }

    /**
     * Check if KOVA accessibility service is enabled.
     */
    private fun isAccessibilityEnabled(): Boolean {
        return try {
            val service = "${activity.packageName}/${KovaAccessibilityService::class.java.canonicalName}"
            val enabledServices = Settings.Secure.getString(
                activity.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            ) ?: ""
            enabledServices.contains(service)
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Request device admin activation if not active.
     * Device admin prevents uninstall and provides additional protection.
     */
    fun requestDeviceAdminIfNeeded() {
        if (!isDeviceAdminActive()) {
            try {
                val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
                    putExtra(
                        DevicePolicyManager.EXTRA_DEVICE_ADMIN,
                        ComponentName(activity, KovaDeviceAdmin::class.java)
                    )
                    putExtra(
                        DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                        "KOVA needs device admin permission to prevent uninstall and ensure continuous protection for your child."
                    )
                }
                activity.startActivity(intent)
            } catch (e: Exception) {
                Log.e(TAG, "Error requesting device admin: ${e.message}")
            }
        }
    }

    /**
     * Check if device admin is active.
     */
    private fun isDeviceAdminActive(): Boolean {
        return try {
            val dpm = activity.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            dpm.isAdminActive(ComponentName(activity, KovaDeviceAdmin::class.java))
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Handle permission result callback from Activity.
     * Call this from your Activity's onRequestPermissionsResult().
     */
    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        when (requestCode) {
            RC_NOTIFICATIONS -> {
                if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    Log.d(TAG, "POST_NOTIFICATIONS granted")
                } else {
                    Log.w(TAG, "POST_NOTIFICATIONS denied — service may be killed in background")
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // DIRECTIVE 1 — Xiaomi Play Protect bypass guidance
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * Check if device is Xiaomi/Redmi and show Play Protect guidance dialog.
     * Call this after battery optimization step during onboarding.
     */
    fun showPlayProtectGuidanceIfXiaomi() {
        val manufacturer = Build.MANUFACTURER
        if (!manufacturer.equals("Xiaomi", ignoreCase = true) &&
            !manufacturer.equals("Redmi", ignoreCase = true)) {
            Log.d(TAG, "Not a Xiaomi/Redmi device, skipping Play Protect guidance")
            return
        }

        Log.d(TAG, "Xiaomi/Redmi detected — showing Play Protect guidance")

        AlertDialog.Builder(activity)
            .setTitle("⚠️ Important: Play Protect Settings")
            .setMessage(
                "Play Protect may flag KOVA as harmful because it uses parental control permissions " +
                "(Accessibility Service, Device Admin, etc.).\n\n" +
                "To prevent this:\n" +
                "1. Tap 'Open Play Protect' below\n" +
                "2. Tap the gear icon (Settings)\n" +
                "3. Turn OFF 'Scan apps with Play Protect'\n\n" +
                "This is required for KOVA to function properly on Xiaomi devices."
            )
            .setPositiveButton("Open Play Protect") { _, _ ->
                openPlayProtectSettings()
            }
            .setNegativeButton("Skip") { dialog, _ ->
                dialog.dismiss()
            }
            .setCancelable(false)
            .show()
    }

    /**
     * Deep-link to Play Protect settings.
     * Tries primary intent, falls back to Play Store if unavailable.
     */
    private fun openPlayProtectSettings() {
        Log.d(TAG, "Opening Play Protect settings...")

        // Primary intent: Open Play Protect directly
        try {
            val intent = Intent().apply {
                action = "com.google.android.finsky.action.OPEN_PLAY_PROTECT"
            }
            activity.startActivity(intent)
            Log.d(TAG, "Opened Play Protect via primary intent")
            return
        } catch (e: Exception) {
            Log.w(TAG, "Primary Play Protect intent failed: ${e.message}")
        }

        // Fallback: Open Play Store
        try {
            val fallback = Intent(Intent.ACTION_VIEW).apply {
                data = Uri.parse("market://details?id=com.google.android.play.core")
            }
            activity.startActivity(fallback)
            Log.d(TAG, "Opened Play Store fallback")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open Play Protect or Play Store: ${e.message}")
            // Last resort: Open app info for KOVA
            try {
                val appInfoIntent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.parse("package:${activity.packageName}")
                }
                activity.startActivity(appInfoIntent)
            } catch (e2: Exception) {
                Log.e(TAG, "All fallback intents failed: ${e2.message}")
            }
        }
    }
}
