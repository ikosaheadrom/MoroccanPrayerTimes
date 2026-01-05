import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../services/daily_prayer_parser.dart';
import '../services/offline_adhan.dart';
import '../services/api_service.dart';
import 'widget_cache_service.dart' show WidgetCacheService, WidgetCacheData;

/// Widget prayer times parser using the same logic as homepage
/// Supports three sources: ministry, adhan, offline
class WidgetPrayerTimesParser {
  static const String _debugTag = '[WidgetPrayerTimesParser]';
  
  final WidgetCacheService _cacheService = WidgetCacheService();

  /// Quick widget cache update using current app settings
  /// This reads the app's actual source settings (useMinistry, isOfflineMode) and updates widget cache
  /// Matches the exact source selection logic from _loadTimes() in main.dart
  /// Priority: 1. Ministry (if enabled) 2. Offline calc (if offline mode) 3. Daily parser cache (Adhan/Ministry)
  Future<bool> quickUpdateWidgetCache() async {
    try {
      debugPrint('$_debugTag Quick widget cache update started');
      
      final prefs = await SharedPreferences.getInstance();
      
      // Read actual app settings - MUST match _loadTimes() logic
      final useMinistry = prefs.getBool('useMinistry') ?? true;
      final isOfflineMode = prefs.getBool('isOfflineMode') ?? false;
      final selectedCityName = prefs.getString('selectedCityName') ?? 'Casablanca';
      final themeMode = prefs.getString('themeMode') ?? 'light';
      final adhanLatitude = double.tryParse(prefs.getString('adhanLatitude') ?? '0') ?? 0.0;
      final adhanLongitude = double.tryParse(prefs.getString('adhanLongitude') ?? '0') ?? 0.0;
      final cityId = prefs.getString('cityCityId') ?? '58';
      
      debugPrint('$_debugTag ═══════════════════════════════════════════════════════');
      debugPrint('$_debugTag Settings: useMinistry=$useMinistry, offline=$isOfflineMode, city=$selectedCityName');
      debugPrint('$_debugTag Coordinates: lat=$adhanLatitude, lon=$adhanLongitude');
      debugPrint('$_debugTag ═══════════════════════════════════════════════════════');
      
      // Determine isDarkMode based on themeMode setting
      final isDarkMode = themeMode == 'dark';
      
      Map<String, String>? prayerTimes;
      String sourceLabel = 'unknown';
      
      // SOURCE SELECTION LOGIC - Must match _loadTimes() in main.dart
      // PRIORITY 1: If offline mode enabled with VALID coordinates → Calculate offline
      if (!useMinistry && isOfflineMode && adhanLatitude != 0.0 && adhanLongitude != 0.0) {
        debugPrint('$_debugTag Source: Offline Calculation (coords=$adhanLatitude, $adhanLongitude)');
        try {
          prayerTimes = calculatePrayerTimesOffline(
            latitude: adhanLatitude,
            longitude: adhanLongitude,
            date: DateTime.now(),
          );
          sourceLabel = 'offline';
          debugPrint('$_debugTag ✓ Fetched from offline calculation');
        } catch (e) {
          debugPrint('$_debugTag ✗ Offline calculation failed: $e, falling back to Ministry');
        }
      }
      
      // PRIORITY 2: If offline failed or disabled, check if offline enabled with INVALID coords (use Ministry fallback)
      if (prayerTimes == null && !useMinistry && isOfflineMode && (adhanLatitude == 0.0 || adhanLongitude == 0.0)) {
        debugPrint('$_debugTag ⚠ Offline mode enabled but INVALID coordinates (lat=$adhanLatitude, lon=$adhanLongitude)');
        debugPrint('$_debugTag  → Falling back to Ministry API');
      }
      
      // PRIORITY 3: If offline not enabled or failed, try Ministry
      if (prayerTimes == null && (useMinistry || (!useMinistry && isOfflineMode && (adhanLatitude == 0.0 || adhanLongitude == 0.0)))) {
        debugPrint('$_debugTag Source: Ministry API (city=$selectedCityName)');
        try {
          final apiService = ApiService();
          final times = await apiService.fetchOfficialMoroccanTimes(selectedCityName);
          prayerTimes = {
            'fajr': times.fajr,
            'sunrise': times.sunrise,
            'dhuhr': times.dhuhr,
            'asr': times.asr,
            'maghrib': times.maghrib,
            'isha': times.isha,
          };
          sourceLabel = 'ministry';
          debugPrint('$_debugTag ✓ Fetched from Ministry API');
        } catch (e) {
          debugPrint('$_debugTag ✗ Ministry API failed: $e, falling back to other sources');
          // Fall through to Adhan or daily parser cache below
        }
      }
      
      // PRIORITY 4: If Ministry not enabled and offline failed/disabled with valid coords, try Adhan API
      if (prayerTimes == null && !isOfflineMode && adhanLatitude != 0.0 && adhanLongitude != 0.0) {
        debugPrint('$_debugTag Source: Adhan API (coords=$adhanLatitude, $adhanLongitude)');
        try {
          final apiService = ApiService();
          final times = await apiService.fetchMoroccoAlAdhanTimes(
            adhanLatitude,
            adhanLongitude,
          );
          prayerTimes = {
            'fajr': times.fajr,
            'sunrise': times.sunrise,
            'dhuhr': times.dhuhr,
            'asr': times.asr,
            'maghrib': times.maghrib,
            'isha': times.isha,
          };
          sourceLabel = 'adhan';
          debugPrint('$_debugTag ✓ Fetched from Adhan API');
        } catch (e) {
          debugPrint('$_debugTag ✗ Adhan API failed: $e, falling back to daily parser');
          // Fall through to daily parser cache
        }
      }
      
      // PRIORITY 5: Try daily parser cache (contains most recent data from any source)
      if (prayerTimes == null || prayerTimes.isEmpty) {
        debugPrint('$_debugTag Source: Daily Parser Cache (fallback)');
        try {
          final dailyKey = 'daily_prayer_times_$cityId';
          final cachedStr = prefs.getString(dailyKey);
          
          if (cachedStr != null) {
            final cached = jsonDecode(cachedStr) as Map<String, dynamic>;
            prayerTimes = {
              'fajr': cached['fajr']?.toString() ?? 'N/A',
              'sunrise': cached['sunrise']?.toString() ?? 'N/A',
              'dhuhr': cached['dhuhr']?.toString() ?? 'N/A',
              'asr': cached['asr']?.toString() ?? 'N/A',
              'maghrib': cached['maghrib']?.toString() ?? 'N/A',
              'isha': cached['isha']?.toString() ?? 'N/A',
            };
            // Determine source from cache if available, otherwise use last known
            sourceLabel = cached['source'] as String? ?? 'cached';
            debugPrint('$_debugTag ✓ Loaded from daily parser cache (source=$sourceLabel)');
          } else {
            debugPrint('$_debugTag ✗ No daily parser cache available');
          }
        } catch (e) {
          debugPrint('$_debugTag ERROR reading daily parser cache: $e');
        }
      }
      
      if (prayerTimes == null || prayerTimes.isEmpty) {
        debugPrint('$_debugTag ERROR: Could not obtain prayer times from any source');
        return false;
      }
      
      debugPrint('$_debugTag ✓ Prayer times obtained from $sourceLabel: Fajr=${prayerTimes['fajr']}, Dhuhr=${prayerTimes['dhuhr']}, Maghrib=${prayerTimes['maghrib']}');
      
      // Determine location based on source
      String location;
      if (sourceLabel == 'offline' || sourceLabel == 'adhan') {
        // For offline and Adhan, use coordinates
        location = '$adhanLatitude, $adhanLongitude';
      } else {
        // For ministry and cache, use city name (latinized for display)
        location = _latinizeLocationName(selectedCityName);
      }
      
      // Get primaryHue (not regular hue)
      final primaryHue = prefs.getDouble('primaryHue') ?? 0.0;
      final widgetBgTransparency = prefs.getDouble('widgetBgTransparency') ?? 1.0;
      debugPrint('$_debugTag PRIMARY HUE DEBUG: primaryHue=$primaryHue, themeMode=$themeMode, isDarkMode=$isDarkMode, bgTransparency=$widgetBgTransparency');
      debugPrint('$_debugTag ═══ WIDGET BG TRANSPARENCY DEBUG ═══');
      debugPrint('$_debugTag Read widgetBgTransparency from prefs: $widgetBgTransparency');
      debugPrint('$_debugTag Will save to cache with bgTransparency=$widgetBgTransparency');
      debugPrint('$_debugTag ════════════════════════════════════');
      
      // Save to widget cache
      final success = await _cacheService.saveWidgetCache(
        fajr: prayerTimes['fajr'] ?? prayerTimes['Fajr'] ?? 'N/A',
        sunrise: prayerTimes['sunrise'] ?? prayerTimes['Sunrise'] ?? 'N/A',
        dhuhr: prayerTimes['dhuhr'] ?? prayerTimes['Dhuhr'] ?? 'N/A',
        asr: prayerTimes['asr'] ?? prayerTimes['Asr'] ?? 'N/A',
        maghrib: prayerTimes['maghrib'] ?? prayerTimes['Maghrib'] ?? 'N/A',
        isha: prayerTimes['isha'] ?? prayerTimes['Isha'] ?? 'N/A',
        source: sourceLabel,
        location: location,
        hue: primaryHue,
        isDarkMode: isDarkMode,
        bgTransparency: widgetBgTransparency,
      );
      debugPrint('$_debugTag PRIMARY HUE DEBUG: saveWidgetCache called with hue=$primaryHue, isDarkMode=$isDarkMode, bgTransparency=$widgetBgTransparency, result=$success');
      
      if (success) {
        debugPrint('$_debugTag ✓ Quick widget cache update completed (source=$sourceLabel)');
      } else {
        debugPrint('$_debugTag ✗ Failed to save widget cache');
      }
      
      return success;
    } catch (e, st) {
      debugPrint('$_debugTag ERROR in quickUpdateWidgetCache: $e');
      debugPrint('$_debugTag Stack trace: $st');
      return false;
    }
  }

