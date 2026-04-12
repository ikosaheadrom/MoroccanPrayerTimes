package com.example.pray_time

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.Log
import java.util.Calendar

/**
 * Helper class to schedule the daily 2 AM widget refresh alarm.
 */
object WidgetAlarmScheduler {
    
    private const val DEBUG_TAG = "[WidgetAlarmScheduler]"
    private const val HOUR_OF_DAY = 2  // 2 AM
    private const val MINUTE = 30      // 30 minutes after 2 AM (2:30 AM) to ensure daily refresh already completed

    /**
     * Schedule the widget refresh alarm to run daily at 2 AM.
     * Call this from MainActivity.onCreate() to set up the alarm.
     */
    fun scheduleWidgetRefreshAlarm(context: Context) {
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            
            // Create intent for the broadcast receiver
            val intent = Intent(context, WidgetRefreshReceiver::class.java)
            intent.action = WidgetRefreshReceiver.ACTION_REFRESH_WIDGET
            
            // Create pending intent
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                0,  // requestCode
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            // Calculate time for next 2 AM
            val calendar = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, HOUR_OF_DAY)
                set(Calendar.MINUTE, MINUTE)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
                
                // If current time is already past 2 AM, schedule for tomorrow
                if (before(Calendar.getInstance())) {
                    add(Calendar.DAY_OF_MONTH, 1)
                }
            }
            
            // Schedule the alarm
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                calendar.timeInMillis,
                pendingIntent
            )
            
            Log.d(DEBUG_TAG, "✓ Widget refresh alarm scheduled for ${calendar.time} daily")
            
        } catch (e: Exception) {
            Log.e(DEBUG_TAG, "✗ Failed to schedule widget refresh alarm", e)
        }
    }
}
