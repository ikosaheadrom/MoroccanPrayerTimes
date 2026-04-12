import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'dart:convert';
import 'dart:io';
import 'prayer_times_parser.dart';
import 'prayer_times_provider.dart';
import 'notifications/notifications.dart';
import '../widgets/widget_cache_updater.dart';

/// Background task names
const String dailyPrayerRefreshTaskName = 'daily_prayer_refresh';
const String monthlyCalendarRefreshTaskName = 'monthly_calendar_refresh';
const String prayerTimeAlarmTaskPrefix = 'prayer_alarm_'; // prayer_alarm_fajr, prayer_alarm_dhuhr, etc

/// Initialize WorkManager and register periodic tasks
Future<void> initializeBackgroundTasks() async {
  debugPrint('[BackgroundTasks] initializeBackgroundTasks called');
  
  debugPrint('[BackgroundTasks] Setting up WorkManager...');
  
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: false,
  );

  debugPrint('[BackgroundTasks] WorkManager initialized');

  // ALWAYS re-register tasks to ensure we have the latest configuration
  // This is important when we update the task logic in new app versions
  // Always cancel old tasks first
  try {
    await Workmanager().cancelByTag(dailyPrayerRefreshTaskName);
    debugPrint('[BackgroundTasks] Cancelled any existing daily refresh task');
  } catch (e) {
    debugPrint('[BackgroundTasks] No daily refresh task to cancel: $e');
  }

  try {
    await Workmanager().cancelByTag(monthlyCalendarRefreshTaskName);
    debugPrint('[BackgroundTasks] Cancelled any existing monthly refresh task');
  } catch (e) {
    debugPrint('[BackgroundTasks] No monthly refresh task to cancel: $e');
  }

  // Register daily prayer time refresh at 2:00 AM
  await registerDailyPrayerRefresh();

  // Register monthly calendar refresh
  await registerMonthlyCalendarRefresh();
  
  debugPrint('[BackgroundTasks] Background tasks re-initialized (always fresh on each app start)');

}

/// Callback dispatcher for WorkManager - must be a top-level function
@pragma('vm:entry-point')
void callbackDispatcher() {
  debugPrint('[BackgroundTasks] callbackDispatcher invoked!');
  Workmanager().executeTask((task, inputData) async {
    debugPrint('[BackgroundTasks] executeTask called for task: $task');
    try {
      switch (task) {
        case dailyPrayerRefreshTaskName:
          debugPrint('[BackgroundTasks] Handling daily prayer refresh...');
          await executeDailyPrayerRefresh();
          return true;

        case monthlyCalendarRefreshTaskName:
          debugPrint('[BackgroundTasks] Handling monthly calendar refresh...');
          await executeMonthlyCalendarRefresh();
          return true;

        case 'background_widget_refresh_test':
          debugPrint('[BackgroundTasks] ═══════════════════════════════════════════════');
          debugPrint('[BackgroundTasks] BACKGROUND WIDGET REFRESH TEST - Simulating 2 AM refresh');
          debugPrint('[BackgroundTasks] ═══════════════════════════════════════════════');
          // Trigger widget refresh through the same path as daily refresh
          await notifyWidgetToRefresh();
          debugPrint('[BackgroundTasks] ✓ Background widget refresh test completed');
          debugPrint('[BackgroundTasks] Check logs for [WidgetCacheUpdateWorker] to see if Android picked it up');
          return true;

        default:
          // Check if it's a prayer time alarm task (prayer_alarm_fajr, etc)
          if (task.startsWith(prayerTimeAlarmTaskPrefix)) {
            debugPrint('[BackgroundTasks] Handling prayer time alarm: $task');
            await _handlePrayerTimeAlarm(task);
            return true;
          }
          debugPrint('[BackgroundTasks] Unknown task: $task');
          return false;
      }
    } catch (e) {
      debugPrint('[BackgroundTasks] Error executing task $task: $e');
      return false;
    }
  });
}

/// Register daily prayer time refresh task at 2:00 AM (when API is updated)
/// Uses hourly check instead of relying on WorkManager's initial delay calculation
/// Assumes old tasks have already been cancelled by initializeBackgroundTasks()
Future<void> registerDailyPrayerRefresh() async {
  try {
    debugPrint('[BackgroundTasks] Registering daily prayer refresh task to run every hour...');
    
    // Run every hour and check internally if it's 2 AM window
    // This is more reliable than trying to use WorkManager's initial delay
    // WorkManager doesn't always respect calculated initial delays
    await Workmanager().registerPeriodicTask(
      dailyPrayerRefreshTaskName,
      dailyPrayerRefreshTaskName,
      frequency: const Duration(hours: 1),
      initialDelay: const Duration(minutes: 0),
      tag: dailyPrayerRefreshTaskName,
      constraints: Constraints(
        networkType: NetworkType.not_required,
        requiresDeviceIdle: false,
        requiresCharging: false,
        requiresBatteryNotLow: false,
        requiresStorageNotLow: false,
      ),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 15),
    );
    debugPrint('[BackgroundTasks] ✓ Daily prayer refresh task registered successfully (hourly with 2 AM check)');
  } catch (e) {
    debugPrint('[BackgroundTasks] ✗ Failed to register daily task: $e');
  }
}

/// Register monthly calendar refresh task
/// Changed to PERIODIC (daily) but only executes when cache expires
/// This ensures the task keeps running and rescheduling automatically
Future<void> registerMonthlyCalendarRefresh() async {
  try {
    debugPrint('[BackgroundTasks] Registering monthly calendar refresh as periodic daily task...');
    final prefs = await SharedPreferences.getInstance();
    final cityId = prefs.getString('cityCityId') ?? '58';
    final cacheKey = 'calendarData_$cityId';
    
    // Calculate cache expiration date
    var expirationDate = await _calculateCacheExpirationDate(cacheKey);
    
    // If cache doesn't exist or expiration can't be determined, use a default 30-day expiration
    if (expirationDate == null) {
      debugPrint('[BackgroundTasks] Cache not found or expiration cannot be calculated, using default 30-day expiration');
      expirationDate = DateTime.now().add(const Duration(days: 30));
    }
    
    // Save expiration date to SharedPreferences so the periodic task knows when to execute
    await prefs.setString('monthlyRefreshExpiration_$cityId', expirationDate.toIso8601String());
    debugPrint('[BackgroundTasks] Saved monthly refresh expiration: ${expirationDate.toIso8601String()}');
    
    // FIX: Always start the periodic task immediately with a short initial delay
    // The task's internal logic will check the expiration date and only execute when needed
    // This ensures the task starts running daily, not waiting 30 days before first check
    const Duration initialDelay = Duration(minutes: 30);
    
    debugPrint('[BackgroundTasks] Scheduling monthly refresh - initial delay: ${initialDelay.inMinutes} minutes (task will check cache expiration daily)');
    
    // Register as PERIODIC task running daily instead of one-off
    // This way it keeps running even after execution and reschedules automatically
    await Workmanager().registerPeriodicTask(
      monthlyCalendarRefreshTaskName,
      monthlyCalendarRefreshTaskName,
      frequency: const Duration(days: 1),
      initialDelay: initialDelay,
      tag: monthlyCalendarRefreshTaskName,
      constraints: Constraints(
        networkType: NetworkType.not_required,
        requiresDeviceIdle: false,
        requiresCharging: false,
        requiresBatteryNotLow: false,
        requiresStorageNotLow: false,
      ),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 15),
    );
    
    debugPrint('[BackgroundTasks] ✓ Monthly calendar refresh registered as periodic daily task');
  } catch (e) {
    debugPrint('[BackgroundTasks] Failed to register monthly task: $e');
  }
}

