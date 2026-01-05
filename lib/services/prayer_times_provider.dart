import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'daily_prayer_parser.dart' show getDailyPrayerTimes;
import 'offline_adhan.dart' show calculatePrayerTimesOffline;

/// Result object from PrayerTimesProvider
class PrayerTimesResult {
  /// Which source was used: 'ministry', 'offline', or 'adhan_api'
  final String sourceUsed;

  /// Input settings used for this source
  /// - For ministry: {'cityId': '58', 'cityName': 'Casablanca'}
  /// - For offline: {'latitude': 33.5898, 'longitude': -7.6038}
  /// - For adhan_api: {'latitude': 33.5898, 'longitude': -7.6038, 'cityName': 'Casablanca'}
  final Map<String, dynamic> inputSettings;

  /// Prayer times in HH:MM format
  /// Keys: 'fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'
  final Map<String, String> times;

  /// Date that these times are for (YYYY-MM-DD)
  final String date;

  /// Latitude (if applicable)
  final double? latitude;

  /// Longitude (if applicable)
  final double? longitude;

  /// City name (if applicable)
  final String? cityName;

  PrayerTimesResult({
    required this.sourceUsed,
    required this.inputSettings,
    required this.times,
    required this.date,
    this.latitude,
    this.longitude,
    this.cityName,
  });

  /// Convert result to a standardized map format
  Map<String, dynamic> toMap() {
    return {
      'source': sourceUsed,
      'inputSettings': inputSettings,
      'times': times,
      'date': date,
      'latitude': latitude,
      'longitude': longitude,
      'cityName': cityName,
    };
  }

  @override
  String toString() {
    return '''PrayerTimesResult(
  source: $sourceUsed,
  inputSettings: $inputSettings,
  times: $times,
  date: $date,
  cityName: $cityName,
  coords: ($latitude, $longitude)
)''';
  }
}

/// Unified Prayer Times Provider
/// 
/// Reads app settings and determines which source to use:
/// 1. Priority 1: Ministry API (if useMinistry=true)
/// 2. Priority 2: Offline calculation (if isOfflineMode=true with valid coordinates)
/// 3. Priority 3: Adhan API (default, uses coordinates if available, otherwise falls back)
///
/// Usage:
/// ```dart
/// final provider = PrayerTimesProvider();
/// final result = await provider.getPrayerTimes();
/// print('Source: ${result.sourceUsed}');
/// print('Fajr: ${result.times['fajr']}');
/// ```
class PrayerTimesProvider {
  static const String _debugTag = '[PrayerTimesProvider]';

  /// Get prayer times based on saved app settings
  /// 
  /// Reads from SharedPreferences:
  /// - useMinistry: bool (default: true)
  /// - isOfflineMode: bool (default: false)
  /// - cityCityId: String (default: '58')
  /// - selectedCityName: String (default: 'Casablanca')
  /// - adhanLatitude: String (default: '0')
  /// - adhanLongitude: String (default: '0')
  Future<PrayerTimesResult> getPrayerTimes() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Read settings
      final useMinistry = prefs.getBool('useMinistry') ?? true;
      final isOfflineMode = prefs.getBool('isOfflineMode') ?? false;
      final cityId = prefs.getString('cityCityId') ?? '58';
      final cityName = prefs.getString('selectedCityName') ?? 'Casablanca';
      final latStr = prefs.getString('adhanLatitude') ?? '0';
      final lonStr = prefs.getString('adhanLongitude') ?? '0';

      final latitude = double.tryParse(latStr) ?? 0.0;
      final longitude = double.tryParse(lonStr) ?? 0.0;

      debugPrint('$_debugTag ════════════════════════════════════════');
      debugPrint('$_debugTag Settings loaded:');
      debugPrint('$_debugTag   useMinistry: $useMinistry');
      debugPrint('$_debugTag   isOfflineMode: $isOfflineMode');
      debugPrint('$_debugTag   cityId: $cityId');
      debugPrint('$_debugTag   cityName: $cityName');
      debugPrint('$_debugTag   latitude: $latitude');
      debugPrint('$_debugTag   longitude: $longitude');
      debugPrint('$_debugTag ════════════════════════════════════════');

      // PRIORITY 1: Ministry API
      if (useMinistry) {
        debugPrint('$_debugTag → Attempting Ministry API (cityId: $cityId)');
        try {
          final times = await getDailyPrayerTimes(
            cityId: cityId,
            cityName: cityName,
            forceRefresh: true,
          );

          // Check if we got valid times
          if (times['fajr'] != 'N/A' && times['fajr']!.isNotEmpty) {
            debugPrint('$_debugTag ✓ SUCCESS: Got times from Ministry API');
            debugPrint('$_debugTag   Fajr: ${times['fajr']}, Dhuhr: ${times['dhuhr']}, Maghrib: ${times['maghrib']}');

            return PrayerTimesResult(
              sourceUsed: 'ministry',
              inputSettings: {
                'cityId': cityId,
                'cityName': cityName,
              },
              times: {
                'fajr': times['fajr'] ?? 'N/A',
                'sunrise': times['sunrise'] ?? 'N/A',
                'dhuhr': times['dhuhr'] ?? 'N/A',
                'asr': times['asr'] ?? 'N/A',
                'maghrib': times['maghrib'] ?? 'N/A',
                'isha': times['isha'] ?? 'N/A',
              },
              date: times['date'] ?? _getTodayDateString(),
              cityName: cityName,
            );
          } else {
            debugPrint('$_debugTag ✗ Ministry returned N/A, falling back...');
          }
        } catch (e) {
          debugPrint('$_debugTag ✗ Ministry API error: $e, falling back...');
        }
      }

