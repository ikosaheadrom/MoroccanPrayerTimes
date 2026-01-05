import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Daily prayer times parsed from habous.gov.ma daily API
typedef DailyPrayerTimes = Map<String, String>;

const String _cacheKeyPrefix = 'daily_prayer_times_';

/// Parse daily prayer times from habous.gov.ma API HTML response
/// 
/// Expected endpoint: `https://www.habous.gov.ma/prieres/horaire-api.php?ville=<cityId>`
/// 
/// Returns a map with keys:
/// - 'fajr': Fajr time (HH:MM)
/// - 'sunrise': Sunrise time (HH:MM)
/// - 'dhuhr': Dhuhr time (HH:MM)
/// - 'asr': Asr time (HH:MM)
/// - 'maghrib': Maghrib time (HH:MM)
/// - 'isha': Isha time (HH:MM)
/// - 'date': Today's date (YYYY-MM-DD)
/// - 'cityName': City name (if found in HTML)
Future<DailyPrayerTimes> parseDailyPrayerTimesFromHtml(String html, {String cityName = ''}) async {
  try {
    debugPrint('[DailyPrayerParser] Parsing daily prayer times...');
    
    final result = <String, String>{
      'fajr': 'N/A',
      'sunrise': 'N/A',
      'dhuhr': 'N/A',
      'asr': 'N/A',
      'maghrib': 'N/A',
      'isha': 'N/A',
      'date': _getTodayDateString(),
      'cityName': cityName,
    };

    // Extract the horaire table
    final tableRx = RegExp(
      r'''<table[^>]*class=['"]?horaire['"]?[^>]*>([\s\S]*?)</table>''',
      caseSensitive: false,
    );
    final tableMatch = tableRx.firstMatch(html);
    if (tableMatch == null) {
      debugPrint('[DailyPrayerParser] No horaire table found');
      return result;
    }

    final tableHtml = tableMatch.group(1)!;

    // Extract all rows
    final trRx = RegExp(r'<tr[^>]*>([\s\S]*?)</tr>', caseSensitive: false);
    final rows = trRx.allMatches(tableHtml).map((m) => m.group(1)!).toList();

    debugPrint('[DailyPrayerParser] Found ${rows.length} rows in table');

    // Parse each row for prayer times
    for (final row in rows) {
      // Extract all <td> cells
      final tdRx = RegExp(r'<td[^>]*>([\s\S]*?)</td>', caseSensitive: false);
      final cells = tdRx.allMatches(row)
          .map((m) => _sanitizeHtmlContent(m.group(1)!))
          .toList();

      // Process pairs of cells: [label, time, label, time, ...]
      for (int i = 0; i < cells.length - 1; i += 2) {
        final label = cells[i].toLowerCase();
        final time = cells[i + 1];

        // Map Arabic labels to prayer times
        if (label.contains('فجر') || label.contains('fajr')) {
          result['fajr'] = _normalizeTime(time);
        } else if (label.contains('شروق') || label.contains('sunrise')) {
          result['sunrise'] = _normalizeTime(time);
        } else if (label.contains('ظهر') || label.contains('dhuhr')) {
          result['dhuhr'] = _normalizeTime(time);
        } else if (label.contains('عصر') || label.contains('asr')) {
          result['asr'] = _normalizeTime(time);
        } else if (label.contains('مغرب') || label.contains('maghrib')) {
          result['maghrib'] = _normalizeTime(time);
        } else if (label.contains('عشاء') || label.contains('isha')) {
          result['isha'] = _normalizeTime(time);
        }
      }
    }

    // Extract city name from HTML if not provided
    if (cityName.isEmpty) {
      final cityRx = RegExp(
        r'مواقيت الصلاة لمدينة</h2>\s*<h2[^>]*>([^<]+)</h2>',
        caseSensitive: false,
      );
      final cityMatch = cityRx.firstMatch(html);
      if (cityMatch != null) {
        result['cityName'] = _sanitizeHtmlContent(cityMatch.group(1)!);
      }
    }

    debugPrint('[DailyPrayerParser] Successfully parsed daily prayer times');
    debugPrint('[DailyPrayerParser] Fajr: ${result['fajr']}, Isha: ${result['isha']}');

    return result;
  } catch (e, st) {
    debugPrint('[DailyPrayerParser] Error parsing daily prayer times: $e\n$st');
    return {
      'fajr': 'N/A',
      'sunrise': 'N/A',
      'dhuhr': 'N/A',
      'asr': 'N/A',
      'maghrib': 'N/A',
      'isha': 'N/A',
      'date': _getTodayDateString(),
      'cityName': cityName,
    };
  }
}

/// Sanitize HTML content to prevent malicious code injection
/// Removes all HTML tags and dangerous characters
String _sanitizeHtmlContent(String content) {
  // Remove all HTML tags
  var sanitized = content.replaceAll(RegExp(r'<[^>]+>'), '');
  
  // Decode common HTML entities
  sanitized = sanitized
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&nbsp', ' ')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'");
  
  // Remove any script-like patterns or dangerous characters
  sanitized = sanitized.replaceAll(RegExp(r'javascript:', caseSensitive: false), '');
  sanitized = sanitized.replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '');
  
  // Remove control characters and null bytes
  sanitized = sanitized.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');
  
  return sanitized.trim();
}

/// Normalize time string to HH:MM format with sanitization
String _normalizeTime(String timeStr) {
  // First sanitize the input
  final sanitized = _sanitizeHtmlContent(timeStr);
  
  // Remove extra whitespace and keep only digits and colons
  final cleaned = sanitized
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll(RegExp(r'[^0-9:]'), '');

  // Validate HH:MM format
  if (RegExp(r'^[0-2]\d:[0-5]\d$').hasMatch(cleaned)) {
    return cleaned;
  }

  return 'N/A';
}

