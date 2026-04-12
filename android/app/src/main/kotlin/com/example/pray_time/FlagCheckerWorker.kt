package com.example.pray_time

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Periodic worker that checks if widget refresh flag was set by Dart background task
 * 
 * Since MethodChannel doesn't work from background isolates, this worker
 * periodically checks if the flag exists in FlutterSharedPreferences and
 * if so, enqueues the WidgetCacheUpdateWorker to handle the update.
 */
class FlagCheckerWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    companion object {
        private const val DEBUG_TAG = "[FlagCheckerWorker]"
        private const val FLAG_KEY = "widget_refresh_timestamp"  // Key used by Dart background task
    }

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        return@withContext try {
            logDebug("Checking for widget refresh flag...")
            
            // Check if refresh flag exists in standard SharedPreferences (where Dart writes it)
            val prefs = applicationContext.getSharedPreferences(
                "FlutterSharedPreferences",
                Context.MODE_PRIVATE
            )
            
            val flagExists = prefs.contains(FLAG_KEY)
            
            if (flagExists) {
                logDebug("✓ Widget refresh flag detected! Enqueueing WidgetCacheUpdateWorker...")
                
                // Enqueue the widget cache update worker
                enqueueWidgetUpdateWorker()
                
                // Clear the flag immediately to avoid duplicate enqueueing
                prefs.edit().remove(FLAG_KEY).apply()
                logDebug("✓ Flag cleared, worker enqueued")
                
                Result.success()
            } else {
                // No flag, nothing to do
                logDebug("No flag detected, continuing...")
                Result.success()
            }
            
        } catch (e: Exception) {
            logError("Error checking flag", e)
            Result.retry()
        }
    }
    
    private fun enqueueWidgetUpdateWorker() {
        try {
            val updateRequest = androidx.work.OneTimeWorkRequestBuilder<WidgetCacheUpdateWorker>()
                .build()
            androidx.work.WorkManager.getInstance(applicationContext).enqueueUniqueWork(
                "widget_cache_update_from_flag",
                androidx.work.ExistingWorkPolicy.KEEP,  // Don't replace if already queued
                updateRequest
            )
            logDebug("WidgetCacheUpdateWorker enqueued successfully")
        } catch (e: Exception) {
            logError("Failed to enqueue worker", e)
        }
    }

    private fun logDebug(message: String) {
        Log.d(DEBUG_TAG, message)
    }
    
    private fun logError(message: String, exception: Exception? = null) {
        Log.e(DEBUG_TAG, message, exception)
    }
}