  /// Fetch and cache prayer times for the widget
  /// Uses settings to determine source, location, theme, and other parameters
  Future<bool> updateWidgetCache() async {
    try {
      debugPrint('$_debugTag Starting widget cache update...');
      
      // Get saved settings
      final prefs = await SharedPreferences.getInstance();
      
      // Retrieve settings with fallbacks
      final sourceIndex = prefs.getInt('sourceIndex') ?? 0;
      final cityIndex = prefs.getInt('selectedCityIndex') ?? 0;
      final citiesJson = prefs.getString('cities') ?? '[]';
      final themeMode = prefs.getString('themeMode') ?? 'light';
      final hue = prefs.getDouble('hue') ?? 0.0;
      
      debugPrint('$_debugTag Settings loaded: source=$sourceIndex, cityIndex=$cityIndex, themeMode=$themeMode, hue=$hue');
      
      // Parse cities
      List<dynamic> cities = [];
      try {
        cities = jsonDecode(citiesJson) as List<dynamic>;
        debugPrint('$_debugTag Parsed ${cities.length} cities from cache');
      } catch (e) {
        debugPrint('$_debugTag ERROR parsing cities JSON: $e');
        cities = [];
      }
      
      if (cities.isEmpty) {
        debugPrint('$_debugTag ERROR: No cities available in settings');
        return false;
      }
      
      if (cityIndex >= cities.length) {
        debugPrint('$_debugTag ERROR: City index $cityIndex out of bounds (${cities.length} cities)');
        return false;
      }
      
      // Get selected city
      final selectedCity = cities[cityIndex] as Map<String, dynamic>?;
      if (selectedCity == null) {
        debugPrint('$_debugTag ERROR: Selected city is null');
        return false;
      }
      
      final cityName = selectedCity['name'] as String? ?? 'Unknown';
      final latitude = (selectedCity['latitude'] as num?)?.toDouble() ?? 0.0;
      final longitude = (selectedCity['longitude'] as num?)?.toDouble() ?? 0.0;
      final ministryId = selectedCity['ministryId'] as String? ?? '';
      
      debugPrint('$_debugTag Using city: $cityName (lat=$latitude, lon=$longitude, ministryId=$ministryId)');
      
      final isDarkMode = themeMode == 'dark';
      
      // Fetch prayer times based on source
      Map<String, String>? prayerTimes;
      String sourceLabel = 'unknown';
      
      switch (sourceIndex) {
        case 0: // Ministry (Daily Parser)
          debugPrint('$_debugTag Fetching from Ministry source...');
          prayerTimes = await _fetchFromMinistry(ministryId, cityName);
          sourceLabel = 'ministry';
          break;
          
        case 1: // Adhan API
          debugPrint('$_debugTag Fetching from Adhan API source...');
          prayerTimes = await _fetchFromAdhanApi(latitude, longitude);
          sourceLabel = 'adhan';
          break;
          
        case 2: // Offline Calculation
          debugPrint('$_debugTag Fetching from Offline calculation source...');
          prayerTimes = _calculateOffline(latitude, longitude);
          sourceLabel = 'offline';
          break;
          
        default:
          debugPrint('$_debugTag ERROR: Unknown source index $sourceIndex');
          return false;
      }
      
      if (prayerTimes == null || prayerTimes.isEmpty) {
        debugPrint('$_debugTag ERROR: Failed to fetch prayer times from source $sourceLabel');
        return false;
      }
      
      debugPrint('$_debugTag Prayer times fetched successfully from $sourceLabel');
      debugPrint('$_debugTag Fajr=${prayerTimes['fajr']}, Dhuhr=${prayerTimes['dhuhr']}, Maghrib=${prayerTimes['maghrib']}');
      
      // Save to cache
      final success = await _cacheService.saveWidgetCache(
        fajr: prayerTimes['fajr'] ?? 'N/A',
        sunrise: prayerTimes['sunrise'] ?? 'N/A',
        dhuhr: prayerTimes['dhuhr'] ?? 'N/A',
        asr: prayerTimes['asr'] ?? 'N/A',
        maghrib: prayerTimes['maghrib'] ?? 'N/A',
        isha: prayerTimes['isha'] ?? 'N/A',
        source: sourceLabel,
        location: cityName,
        hue: hue,
        isDarkMode: isDarkMode,
      );
      
      if (success) {
        debugPrint('$_debugTag Widget cache updated successfully');
      } else {
        debugPrint('$_debugTag ERROR: Failed to save widget cache');
      }
      
      return success;
    } catch (e, st) {
      debugPrint('$_debugTag EXCEPTION in updateWidgetCache: $e');
      debugPrint('$_debugTag Stack trace: $st');
      return false;
    }
  }

