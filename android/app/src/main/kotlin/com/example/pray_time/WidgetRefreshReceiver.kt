package com.example.pray_time

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.appwidget.AppWidgetManager
import android.util.Log

/**
 * BroadcastReceiver that handles the daily 2 AM widget refresh alarm.
 * 
 * Triggered by AlarmManager at 2 AM every day.
 * Updates the widget with the latest cached prayer times.
 */
class WidgetRefreshReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_REFRESH_WIDGET = "com.example.pray_time.WIDGET_REFRESH_ALARM"
        private const val DEBUG_TAG = "[WidgetRefreshReceiver]"
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null) return
        
        if (intent?.action == ACTION_REFRESH_WIDGET) {
            Log.d(DEBUG_TAG, "═══════════════════════════════════════════════")
            Log.d(DEBUG_TAG, "📱 2 AM WIDGET REFRESH ALARM TRIGGERED")
            Log.d(DEBUG_TAG, "═══════════════════════════════════════════════")
            
            try {
                // Read cached prayer times from Dart's FlutterSharedPreferences
                val flutterPrefs = context.getSharedPreferences(
                    "FlutterSharedPreferences",
                    Context.MODE_PRIVATE
                )
                val cacheJson = flutterPrefs.getString("flutter.widget_info_cache", null)
                
                if (cacheJson != null && cacheJson.isNotEmpty()) {
                    Log.d(DEBUG_TAG, "✓ Found cached prayer times, updating widget storage...")
                    
                    // Copy cache to widget storage (widget_prefs) - use commit() for synchronous write
                    val widgetPrefs = context.getSharedPreferences("widget_prefs", Context.MODE_PRIVATE)
                    widgetPrefs.edit().apply {
                        putString("widget_info_cache", cacheJson)
                        putLong("widget_last_update_time", System.currentTimeMillis())
                    }.commit()  // Use commit() instead of apply() for synchronous write
                    
                    Log.d(DEBUG_TAG, "✓ Widget cache updated successfully")
                    
                    // Update widgets DIRECTLY without sending another broadcast
                    // This avoids the "double-hop" broadcast that can be dropped on Android 12+
                    val appWidgetManager = AppWidgetManager.getInstance(context)
                    
                    // Update Vertical Widget
                    Log.d(DEBUG_TAG, "↳ Updating Vertical Widget...")
                    val verticalProvider = ComponentName(context, PrayerWidgetProvider::class.java)
                    val verticalIds = appWidgetManager.getAppWidgetIds(verticalProvider)
                    for (id in verticalIds) {
                        try {
                            PrayerWidgetProvider().updateAppWidget(context, appWidgetManager, id)
                            Log.d(DEBUG_TAG, "  ✓ Vertical widget $id updated")
                        } catch (e: Exception) {
                            Log.e(DEBUG_TAG, "  ✗ Failed to update vertical widget $id", e)
                        }
                    }
                    
                    // Update Horizontal Widget
                    Log.d(DEBUG_TAG, "↳ Updating Horizontal Widget...")
                    val horizontalProvider = ComponentName(context, PrayerWidgetProviderHorizontal::class.java)
                    val horizontalIds = appWidgetManager.getAppWidgetIds(horizontalProvider)
                    for (id in horizontalIds) {
                        try {
                            PrayerWidgetProviderHorizontal().updateAppWidget(context, appWidgetManager, id)
                            Log.d(DEBUG_TAG, "  ✓ Horizontal widget $id updated")
                        } catch (e: Exception) {
                            Log.e(DEBUG_TAG, "  ✗ Failed to update horizontal widget $id", e)
                        }
                    }
                    
                    Log.d(DEBUG_TAG, "✓ Widget refresh complete (direct update, no broadcast)")
                } else {
                    Log.w(DEBUG_TAG, "⚠ No cached prayer times found")
                }
                
            } catch (e: Exception) {
                Log.e(DEBUG_TAG, "✗ Error refreshing widget", e)
            }
            
            // Reschedule the alarm for tomorrow
            WidgetAlarmScheduler.scheduleWidgetRefreshAlarm(context)
            Log.d(DEBUG_TAG, "✓ Next alarm scheduled for tomorrow at 2:30 AM")
        }
    }
}