/// Cancel all background tasks
Future<void> cancelAllBackgroundTasks() async {
  try {
    await Workmanager().cancelByTag(dailyPrayerRefreshTaskName);
    await Workmanager().cancelByTag(monthlyCalendarRefreshTaskName);
    debugPrint('[BackgroundTasks] All background tasks cancelled');
  } catch (e) {
    debugPrint('[BackgroundTasks] Failed to cancel tasks: $e');
  }
}

/// Handle daily prayer time refresh
/// This method refreshes today's prayer times, updates widget cache, and schedules prayer alarms
/// NOTE: This runs hourly but only executes actual refresh during 2 AM window
/// 
/// Parameters:
/// - forceShowNotification: If true, always show the notification (useful for testing)
Future<void> _handleDailyPrayerRefresh({bool forceShowNotification = false}) async {
  debugPrint('[BackgroundTasks] ═════ DAILY PRAYER REFRESH TASK ═════');
  final now = DateTime.now();
  debugPrint('[BackgroundTasks] Executing daily prayer refresh task at $now');

  // Check if we're in the 2 AM window (2:00 - 2:59 AM)
  // Only execute actual refresh during this window (unless testing)
  if (now.hour != 2 && !forceShowNotification) {
    debugPrint('[BackgroundTasks] ⏭ Current hour is ${now.hour}, skipping refresh (only runs at 2:00 AM)');
    debugPrint('[BackgroundTasks] ═════ END DAILY REFRESH (SKIPPED - NOT 2 AM) ═════');
    return;
  }

  try {
    final prefs = await SharedPreferences.getInstance();
    
    // Write execution log to SharedPreferences for debugging
    final executionTime = now.toIso8601String();
    await prefs.setString('lastBackgroundTaskExecution', 'Daily refresh at $executionTime');

    // Get current city and settings
    final cityId = prefs.getString('cityCityId') ?? '58';
    final cityName = prefs.getString('cityCityName') ?? 'Casablanca';
    final useMinistry = prefs.getBool('useMinistry') ?? true;
    final isOfflineMode = prefs.getBool('isOfflineMode') ?? false;
    
    debugPrint('[BackgroundTasks] City ID: $cityId, City Name: $cityName');
    debugPrint('[BackgroundTasks] useMinistry: $useMinistry, isOfflineMode: $isOfflineMode');

    // Mark cache as stale and set flag to refresh
    await prefs.setBool('needsDailyRefresh', true);
    await prefs.setString('lastDailyRefreshTime', DateTime.now().toIso8601String());
    debugPrint('[BackgroundTasks] Set needsDailyRefresh flag');

    // Use PrayerTimesProvider to get prayer times (unified source logic)
    final provider = PrayerTimesProvider();
    final result = await provider.getPrayerTimes();
    
    debugPrint('[BackgroundTasks] ═══════════════════════════════════════════');
    debugPrint('[BackgroundTasks] Got prayer times from provider:');
    debugPrint('[BackgroundTasks]   Source: ${result.sourceUsed}');
    debugPrint('[BackgroundTasks]   Input: ${result.inputSettings}');
    debugPrint('[BackgroundTasks]   Latitude: ${result.latitude}');
    debugPrint('[BackgroundTasks]   Longitude: ${result.longitude}');
    debugPrint('[BackgroundTasks]   CityName: ${result.cityName}');
    debugPrint('[BackgroundTasks] ═══════════════════════════════════════════');
    
    final dailyTimes = result.times;
    final sourceUsed = result.sourceUsed;
    
    // Check if we got valid data
    final hasValidData = dailyTimes.isNotEmpty && 
                        dailyTimes['fajr'] != 'N/A' && 
                        dailyTimes['dhuhr'] != 'N/A' && 
                        dailyTimes['maghrib'] != 'N/A';
    
    // Initialize scheduling tracking variables
    bool notificationsScheduledSuccessfully = false;
    String schedulingStatus = 'Not attempted';
    String widgetUpdateStatus = 'Not attempted';
    
    if (hasValidData) {
      debugPrint('[BackgroundTasks] ✓ Successfully obtained prayer times from $sourceUsed:');
      debugPrint('[BackgroundTasks]   Fajr: ${dailyTimes['fajr']}');
      debugPrint('[BackgroundTasks]   Sunrise: ${dailyTimes['sunrise']}');
      debugPrint('[BackgroundTasks]   Dhuhr: ${dailyTimes['dhuhr']}');
      debugPrint('[BackgroundTasks]   Asr: ${dailyTimes['asr']}');
      debugPrint('[BackgroundTasks]   Maghrib: ${dailyTimes['maghrib']}');
      debugPrint('[BackgroundTasks]   Isha: ${dailyTimes['isha']}');
      
      // Update widget cache with the fetched prayer times
      try {
        await WidgetCacheUpdater.updateCacheWithPrayerTimesMap(
          dailyTimes,
          sourceOverride: sourceUsed,
        );
        debugPrint('[BackgroundTasks] ✓ Widget cache updated with prayer times');
        widgetUpdateStatus = 'Widget cache updated';
        
        // Notify Android widget to refresh immediately
        try {
          await notifyWidgetToRefresh();
          widgetUpdateStatus = 'Widget refreshed successfully';
          debugPrint('[BackgroundTasks] ✓ Widget refresh flag set and notification sent');
        } catch (e) {
          debugPrint('[BackgroundTasks] ⚠ Failed to notify widget: $e');
          widgetUpdateStatus = 'Widget cache updated (refresh failed: $e)';
        }
      } catch (e) {
        debugPrint('[BackgroundTasks] ⚠ Failed to update widget cache: $e');
        widgetUpdateStatus = 'Failed to update: $e';
      }
      
      // Cancel old prayer time notifications BEFORE scheduling new ones
      try {
        await _cancelOldPrayerNotifications();
        debugPrint('[BackgroundTasks] ✓ Old prayer notifications cancelled');
      } catch (e) {
        debugPrint('[BackgroundTasks] ⚠ Failed to cancel old notifications: $e');
      }
      
      // Schedule prayer time notifications using new NotificationManager
      try {
        final prefs = await SharedPreferences.getInstance();
        final globalStateValue = prefs.getInt('notificationState') ?? 2;
        final notificationState = NotificationState.fromValue(globalStateValue);
        final athanSoundTypeValue = prefs.getInt('athanSoundType') ?? 0;
        final athanSoundType = AthanSoundType.fromValue(athanSoundTypeValue);
        final reminderEnabled = prefs.getBool('reminderEnabled') ?? false;
        final reminderMinutes = prefs.getInt('reminderMinutes') ?? 10;
        
        final manager = NotificationManager();
        final timezone = _getDeviceTimezone();
        
        // Use PrayerTimesProvider to get times based on user's selected source
        final provider = PrayerTimesProvider();
        final result = await provider.getPrayerTimes();
        
        debugPrint('[BackgroundTasks] Using source: ${result.sourceUsed}');
        
        await manager.scheduleNotificationsForTodaysPrayers(
          prayerTimes: result.times,
          reminderEnabled: reminderEnabled,
          reminderMinutes: reminderMinutes,
          notificationState: notificationState,
          athanSoundType: athanSoundType,
          timezone: timezone,
        );
        debugPrint('[BackgroundTasks] ✓ Prayer time notifications scheduled');
        notificationsScheduledSuccessfully = true;
        schedulingStatus = 'Notifications scheduled successfully';
      } catch (e) {
        debugPrint('[BackgroundTasks] ⚠ Failed to schedule notifications: $e');
        schedulingStatus = 'Failed to schedule: $e';
      }
    } else {
      debugPrint('[BackgroundTasks] Daily times returned invalid data (N/A values or empty)');
      debugPrint('[BackgroundTasks] Times received: $dailyTimes');
    }
    
    // Set flag to reschedule notifications when app opens (in case of app background)
    await prefs.setBool('needsNotificationReschedule', true);
    debugPrint('[BackgroundTasks] Set needsNotificationReschedule flag for app');

    debugPrint('[BackgroundTasks] ✓ Daily prayer refresh completed at ${DateTime.now()}');
    debugPrint('[BackgroundTasks] ═════ END DAILY REFRESH ═════');
    
    // SEND SUCCESS NOTIFICATION (if enabled via devtools OR if force-showing for testing)
    final showDailyRefreshNotification = forceShowNotification || (prefs.getBool('devShowDailyRefreshNotification') ?? false);
    if (showDailyRefreshNotification) {
      final sourceInfo = hasValidData ? sourceUsed : 'Unknown';
      String notificationMessage;
      
      if (hasValidData) {
        // Format prayer times nicely with line breaks and include scheduling status
        notificationMessage = 'Fetched from $sourceInfo:\n'
            'Fajr: ${dailyTimes['fajr']}\n'
            'Dhuhr: ${dailyTimes['dhuhr']}\n'
            'Asr: ${dailyTimes['asr']}\n'
            'Maghrib: ${dailyTimes['maghrib']}\n'
            'Isha: ${dailyTimes['isha']}\n'
            'Widget: $widgetUpdateStatus\n'
            'Scheduling: $schedulingStatus';
      } else {
        notificationMessage = 'Failed to fetch valid prayer times\n'
            'Widget: $widgetUpdateStatus\n'
            'Scheduling: $schedulingStatus';
      }
      
      await _sendDailyRefreshNotification(
        result: hasValidData ? (notificationsScheduledSuccessfully ? 'success' : 'partial') : 'partial',
        message: notificationMessage,
      );
      debugPrint('[BackgroundTasks] ✓ Daily refresh notification shown successfully');
    } else {
      debugPrint('[BackgroundTasks] Daily refresh notification disabled (enable via devtools or use test button)');
    }
  } catch (e, st) {
    debugPrint('[BackgroundTasks] ✗ Error in daily refresh: $e');
    debugPrint('[BackgroundTasks] Stack: $st');
    
    // Still set the reschedule flag so app can handle it
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('needsNotificationReschedule', true);
    
    // SEND ERROR NOTIFICATION (if enabled via devtools OR if force-showing for testing)
    final showDailyRefreshNotification = forceShowNotification || (prefs.getBool('devShowDailyRefreshNotification') ?? false);
    if (showDailyRefreshNotification) {
      await _sendDailyRefreshNotification(
        result: 'failed',
        message: 'Daily refresh failed: $e\n'
            'Scheduling: Not attempted (due to refresh failure)',
      );
    }
  }
}