  /// Fetch prayer times from Ministry (habous.gov.ma) using daily parser
  Future<Map<String, String>?> _fetchFromMinistry(String ministryId, String cityName) async {
    try {
      debugPrint('$_debugTag Fetching from Ministry API (ministryId=$ministryId)...');
      
      if (ministryId.isEmpty) {
        debugPrint('$_debugTag ERROR: Ministry ID is empty');
        return null;
      }
      
      final url = 'https://www.habous.gov.ma/prieres/horaire-api.php?ville=$ministryId';
      debugPrint('$_debugTag Ministry URL: $url');
      
      try {
        final response = await http.get(Uri.parse(url))
            .timeout(const Duration(seconds: 10));
        
        if (response.statusCode != 200) {
          debugPrint('$_debugTag ERROR: Ministry API returned status ${response.statusCode}');
          return null;
        }
        
        debugPrint('$_debugTag Parsing Ministry HTML response...');
        
        final prayerTimes = await parseDailyPrayerTimesFromHtml(
          response.body,
          cityName: cityName,
        );
        
        debugPrint('$_debugTag Successfully parsed Ministry prayer times');
        return prayerTimes;
      } catch (e) {
        debugPrint('$_debugTag ERROR: Ministry API request failed: $e');
        return null;
      }
    } catch (e, st) {
      debugPrint('$_debugTag ERROR fetching from Ministry: $e');
      debugPrint('$_debugTag Stack trace: $st');
      return null;
    }
  }

