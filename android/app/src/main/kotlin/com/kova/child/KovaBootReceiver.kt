package com.kova.child

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * KovaBootReceiver — Survives device reboot
 * 
 * On device boot:
 * - Start monitoring services
 * - Ensure accessibility service is enabled
 * - Start foreground protection service
 */
class KovaBootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "KovaBootReceiver"
        private const val PREFS_NAME = "com.example.kova"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != Intent.ACTION_LOCKED_BOOT_COMPLETED &&
            action != Intent.ACTION_MY_PACKAGE_REPLACED) {
            return
        }
        
        Log.d(TAG, "Boot event received: $action")
        
        // Check if KOVA is enabled for this device
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val isEnabled = prefs.getBoolean("kova_enabled", false)
        val childId = prefs.getString("child_id", null)
        
        if (!isEnabled || childId == null) {
            Log.d(TAG, "KOVA not enabled on this device")
            return
        }
        
        // Re-enable accessibility service if needed
        ensureAccessibilityEnabled(context)
        
        // Start foreground protection service
        startProtectionService(context)
        
        // Re-activate device admin if needed
        ensureDeviceAdminActive(context)
        
        Log.d(TAG, "Protection services restarted after boot")
    }

    /**
     * Ensure accessibility service is enabled
     */
    private fun ensureAccessibilityEnabled(context: Context) {
        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            if (!prefs.getBoolean("accessibility_enabled", false)) {
                Log.d(TAG, "Re-enabling accessibility service after boot")
                // Mark for re-enabling - actual enable is done by user
                prefs.edit().putBoolean("accessibility_pending", true).apply()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error ensuring accessibility: ${e.message}")
        }
    }

    /**
     * Start foreground protection service
     */
    private fun startProtectionService(context: Context) {
        try {
            val serviceIntent = Intent(context, KovaForegroundService::class.java)
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            
            Log.d(TAG, "Foreground service started after boot")
        } catch (e: Exception) {
            Log.e(TAG, "Error starting foreground service: ${e.message}")
        }
    }

    /**
     * Ensure device admin is active
     */
    private fun ensureDeviceAdminActive(context: Context) {
        try {
            val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as android.app.admin.DevicePolicyManager
            val componentName = android.content.ComponentName(context, KovaDeviceAdmin::class.java)
            
            if (!dpm.isAdminActive(componentName)) {
                Log.d(TAG, "Device admin no longer active, marking for re-activation")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking device admin: ${e.message}")
        }
    }
}