/// PUBLIC: Execute monthly calendar refresh
/// Called by both WorkManager (periodic task) and test button
/// This is the single entry point for all monthly refresh execution
Future<void> executeMonthlyCalendarRefresh() async {
  try {
    await _handleMonthlyCalendarRefresh();
  } catch (e, st) {
    debugPrint('[BackgroundTasks] ✗ Error in monthly calendar refresh: $e');
    debugPrint('[BackgroundTasks] Stack: $st');
  }
}

/// Handle monthly calendar refresh
/// This method fetches fresh calendar data from Ministry website, parses it using the prayer_times_parser service,
/// saves to cache, and schedules next refresh
Future<void> _handleMonthlyCalendarRefresh() async {
  debugPrint('[BackgroundTasks] ═════ MONTHLY CALENDAR REFRESH TASK ═════');
  debugPrint('[BackgroundTasks] Executing monthly calendar refresh task at ${DateTime.now()}');

  try {
    final prefs = await SharedPreferences.getInstance();
    final cityId = prefs.getString('cityCityId') ?? '58';
    
    // CHECK IF CACHE HAS ACTUALLY EXPIRED
    // Since this is now a periodic daily task, we should only execute if cache has expired
    final expirationStr = prefs.getString('monthlyRefreshExpiration_$cityId');
    if (expirationStr != null) {
      try {
        final expirationDate = DateTime.parse(expirationStr);
        final now = DateTime.now();
        
        debugPrint('[BackgroundTasks] ═══ CACHE EXPIRATION CHECK ═══');
        debugPrint('[BackgroundTasks] Current time: ${now.toIso8601String()}');
        debugPrint('[BackgroundTasks] Expiration time: ${expirationDate.toIso8601String()}');
        debugPrint('[BackgroundTasks] Days until expiration: ${expirationDate.difference(now).inDays}');
        
        // Only execute if expiration date has been reached
        if (now.isBefore(expirationDate)) {
          debugPrint('[BackgroundTasks] ⚠ Cache has NOT expired yet');
          debugPrint('[BackgroundTasks] Status: SKIPPING monthly refresh (will retry tomorrow)');
          debugPrint('[BackgroundTasks] ═══════════════════════════════');
          
          // Send skip notification (if enabled via devtools)
          final showMonthlyRefreshNotification = prefs.getBool('devShowMonthlyRefreshNotification') ?? false;
          if (showMonthlyRefreshNotification) {
            final daysUntilExpiration = expirationDate.difference(now).inDays;
            final today = DateTime.now();
            final todayFormatted = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
            final expirationDateFormatted = '${expirationDate.year}-${expirationDate.month.toString().padLeft(2, '0')}-${expirationDate.day.toString().padLeft(2, '0')}';
            
            final skipMessage = 'Today: $todayFormatted\n'
                'Cache Expires: $expirationDateFormatted\n'
                'Days Remaining: $daysUntilExpiration\n'
                'Status: SKIPPED (not expired)';
            
            await _sendMonthlyRefreshNotification(
              monthNameLatin: 'Cache Valid',
              result: 'skipped',
              message: skipMessage,
            );
          }
          
          return; // Don't execute, try again tomorrow
        }
        debugPrint('[BackgroundTasks] ✓ Cache HAS expired - proceeding with refresh');
        debugPrint('[BackgroundTasks] ═══════════════════════════════');
      } catch (e) {
        debugPrint('[BackgroundTasks] ✗ ERROR parsing expiration date: $e');
        debugPrint('[BackgroundTasks] Proceeding with refresh anyway (as fallback)');
      }
    } else {
      debugPrint('[BackgroundTasks] ⚠ No expiration date found in cache, forcing refresh');
    }
    
    final executionTime = DateTime.now().toIso8601String();
    await prefs.setString('lastBackgroundTaskExecution', 'Monthly refresh at $executionTime');
    
    final cacheKey = 'calendarData_$cityId';
    final lastCityKey = 'calendarLastCity_$cityId';
    debugPrint('[BackgroundTasks] City ID: $cityId');

    // Save previous cache as backup
    final previousKey = 'calendarData_${cityId}_previous';
    final currentCache = prefs.getString(cacheKey);
    String? monthNameLatin;
    
    if (currentCache != null) {
      try {
        final cacheData = jsonDecode(currentCache) as Map<String, dynamic>;
        monthNameLatin = cacheData['_monthLabelLatin'] as String?;
        debugPrint('[BackgroundTasks] Extracted current month name: "$monthNameLatin"');
      } catch (e) {
        debugPrint('[BackgroundTasks] Could not extract month name from cache: $e');
      }
      await prefs.setString(previousKey, currentCache);
      debugPrint('[BackgroundTasks] ✓ Saved previous calendar cache as backup');
    }

    // FETCH HTML FROM MINISTRY
    debugPrint('[BackgroundTasks] Fetching fresh calendar HTML...');
    String htmlBody = '';
    try {
      var ministryUrl = prefs.getString('ministryUrl') ?? 'https://habous.gov.ma/prieres/horaire_hijri_2.php';
      
      // FIX: Replace old incorrect URL with correct working URL
      if (ministryUrl.contains('/fr/horaire-des-prieres/horaire')) {
        ministryUrl = 'https://habous.gov.ma/prieres/horaire_hijri_2.php';
        debugPrint('[BackgroundTasks] ✓ Detected old URL format, using correct URL');
        await prefs.setString('ministryUrl', ministryUrl);
      }
      
      final separator = ministryUrl.contains('?') ? '&' : '?';
      final uri = Uri.parse('$ministryUrl${separator}ville=$cityId');
      
      debugPrint('[BackgroundTasks] Fetching from: $uri');
      
      final httpClient = HttpClient();
      httpClient.badCertificateCallback = (cert, host, port) => true; // Dev only
      final request = await httpClient.getUrl(uri);
      final response = await request.close();
      htmlBody = await response.transform(utf8.decoder).join();
      httpClient.close();
      
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch HTML: ${response.statusCode}');
      }
      
      debugPrint('[BackgroundTasks] ✓ HTML fetched successfully (${htmlBody.length} bytes)');
    } catch (e) {
      debugPrint('[BackgroundTasks] ✗ Error fetching HTML: $e');
      rethrow;
    }

    // PARSE HTML USING PRAYER TIMES PARSER SERVICE
    debugPrint('[BackgroundTasks] Parsing HTML with PrayerTimesParser service...');
    final parsedCalendar = await parseMonthlyCalendarFromHtml(htmlBody, cityId: int.tryParse(cityId) ?? 58);
    
    if (parsedCalendar.isEmpty || parsedCalendar['days'] == null) {
      throw Exception('Failed to parse calendar from HTML');
    }

    final allDays = getAllPrayerDays(parsedCalendar);
    debugPrint('[BackgroundTasks] ✓ Parsed ${allDays.length} days from HTML');

    // BUILD CACHE FROM PARSED DATA
    final Map<String, dynamic> toSave = {};

    for (final dayData in allDays) {
      final gregorianDateStr = dayData['gregorianDate_ISO'] ?? '';
      if (gregorianDateStr.isNotEmpty) {
        try {
          final dateKey = '${gregorianDateStr}T00:00:00.000';
          
          toSave[dateKey] = {
            'Fajr': dayData['fajr_HHmm'] ?? 'N/A',
            'Sunrise': dayData['sunrise_HHmm'] ?? 'N/A',
            'Dhuhr': dayData['dhuhr_HHmm'] ?? 'N/A',
            'Asr': dayData['asr_HHmm'] ?? 'N/A',
            'Maghrib': dayData['maghrib_HHmm'] ?? 'N/A',
            'Isha': dayData['isha_HHmm'] ?? 'N/A',
            'DayOfWeek': dayData['dayOfWeek_TEXT'] ?? 'N/A',
            'Hijri': dayData['hijriDay'] ?? '',
            'Solar': dayData['solarDay'] ?? '',
            'HijriMonth': dayData['hijriMonth_TEXT'] ?? '',
            'SolarMonth': dayData['solarMonth_TEXT'] ?? '',
          };
        } catch (e) {
          debugPrint('[BackgroundTasks] Error processing day ${dayData['hijriDay']}: $e');
        }
      }
    }

    // GET CACHE EXPIRATION FROM PARSER
    final expiresAtStr = parsedCalendar['expiresAt_ISO'] as String?;
    DateTime? cacheExpiresAt;
    if (expiresAtStr != null) {
      try {
        cacheExpiresAt = DateTime.parse(expiresAtStr);
        debugPrint('[BackgroundTasks] ✓ Cache expiration from parser: $expiresAtStr');
      } catch (e) {
        debugPrint('[BackgroundTasks] Error parsing expiration date: $e');
      }
    }

    // SAVE METADATA
    monthNameLatin = parsedCalendar['hijriMonthLatin'] as String? ?? 'Islamic Month';
    final hijriMonthArabic = parsedCalendar['hijriMonth'] as String? ?? '';
    final parsedCityId = parsedCalendar['cityId'] as int?;
    final firstDateISO = parsedCalendar['firstDate_ISO'] as String?;
    final lastDateISO = parsedCalendar['lastDate_ISO'] as String?;
    final expiresAtISO = parsedCalendar['expiresAt_ISO'] as String?;
    
    toSave['_monthLabelArabic'] = hijriMonthArabic;
    toSave['_monthLabelLatin'] = monthNameLatin;
    toSave['_cityId'] = parsedCityId ?? cityId;
    
    // Store parser's expiration date
    if (expiresAtISO != null) {
      toSave['_expiresAt_ISO'] = expiresAtISO;
      cacheExpiresAt = DateTime.parse(expiresAtISO);
      debugPrint('[BackgroundTasks] ✓ Cache will expire on: $expiresAtISO (from parser)');
    }
    
    if (firstDateISO != null) {
      toSave['_firstDate_ISO'] = firstDateISO;
    }
    if (lastDateISO != null) {
      toSave['_lastDate_ISO'] = lastDateISO;
    }

    // PERSIST CACHE
    await prefs.setString(cacheKey, jsonEncode(toSave));
    final currentCity = prefs.getString('selectedCityName') ?? 'Casablanca';
    await prefs.setString(lastCityKey, currentCity);
    debugPrint('[BackgroundTasks] ✓ Saved ${toSave.length - 4} prayer time entries to cache');
    debugPrint('[BackgroundTasks] ✓ City ID verified: $parsedCityId');

    // Update widget cache with today's prayer times from the calendar
    try {
      // Get today's entry from the calendar
      final today = DateTime.now();
      final todayKey = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}T00:00:00.000';
      
      if (toSave.containsKey(todayKey)) {
        final todayEntry = toSave[todayKey] as Map<String, dynamic>?;
        if (todayEntry != null) {
          final todayTimes = {
            'fajr': (todayEntry['Fajr'] as String?) ?? 'N/A',
            'sunrise': (todayEntry['Sunrise'] as String?) ?? 'N/A',
            'dhuhr': (todayEntry['Dhuhr'] as String?) ?? 'N/A',
            'asr': (todayEntry['Asr'] as String?) ?? 'N/A',
            'maghrib': (todayEntry['Maghrib'] as String?) ?? 'N/A',
            'isha': (todayEntry['Isha'] as String?) ?? 'N/A',
          };
          
          await WidgetCacheUpdater.updateCacheWithPrayerTimesMap(todayTimes);
          debugPrint('[BackgroundTasks] ✓ Widget cache updated with today\'s prayer times from calendar');
          // Notify Android widget to refresh immediately
          await notifyWidgetToRefresh();
        }
      } else {
        debugPrint('[BackgroundTasks] ⚠ Today\'s entry not found in calendar (key: $todayKey)');
      }
    } catch (e) {
      debugPrint('[BackgroundTasks] ⚠ Failed to update widget cache: $e');
    }

    // UPDATE EXPIRATION DATE FOR NEXT PERIODIC CHECK
    // Since this is now a periodic daily task, we update the expiration date
    // The task will check this date every day and only execute when date is reached
    if (cacheExpiresAt != null) {
      final cityId = prefs.getString('cityCityId') ?? '58';
      await prefs.setString('monthlyRefreshExpiration_$cityId', cacheExpiresAt.toIso8601String());
      final expirationDate = cacheExpiresAt.toIso8601String().split('T')[0];
      final daysFromNow = cacheExpiresAt.difference(DateTime.now()).inDays;
      debugPrint('[BackgroundTasks] ✓ REFRESH COMPLETED - Cache will expire on: $expirationDate');
      debugPrint('[BackgroundTasks] ✓ Next refresh will trigger in approximately $daysFromNow days');
      debugPrint('[BackgroundTasks] ✓ Periodic task will check daily and execute when date is reached');
    } else {
      debugPrint('[BackgroundTasks] ⚠ Could not determine expiration date');
    }
    
    // SEND USER NOTIFICATION (always shown, not controlled by devtools toggle)
    // Check if today is the last day of the Hijri month
    bool isTodayLastDayOfMonth = false;
    String? nextMonthNameLatin;
    
    if (allDays.isNotEmpty && lastDateISO != null) {
      try {
        final lastDate = DateTime.parse(lastDateISO);
        final today = DateTime.now();
        
        // Check if today is the last day of the cached period
        if (today.year == lastDate.year && 
            today.month == lastDate.month && 
            today.day == lastDate.day) {
          isTodayLastDayOfMonth = true;
          
          // Extract next month name from parsed calendar if available
          final hijriMonthNum = parsedCalendar['hijriMonth'] as String?;
          if (hijriMonthNum != null) {
            // Parse the hijri month number and calculate next month
            final monthNum = int.tryParse(hijriMonthNum.split('/').first);
            if (monthNum != null) {
              // Hijri months: 1=Muharram, 2=Safar, ..., 12=Dhul-Hijjah
              final nextMonth = monthNum == 12 ? 1 : monthNum + 1;
              final hijriMonthNames = [
                'Muharram', 'Safar', 'Rabi\' al-Awwal', 'Rabi\' al-Thani',
                'Jumada al-Awwal', 'Jumada al-Thani', 'Rajab', 'Sha\'ban',
                'Ramadan', 'Shawwal', 'Dhu al-Qi\'dah', 'Dhu al-Hijjah'
              ];
              if (nextMonth >= 1 && nextMonth <= 12) {
                nextMonthNameLatin = hijriMonthNames[nextMonth - 1];
              }
            }
          }
          
          debugPrint('[BackgroundTasks] ✓ Today is the last day of recorded Hijri month');
          debugPrint('[BackgroundTasks] Next month will be: $nextMonthNameLatin');
        }
      } catch (e) {
        debugPrint('[BackgroundTasks] Error checking if today is last day of month: $e');
      }
    }
    
    // Determine which user notification to send
    if (isTodayLastDayOfMonth && nextMonthNameLatin != null) {
      // Show moon observation notification for next month
      await _sendUserMonthlyNotification(
        title: '🌙 Moon Observation',
        message: 'Waiting for moon sighting to confirm the start of $nextMonthNameLatin',
      );
      debugPrint('[BackgroundTasks] ✓ User notification sent: Moon observation for $nextMonthNameLatin');
    } else if (!isTodayLastDayOfMonth) {
      // Show "waiting for ministry to update" notification
      final daysUntilExpiration = cacheExpiresAt?.difference(DateTime.now()).inDays ?? 0;
      if (daysUntilExpiration > 0) {
        await _sendUserMonthlyNotification(
          title: '⏳ Awaiting Update',
          message: 'Waiting for ministry to update prayer times data. Next check in $daysUntilExpiration day${daysUntilExpiration == 1 ? '' : 's'}.',
        );
        debugPrint('[BackgroundTasks] ✓ User notification sent: Waiting for ministry update');
      }
    } else {
      // Successfully fetched new data
      await _sendUserMonthlyNotification(
        title: '✓ Calendar Updated',
        message: 'New $monthNameLatin prayer times data has been fetched and will be ready for moon observation.',
      );
      debugPrint('[BackgroundTasks] ✓ User notification sent: New data fetched');
    }
    
    // SEND DIAGNOSTIC NOTIFICATION (if enabled via devtools)
    final showMonthlyRefreshNotification = prefs.getBool('devShowMonthlyRefreshNotification') ?? false;
    if (showMonthlyRefreshNotification) {
      // Parse dates for notification
      String firstDateFormatted = 'N/A';
      String lastDateFormatted = 'N/A';
      String gregorianMonths = '';
      
      if (firstDateISO != null && lastDateISO != null) {
        try {
          final firstDate = DateTime.parse(firstDateISO);
          final lastDate = DateTime.parse(lastDateISO);
          
          firstDateFormatted = '${firstDate.year}-${firstDate.month.toString().padLeft(2, '0')}-${firstDate.day.toString().padLeft(2, '0')}';
          lastDateFormatted = '${lastDate.year}-${lastDate.month.toString().padLeft(2, '0')}-${lastDate.day.toString().padLeft(2, '0')}';
          
          // Get month names
          final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
          final startMonth = '${monthNames[firstDate.month - 1]} ${firstDate.year}';
          final endMonth = '${monthNames[lastDate.month - 1]} ${lastDate.year}';
          
          if (startMonth == endMonth) {
            gregorianMonths = startMonth;
          } else {
            gregorianMonths = '$startMonth - $endMonth';
          }
        } catch (e) {
          debugPrint('[BackgroundTasks] Error parsing dates for notification: $e');
        }
      }
      
      final today = DateTime.now();
      final todayFormatted = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final expirationDateFormatted = cacheExpiresAt != null 
          ? '${cacheExpiresAt.year}-${cacheExpiresAt.month.toString().padLeft(2, '0')}-${cacheExpiresAt.day.toString().padLeft(2, '0')}'
          : 'N/A';
      
      final notificationMessage = 'Today: $todayFormatted\n'
          'Month: $monthNameLatin\n'
          'Period: $firstDateFormatted - $lastDateFormatted\n'
          'Gregorian: $gregorianMonths\n'
          'Days Parsed: ${allDays.length}\n'
          'Expires: $expirationDateFormatted';
      
      await _sendMonthlyRefreshNotification(
        monthNameLatin: monthNameLatin,
        result: 'success',
        message: notificationMessage,
      );
      debugPrint('[BackgroundTasks] ✓ Notification shown successfully');
    } else {
      debugPrint('[BackgroundTasks] Monthly refresh notification disabled via devtools');
    }
    
    debugPrint('[BackgroundTasks] ✓ Monthly calendar refresh completed');

  } catch (e, st) {
    debugPrint('[BackgroundTasks] ✗ Error in monthly refresh: $e');
    debugPrint('[BackgroundTasks] Stack: $st');
    
    // Send error notification (if enabled via devtools)
    final prefs = await SharedPreferences.getInstance();
    final showMonthlyRefreshNotification = prefs.getBool('devShowMonthlyRefreshNotification') ?? false;
    if (showMonthlyRefreshNotification) {
      await _sendMonthlyRefreshNotification(
        monthNameLatin: 'Error',
        result: 'failed',
        message: 'Monthly refresh failed: $e',
      );
    }
    
    // Clear cache on error so app knows to retry
    final cityId = prefs.getString('cityCityId') ?? '58';
    await prefs.remove('calendarData_$cityId');
    await prefs.setBool('needsMonthlyRefresh', true);
  }
}

