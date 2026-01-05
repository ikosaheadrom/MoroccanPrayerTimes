import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'notification_config.dart';
import 'prayer_notification_scheduler.dart';
import 'reminder_notification_scheduler.dart';

/// Central notification management service
class NotificationManager {
  static const String _debugTag = '[NotificationManager]';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  /// Schedule all notifications for today's prayer times
  Future<int> scheduleNotificationsForTodaysPrayers({
    required Map<String, String> prayerTimes,
    required bool reminderEnabled,
    required int reminderMinutes,
    required NotificationState notificationState,
    required AthanSoundType athanSoundType,
    required tz.Location timezone,
    bool dryRun = false,
  }) async {
    int totalScheduled = 0;

    try {
      debugPrint('$_debugTag ═══════════════════════════════════════════');
      debugPrint('$_debugTag Scheduling notifications:');
      debugPrint('$_debugTag   Global State: ${notificationState.label}');
      debugPrint('$_debugTag   Athan Type: ${athanSoundType.label}');
      debugPrint('$_debugTag   Reminder Enabled: $reminderEnabled ($reminderMinutes min before)');
      debugPrint('$_debugTag   Dry Run: $dryRun');
      debugPrint('$_debugTag ═══════════════════════════════════════════');

      if (dryRun) {
        debugPrint('$_debugTag DRY RUN - No notifications will be scheduled');
        return 0;
      }

      // Read per-prayer notification states from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final prayerStatesJson = prefs.getString('prayerNotificationStates') ?? '{}';
      final prayerStatesMap = jsonDecode(prayerStatesJson) as Map<String, dynamic>;
      final reminderStatesJson = prefs.getString('reminderNotificationStates') ?? '{}';
      final reminderStatesMap = jsonDecode(reminderStatesJson) as Map<String, dynamic>;
      
      final useAdvancedNotificationControl = prefs.getBool('useAdvancedNotificationControl') ?? false;
      
      debugPrint('$_debugTag Advanced control enabled: $useAdvancedNotificationControl');
      if (useAdvancedNotificationControl) {
        debugPrint('$_debugTag Prayer states: $prayerStatesMap');
        debugPrint('$_debugTag Reminder states: $reminderStatesMap');
      }

      // Schedule prayer notifications for each prayer with its specific state
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

        // Determine notification state for this prayer
        late NotificationState prayerNotificationState;
        if (useAdvancedNotificationControl) {
          // Use per-prayer state if advanced control is enabled
          final stateValue = prayerStatesMap[prayerName] as int? ?? 2;
          prayerNotificationState = NotificationState.fromValue(stateValue);
        } else {
          // Use global state
          prayerNotificationState = notificationState;
        }

        // Skip if prayer notification is disabled (-1)
        if (prayerNotificationState == NotificationState.off) {
          debugPrint('$_debugTag Skipping $prayerName athan - disabled');
          continue;
        }

        try {
          final parts = timeStr.replaceAll(RegExp(r'[^0-9:]'), '').split(':');
          final hour = int.tryParse(parts[0]) ?? 0;
          final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
          final scheduledTime = tz.TZDateTime(timezone, now.year, now.month, now.day, hour, minute, 0);

          if (scheduledTime.isBefore(now)) {
            debugPrint('$_debugTag Skipping $prayerName - already passed');
            continue;
          }

          await PrayerNotificationScheduler.schedulePrayerNotification(
            plugin: _plugin,
            prayerName: prayerName,
            scheduledTime: scheduledTime,
            notificationState: prayerNotificationState,
            athanSoundType: athanSoundType,
          );
          totalScheduled++;
        } catch (e) {
          debugPrint('$_debugTag Error scheduling $prayerName: $e');
        }
      }

      debugPrint('$_debugTag Scheduled $totalScheduled prayer notifications');

      // Schedule reminder notifications if enabled
      if (reminderEnabled && reminderMinutes > 0) {
        final reminderCount = await ReminderNotificationScheduler.scheduleRemindersForDay(
          plugin: _plugin,
          prayerTimes: prayerTimes,
          reminderMinutes: reminderMinutes,
          notificationState: notificationState,
          timezone: timezone,
          useAdvancedControl: useAdvancedNotificationControl,
          reminderStatesMap: reminderStatesMap,
        );
        totalScheduled += reminderCount;
        debugPrint('$_debugTag Scheduled $reminderCount reminder notifications');
      }

      debugPrint('$_debugTag ✓ Total notifications scheduled: $totalScheduled');
    } catch (e, st) {
      debugPrint('$_debugTag ✗ Error scheduling notifications: $e');
      debugPrint('$_debugTag Stack: $st');
      rethrow;
    }

    return totalScheduled;
  }

  /// Cancel all prayer-related notifications
  Future<void> cancelAllPrayerNotifications() async {
    try {
      debugPrint('$_debugTag Cancelling all prayer notifications...');
      await _plugin.cancelAll();
      debugPrint('$_debugTag ✓ All notifications cancelled');
    } catch (e) {
      debugPrint('$_debugTag ✗ Error cancelling notifications: $e');
      rethrow;
    }
  }

  /// Cancel notifications for specific prayers
  Future<void> cancelNotificationsForPrayers(List<String> prayerNames) async {
    try {
      debugPrint('$_debugTag Cancelling notifications for: $prayerNames');
      final pending = await _plugin.pendingNotificationRequests();

      for (final prayer in prayerNames) {
        for (final notification in pending) {
          if (notification.title?.contains(prayer) ?? false) {
            await _plugin.cancel(notification.id);
            debugPrint('$_debugTag Cancelled notification ${notification.id}');
          }
        }
      }
    } catch (e) {
      debugPrint('$_debugTag Error cancelling specific notifications: $e');
      rethrow;
    }
  }

  /// Get count of pending notifications
  Future<int> getPendingNotificationCount() async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      return pending.length;
    } catch (e) {
      debugPrint('$_debugTag Error getting pending notification count: $e');
      return 0;
    }
  }

  /// List all pending notifications
  Future<void> debugListPendingNotifications() async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      debugPrint('$_debugTag ═══════════════════════════════════════════');
      debugPrint('$_debugTag Pending Notifications: ${pending.length}');
      for (final notif in pending) {
        debugPrint('$_debugTag ID: ${notif.id} | Title: ${notif.title} | Body: ${notif.body}');
      }
      debugPrint('$_debugTag ═══════════════════════════════════════════');
    } catch (e) {
      debugPrint('$_debugTag Error listing pending notifications: $e');
    }
  }
}
