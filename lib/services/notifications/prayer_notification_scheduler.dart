import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_config.dart';

/// Schedules prayer time (athan) notifications
class PrayerNotificationScheduler {
  static const String _debugTag = '[PrayerNotificationScheduler]';

  /// Helper function to get next prayer/event message
  /// Calculates time difference from current prayer time to next prayer time
  static String _getNextPrayerMessage(String currentPrayer, Map<String, String> allPrayerTimes) {
    const prayerOrder = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    
    final currentIndex = prayerOrder.indexOf(currentPrayer);
    if (currentIndex == -1 || currentIndex >= prayerOrder.length - 1) {
      return '$currentPrayer has begun';
    }
    
    // Get current prayer time from allPrayerTimes
    final currentTimeStr = allPrayerTimes[currentPrayer.toLowerCase()] ?? '';
    final currentParts = currentTimeStr.replaceAll(RegExp(r'[^0-9:]'), '').split(':');
    final currentHour = int.tryParse(currentParts[0]) ?? 0;
    final currentMinute = int.tryParse(currentParts.length > 1 ? currentParts[1] : '0') ?? 0;
    
    final nextPrayer = prayerOrder[currentIndex + 1];
    // Convert prayer name to lowercase for map lookup (keys are lowercase: 'fajr', 'sunrise', etc.)
    final nextTimeStr = allPrayerTimes[nextPrayer.toLowerCase()] ?? 'N/A';
    
    if (nextTimeStr == 'N/A' || nextTimeStr.isEmpty) {
      return '$currentPrayer has begun';
    }
    
    final nextParts = nextTimeStr.replaceAll(RegExp(r'[^0-9:]'), '').split(':');
    final nextHour = int.tryParse(nextParts[0]) ?? 0;
    final nextMinute = int.tryParse(nextParts.length > 1 ? nextParts[1] : '0') ?? 0;
    
    // Create DateTime objects for current and next prayer times using today's date
    var currentTime = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, currentHour, currentMinute);
    var nextTime = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, nextHour, nextMinute);
    
    // Handle case where next prayer is tomorrow (e.g., Isha to next day's Fajr)
    if (nextTime.isBefore(currentTime)) {
      nextTime = nextTime.add(const Duration(days: 1));
    }
    
    final difference = nextTime.difference(currentTime);
    final hours = difference.inHours;
    final minutes = difference.inMinutes % 60;
    
    if (hours > 0) {
      if (minutes > 0) {
        return '$nextPrayer is in ${hours}h ${minutes}m';
      } else {
        return '$nextPrayer is in ${hours}h';
      }
    } else {
      return '$nextPrayer is in ${minutes}m';
    }
  }

  /// Schedule a prayer (athan) notification at the specified time
  static Future<void> schedulePrayerNotification({
    required FlutterLocalNotificationsPlugin plugin,
    required String prayerName,
    required tz.TZDateTime scheduledTime,
    required NotificationState notificationState,
    required AthanSoundType athanSoundType,
    Map<String, String>? allPrayerTimes,
  }) async {
    try {
      debugPrint('$_debugTag Scheduling $prayerName notification at $scheduledTime');

      final channelId = getPrayerChannelId(notificationState, athanType: athanSoundType);
      final notificationId = (prayerName + scheduledTime.toString()).hashCode;
      final enableVibration = notificationState != NotificationState.silent;
      final playSound = notificationState == NotificationState.full;
      
      // Get next prayer message if all prayer times provided
      // Calculates time from current prayer to next prayer based on prayer times data
      final notificationBody = allPrayerTimes != null 
        ? _getNextPrayerMessage(prayerName, allPrayerTimes)
        : '';
      
      // Get athan color from preferences
      final prefs = await SharedPreferences.getInstance();
      final hue = prefs.getDouble('primaryHue') ?? 260.0;
      final athanColor = HSLColor.fromAHSL(1.0, hue, 0.80, 0.50).toColor();
      
      // Add insistent flag for full/short athan so it doesn't get dismissed by pulling down
      final isAthanSound = athanSoundType == AthanSoundType.fullAthan || athanSoundType == AthanSoundType.shortAthan;
      final insistentFlag = 4; // Notification.FLAG_INSISTENT = 4
      final additionalFlagsForAthan = isAthanSound ? Int32List.fromList(<int>[insistentFlag]) : null;

      await plugin.zonedSchedule(
        notificationId,
        'Time for $prayerName Prayer',
        notificationBody,
        scheduledTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            'Prayer Times Notifications',
            channelDescription: 'Notifications for prayer times',
            importance: Importance.max,
            priority: Priority.max,
            icon: 'ic_notification',
            enableLights: true,
            tag: 'prayer_$prayerName',
            color: athanColor,
            playSound: playSound,
            enableVibration: enableVibration,
            additionalFlags: additionalFlagsForAthan,
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
          'type': 'athan',
          'prayer': prayerName,
          'scheduledTime': scheduledTime.millisecondsSinceEpoch,
          'state': notificationState.value,
          'hasCountdown': false,
        }),
      );

      debugPrint('$_debugTag ✓ Successfully scheduled $prayerName notification');
    } catch (e) {
      debugPrint('$_debugTag ✗ Failed to schedule $prayerName notification: $e');
      rethrow;
    }
  }

  /// Schedule multiple prayer notifications for all prayers in a map
  static Future<int> schedulePrayerNotificationsForDay({
    required FlutterLocalNotificationsPlugin plugin,
    required Map<String, String> prayerTimes,
    required NotificationState notificationState,
    required AthanSoundType athanSoundType,
    required tz.Location timezone,
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
        debugPrint('$_debugTag Skipping $prayerName - N/A time');
        continue;
      }

      try {
        final parts = timeStr.replaceAll(RegExp(r'[^0-9:]'), '').split(':');
        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;

        final scheduledTime = tz.TZDateTime(timezone, now.year, now.month, now.day, hour, minute, 0);

        // Skip if prayer time has already passed today
        if (scheduledTime.isBefore(now)) {
          debugPrint('$_debugTag Skipping $prayerName - time has already passed today ($scheduledTime is before $now)');
          continue;
        }

        await schedulePrayerNotification(
          plugin: plugin,
          prayerName: prayerName,
          scheduledTime: scheduledTime,
          notificationState: notificationState,
          athanSoundType: athanSoundType,
        );
        scheduledCount++;
      } catch (e) {
        debugPrint('$_debugTag Error scheduling $prayerName: $e');
      }
    }

    return scheduledCount;
  }
}