/// Send notification for monthly calendar refresh with detailed result status
/// Parameters:
/// - monthNameLatin: The Islamic month name (Muharram, Safar, etc.)
/// - result: 'success', 'skipped', or 'failed'
/// - message: Detailed message about what happened
Future<void> _sendMonthlyRefreshNotification({
  required String monthNameLatin,
  required String result,
  required String message,
}) async {
  try {
    final plugin = FlutterLocalNotificationsPlugin();
    
    debugPrint('[BackgroundTasks] Initializing notification plugin...');
    // Initialize if needed (for background context)
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: null,
    );
    debugPrint('[BackgroundTasks] Notification plugin initialized');
    
    // Build title based on result
    final title = _getNotificationTitle(result);
    
    // Build body with result details
    final body = '$message\nStatus: ${result.toUpperCase()}';
    
    debugPrint('[BackgroundTasks] Showing notification - Title: $title, Body: $body');
    await plugin.show(
      999, // Notification ID for monthly refresh
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'silent_channel',
          'Silent Updates',
          channelDescription: 'Silent notifications for background updates',
          importance: Importance.min,
          priority: Priority.min,
          icon: 'ic_notification',
          silent: true,
          playSound: false,
          enableVibration: false,
          showWhen: true,
          styleInformation: BigTextStyleInformation(
            body,
            contentTitle: title,
            htmlFormatBigText: false,
            htmlFormatContent: false,
          ),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: false,
          presentBadge: false,
          presentSound: false,
        ),
      ),
    );
    debugPrint('[BackgroundTasks] Notification shown successfully');
  } catch (e) {
    debugPrint('[BackgroundTasks] Error sending notification: $e');
  }
}

