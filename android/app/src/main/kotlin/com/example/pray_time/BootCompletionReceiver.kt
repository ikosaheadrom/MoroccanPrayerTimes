package com.example.pray_time

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.ExistingWorkPolicy
import androidx.work.WorkManager

/**
 * Boot Completion Receiver
 * 
 * Reschedules widget updates and alarms when the device reboots
 * This ensures the widget continues to function after a restart
 */
class BootCompletionReceiver : BroadcastReceiver() {

    companion object {
        private const val DEBUG_TAG = "[BootCompletionReceiver]"
        
        private fun logDebug(message: String) {
            Log.d(DEBUG_TAG, message)
        }
        
        private fun logError(message: String, exception: Exception? = null) {
            Log.e(DEBUG_TAG, message, exception)
        }
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) {
            logError("onReceive: context or intent is null")
            return
        }

        if (intent.action != Intent.ACTION_BOOT_COMPLETED) {
            logDebug("onReceive: Ignoring action ${intent.action}")
            return
        }

        try {
            logDebug("onReceive: Device boot completed, rescheduling widget updates")
            
            // Trigger an immediate widget cache update
            scheduleWidgetCacheUpdate(context)
            
            logDebug("onReceive: Widget updates rescheduled successfully")
            
        } catch (e: Exception) {
            logError("Error handling boot completion", e)
        }
    }

    /**
     * Schedule widget cache update via WorkManager
     */
    private fun scheduleWidgetCacheUpdate(context: Context) {
        try {
            logDebug("scheduleWidgetCacheUpdate: Scheduling update")
            
            val updateRequest = OneTimeWorkRequestBuilder<WidgetCacheUpdateWorker>()
                .build()
            
            WorkManager.getInstance(context).enqueueUniqueWork(
                "widget_cache_update_boot",
                ExistingWorkPolicy.KEEP,
                updateRequest
            )
            
            logDebug("scheduleWidgetCacheUpdate: Worker enqueued successfully")
            
        } catch (e: Exception) {
            logError("Error scheduling widget cache update", e)
        }
    }
}