  /// Fetch prayer times from Adhan API
  Future<Map<String, String>?> _fetchFromAdhanApi(double latitude, double longitude) async {
    try {
      debugPrint('$_debugTag Fetching from Adhan API (lat=$latitude, lon=$longitude)...');
      
      if (latitude == 0.0 || longitude == 0.0) {
        debugPrint('$_debugTag ERROR: Invalid coordinates (lat=$latitude, lon=$longitude)');
        return null;
      }
      
      try {
        final apiService = ApiService();
        final prayerTimes = await apiService.fetchMoroccoAlAdhanTimes(latitude, longitude);
        
        // Convert PrayerTimes object to Map<String, String>
        final result = {
          'fajr': prayerTimes.fajr,
          'sunrise': prayerTimes.sunrise,
          'dhuhr': prayerTimes.dhuhr,
          'asr': prayerTimes.asr,
          'maghrib': prayerTimes.maghrib,
          'isha': prayerTimes.isha,
        };
        
        debugPrint('$_debugTag Successfully fetched Adhan API prayer times');
        return result;
      } catch (e) {
        debugPrint('$_debugTag ERROR: Adhan API request failed: $e');
        return null;
      }
    } catch (e, st) {
      debugPrint('$_debugTag ERROR fetching from Adhan API: $e');
      debugPrint('$_debugTag Stack trace: $st');
      return null;
    }
  }

