import 'dart:convert';
import 'package:flutter/services.dart';

class CityLookupService {
  // Singleton pattern to keep data in memory
  static final CityLookupService _instance = CityLookupService._internal();

  factory CityLookupService() => _instance;

  CityLookupService._internal();

  List<dynamic>? _cities;

  /// Loads the JSON from assets. Call this in main() or during app splash screen.
  Future<void> init() async {
    if (_cities != null) return; // Already loaded
    final String response = await rootBundle.loadString('assets/moroccan_cities_coordinates.json');
    final data = await json.decode(response);
    _cities = data['cities'];
  }

  /// Finds the closest city record based on coordinates.
  /// Returns a map with city data + ministry ID (if available).
  Map<String, dynamic>? findClosestCity(double userLat, double userLon, Map<String, String>? ministryIds) {
    if (_cities == null || _cities!.isEmpty) return null;

    Map<String, dynamic>? closestCity;
    double minDistanceSq = double.infinity;

    for (var city in _cities!) {
      double cityLat = city['lat'];
      double cityLon = city['lon'];

      // Calculating (x2 - x1)^2 + (y2 - y1)^2
      // More precise distance squared for Morocco's latitude (~33°N)
      double dLat = cityLat - userLat;
      double dLon = (cityLon - userLon) * 0.83; // Correction factor for Morocco's latitude

      double distanceSq = (dLat * dLat) + (dLon * dLon);

      if (distanceSq < minDistanceSq) {
        minDistanceSq = distanceSq;
        closestCity = Map.from(city);
      }
    }

    if (closestCity != null) {
      final arabicName = closestCity['arabic'] as String;
      // Try to find ministry ID if the map is provided
      final ministryId = ministryIds?[arabicName] ?? 'N/A';
      closestCity['ministry_id'] = ministryId;
      closestCity['distance_sq'] = minDistanceSq;
    }

    return closestCity;
  }
}