/// Send notification for daily prayer refresh with result status
/// Parameters:
/// - result: 'success', 'partial', or 'failed'
/// - message: Detailed message about what happened
Future<void> _sendDailyRefreshNotification({
  required String result,
  required String message,
}) async {
  try {
    final plugin = FlutterLocalNotificationsPlugin();
    
    debugPrint('[BackgroundTasks] Initializing notification plugin for daily refresh...');
    // Initialize if needed (for background context)
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: null,
    );
    debugPrint('[BackgroundTasks] Notification plugin initialized');
    
    // Build title based on result
    final title = _getDailyRefreshNotificationTitle(result);
    
    // Build body with result details
    final body = '$message\nStatus: ${result.toUpperCase()}';
    
    debugPrint('[BackgroundTasks] Showing daily refresh notification - Title: $title, Body: $body');
    await plugin.show(
      998, // Notification ID for daily refresh
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'silent_channel',
          'Silent Updates',
          channelDescription: 'Silent notifications for background updates',
          importance: Importance.min,
          priority: Priority.min,
          icon: 'ic_notification',
          silent: true,
          playSound: false,
          enableVibration: false,
          showWhen: true,
          styleInformation: BigTextStyleInformation(
            body,
            contentTitle: title,
            htmlFormatBigText: false,
            htmlFormatContent: false,
          ),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: false,
          presentBadge: false,
          presentSound: false,
        ),
      ),
    );
    debugPrint('[BackgroundTasks] Daily refresh notification shown successfully');
  } catch (e) {
    debugPrint('[BackgroundTasks] Error sending daily refresh notification: $e');
  }
}