      // PRIORITY 2: Offline Calculation
      if (isOfflineMode && latitude != 0.0 && longitude != 0.0) {
        debugPrint('$_debugTag → Attempting Offline Calculation (lat: $latitude, lon: $longitude)');
        try {
          final times = calculatePrayerTimesOffline(
            latitude: latitude,
            longitude: longitude,
            date: DateTime.now(),
          );

          if (times['Fajr'] != null && times['Fajr']!.isNotEmpty) {
            debugPrint('$_debugTag ✓ SUCCESS: Got times from Offline Calculation');
            debugPrint('$_debugTag   Fajr: ${times['Fajr']}, Dhuhr: ${times['Dhuhr']}, Maghrib: ${times['Maghrib']}');

            return PrayerTimesResult(
              sourceUsed: 'offline',
              inputSettings: {
                'latitude': latitude,
                'longitude': longitude,
              },
              times: {
                'fajr': times['Fajr'] ?? 'N/A',
                'sunrise': times['Sunrise'] ?? 'N/A',
                'dhuhr': times['Dhuhr'] ?? 'N/A',
                'asr': times['Asr'] ?? 'N/A',
                'maghrib': times['Maghrib'] ?? 'N/A',
                'isha': times['Isha'] ?? 'N/A',
              },
              date: _getTodayDateString(),
              latitude: latitude,
              longitude: longitude,
              cityName: '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}', // Show coordinates
            );
          } else {
            debugPrint('$_debugTag ✗ Offline returned N/A, falling back...');
          }
        } catch (e) {
          debugPrint('$_debugTag ✗ Offline Calculation error: $e, falling back...');
        }
      }

      // PRIORITY 3: Adhan API (default fallback)
      debugPrint('$_debugTag → Attempting Adhan API');
      try {
        // Use coordinates if available, otherwise mention fallback
        if (latitude != 0.0 && longitude != 0.0) {
          debugPrint('$_debugTag   Using coordinates: lat=$latitude, lon=$longitude');
        } else {
          debugPrint('$_debugTag   Using default Morocco coordinates');
        }

        final apiService = ApiService();
        final times = await apiService.fetchMoroccoAlAdhanTimes(latitude, longitude);

        debugPrint('$_debugTag ✓ SUCCESS: Got times from Adhan API');
        debugPrint('$_debugTag   Fajr: ${times.fajr}, Dhuhr: ${times.dhuhr}, Maghrib: ${times.maghrib}');

        // For Adhan API, only show cityName if using default Morocco coordinates
        // Otherwise show coordinate-based location
        final isDefaultCoordinates = latitude == 0.0 && longitude == 0.0;
        final displayCityName = isDefaultCoordinates ? cityName : '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';

        return PrayerTimesResult(
          sourceUsed: 'adhan_api',
          inputSettings: {
            'latitude': latitude,
            'longitude': longitude,
            if (cityName.isNotEmpty) 'cityName': cityName,
          },
          times: {
            'fajr': times.fajr,
            'sunrise': times.sunrise,
            'dhuhr': times.dhuhr,
            'asr': times.asr,
            'maghrib': times.maghrib,
            'isha': times.isha,
          },
          date: _getTodayDateString(),
          latitude: latitude,
          longitude: longitude,
          cityName: displayCityName, // Show coordinates if using custom location
        );
      } catch (e) {
        debugPrint('$_debugTag ✗ Adhan API error: $e');
        // Return N/A times as last resort
        return PrayerTimesResult(
          sourceUsed: 'none',
          inputSettings: {
            'error': 'All sources failed',
            'lastError': e.toString(),
          },
          times: {
            'fajr': 'N/A',
            'sunrise': 'N/A',
            'dhuhr': 'N/A',
            'asr': 'N/A',
            'maghrib': 'N/A',
            'isha': 'N/A',
          },
          date: _getTodayDateString(),
        );
      }
    } catch (e, st) {
      debugPrint('$_debugTag FATAL ERROR: $e');
      debugPrint('$_debugTag Stack: $st');

      return PrayerTimesResult(
        sourceUsed: 'none',
        inputSettings: {
          'error': 'Fatal error in provider',
          'message': e.toString(),
        },
        times: {
          'fajr': 'N/A',
          'sunrise': 'N/A',
          'dhuhr': 'N/A',
          'asr': 'N/A',
          'maghrib': 'N/A',
          'isha': 'N/A',
        },
        date: _getTodayDateString(),
      );
    }
  }

  /// Get today's date in YYYY-MM-DD format
  static String _getTodayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
