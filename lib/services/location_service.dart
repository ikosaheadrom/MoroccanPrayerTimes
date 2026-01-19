import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Fetches a one-off coordinate.
  /// Returns null if permissions are denied or GPS is off.
  static Future<Position?> getOneOffPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Check if the "Location" toggle is ON in system settings
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    // 2. Handle Permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }

    if (permission == LocationPermission.deniedForever) return null;

    // 3. Request Position
    try {
      return await Geolocator.getCurrentPosition(
        // 'low' uses Cell/Wi-Fi mostly (Fast & Battery efficient)
        // 'high' forces the GPS hardware to spin up.
        desiredAccuracy: LocationAccuracy.low,
        // We kill the request after 5 seconds to ensure the chip doesn't stay on
        timeLimit: const Duration(seconds: 5),
      );
    } catch (e) {
      // If a timeout occurs, fallback to the last location the phone recorded
      return await Geolocator.getLastKnownPosition();
    }
  }
}