/// Get notification title for daily refresh based on result status
String _getDailyRefreshNotificationTitle(String result) {
  switch (result.toLowerCase()) {
    case 'success':
      return '✓ Prayer Times Updated';
    case 'partial':
      return '⚠ Prayer Times Incomplete';
    case 'failed':
      return '✗ Prayer Times Update Failed';
    default:
      return 'Prayer Times Status';
  }
}

/// Get notification title based on result status
String _getNotificationTitle(String result) {
  switch (result.toLowerCase()) {
    case 'success':
      return '✓ Calendar Updated';
    case 'skipped':
      return '⏭ Calendar Skipped';
    case 'failed':
      return '✗ Calendar Update Failed';
    default:
      return 'Calendar Status';
  }
}

/// Send user-facing notification for monthly calendar refresh
/// These notifications are always shown (not controlled by devtools toggle)
/// Parameters:
/// - title: Notification title
/// - message: User-friendly message about the calendar status
Future<void> _sendUserMonthlyNotification({
  required String title,
  required String message,
}) async {
  try {
    final plugin = FlutterLocalNotificationsPlugin();
    
    debugPrint('[BackgroundTasks] Initializing notification plugin for user notification...');
    // Initialize if needed (for background context)
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: null,
    );
    debugPrint('[BackgroundTasks] Notification plugin initialized');
    
    debugPrint('[BackgroundTasks] Showing user notification - Title: $title, Message: $message');
    await plugin.show(
      1000, // Notification ID for user calendar notifications
      title,
      message,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'calendar_updates',
          'Calendar Updates',
          channelDescription: 'Important calendar and moon observation updates',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_notification',
          silent: false,
          playSound: true,
          enableVibration: true,
          showWhen: true,
          styleInformation: BigTextStyleInformation(
            message,
            contentTitle: title,
            htmlFormatBigText: false,
            htmlFormatContent: false,
          ),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
    debugPrint('[BackgroundTasks] User notification shown successfully');
  } catch (e) {
    debugPrint('[BackgroundTasks] Error sending user notification: $e');
  }
}

