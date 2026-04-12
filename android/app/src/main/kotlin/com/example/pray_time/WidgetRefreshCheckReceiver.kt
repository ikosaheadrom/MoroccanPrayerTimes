package com.example.pray_time

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager

/**
 * BroadcastReceiver that checks if widget needs refresh
 * Triggered by PrayerWidgetProvider when widget updates are needed
 */
class WidgetRefreshCheckReceiver : BroadcastReceiver() {
    companion object {
        private const val DEBUG_TAG = "[WidgetRefreshCheckReceiver]"
        const val ACTION_CHECK_WIDGET_REFRESH = "com.example.pray_time.CHECK_WIDGET_REFRESH"
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null) return
        
        Log.d(DEBUG_TAG, "onReceive: action=${intent?.action}")
        
        // Check if widget cache refresh flag is set
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val refreshTimestamp = prefs.getLong("flutter.widget_refresh_timestamp", 0L)
        
        if (refreshTimestamp > 0) {
            Log.d(DEBUG_TAG, "✓ Widget refresh flag detected (timestamp=$refreshTimestamp)")
            
            // Trigger the widget update worker
            try {
                val updateRequest = OneTimeWorkRequestBuilder<WidgetCacheUpdateWorker>().build()
                WorkManager.getInstance(context).enqueueUniqueWork(
                    "widget_cache_update_check",
                    ExistingWorkPolicy.REPLACE,
                    updateRequest
                )
                Log.d(DEBUG_TAG, "✓ Widget update worker enqueued")
                
                // Clear the flag
                prefs.edit().remove("flutter.widget_refresh_timestamp").apply()
                Log.d(DEBUG_TAG, "✓ Refresh flag cleared")
            } catch (e: Exception) {
                Log.e(DEBUG_TAG, "✗ Failed to enqueue worker: ${e.message}")
            }
        } else {
            Log.d(DEBUG_TAG, "⚠ No widget refresh flag found")
        }
    }
}