  /// Calculate prayer times offline using Adhan package
  Map<String, String>? _calculateOffline(double latitude, double longitude) {
    try {
      debugPrint('$_debugTag Calculating prayer times offline (lat=$latitude, lon=$longitude)...');
      
      if (latitude == 0.0 || longitude == 0.0) {
        debugPrint('$_debugTag ERROR: Invalid coordinates (lat=$latitude, lon=$longitude)');
        return null;
      }
      
      final result = calculatePrayerTimesOffline(
        latitude: latitude,
        longitude: longitude,
        date: DateTime.now(),
      );
      
      if (result.isEmpty) {
        debugPrint('$_debugTag ERROR: Offline calculation returned empty result');
        return null;
      }
      
      debugPrint('$_debugTag Successfully calculated offline prayer times');
      return result;
    } catch (e, st) {
      debugPrint('$_debugTag ERROR calculating offline prayer times: $e');
      debugPrint('$_debugTag Stack trace: $st');
      return null;
    }
  }

  /// Get widget cache data (checks if valid and returns)
  Future<WidgetCacheData?> getWidgetCache() async {
    return await _cacheService.getWidgetCache();
  }

  /// Clear widget cache
  Future<bool> clearCache() async {
    return await _cacheService.clearWidgetCache();
  }
}
/// Map of Arabic city names to Latin names
const Map<String, String> _latinNames = {
  'آزرو': 'Azrou',
  'آسفي': 'Safi',
  'آيت القاق': 'Aït El Kag',
  'آيت ورير': 'Aït Ourir',
  'أحفير': 'Ahfir',
  'أخفنير': 'Akhfennir',
  'أرفود': 'Erfoud',
  'أزمور': 'Azemmour',
  'أزيلال': 'Azilal',
  'أسا': 'Assa',
  'أسكين': 'Asguine',
  'أسول': 'Assoul',
  'أصيلة': 'Asilah',
  'أقا': 'Akka',
  'أكادير': 'Agadir',
  'أكايوار': 'Akaïouar',
  'أكدال أملشيل': 'Agoudal Amilchil',
  'أكدز': 'Agdz',
  'أكنول': 'Aknoul',
  'أمسمرير': 'Msemrir',
  'أمكالة': 'Amgala',
  'أوسرد': 'Aousserd',
  'أولاد تايمة': 'Oulad Teïma',
  'أولاد عياد': 'Oulad Ayad',
  'إغرم': 'Igherm',
  'إملشيل': 'Imilchil',
  'إموزار كندر': 'Imouzzer Kandar',
  'إيكس': 'Iks',
  'إيمنتانوت': 'Imintanoute',
  'إيمين ثلاث': 'Imin N\'Tlat',
  'ابن أحمد': 'Bin Ahmed',
  'اكودال املشيل ميدلت': 'Agoudal Amilchil Midelt',
  'البروج': 'El Borouj',
  'الجبهة': 'El Jebha',
  'الجديدة': 'El Jadida',
  'الحاجب': 'El Hajeb',
  'الحسيمة': 'Al Hoceima',
  'الخميسات': 'Khemisset',
  'الداخلة': 'Dakhla',
  'الدار البيضاء': 'Casablanca',
  'الرباط': 'Rabat',
  'الرحامنة': 'Rehamna',
  'الرشيدية': 'Errachidia',
  'الرماني': 'Rommani',
  'الريش': 'Errich',
  'الريصاني': 'Rissani',
  'الزاك': 'Assa-Zag',
  'السعيدية': 'Saïdia',
  'السمارة': 'Es-Semara',
  'الصويرة': 'Essaouira',
  'العرائش': 'Larache',
  'العيون': 'Laâyoune',
  'العيون الشرقية': 'El Aïoun Sidi Mellouk',
  'الفقيه بنصالح': 'Fquih Ben Salah',
  'الفنيدق': 'Fnideq',
  'القصر الصغير': 'Ksar Sghir',
  'القصر الكبير': 'Ksar El Kebir',
  'القصيبة': 'El Ksiba',
  'القنيطرة': 'Kenitra',
  'الكارة': 'El Gara',
  'الكويرة': 'Lagouira',
  'المحبس': 'Al Mahbass',
  'المحمدية': 'Mohammedia',
  'المضيق': 'M\'diq',
  'المنزل بني يازغة': 'El Menzel',
  'الناظور': 'Nador',
  'النيف': 'Alnif',
  'الوليدية': 'Oualidia',
  'اليوسفية': 'Youssoufia',
  'بئر أنزاران': 'Bir Anzarane',
  'بئر كندوز': 'Bir Gandouz',
  'باب برد': 'Bab Berred',
  'برشيد': 'Berrechid',
  'بركان': 'Berkane',
  'بن سليمان': 'Benslimane',
  'بنجرير': 'Benguerir',
  'بني أنصار': 'Beni Ensar',
};

/// Convert Arabic city name to Latin name for display
String _latinizeLocationName(String location) {
  return _latinNames[location] ?? location;
}