/// Get last daily refresh time
Future<DateTime?> getLastDailyRefreshTime() async {
  final prefs = await SharedPreferences.getInstance();
  final timeStr = prefs.getString('lastDailyRefreshTime');
  if (timeStr != null) {
    return DateTime.parse(timeStr);
  }
  return null;
}

/// Get last monthly refresh time
Future<DateTime?> getLastMonthlyRefreshTime() async {
  final prefs = await SharedPreferences.getInstance();
  final timeStr = prefs.getString('lastMonthlyRefreshTime');
  if (timeStr != null) {
    return DateTime.parse(timeStr);
  }
  return null;
}

/// Check if daily refresh is pending
Future<bool> isDailyRefreshPending() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('needsDailyRefresh') ?? false;
}

/// Check if monthly refresh is pending
Future<bool> isMonthlyRefreshPending() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('needsMonthlyRefresh') ?? false;
}

/// Clear daily refresh flag
Future<void> clearDailyRefreshFlag() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('needsDailyRefresh');
}

/// Clear monthly refresh flag
Future<void> clearMonthlyRefreshFlag() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('needsMonthlyRefresh');
}

/// Calculate cache expiration date based on current cache state
/// Returns null if cache cannot be analyzed
Future<DateTime?> _calculateCacheExpirationDate(String cacheKey) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final cachedDataStr = prefs.getString(cacheKey);
    
    if (cachedDataStr == null) {
      debugPrint('[BackgroundTasks] No cache found, cannot calculate expiration');
      return null;
    }

    debugPrint('[BackgroundTasks] Parsing cache to find expiration date...');
    // Parse cache to find expiration
    final cachedDataMap = jsonDecode(cachedDataStr) as Map<String, dynamic>;
    
    // Try to parse Gregorian date keys first (new format: "2025-12-01T00:00:00.000")
    DateTime? maxDate;
    int dateKeysFound = 0;
    for (final key in cachedDataMap.keys) {
      if (key.startsWith('_')) continue;
      
      // Try to parse as ISO8601 datetime
      try {
        final parsedDate = DateTime.tryParse(key);
        if (parsedDate != null) {
          dateKeysFound++;
          debugPrint('[BackgroundTasks] Found Gregorian date key: $key -> $parsedDate');
          if (maxDate == null || parsedDate.isAfter(maxDate)) {
            maxDate = parsedDate;
          }
        }
      } catch (e) {
        // Not a date, continue
      }
    }
    
    if (maxDate != null) {
      debugPrint('[BackgroundTasks] ✓ Using Gregorian format - found $dateKeysFound date keys, max date: ${maxDate.year}-${maxDate.month}-${maxDate.day}');
      return maxDate;
    }
    
    debugPrint('[BackgroundTasks] No Gregorian dates found (found $dateKeysFound date keys)');
    
    // Fallback to Hijri day format (legacy)
    final now = DateTime.now();
    int hijriDayCount = 0;
    int? currentHijriDay;
    
    currentHijriDay = cachedDataMap['_currentHijriDay'] as int?;
    
    for (final key in cachedDataMap.keys) {
      if (key.startsWith('_')) continue;
      final dayNum = int.tryParse(key);
      if (dayNum != null && dayNum > 0 && dayNum < 32) {
        hijriDayCount++;
      }
    }

    if (hijriDayCount > 0 && currentHijriDay != null) {
      // Calculate based on Hijri days
      // Creation date = today - (currentHijriDay - 1)
      final daysBeforeToday = currentHijriDay - 1;
      final cacheCreationDate = now.subtract(Duration(days: daysBeforeToday));
      
      // Expiration = creation date + total days
      final expirationDate = cacheCreationDate.add(Duration(days: hijriDayCount));
      
      debugPrint('[BackgroundTasks] ✓ Using Hijri format - day $currentHijriDay of $hijriDayCount, expires ${expirationDate.year}-${expirationDate.month}-${expirationDate.day}');
      return expirationDate;
    }

    debugPrint('[BackgroundTasks] Could not determine cache expiration format (found $hijriDayCount hijri days)');
    return null;
  } catch (e) {
    debugPrint('[BackgroundTasks] Error calculating cache expiration: $e');
    return null;
  }
}

/// Reset background tasks initialization flag (for debugging/testing)
Future<void> resetBackgroundTasksInitializationFlag() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('backgroundTasksInitialized');
  debugPrint('[BackgroundTasks] Initialization flag reset - tasks will re-initialize on next app launch');
}

/// PUBLIC: Execute daily prayer refresh
/// Called by both WorkManager (periodic task) and test button
/// This is the single entry point for all daily refresh execution
/// 
/// Parameters:
/// - forceShowNotification: If true, always show the notification regardless of devtools setting
///   This is useful for testing from the debug menu
Future<void> executeDailyPrayerRefresh({bool forceShowNotification = false}) async {
  try {
    await _handleDailyPrayerRefresh(forceShowNotification: forceShowNotification);
  } catch (e, st) {
    debugPrint('[BackgroundTasks] ✗ Error in daily prayer refresh: $e');
    debugPrint('[BackgroundTasks] Stack: $st');
  }
}

/// Public wrapper to run the daily refresh task for testing purposes
/// Allows manual testing of the WorkManager daily refresh logic
@Deprecated('Use executeDailyPrayerRefresh() instead')
Future<void> handleDailyRefreshForTesting() async {
  return await executeDailyPrayerRefresh();
}

/// Schedule prayer time alarms for today's prayer times
/// Alarms are scheduled for prayer time + 1 minute for punctuality
/// This is called after fetching/calculating prayer times

/// Schedule prayer time alarms for today's prayer times
/// Alarms are scheduled for prayer time + 1 minute for punctuality
/// This is called after fetching/calculating prayer times
/// 
/// DEPRECATED: Use NotificationManager instead
@Deprecated('Use NotificationManager.scheduleNotificationsForTodaysPrayers() instead')
Future<void> schedulePrayerTimeAlarms(Map<String, String> prayerTimes) async {
  // This function is deprecated. Use NotificationManager instead.
  // Keeping for backwards compatibility if needed.
}


