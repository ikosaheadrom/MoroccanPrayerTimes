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
            logDebug("╔════════════════════════════════════════════════════════╗")
            logDebug("║ WIDGET CACHE UPDATE WORKER - STARTING                  ║")
            logDebug("╚════════════════════════════════════════════════════════╝")
            
            // Fetch prayer times from Dart widget cache system
            val prayerTimesMap = fetchPrayerTimesFromDart()
            
            if (prayerTimesMap.isEmpty()) {
                logError("doWork: ✗ Failed to fetch prayer times from Dart - map is empty")
                return@withContext Result.retry()
            }
            
            logDebug("doWork: ✓ Prayer times fetched successfully (${prayerTimesMap.size} entries)")
            
            // Save to SharedPreferences
            savePrayerTimesToPrefs(prayerTimesMap)
            
            // Update widget UI
            triggerWidgetUpdate()
            
            logDebug("╔════════════════════════════════════════════════════════╗")
            logDebug("║ WIDGET CACHE UPDATE WORKER - COMPLETED                 ║")
            logDebug("╚════════════════════════════════════════════════════════╝")
            Result.success()
            
        } catch (e: Exception) {
            logError("doWork: ✗ Unexpected error", e)
            Result.retry()
        }
    }

    /**
     * Fetch prayer times from Dart widget cache system
     * This calls the Dart method to fetch FRESH prayer times, not just read cached data
     */
    private suspend fun fetchPrayerTimesFromDart(): Map<String, String> {
        return withContext(Dispatchers.IO) {
            try {
                logDebug("──── fetchPrayerTimesFromDart START (REQUESTING FRESH DATA FROM DART) ────")
                
                // First try to call Dart to fetch FRESH prayer times via the MainActivity's MethodChannel
                logDebug("fetchPrayerTimesFromDart: Attempting to fetch FRESH prayer times from Dart...")
                try {
                    // This will trigger MainActivity to call Dart's refreshWidget method
                    // which calls quickUpdateWidgetCache() to fetch fresh data
                    val intent = Intent("com.example.pray_time.REFRESH_WIDGET_CACHE")
                    intent.setPackage(applicationContext.packageName)
                    applicationContext.sendBroadcast(intent)
                    logDebug("fetchPrayerTimesFromDart: ✓ Sent broadcast to refresh widget cache in Dart")
                    
                    // Wait a bit for Dart to process and cache the fresh data
                    Thread.sleep(1000)
                } catch (e: Exception) {
                    logDebug("fetchPrayerTimesFromDart: Failed to trigger fresh fetch: ${e.message}")
                }
                
                // Now read the (hopefully fresh) cached widget data from Dart's SharedPreferences
                val sharedPreferences = applicationContext.getSharedPreferences(
                    "FlutterSharedPreferences",
                    Context.MODE_PRIVATE
                )
                
                logDebug("fetchPrayerTimesFromDart: FlutterSharedPreferences obtained")
                logDebug("fetchPrayerTimesFromDart: Total keys in FlutterSharedPreferences: ${sharedPreferences.all.size}")
                
                // Get the widget data from Dart's SharedPreferences
                val cacheJson = sharedPreferences.getString("flutter.widget_info_cache", null)
                
                if (cacheJson == null) {
                    logError("fetchPrayerTimesFromDart: ✗ No cached data from Dart - 'flutter.widget_info_cache' is NULL")
                    logDebug("fetchPrayerTimesFromDart: All available keys: ${sharedPreferences.all.keys}")
                    return@withContext emptyMap()
                }
                
                logDebug("fetchPrayerTimesFromDart: ✓ Cache JSON found (${cacheJson.length} chars)")
                logDebug("fetchPrayerTimesFromDart: Cache value: ${cacheJson.take(150)}...")
                
                // Parse the JSON
                val gson = Gson()
                val jsonObject = gson.fromJson(cacheJson, JsonObject::class.java)
                
                logDebug("fetchPrayerTimesFromDart: ✓ JSON parsed successfully")
                logDebug("fetchPrayerTimesFromDart: JSON keys: ${jsonObject.keySet()}")
                
                // Extract prayer times
                val prayerTimes = mutableMapOf<String, String>()
                
                val prayerKeys = listOf("fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha")
                for (key in prayerKeys) {
                    val value = jsonObject.get(key)?.asString ?: "N/A"
                    prayerTimes[key] = value
                    logDebug("fetchPrayerTimesFromDart: ✓ $key = $value")
                }
                
                // Also extract metadata
                prayerTimes["source"] = jsonObject.get("source")?.asString ?: "unknown"
                prayerTimes["location"] = jsonObject.get("location")?.asString ?: "Unknown"
                prayerTimes["hue"] = jsonObject.get("hue")?.asDouble?.toString() ?: "0.0"
                prayerTimes["isDarkMode"] = jsonObject.get("isDarkMode")?.asBoolean?.toString() ?: "false"
                prayerTimes["bgTransparency"] = jsonObject.get("bgTransparency")?.asDouble?.toString() ?: "1.0"
                prayerTimes["cacheDateDdMmYyyy"] = jsonObject.get("cacheDateDdMmYyyy")?.asString ?: ""
                prayerTimes["cacheTimestampMs"] = jsonObject.get("cacheTimestampMs")?.asString ?: ""
                
                logDebug("fetchPrayerTimesFromDart: ✓ Metadata extracted")
                logDebug("fetchPrayerTimesFromDart: Source: ${prayerTimes["source"]}")
                logDebug("fetchPrayerTimesFromDart: Location: ${prayerTimes["location"]}")
                logDebug("fetchPrayerTimesFromDart: Hue: ${prayerTimes["hue"]}")
                logDebug("fetchPrayerTimesFromDart: IsDarkMode: ${prayerTimes["isDarkMode"]}")
                logDebug("fetchPrayerTimesFromDart: BgTransparency: ${prayerTimes["bgTransparency"]}")
                logDebug("fetchPrayerTimesFromDart: CacheDate: ${prayerTimes["cacheDateDdMmYyyy"]}")
                logDebug("──── fetchPrayerTimesFromDart COMPLETE ────")
                
                return@withContext prayerTimes
                
            } catch (e: Exception) {
                logError("fetchPrayerTimesFromDart: ✗ Exception while parsing cache data", e)
                return@withContext emptyMap()
            }
        }
    }

    /**
     * Save prayer times to SharedPreferences for widget access
     */
    private fun savePrayerTimesToPrefs(prayerTimesMap: Map<String, String>) {
        try {
            logDebug("──── savePrayerTimesToPrefs START ────")
            
            val widgetPrefs = applicationContext.getSharedPreferences(
                "widget_prefs",
                Context.MODE_PRIVATE
            )
            
            logDebug("savePrayerTimesToPrefs: widget_prefs SharedPreferences obtained")
            
            val gson = Gson()
            val jsonString = gson.toJson(prayerTimesMap)
            
            logDebug("savePrayerTimesToPrefs: JSON to save (${jsonString.length} chars): ${jsonString.take(150)}...")
            
            val editor = widgetPrefs.edit()
            editor.putString(WIDGET_CACHE_KEY, jsonString)
            logDebug("savePrayerTimesToPrefs: ✓ Added $WIDGET_CACHE_KEY to editor")
            
            editor.putLong(LAST_UPDATE_TIME_KEY, System.currentTimeMillis())
            logDebug("savePrayerTimesToPrefs: ✓ Added $LAST_UPDATE_TIME_KEY to editor")
            
            editor.apply()
            logDebug("savePrayerTimesToPrefs: ✓ Applied changes to widget_prefs")
            
            // Verify the save
            val verifyValue = widgetPrefs.getString(WIDGET_CACHE_KEY, null)
            if (verifyValue != null) {
                logDebug("savePrayerTimesToPrefs: ✓ VERIFICATION SUCCESS - Data was saved to widget_prefs")
                logDebug("savePrayerTimesToPrefs: Verified content: ${verifyValue.take(150)}...")
            } else {
                logError("savePrayerTimesToPrefs: ✗ VERIFICATION FAILED - Data NOT found in widget_prefs after save!")
            }
            
            logDebug("──── savePrayerTimesToPrefs COMPLETE ────")
            
        } catch (e: Exception) {
            logError("savePrayerTimesToPrefs: ✗ Exception while saving", e)
        }
    }

    /**
     * Trigger widget UI update
     */
    private fun triggerWidgetUpdate() {
        try {
            logDebug("──── triggerWidgetUpdate START ────")
            
            val widgetManager = AppWidgetManager.getInstance(applicationContext)
            
            // Get vertical widget IDs
            val componentNameVertical = android.content.ComponentName(
                applicationContext,
                PrayerWidgetProvider::class.java
            )
            val verticalWidgetIds = widgetManager.getAppWidgetIds(componentNameVertical)
            logDebug("triggerWidgetUpdate: Found ${verticalWidgetIds.size} vertical widget IDs")
            
            for (id in verticalWidgetIds) {
                logDebug("triggerWidgetUpdate: Vertical Widget ID: $id")
            }
            
            // Get horizontal widget IDs
            val componentNameHorizontal = android.content.ComponentName(
                applicationContext,
                PrayerWidgetProviderHorizontal::class.java
            )
            val horizontalWidgetIds = widgetManager.getAppWidgetIds(componentNameHorizontal)
            logDebug("triggerWidgetUpdate: Found ${horizontalWidgetIds.size} horizontal widget IDs")
            
            for (id in horizontalWidgetIds) {
                logDebug("triggerWidgetUpdate: Horizontal Widget ID: $id")
            }
            
            // Send broadcast to trigger onUpdate for vertical widgets
            if (verticalWidgetIds.isNotEmpty()) {
                val intentVertical = Intent(applicationContext, PrayerWidgetProvider::class.java).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, verticalWidgetIds)
                }
                applicationContext.sendBroadcast(intentVertical)
                logDebug("triggerWidgetUpdate: ✓ Broadcast sent to vertical widget")
            }
            
            // Send broadcast to trigger onUpdate for horizontal widgets
            if (horizontalWidgetIds.isNotEmpty()) {
                val intentHorizontal = Intent(applicationContext, PrayerWidgetProviderHorizontal::class.java).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, horizontalWidgetIds)
                }
                applicationContext.sendBroadcast(intentHorizontal)
                logDebug("triggerWidgetUpdate: ✓ Broadcast sent to horizontal widget")
            }
            
            logDebug("triggerWidgetUpdate: ✓ All broadcasts sent successfully")
            logDebug("──── triggerWidgetUpdate COMPLETE ────")
            
        } catch (e: Exception) {
            logError("triggerWidgetUpdate: ✗ Exception while sending broadcast", e)
        }
    }

    private fun logDebug(message: String) {
        Log.d(DEBUG_TAG, message)
    }
    
    private fun logError(message: String, exception: Exception? = null) {
        Log.e(DEBUG_TAG, message, exception)
    }
}

