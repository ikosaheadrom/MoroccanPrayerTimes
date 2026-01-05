import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'notification_config.dart';

/// Schedules prayer time (athan) notifications
class PrayerNotificationScheduler {
  static const String _debugTag = '[PrayerNotificationScheduler]';

  /// Schedule a prayer (athan) notification at the specified time
  static Future<void> schedulePrayerNotification({
    required FlutterLocalNotificationsPlugin plugin,
    required String prayerName,
    required tz.TZDateTime scheduledTime,
    required NotificationState notificationState,
    required AthanSoundType athanSoundType,
  }) async {
    try {
      debugPrint('$_debugTag Scheduling $prayerName notification at $scheduledTime');

      final channelId = getPrayerChannelId(notificationState, athanType: athanSoundType);
      final notificationId = (prayerName + scheduledTime.toString()).hashCode;
      final enableVibration = notificationState != NotificationState.silent;
      final playSound = notificationState == NotificationState.full;
      
      // Add insistent flag for full/short athan so it doesn't get dismissed by pulling down
      final isAthanSound = athanSoundType == AthanSoundType.fullAthan || athanSoundType == AthanSoundType.shortAthan;
      final insistentFlag = 4; // Notification.FLAG_INSISTENT = 4
      final additionalFlagsForAthan = isAthanSound ? Int32List.fromList(<int>[insistentFlag]) : null;

      await plugin.zonedSchedule(
        notificationId,
        'Time for $prayerName Prayer',
        'It is now time for $prayerName prayer',
        scheduledTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            'Prayer Times Notifications',
            channelDescription: 'Notifications for prayer times',
            importance: Importance.max,
            priority: Priority.max,
            enableLights: true,
            tag: 'prayer_$prayerName',
            color: Colors.green,
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