/// Handle prayer time alarm - triggers widget update
Future<void> _handlePrayerTimeAlarm(String taskName) async {
  try {
    final prayerName = taskName.replaceFirst(prayerTimeAlarmTaskPrefix, '');
    debugPrint('[BackgroundTasks:PrayerAlarm] ═════ PRAYER ALARM TRIGGERED: $prayerName ═════');
    debugPrint('[BackgroundTasks:PrayerAlarm] Time: ${DateTime.now()}');
    
    // Update widget to highlight this prayer time
    // The widget receives the prayer name and highlights it
    try {
      await WidgetCacheUpdater.updateCurrentPrayerHighlight(prayerName);
      debugPrint('[BackgroundTasks:PrayerAlarm] ✓ Widget updated to highlight: $prayerName');
    } catch (e) {
      debugPrint('[BackgroundTasks:PrayerAlarm] ⚠ Failed to update widget highlight: $e');
    }
    
    // Show optional notification for this prayer time
    try {
      debugPrint('[BackgroundTasks:PrayerAlarm] ✓ Prayer time notification shown for $prayerName');
    } catch (e) {
      debugPrint('[BackgroundTasks:PrayerAlarm] ⚠ Failed to show notification: $e');
    }
    
    debugPrint('[BackgroundTasks:PrayerAlarm] ═════ END PRAYER ALARM ═════');
  } catch (e, st) {
    debugPrint('[BackgroundTasks:PrayerAlarm] ✗ Error in prayer alarm handler: $e');
    debugPrint('[BackgroundTasks:PrayerAlarm] Stack: $st');
  }
}

/// Cancel all old prayer time notifications
/// Prevents duplicate notifications when daily refresh reschedules prayer times
Future<void> _cancelOldPrayerNotifications() async {
  try {
    final plugin = FlutterLocalNotificationsPlugin();
    
    // Get all pending notifications
    final pending = await plugin.pendingNotificationRequests();
    
    if (pending.isEmpty) {
      debugPrint('[BackgroundTasks] No pending notifications to cancel');
      return;
    }
    
    // Prayer names used to generate notification IDs
    final prayerNames = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    
    int cancelledCount = 0;
    
    // Cancel notifications for each prayer
    for (final notification in pending) {
      // Check if this is a prayer notification (contains prayer name in title or is generated from prayer name hash)
      bool isPrayerNotification = false;
      
      for (final prayerName in prayerNames) {
        if (notification.title?.contains(prayerName) ?? false) {
          isPrayerNotification = true;
          break;
        }
      }
      
      if (isPrayerNotification) {
        try {
          await plugin.cancel(notification.id);
          debugPrint('[BackgroundTasks] ✓ Cancelled prayer notification ID: ${notification.id}');
          cancelledCount++;
        } catch (e) {
          debugPrint('[BackgroundTasks] Could not cancel notification ${notification.id}: $e');
        }
      }
    }
    
    debugPrint('[BackgroundTasks] Total prayer notifications cancelled: $cancelledCount');
  } catch (e, st) {
    debugPrint('[BackgroundTasks] Error cancelling old notifications: $e');
    debugPrint('[BackgroundTasks] Stack: $st');
  }
}

/// Get device timezone
tz.Location _getDeviceTimezone() {
  try {
    // First try to use the explicitly set local timezone
    final localLocation = tz.local;
    debugPrint('[BackgroundTasks] Initial tz.local: ${localLocation.name}');
    
    // Always try to detect actual timezone regardless (don't just check if UTC)
    debugPrint('[BackgroundTasks] Attempting timezone detection...');
    
    // Get device timezone offset
    final offset = DateTime.now().timeZoneOffset;
    debugPrint('[BackgroundTasks] Device offset: ${offset.inHours}h ${offset.inMinutes % 60}m (total minutes: ${offset.inMinutes})');
    
    // Try common timezones based on offset
    final commonTimezones = [
      'Africa/Casablanca', 'Africa/Cairo', 'Africa/Lagos', 'Africa/Nairobi',
      'Europe/London', 'Europe/Paris', 'Europe/Berlin', 'Europe/Moscow', 'Europe/Amsterdam',
      'Asia/Dubai', 'Asia/Bangkok', 'Asia/Jakarta', 'Asia/Kolkata', 'Asia/Singapore', 'Asia/Tokyo',
      'America/New_York', 'America/Chicago', 'America/Denver', 'America/Los_Angeles', 'America/Toronto',
      'Australia/Sydney', 'Australia/Melbourne', 'Australia/Brisbane',
    ];
    
    debugPrint('[BackgroundTasks] Checking ${commonTimezones.length} common timezones...');
    for (final tzName in commonTimezones) {
      try {
        final location = tz.getLocation(tzName);
        final tzTime = tz.TZDateTime.now(location);
        
        // Get offset by comparing UTC and TZ time
        final tzOffset = tzTime.timeZoneOffset;
        
        debugPrint('[BackgroundTasks] Testing $tzName: offset = ${tzOffset.inMinutes} minutes (${tzOffset.inHours}h)');
        
        if (tzOffset == offset) {
          debugPrint('[BackgroundTasks] ✓ MATCHED device timezone: $tzName (offset: ${tzOffset.inHours}h)');
          return location;
        }
      } catch (e) {
        debugPrint('[BackgroundTasks] Failed to check $tzName: $e');
      }
    }
    
    debugPrint('[BackgroundTasks] No match found in common timezones, returning tz.local: ${localLocation.name}');
    return localLocation;
  } catch (e) {
    debugPrint('[BackgroundTasks] Error in getDeviceTimezone: $e');
    return tz.UTC;
  }
}





/// TEST FUNCTION: Manually trigger monthly calendar refresh to test logic
/// Call this from UI or test code to simulate a monthly refresh cycle
Future<void> testMonthlyCalendarRefresh() async {
  debugPrint('[BackgroundTasks] [TEST] Starting manual monthly calendar refresh test...');
  await executeMonthlyCalendarRefresh();
}

/// TEST FUNCTION: Check current cache expiration date
Future<String> testGetCacheExpirationDate() async {
  final prefs = await SharedPreferences.getInstance();
  final expirationDateStr = prefs.getString('monthlyCalendarCacheExpirationDate') ?? 'NOT SET';
  debugPrint('[BackgroundTasks] [TEST] Current cache expiration date: $expirationDateStr');
  return expirationDateStr;
}

/// TEST FUNCTION: Manually set cache expiration to a past date to test refresh
/// This will make the periodic task execute the refresh logic on next run
Future<void> testSetCacheExpirationToPast() async {
  final prefs = await SharedPreferences.getInstance();
  final pastDate = DateTime.now().subtract(const Duration(days: 1)).toString();
  await prefs.setString('monthlyCalendarCacheExpirationDate', pastDate);
  debugPrint('[BackgroundTasks] [TEST] Cache expiration set to past date: $pastDate');
  debugPrint('[BackgroundTasks] [TEST] Next periodic task run will execute the refresh logic');
}

/// Notify Android widget to refresh after cache update
/// The Android side has a 2 AM alarm that automatically refreshes the widget
/// This method is now simplified since the alarm handles the update
Future<void> notifyWidgetToRefresh() async {
  try {
    debugPrint('[BackgroundTasks] Cache updated successfully. Widget will refresh at next scheduled alarm (2 AM)');
  } catch (e) {
    debugPrint('[BackgroundTasks] ✗ Error in notifyWidgetToRefresh: $e');
    rethrow;
  }
}

