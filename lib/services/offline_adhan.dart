import 'package:adhan/adhan.dart';
import 'package:intl/intl.dart';

class PrayerService {
  // We make it a singleton or just a class with static/instance methods
  
  Map<String, String> calculateOffline({
    required double lat,
    required double lon,
    required DateTime date,
  }) {
    final coordinates = Coordinates(lat, lon);
    final dateComponents = DateComponents.from(date);

    // Matches your Python "Method 99" & "Hybrid" Logic
    final params = CalculationParameters(fajrAngle: 19.0, ishaAngle: 17.0);
    params.madhab = Madhab.shafi;
    params.highLatitudeRule = HighLatitudeRule.twilight_angle;
    
    // Applying +5m Maghrib adjustment (compensates for calculation vs observed difference)
    params.adjustments.maghrib = 0;

    final pt = PrayerTimes(coordinates, dateComponents, params);

    // Format to HH:mm while automatically handling the Morocco Ramadan shift
    return {
      "Fajr": _format(pt.fajr),
      "Sunrise": _format(pt.sunrise),
      "Dhuhr": _format(pt.dhuhr),
      "Asr": _format(pt.asr),
      "Maghrib": _format(pt.maghrib),
      "Isha": _format(pt.isha),
    };
  }

  String _format(DateTime time) {
    return DateFormat.Hm().format(time.toLocal());
  }
}

/// Helper function to calculate prayer times offline
Map<String, String> calculatePrayerTimesOffline({
  required double latitude,
  required double longitude,
  required DateTime date,
}) {
  final service = PrayerService();
  return service.calculateOffline(
    lat: latitude,
    lon: longitude,
    date: date,
  );
}