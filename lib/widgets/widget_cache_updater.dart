import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prayer_times.dart';
import 'widget_cache_service.dart';

/// Helper utility to update widget cache whenever prayer times are available
/// This should be called after fetching prayer times from any source
class WidgetCacheUpdater {
  static const String _debugTag = '[WidgetCacheUpdater]';
  static final WidgetCacheService _cacheService = WidgetCacheService();

  /// Update widget cache with prayer times and current settings.
  /// Call this after fetching prayer times from ANY source (Ministry, Adhan, Offline).
  static Future<bool> updateCacheWithPrayerTimes(PrayerTimes times) async {
    try {
      debugPrint('$_debugTag Updating widget cache with prayer times...');
      
      final prefs = await SharedPreferences.getInstance();
      
      // Get current settings
      final sourceIndex = prefs.getInt('sourceIndex') ?? 0;
      final selectedCityName = prefs.getString('selectedCityName') ?? 'Unknown';
      final themeMode = prefs.getString('themeMode') ?? 'light';
      final primaryHue = prefs.getDouble('primaryHue') ?? 0.0;
      final widgetBgTransparency = prefs.getDouble('widgetBgTransparency') ?? 1.0;
      final adhanLatitude = prefs.getString('adhanLatitude') ?? '';
      final adhanLongitude = prefs.getString('adhanLongitude') ?? '';
      
      debugPrint('$_debugTag [DEBUG] primaryHue from prefs: $primaryHue, themeMode: $themeMode, bgTransparency: $widgetBgTransparency');
      
      // Map source index to source label
      final sourceLabel = _getSourceLabel(sourceIndex);
      
      // Determine isDarkMode based on themeMode setting
      final isDarkMode = themeMode == 'dark';
      
      // Determine location based on source
      String location;
      if (sourceLabel == 'offline' || sourceLabel == 'adhan') {
        location = '$adhanLatitude, $adhanLongitude';
      } else {
        location = _latinizeLocationName(selectedCityName);
      }
      
      debugPrint('$_debugTag Source: $sourceLabel, Location: $location, Theme: $themeMode, Hue: $primaryHue');
      
      // Save to widget cache
      final success = await _cacheService.saveWidgetCache(
        fajr: times.fajr,
        sunrise: times.sunrise,
        dhuhr: times.dhuhr,
        asr: times.asr,
        maghrib: times.maghrib,
        isha: times.isha,
        source: sourceLabel,
        location: location,
        hue: primaryHue,
        isDarkMode: isDarkMode,
        bgTransparency: widgetBgTransparency,
      );
      
      debugPrint('$_debugTag [DEBUG] saveWidgetCache result: success=$success, hue=$primaryHue, isDarkMode=$isDarkMode');
      
      if (success) {
        debugPrint('$_debugTag ✓ Widget cache updated successfully');
        debugPrint('$_debugTag Prayer times: Fajr=${times.fajr}, Dhuhr=${times.dhuhr}, Asr=${times.asr}, Maghrib=${times.maghrib}, Isha=${times.isha}');
      } else {
        debugPrint('$_debugTag ✗ Failed to save widget cache');
      }
      
      return success;
    } catch (e, st) {
      debugPrint('$_debugTag ERROR updating widget cache: $e');
      debugPrint('$_debugTag Stack trace: $st');
      return false;
    }
  }

