import 'package:flutter/foundation.dart';
import 'widget_info_manager.dart';
import 'widget_cache_service.dart' show WidgetCacheData;

/// Background task callback for widget cache updates
/// 
/// Call this function:
/// - Hourly from WorkManager
/// - On app startup
/// - When user changes settings (source, location, etc.)
/// 
/// The function will:
/// 1. Check if cache is valid
/// 2. Only update if cache is expired or doesn't exist
/// 3. Log success/failure to console
/// 4. Return completion status
///
/// Example usage in background_tasks.dart:
/// ```dart
/// @pragma('vm:entry-point')
/// void widgetCacheCallbackDispatcher() {
///   Workmanager().executeTask((taskName, inputData) async {
///     if (taskName == 'updateWidgetCache') {
///       return await updateWidgetCacheBackground();
///     }
///     return false;
///   });
/// }
/// ```
Future<bool> updateWidgetCacheBackground() async {
  const debugTag = '[WidgetCacheBackground]';
  
  try {
    debugPrint('$debugTag Starting background widget cache update');
    
    final manager = WidgetInfoManager();
    
    // Check if cache is still valid
    final isValid = await manager.isWidgetCacheValid();
    
    if (isValid) {
      debugPrint('$debugTag Cache is still valid, skipping update');
      return true;
    }
    
    debugPrint('$debugTag Cache expired or missing, updating...');
    
    // Update cache with latest prayer times
    final success = await manager.updateWidgetInfo();
    
    if (success) {
      debugPrint('$debugTag Widget cache updated successfully');
      
      // Log cache info for verification
      final debugInfo = await manager.getCacheDebugInfo();
      debugPrint('$debugTag $debugInfo');
      
      return true;
    } else {
      debugPrint('$debugTag ERROR: Failed to update widget cache');
      return false;
    }
  } catch (e, st) {
    debugPrint('$debugTag EXCEPTION in background update: $e');
    debugPrint('$debugTag Stack trace: $st');
    return false;
  }
}

/// Alternative: Force update widget cache regardless of cache state
/// 
/// Use this when:
/// - User changes settings
/// - User manually refreshes
/// - Force sync is requested
/// 
/// This will clear the old cache and fetch new data
Future<bool> forceUpdateWidgetCacheBackground() async {
  const debugTag = '[WidgetCacheBackground]';
  
  try {
    debugPrint('$debugTag Starting FORCE widget cache update');
    
    final manager = WidgetInfoManager();
    
    // Force refresh (clears old cache, fetches new data)
    final success = await manager.forceRefreshWidget();
    
    if (success) {
      debugPrint('$debugTag Widget cache force updated successfully');
      
      // Log cache info
      final debugInfo = await manager.getCacheDebugInfo();
      debugPrint('$debugTag $debugInfo');
      
      return true;
    } else {
      debugPrint('$debugTag ERROR: Failed to force update widget cache');
      return false;
    }
  } catch (e, st) {
    debugPrint('$debugTag EXCEPTION in force update: $e');
    debugPrint('$debugTag Stack trace: $st');
    return false;
  }
}

/// Get widget cache data for widget display
/// 
/// Call this from your widget display code to get latest cached data
/// 
/// Example in your widget code:
/// ```dart
/// final cacheData = await getWidgetCacheForDisplay();
/// if (cacheData != null) {
///   return PrayerTimesWidget(data: cacheData);
/// } else {
///   return ErrorWidget('Prayer times unavailable');
/// }
/// ```
Future<WidgetCacheData?> getWidgetCacheForDisplay() async {
  const debugTag = '[WidgetDisplay]';
  
  try {
    debugPrint('$debugTag Fetching widget cache for display');
    
    final manager = WidgetInfoManager();
    final cacheData = await manager.getWidgetData();
    
    if (cacheData == null) {
      debugPrint('$debugTag WARNING: Cache is empty or expired');
      return null;
    }
    
    debugPrint('$debugTag Cache retrieved: ${cacheData.location}');
    return cacheData;
  } catch (e, st) {
    debugPrint('$debugTag ERROR fetching cache: $e');
    debugPrint('$debugTag Stack trace: $st');
    return null;
  }
}

/// Example integration with WorkManager
/// 
/// Add this to your background_tasks.dart:
/// 
/// ```dart
/// import 'widgets/widget_cache_example.dart';
/// 
/// // Define periodic widget cache update
/// Future<void> scheduleWidgetCacheUpdate() async {
///   try {
///     await Workmanager().periodic(
///       Duration(hours: 1), // Update every hour
///       'updateWidgetCache',
///       initialDelay: Duration(minutes: 15),
///       constraints: Constraints(
///         networkType: NetworkType.connected,
///       ),
///     );
///     debugPrint('[WorkManager] Widget cache update scheduled');
///   } catch (e) {
///     debugPrint('[WorkManager] ERROR scheduling widget cache: $e');
///   }
/// }
/// 
/// // Dispatcher callback
/// @pragma('vm:entry-point')
/// void widgetCacheCallbackDispatcher() {
///   Workmanager().executeTask((taskName, inputData) async {
///     if (taskName == 'updateWidgetCache') {
///       return await updateWidgetCacheBackground();
///     }
///     return false;
///   });
/// }
/// 
/// // Call in initializeWorkmanager():
/// Workmanager().initialize(
///   widgetCacheCallbackDispatcher,
///   isInDebugMode: kDebugMode,
/// );
/// scheduleWidgetCacheUpdate();
/// ```

/// Example: Check cache status
/// 
/// Use this to display cache freshness in debug screens:
Future<Map<String, dynamic>> getWidgetCacheStatus() async {
  const debugTag = '[WidgetStatus]';
  
  try {
    final manager = WidgetInfoManager();
    
    final isValid = await manager.isWidgetCacheValid();
    final age = await manager.getCacheAgeInHours();
    final data = await manager.getWidgetData();
    
    return {
      'isValid': isValid,
      'ageHours': age ?? -1,
      'location': data?.location ?? 'N/A',
      'source': data?.source ?? 'N/A',
      'lastUpdate': data?.cacheDateDdMmYyyy ?? 'Never',
      'theme': data?.isDarkMode == true ? 'Dark' : 'Light',
    };
  } catch (e) {
    debugPrint('$debugTag ERROR getting status: $e');
    return {
      'isValid': false,
      'error': 'Failed to get cache status',
    };
  }
}

/// Example: Cache statistics
/// 
/// Returns formatted string for debugging:
Future<String> getWidgetCacheStatistics() async {
  try {
    final manager = WidgetInfoManager();
    return await manager.getCacheDebugInfo();
  } catch (e) {
    return 'Error: Unable to retrieve cache statistics';
  }
}
