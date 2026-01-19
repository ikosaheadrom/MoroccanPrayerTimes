import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_config.dart';

/// Schedules reminder notifications (prayer time - X minutes)
class ReminderNotificationScheduler {
  static const String _debugTag = '[ReminderNotificationScheduler]';

  /// Schedule a reminder notification before a prayer with countdown
  static Future<void> scheduleReminderNotification({
    required FlutterLocalNotificationsPlugin plugin,
    required String prayerName,
    required tz.TZDateTime reminderTime,
    required tz.TZDateTime prayerTime,
    required int reminderMinutes,
    required NotificationState notificationState,
    bool enableCountdownTimer = false,
  }) async {
    try {
      debugPrint('$_debugTag Scheduling reminder for $prayerName at $reminderTime');
      
      // Validate that prayer time is after reminder time
      if (!prayerTime.isAfter(reminderTime)) {
        debugPrint('$_debugTag ✗ Invalid reminder times - prayer time must be after reminder time');
        return;
      }

      final channelId = getReminderChannelId(notificationState);
      final reminderId = ('${prayerName}_reminder_${reminderTime.day}${reminderTime.month}').hashCode;
      final enableVibration = notificationState != NotificationState.silent;
      final playSound = notificationState == NotificationState.full;

      // Get reminder color from preferences (less saturated than athan)
      final prefs = await SharedPreferences.getInstance();
      final hue = prefs.getDouble('primaryHue') ?? 260.0;
      final reminderColor = HSLColor.fromAHSL(1.0, hue, 0.45, 0.55).toColor();

      // Schedule NOTIFICATION #1: Visual Timer with Chronometer
      await plugin.zonedSchedule(
        reminderId,
        'Reminder: $prayerName in $reminderMinutes minutes',
        'Get ready for $prayerName',
        reminderTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            'Prayer Reminders',
            channelDescription: 'Countdown timer notifications',
            importance: Importance.max,
            priority: Priority.max,
            icon: 'ic_notification',
            enableLights: true,
            tag: 'reminder_$prayerName',
            color: reminderColor,
            // Native Chronometer countdown
            usesChronometer: true,
            chronometerCountDown: true,
            when: prayerTime.millisecondsSinceEpoch,
            showWhen: true,
            playSound: playSound,
            enableVibration: enableVibration,
            // Auto-dismiss countdown notification at prayer time (after countdown duration)
            timeoutAfter: Duration(minutes: reminderMinutes).inMilliseconds,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: jsonEncode({
          'type': 'reminder',
          'prayer': prayerName,
          'scheduledTime': reminderTime.millisecondsSinceEpoch,
          'state': notificationState.value,
          'hasCountdown': enableCountdownTimer,
        }),
      );

      debugPrint('$_debugTag ✓ Successfully scheduled reminder countdown for $prayerName');
    } catch (e) {
      debugPrint('$_debugTag ✗ Failed to schedule reminder for $prayerName: $e');
      rethrow;
    }
  }

  /// Schedule reminders for all prayers
  static Future<int> scheduleRemindersForDay({
    required FlutterLocalNotificationsPlugin plugin,
    required Map<String, String> prayerTimes,
    required int reminderMinutes,
    required NotificationState notificationState,
    required tz.Location timezone,
    bool useAdvancedControl = false,
    Map<String, dynamic> reminderStatesMap = const {},
    bool enableCountdownTimer = false,
  }) async {
    int scheduledCount = 0;
    final now = tz.TZDateTime.now(timezone);

    final prayers = {
      'Fajr': prayerTimes['fajr'],
      'Sunrise': prayerTimes['sunrise'],
      'Dhuhr': prayerTimes['dhuhr'],
      'Asr': prayerTimes['asr'],
      'Maghrib': prayerTimes['maghrib'],
      'Isha': prayerTimes['isha'],
    };

    for (final entry in prayers.entries) {
      final prayerName = entry.key;
      final timeStr = entry.value;

      if (timeStr == null || timeStr == 'N/A') {
        debugPrint('$_debugTag Skipping reminder for $prayerName - N/A time');
        continue;
      }

      // Determine notification state for this reminder
      late NotificationState reminderNotificationState;
      if (useAdvancedControl) {
        final stateValue = reminderStatesMap[prayerName] as int? ?? 2;
        reminderNotificationState = NotificationState.fromValue(stateValue);
      } else {
        reminderNotificationState = notificationState;
      }

      // Skip if reminder is disabled (-1)
      if (reminderNotificationState == NotificationState.off) {
        debugPrint('$_debugTag Skipping $prayerName reminder - disabled');
        continue;
      }

      try {
        final parts = timeStr.replaceAll(RegExp(r'[^0-9:]'), '').split(':');
        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;

        final prayerDateTime = tz.TZDateTime(timezone, now.year, now.month, now.day, hour, minute, 0);
        final reminderDateTime = prayerDateTime.subtract(Duration(minutes: reminderMinutes));

        // Skip if reminder time has already passed today
        if (!reminderDateTime.isAfter(now)) {
          debugPrint('$_debugTag Skipping reminder for $prayerName - reminder time has already passed ($reminderDateTime is not after $now)');
          continue;
        }

        await scheduleReminderNotification(
          plugin: plugin,
          prayerName: prayerName,
          reminderTime: reminderDateTime,
          prayerTime: prayerDateTime,
          reminderMinutes: reminderMinutes,
          notificationState: reminderNotificationState,
          enableCountdownTimer: enableCountdownTimer,
        );
        scheduledCount++;
      } catch (e) {
        debugPrint('$_debugTag Error scheduling reminder for $prayerName: $e');
      }
    }

    return scheduledCount;
  }
}