  /// Update widget cache with prayer times map.
  /// Useful when prayer times are returned as `Map<String, String>`.
  static Future<bool> updateCacheWithPrayerTimesMap(Map<String, String> times, {String? sourceOverride}) async {
    try {
      debugPrint('$_debugTag Updating widget cache with prayer times map...');
      
      final prefs = await SharedPreferences.getInstance();
      
      // Get current settings
      final sourceIndex = prefs.getInt('sourceIndex') ?? 0;
      final selectedCityName = prefs.getString('selectedCityName') ?? 'Unknown';
      final themeMode = prefs.getString('themeMode') ?? 'light';
      final primaryHue = prefs.getDouble('primaryHue') ?? 0.0;
      final widgetBgTransparency = prefs.getDouble('widgetBgTransparency') ?? 1.0;
      final adhanLatitude = prefs.getString('adhanLatitude') ?? '';
      final adhanLongitude = prefs.getString('adhanLongitude') ?? '';
      
      debugPrint('$_debugTag [DEBUG-MAP] primaryHue from prefs: $primaryHue, themeMode: $themeMode');
      
      // Use sourceOverride if provided, otherwise use sourceIndex
      final sourceLabel = sourceOverride ?? _getSourceLabel(sourceIndex);
      
      // Determine isDarkMode based on themeMode setting
      final isDarkMode = themeMode == 'dark';
      
      // Determine location based on source
      String location;
      if (sourceLabel == 'offline' || sourceLabel == 'adhan') {
        location = '$adhanLatitude, $adhanLongitude';
      } else {
        location = _latinizeLocationName(selectedCityName);
      }
      
      debugPrint('$_debugTag Source: $sourceLabel, Location: $location, Hue: $primaryHue');
      
      // Save to widget cache
      final success = await _cacheService.saveWidgetCache(
        fajr: times['fajr'] ?? times['Fajr'] ?? 'N/A',
        sunrise: times['sunrise'] ?? times['Sunrise'] ?? 'N/A',
        dhuhr: times['dhuhr'] ?? times['Dhuhr'] ?? 'N/A',
        asr: times['asr'] ?? times['Asr'] ?? 'N/A',
        maghrib: times['maghrib'] ?? times['Maghrib'] ?? 'N/A',
        isha: times['isha'] ?? times['Isha'] ?? 'N/A',
        source: sourceLabel,
        location: location,
        hue: primaryHue,
        isDarkMode: isDarkMode,
        bgTransparency: widgetBgTransparency,
      );
      
      debugPrint('$_debugTag [DEBUG-MAP] saveWidgetCache result: success=$success, hue=$primaryHue, isDarkMode=$isDarkMode');
      
      if (success) {
        debugPrint('$_debugTag ✓ Widget cache updated successfully');
        debugPrint('$_debugTag Prayer times: Fajr=${times['fajr'] ?? times['Fajr']}, Dhuhr=${times['dhuhr'] ?? times['Dhuhr']}, Maghrib=${times['maghrib'] ?? times['Maghrib']}');
      } else {
        debugPrint('$_debugTag ✗ Failed to save widget cache');
      }
      
      return success;
    } catch (e, st) {
      debugPrint('$_debugTag ERROR updating widget cache: $e');
      debugPrint('$_debugTag Stack trace: $st');
      return false;
    }
  }

  /// Convert source index to source label
  static String _getSourceLabel(int sourceIndex) {
    switch (sourceIndex) {
      case 0:
        return 'ministry';
      case 1:
        return 'adhan';
      case 2:
        return 'offline';
      default:
        return 'unknown';
    }
  }

  /// Update widget to highlight current prayer time
  /// This is called by prayer time alarms to update the widget display
  static Future<bool> updateCurrentPrayerHighlight(String prayerName) async {
    try {
      debugPrint('$_debugTag Updating widget highlight for: $prayerName');
      
      final prefs = await SharedPreferences.getInstance();
      
      // Save the current highlighted prayer to SharedPreferences
      // The widget reads this value and updates its display
      await prefs.setString('currentHighlightedPrayer', prayerName.toLowerCase());
      await prefs.setString('lastHighlightUpdateTime', DateTime.now().toIso8601String());
      
      debugPrint('$_debugTag ✓ Widget highlight updated: $prayerName');
      return true;
    } catch (e, st) {
      debugPrint('$_debugTag ERROR updating widget highlight: $e');
      debugPrint('$_debugTag Stack trace: $st');
      return false;
    }
  }

  /// Map of Arabic city names to Latin names
  static const Map<String, String> _latinNames = {
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
  static String _latinizeLocationName(String location) {
    return _latinNames[location] ?? location;
  }
}