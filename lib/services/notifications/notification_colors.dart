import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Generates notification colors from the user's selected hue preference
class NotificationColors {
  /// Get athan notification color (more saturated) from hue preference
  static Future<Color> getAthanColor() async {
    final hue = await _getHueFromPreferences();
    return HSLColor.fromAHSL(1.0, hue, 0.80, 0.50).toColor();
  }

  /// Get reminder notification color (less saturated) from hue preference
  static Future<Color> getReminderColor() async {
    final hue = await _getHueFromPreferences();
    return HSLColor.fromAHSL(1.0, hue, 0.45, 0.55).toColor();
  }

  /// Get hue value from SharedPreferences (default: 260.0 = blue)
  static Future<double> _getHueFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble('primaryHue') ?? 260.0;
    } catch (e) {
      return 260.0; // Default to blue if error
    }
  }

  /// Synchronous version using a provided hue value
  static Color getAthanColorSync(double hue) {
    return HSLColor.fromAHSL(1.0, hue, 0.80, 0.50).toColor();
  }

  /// Synchronous reminder color using provided hue
  static Color getReminderColorSync(double hue) {
    return HSLColor.fromAHSL(1.0, hue, 0.45, 0.55).toColor();
  }
}