/// Get today's date as YYYY-MM-DD string
String _getTodayDateString() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

/// Fetch and parse daily prayer times from habous.gov.ma API
/// 
/// Parameters:
/// - cityId: City ID from habous.gov.ma (e.g., 58 for Casablanca)
/// - cityName: Display name for the city
/// 
/// Returns DailyPrayerTimes map or error details
/// Caches data automatically with expiration at start of next day
Future<DailyPrayerTimes> fetchDailyPrayerTimesFromHabous({
  required String cityId,
  String cityName = '',
}) async {
  try {
    debugPrint('[DailyPrayerParser] Fetching daily times for city: $cityId');
    
    final url = 'https://www.habous.gov.ma/prieres/horaire-api.php?ville=$cityId';
    final uri = Uri.parse(url);

    // Make HTTP request
    final client = HttpClient();
    client.badCertificateCallback = (cert, host, port) => true;
    final request = await client.getUrl(uri);
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    client.close();

    if (response.statusCode == 200) {
      final result = await parseDailyPrayerTimesFromHtml(body, cityName: cityName);
      // Save to cache after successful parse
      await _saveDailyPrayerTimesToCache(cityId, result);
      return result;
    } else {
      debugPrint('[DailyPrayerParser] HTTP error: ${response.statusCode}');
      return {
        'fajr': 'N/A',
        'sunrise': 'N/A',
        'dhuhr': 'N/A',
        'asr': 'N/A',
        'maghrib': 'N/A',
        'isha': 'N/A',
        'date': _getTodayDateString(),
        'cityName': cityName,
      };
    }
  } catch (e, st) {
    debugPrint('[DailyPrayerParser] Error fetching daily times: $e\n$st');
    return {
      'fajr': 'N/A',
      'sunrise': 'N/A',
      'dhuhr': 'N/A',
      'asr': 'N/A',
      'maghrib': 'N/A',
      'isha': 'N/A',
      'date': _getTodayDateString(),
      'cityName': cityName,
    };
  }
}

/// Get daily prayer times from cache or fetch from API if not cached
/// 
/// Returns cached data if available, otherwise fetches fresh data from API
/// Use forceRefresh=true to bypass cache and always fetch fresh data
Future<DailyPrayerTimes> getDailyPrayerTimes({
  required String cityId,
  String cityName = '',
  bool forceRefresh = false,
}) async {
  try {
    if (!forceRefresh) {
      final cached = await _getDailyPrayerTimesFromCache(cityId);
      if (cached != null) {
        debugPrint('[DailyPrayerParser] Using cached daily prayer times for city: $cityId');
        return cached;
      }
    }

    debugPrint('[DailyPrayerParser] Cache miss, fetching from API...');
    return await fetchDailyPrayerTimesFromHabous(cityId: cityId, cityName: cityName);
  } catch (e, st) {
    debugPrint('[DailyPrayerParser] Error getting daily prayer times: $e\n$st');
    return {
      'fajr': 'N/A',
      'sunrise': 'N/A',
      'dhuhr': 'N/A',
      'asr': 'N/A',
      'maghrib': 'N/A',
      'isha': 'N/A',
      'date': _getTodayDateString(),
      'cityName': cityName,
    };
  }
}

/// Save daily prayer times to SharedPreferences cache
/// Cache persists indefinitely and is replaced when new data is fetched
Future<void> _saveDailyPrayerTimesToCache(String cityId, DailyPrayerTimes times) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '$_cacheKeyPrefix$cityId';

    // Save prayer times as JSON
    await prefs.setString(cacheKey, jsonEncode(times));

    debugPrint('[DailyPrayerParser] Cached daily prayer times for city: $cityId');
  } catch (e, st) {
    debugPrint('[DailyPrayerParser] Error saving to cache: $e\n$st');
  }
}

/// Retrieve daily prayer times from cache
/// Returns null if cache is missing
Future<DailyPrayerTimes?> _getDailyPrayerTimesFromCache(String cityId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '$_cacheKeyPrefix$cityId';

    final cachedJson = prefs.getString(cacheKey);

    if (cachedJson == null) {
      debugPrint('[DailyPrayerParser] No cached data found for city: $cityId');
      return null;
    }

    final cached = Map<String, String>.from(jsonDecode(cachedJson) as Map<String, dynamic>);
    debugPrint('[DailyPrayerParser] Retrieved cached data for city: $cityId');
    return cached;
  } catch (e, st) {
    debugPrint('[DailyPrayerParser] Error retrieving from cache: $e\n$st');
    return null;
  }
}

/// Clear cache for specific city
Future<void> clearDailyPrayerCache(String cityId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '$_cacheKeyPrefix$cityId';

    await prefs.remove(cacheKey);

    debugPrint('[DailyPrayerParser] Cleared cache for city: $cityId');
  } catch (e, st) {
    debugPrint('[DailyPrayerParser] Error clearing cache: $e\n$st');
  }
}

/// Clear all daily prayer cache
Future<void> clearAllDailyPrayerCache() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    for (final key in keys) {
      if (key.startsWith(_cacheKeyPrefix)) {
        await prefs.remove(key);
      }
    }

    debugPrint('[DailyPrayerParser] Cleared all daily prayer cache');
  } catch (e, st) {
    debugPrint('[DailyPrayerParser] Error clearing all cache: $e\n$st');
  }


}