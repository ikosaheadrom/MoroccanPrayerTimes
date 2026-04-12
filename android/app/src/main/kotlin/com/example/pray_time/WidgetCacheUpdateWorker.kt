package com.example.pray_time

import android.content.Context
import android.content.Intent
import android.appwidget.AppWidgetManager
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.google.gson.Gson
import com.google.gson.JsonObject
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * WorkManager for updating widget cache
 * 
 * This worker:
 * 1. Fetches prayer times using the Dart widget cache system
 * 2. Saves them to SharedPreferences for widget access
 * 3. Updates the last update time
 * 4. Triggers widget UI update
 */
class WidgetCacheUpdateWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    companion object {
        private const val DEBUG_TAG = "[WidgetCacheUpdateWorker]"
        const val WIDGET_CACHE_KEY = "widget_info_cache"
        const val LAST_UPDATE_TIME_KEY = "widget_last_update_time"
    }

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        return@withContext try {
            logDebug("WidgetCacheUpdateWorker: Starting")
            
            // Request Dart to fetch fresh prayer times
            val prayerTimesMap = fetchPrayerTimesFromDart()
            
            if (prayerTimesMap.isEmpty()) {
                logDebug("WidgetCacheUpdateWorker: No prayer times found - retrying")
                return@withContext Result.retry()
            }
            
            // Save to SharedPreferences for widget to read
            savePrayerTimesToPrefs(prayerTimesMap)
            
            // Update widget UI
            triggerWidgetUpdate()
            
            // Clear the refresh flag so onUpdate() doesn't keep enqueueing the worker
            try {
                val flutterPrefs = applicationContext.getSharedPreferences(
                    "FlutterSharedPreferences",
                    android.content.Context.MODE_PRIVATE
                )
                flutterPrefs.edit().remove("flutter.widget_refresh_timestamp").apply()
                logDebug("WidgetCacheUpdateWorker: ✓ Cleared refresh flag")
            } catch (e: Exception) {
                logDebug("WidgetCacheUpdateWorker: Could not clear flag: ${e.message}")
            }
            
            logDebug("WidgetCacheUpdateWorker: ✓ Complete")
            Result.success()
            
        } catch (e: Exception) {
            logError("WidgetCacheUpdateWorker: Exception", e)
            Result.retry()
        }
    }

    /**
     * Fetch prayer times from Dart widget cache system
     * 
     * NOTE: The cache should have already been updated by background_tasks.dart
     * when it called WidgetCacheUpdater.updateCacheWithPrayerTimesMap()
     * We simply read the already-updated cache here.
     */
    private suspend fun fetchPrayerTimesFromDart(): Map<String, String> {
        return withContext(Dispatchers.IO) {
            try {
                // Wait a brief moment to ensure Dart has finished writing the cache
                Thread.sleep(1000)
                
                // Read cached widget data from Dart's FlutterSharedPreferences
                val sharedPreferences = applicationContext.getSharedPreferences(
                    "FlutterSharedPreferences",
                    Context.MODE_PRIVATE
                )
                
                val cacheJson = sharedPreferences.getString("flutter.widget_info_cache", null)
                
                if (cacheJson == null) {
                    logDebug("WidgetCacheUpdateWorker: No cache in FlutterSharedPreferences")
                    return@withContext emptyMap()
                }
                
                // Parse the JSON
                val gson = Gson()
                val jsonObject = gson.fromJson(cacheJson, JsonObject::class.java)
                
                // Extract prayer times
                val prayerTimes = mutableMapOf<String, String>()
                
                val prayerKeys = listOf("fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha")
                for (key in prayerKeys) {
                    prayerTimes[key] = jsonObject.get(key)?.asString ?: "N/A"
                }
                
                // Extract metadata
                prayerTimes["source"] = jsonObject.get("source")?.asString ?: "unknown"
                prayerTimes["location"] = jsonObject.get("location")?.asString ?: "Unknown"
                prayerTimes["hue"] = jsonObject.get("hue")?.asDouble?.toString() ?: "0.0"
                prayerTimes["isDarkMode"] = jsonObject.get("isDarkMode")?.asBoolean?.toString() ?: "false"
                prayerTimes["bgTransparency"] = jsonObject.get("bgTransparency")?.asDouble?.toString() ?: "1.0"
                prayerTimes["cacheDateDdMmYyyy"] = jsonObject.get("cacheDateDdMmYyyy")?.asString ?: ""
                
                return@withContext prayerTimes
                
            } catch (e: Exception) {
                logError("WidgetCacheUpdateWorker: Error parsing cache", e)
                return@withContext emptyMap()
            }
        }
    }

    /**
     * Save prayer times to SharedPreferences for widget access
     */
    private fun savePrayerTimesToPrefs(prayerTimesMap: Map<String, String>) {
        try {
            val widgetPrefs = applicationContext.getSharedPreferences(
                "widget_prefs",
                Context.MODE_PRIVATE
            )
            
            val gson = Gson()
            val jsonString = gson.toJson(prayerTimesMap)
            
            val editor = widgetPrefs.edit()
            editor.putString(WIDGET_CACHE_KEY, jsonString)
            editor.putLong(LAST_UPDATE_TIME_KEY, System.currentTimeMillis())
            editor.apply()
            
        } catch (e: Exception) {
            logError("WidgetCacheUpdateWorker: Error saving prefs", e)
        }
    }

    /**
     * Trigger widget UI update via broadcast
     */
    private fun triggerWidgetUpdate() {
        try {
            val widgetManager = AppWidgetManager.getInstance(applicationContext)
            
            // Get vertical widget IDs
            val componentNameVertical = android.content.ComponentName(
                applicationContext,
                PrayerWidgetProvider::class.java
            )
            val verticalWidgetIds = widgetManager.getAppWidgetIds(componentNameVertical)
            logDebug("Worker: Found ${verticalWidgetIds.size} vertical widget(s): ${verticalWidgetIds.joinToString(",")}")
            
            // Get horizontal widget IDs
            val componentNameHorizontal = android.content.ComponentName(
                applicationContext,
                PrayerWidgetProviderHorizontal::class.java
            )
            val horizontalWidgetIds = widgetManager.getAppWidgetIds(componentNameHorizontal)
            logDebug("Worker: Found ${horizontalWidgetIds.size} horizontal widget(s): ${horizontalWidgetIds.joinToString(",")}")
            
            // Send broadcast to trigger onUpdate for vertical widgets
            if (verticalWidgetIds.isNotEmpty()) {
                val intentVertical = Intent(AppWidgetManager.ACTION_APPWIDGET_UPDATE).apply {
                    setClass(applicationContext, PrayerWidgetProvider::class.java)
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, verticalWidgetIds)
                }
                applicationContext.sendBroadcast(intentVertical)
                logDebug("Worker: ✓ Broadcast sent for ${verticalWidgetIds.size} vertical widget(s)")
            } else {
                logDebug("WidgetCacheUpdateWorker: No vertical widgets found")
            }
            
            // Send broadcast to trigger onUpdate for horizontal widgets
            if (horizontalWidgetIds.isNotEmpty()) {
                val intentHorizontal = Intent(AppWidgetManager.ACTION_APPWIDGET_UPDATE).apply {
                    setClass(applicationContext, PrayerWidgetProviderHorizontal::class.java)
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, horizontalWidgetIds)
                }
                applicationContext.sendBroadcast(intentHorizontal)
            }
            
            if (verticalWidgetIds.isEmpty() && horizontalWidgetIds.isEmpty()) {
                logDebug("WidgetCacheUpdateWorker: ⚠ No widgets found on device")
            }
            
        } catch (e: Exception) {
            logError("WidgetCacheUpdateWorker: Exception sending broadcast", e)
        }
    }

    private fun logDebug(message: String) {
        Log.d(DEBUG_TAG, message)
    }
    
    private fun logError(message: String, exception: Exception? = null) {
        Log.e(DEBUG_TAG, message, exception)
    }
}

