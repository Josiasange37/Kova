package com.kova.child

import android.app.admin.DeviceAdminReceiver
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * KovaDeviceAdmin — Device admin receiver for enhanced protection
 *
 * Capabilities:
 * - Lock screen when threats detected
 * - Disable uninstall of KOVA app
 * - Monitor device state changes
 */
class KovaDeviceAdmin : DeviceAdminReceiver() {
    companion object {
        private const val TAG = "KovaDeviceAdmin"

        /**
         * Get the ComponentName for this DeviceAdminReceiver
         */
        fun getComponentName(context: Context): ComponentName {
            return ComponentName(context, KovaDeviceAdmin::class.java)
        }
    }

    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
        Log.d(TAG, "Device admin enabled")
        
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        
        // Disable uninstall of KOVA
        try {
            dpm.setUninstallBlocked(
                Companion.getComponentName(context),
                context.packageName,
                true
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error disabling uninstall: ${e.message}")
        }
    }

    override fun onDisabled(context: Context, intent: Intent) {
        super.onDisabled(context, intent)
        Log.d(TAG, "Device admin disabled")
    }

    override fun onPasswordChanged(context: Context, intent: Intent) {
        super.onPasswordChanged(context, intent)
        Log.d(TAG, "Device password changed")
    }

    override fun onPasswordFailed(context: Context, intent: Intent) {
        super.onPasswordFailed(context, intent)
        Log.d(TAG, "Password entry failed")
    }

    override fun onPasswordSucceeded(context: Context, intent: Intent) {
        super.onPasswordSucceeded(context, intent)
        Log.d(TAG, "Password succeeded")
    }

    /**
     * Called by system when admin starts
     */
    override fun onBugreportFailed(context: Context, intent: Intent) {
        super.onBugreportFailed(context, intent)
        Log.d(TAG, "Bug report failed")
    }

    /**
     * Lock device - called when critical threat detected
     */
    fun lockDevice(context: Context) {
        try {
            val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            if (dpm.isAdminActive(Companion.getComponentName(context))) {
                dpm.lockNow()
                Log.d(TAG, "Device locked")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error locking device: ${e.message}")
        }
    }
}
