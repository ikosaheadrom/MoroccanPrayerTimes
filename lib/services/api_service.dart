import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/prayer_times.dart'; // Import the data model

class ApiService {
  /// Create an HttpClient that ignores certificate errors for development
  /// WARNING: This is insecure; only use for development/testing
  static HttpClient _createHttpClient() {
    final client = HttpClient();
    client.badCertificateCallback = (X509Certificate cert, String host, int port) {
      debugPrint('[SSL] Accepting certificate for $host due to development mode');
      return true;
    };
    return client;
  }

  /// Fetch prayer times from AlAdhan API with hardcoded Morocco settings
  /// Uses method=99 (custom) with Fajr 19°, Isha 17°, Shafi madhab, Isha +5min adjustment
  Future<PrayerTimes> fetchMoroccoAlAdhanTimes(double latitude, double longitude) async {
    debugPrint('[fetchMoroccoAlAdhanTimes] ═════ CALLED ═════');
    debugPrint('[fetchMoroccoAlAdhanTimes] Input latitude: $latitude');
    debugPrint('[fetchMoroccoAlAdhanTimes] Input longitude: $longitude');
    
    const apiAuthority = 'http://api.aladhan.com';
    const apiPath = '/v1/timings';
    
    // Get Unix timestamp for today
    final now = DateTime.now();
    final timestamp = (DateTime(now.year, now.month, now.day).millisecondsSinceEpoch / 1000).toStringAsFixed(0);
    
    debugPrint('[fetchMoroccoAlAdhanTimes] Timestamp: $timestamp');
    debugPrint('[fetchMoroccoAlAdhanTimes] Year: ${now.year}, Month: ${now.month}, Day: ${now.day}');
    
    // Build URL with Morocco parameters using methodSettings format
    // method=99: Custom method that respects methodSettings
    // methodSettings="19,null,17": Fajr 19°, null for second param, Isha 17°
    // school=0: Shafi madhab
    // latitudeAdjustmentMethod=0: Standard latitude adjustment
    // tune="0,0,0,0,0,5,0,0,0": Isha +5 minutes (Fajr,Sunrise,Dhuhr,Asr,Maghrib,Isha,Imsak,Midnight,Firstthird)
    final uri = Uri.parse(
      '$apiAuthority$apiPath/$timestamp?'
      'latitude=$latitude&'
      'longitude=$longitude&'
      'method=99&'
      'methodSettings=19,null,17&'
      'school=0&'
      'latitudeAdjustmentMethod=0&'
      'midnightMethod=Standard&'
      'tune=0,0,0,0,0,5,0,0,0'
    );

    debugPrint('[fetchMoroccoAlAdhanTimes] ════════════════════════════════════');
    debugPrint('[fetchMoroccoAlAdhanTimes] FULL URL: $uri');
    debugPrint('[fetchMoroccoAlAdhanTimes] ════════════════════════════════════');

    try {
      final client = _createHttpClient();
      final request = await client.getUrl(uri);
      
      debugPrint('[fetchMoroccoAlAdhanTimes] Request created, sending...');
      
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      debugPrint('[fetchMoroccoAlAdhanTimes] Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(body);
        final responseLatitude = jsonResponse['data']?['meta']?['latitude'];
        final responseLongitude = jsonResponse['data']?['meta']?['longitude'];
        final methodInfo = jsonResponse['data']?['meta']?['method'];
        
        debugPrint('[fetchMoroccoAlAdhanTimes] ════ RESPONSE DATA ════');
        debugPrint('[fetchMoroccoAlAdhanTimes] Response Latitude: $responseLatitude');
        debugPrint('[fetchMoroccoAlAdhanTimes] Response Longitude: $responseLongitude');
        debugPrint('[fetchMoroccoAlAdhanTimes] Response Method: ${methodInfo?['id']} - ${methodInfo?['name']}');
        debugPrint('[fetchMoroccoAlAdhanTimes] Response Params: ${methodInfo?['params']}');
        debugPrint('[fetchMoroccoAlAdhanTimes] ═══════════════════════');
        
        if (jsonResponse['code'] == 200 && jsonResponse['data'] != null) {
          // Extract timings from AlAdhan response
          final timings = jsonResponse['data']['timings'];
          
          debugPrint('[fetchMoroccoAlAdhanTimes] Prayer Times:');
          debugPrint('[fetchMoroccoAlAdhanTimes]   Fajr: ${timings['Fajr']}');
          debugPrint('[fetchMoroccoAlAdhanTimes]   Sunrise: ${timings['Sunrise']}');
          debugPrint('[fetchMoroccoAlAdhanTimes]   Dhuhr: ${timings['Dhuhr']}');
          debugPrint('[fetchMoroccoAlAdhanTimes]   Asr: ${timings['Asr']}');
          debugPrint('[fetchMoroccoAlAdhanTimes]   Maghrib: ${timings['Maghrib']}');
          debugPrint('[fetchMoroccoAlAdhanTimes]   Isha: ${timings['Isha']}');
          
          // Extract prayer times and format them (remove timezone info if present)
          String extractTime(String? timeStr) {
            if (timeStr == null || timeStr.isEmpty) return '00:00';
            // API may return times like "07:00 +01" or just "07:00"
            if (timeStr.contains(' ')) {
              return timeStr.split(' ').first.trim();
            }
            return timeStr.trim();
          }
          
          client.close();
          return PrayerTimes(
            fajr: extractTime(timings['Fajr'] as String?),
            sunrise: extractTime(timings['Sunrise'] as String?),
            dhuhr: extractTime(timings['Dhuhr'] as String?),
            asr: extractTime(timings['Asr'] as String?),
            maghrib: extractTime(timings['Maghrib'] as String?),
            isha: extractTime(timings['Isha'] as String?),
          );
        } else {
          client.close();
          throw Exception('Invalid response from AlAdhan API: ${jsonResponse['status']}');
        }
      } else {
        client.close();
        throw Exception('Failed to load prayer times from AlAdhan. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[fetchMoroccoAlAdhanTimes] ERROR: $e');
      throw Exception('Failed to load prayer times: $e');
    }
  }

  /// Alias method for fetching from Adhan API (same as fetchMoroccoAlAdhanTimes)
  /// Uses method=99 (custom) with Fajr 19°, Isha 17°, Shafi madhab, Isha +5min adjustment
  Future<PrayerTimes> fetchAdhanApiTimes({
    required double latitude,
    required double longitude,
  }) async {
    return fetchMoroccoAlAdhanTimes(latitude, longitude);
  }

  // Method to fetch the times for a given city
  Future<PrayerTimes> fetchOfficialMoroccanTimes(String cityName) async {
    const apiAuthority = 'https://salat-maghrib.vercel.app'; 
    const apiPath = '/api/today'; 
    final uri = Uri.parse('$apiAuthority$apiPath?city=$cityName');

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      return PrayerTimes.fromJson(jsonResponse);
    } else {
      throw Exception('Failed to load official prayer times for $cityName. Status Code: ${response.statusCode}');
    }
  }
}