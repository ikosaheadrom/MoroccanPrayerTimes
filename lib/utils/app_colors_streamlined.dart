// ignore_for_file: non_constant_identifier_names

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Comprehensive Color System organized by UI component priority
/// 
/// All colors are defined using HSV with:
/// - Hue: from SharedPreferences (user preference)
/// - Saturation & Value: customizable parameters
/// 
/// TO CUSTOMIZE COLORS:
/// Modify (saturation, value) values below, then hot restart
/// Example: header_txt => change the (0.60, 0.20) values
/// 
/// NAMING CONVENTION:
/// {component}_{element} where element is:
/// - txt = text color
/// - subtxt = secondary/muted text  
/// - bg = background color
/// - HL = highlighted/active state

class AppColorsStreamlined {
  static double? _cachedHue;
  static bool? _cachedIsDarkMode;
  
  final double hue;
  final bool isDarkMode;

  /// Private constructor
  AppColorsStreamlined._({
    required this.hue,
    required this.isDarkMode,
  });

  /// Factory constructor to create from BuildContext
  factory AppColorsStreamlined(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // Try to extract hue from theme's primary color if available
    final primary = Theme.of(context).colorScheme.primary;
    final hsvColor = HSVColor.fromColor(primary);
    double hue = hsvColor.hue;
    
    // Cache the values
    _cachedHue = hue;
    _cachedIsDarkMode = isDarkMode;
    
    return AppColorsStreamlined._(hue: hue, isDarkMode: isDarkMode);
  }

  /// Initialize colors from SharedPreferences
  static Future<AppColorsStreamlined> init(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // Get hue from preferences, default to 260
    double hue = prefs.getDouble('colorHue') ?? 260.0;
    
    _cachedHue = hue;
    _cachedIsDarkMode = isDarkMode;

    return AppColorsStreamlined._(hue: hue, isDarkMode: isDarkMode);
  }

  /// Get instance with cached values (for quick access)
  static AppColorsStreamlined fromCache() {
    return AppColorsStreamlined._(
      hue: _cachedHue ?? 260.0,
      isDarkMode: _cachedIsDarkMode ?? false,
    );
  }

  /// Create HSV color from hue (shared prefs) and saturation/value
  Color _hsv(double saturation, double value) {
    return HSVColor.fromAHSV(
      1.0,
      hue % 360,
      saturation.clamp(0.0, 1.0),
      value.clamp(0.0, 1.0),
    ).toColor();
  }

  /// Create HSV color with alpha
  Color _hsvAlpha(double saturation, double value, double alpha) {
    return HSVColor.fromAHSV(
      alpha,
      hue % 360,
      saturation.clamp(0.0, 1.0),
      value.clamp(0.0, 1.0),
    ).toColor();
  }

  // ============= HEADER COLORS (Highest Priority) =============
  
  /// App bar header text
  Color get header_txt => isDarkMode 
    ? _hsv(0.10, 0.95)  
    : _hsv(0.80, 0.30); 

  /// App bar header background
  Color get header_bg => isDarkMode
    ? _hsv(0.55, 0.45)  
    : _hsv(0.25, 0.90); 

  // ============= TAB COLORS =============

  /// Tab text (unselected)
  Color get tab_txt => isDarkMode
    ? _hsv(0.28, 0.70)
    : _hsv(0.80, 0.35);

    /// Tab text (selected)
  Color get HLtab_txt => isDarkMode
    ? _hsv(0.28, 0.90)
    : _hsv(0.90, 0.60);

  /// Tab background (unselected)
  Color get tab_bg => isDarkMode
    ? _hsv(0.55, 0.35)
    : _hsv(0.25, 0.95);

    /// Tab background (selected)
  Color get HLtab_bg => isDarkMode
    ? _hsv(0.55, 0.75)
    : _hsv(0.30, 0.95);

  // ============= SURFACE COLORS (Main Content Area) =============

  /// Surface/page background
  Color get surface_bg => isDarkMode
    ? _hsv(0.10, 0.10)
    : _hsv(0.10, 0.97);

  /// Surface text (primary text on surface)
  Color get surface_txt => isDarkMode
    ? _hsv(0.08, 0.9)
    : _hsv(0.08, 0.20);

  /// Surface secondary text
  Color get surface_subtxt => isDarkMode
    ? _hsv(0.08, 0.70)
    : _hsv(0.08, 0.35);

  // ============= PRIMARY CONTAINER COLORS =============

  /// Primary container text
  Color get primarycontainer_txt => isDarkMode
    ? _hsv(0.24, 0.95)
    : _hsv(0.30, 0.30);

  /// Primary container secondary text
  Color get primarycontainer_subtxt => isDarkMode
    ? _hsv(0.25, 0.88)
    : _hsv(0.45, 0.45);

  /// Primary container background
  Color get primarycontainer_bg => isDarkMode
    ? _hsv(0.44, 0.40)
    : _hsv(0.40, 0.89);

  // ============= SECONDARY CONTAINER COLORS =============

  /// Secondary container text
  Color get secondarycontainer_txt => isDarkMode
    ? _hsv(0.30, 0.80)
    : _hsv(0.30, 0.6);

  /// Secondary container secondary text
  Color get secondarycontainer_subtxt => isDarkMode
    ? _hsv(0.30, 0.60)
    : _hsv(0.40, 0.85);

  /// Secondary container background (normal state)
  Color get secondarycontainer_bg => isDarkMode
    ? _hsv(0.31, 0.20)
    : _hsv(0.10, 0.96);

  /// Secondary container background (highlighted/active)
  Color get HLsecondarycontainer_bg => isDarkMode
    ? _hsv(0.30, 0.70)
    : _hsv(0.50, 0.60);

  /// Secondary container text (highlighted)
  Color get HLsecondarycontainer_txt => isDarkMode
    ? _hsv(0.31, 0.20)
    : _hsv(0.10, 0.90);

  /// Secondary container secondary text (highlighted)
  Color get HLsecondarycontainer_subtxt => isDarkMode
    ? _hsv(0.31, 0.30)
    : _hsv(0.21, 0.90);

  // ============= HIGHLIGHTED CONTAINER COLORS (for selections/active states) =============

  /// Highlighted container background
  Color get HLcontainer_bg => isDarkMode
    ? _hsv(0.24, 0.80)
    : _hsv(0.80, 0.30);

  /// Highlighted container text
  Color get HLcontainer_txt => isDarkMode
    ? _hsv(0.38, 0.39)
    : _hsv(0.40, 0.89);

  /// Highlighted container secondary text
  Color get HLcontainer_subtxt => isDarkMode
    ? _hsv(0.38, 0.5)
    : _hsv(0.44, 0.7);

  // ============= TERTIARY CONTAINER COLORS =============

  /// Tertiary container text
  Color get tertiarycontainer_txt => isDarkMode
    ? _hsv(0.31, 0.90)
    : _hsv(0.31, 0.20);

  /// Tertiary container secondary text
  Color get tertiarycontainer_subtxt => isDarkMode
    ? _hsv(0.70, 0.70)
    : _hsv(0.70, 0.35);

  /// Tertiary container background
  Color get tertiarycontainer_bg => isDarkMode
    ? _hsv(0.60, 0.50)
    : _hsv(0.40, 0.95);

  /// Tertiary container background
  Color get tertiarycontainer_bg2 => isDarkMode
    ? _hsv(0.55, 0.45)
    : _hsv(0.30, 0.95);

  /// Tertiary container background
  Color get tertiarycontainer_bg3 => isDarkMode
    ? _hsv(0.50, 0.35)
    : _hsv(0.20, 0.95);

  // ============= BUTTON COLORS =============

  /// Button enabled/active state
  Color get button_on => isDarkMode
    ? _hsv(0.25, 0.90)
    : _hsv(0.30, 0.99);

  /// Button disabled state
  Color get button_off => isDarkMode
    ? _hsv(0.60, 0.35)
    : _hsv(0.50, 0.60);

  // ============= SWITCH/TOGGLE COLORS =============

  /// Switch enabled/on state
  Color get switch_on => isDarkMode
    ? _hsv(0.60, 0.65)
    : _hsv(0.50, 0.90);

  /// Switch track disabled/off state
  Color get switch_track_on => isDarkMode
    ? _hsv(0.40, 0.75)
    : _hsv(0.60, 0.60);

  /// Switch disabled/off state
  Color get switch_off => isDarkMode
    ? _hsv(0.40, 0.50)
    : _hsv(0.50, 0.6);

  /// Switch track disabled/off state
  Color get switch_track_off => isDarkMode
    ? _hsv(0.40, 0.30)
    : _hsv(0.40, 0.30);

  /// Switch border color
  Color get switch_border => isDarkMode
    ? _hsv(0.40, 0.50)
    : _hsv(0.50, 0.78);

  // ============= TEXT FIELD COLORS =============

  /// Text field input text
  Color get textfield_txt => isDarkMode
    ? _hsv(0.08, 0.95)
    : _hsv(0.08, 0.15);

  /// Text field hint/helper text
  Color get textfield_subtxt => isDarkMode
    ? _hsv(0.08, 0.65)
    : _hsv(0.1, 0.45);

  /// Text field background
  Color get textfield_bg => isDarkMode
    ? _hsv(0.10, 0.10)
    : _hsv(0.15, 0.95);

  // ============= DROPDOWN COLORS =============

  /// Dropdown text (normal state)
  Color get dropdown_txt => isDarkMode
    ? _hsv(0.28, 0.60)
    : _hsv(0.28, 0.30);

  /// Dropdown background (normal state)
  Color get dropdown_bg => isDarkMode
    ? _hsv(0.35, 0.15)
    : _hsv(0.20, 0.95);

  /// Dropdown text (highlighted/selected)
  Color get HLdropdown_txt => isDarkMode
    ? _hsv(0.25, 0.95)
    : _hsv(0.25, 0.25);

  /// Dropdown background (highlighted/selected)
  Color get HLdropdown_bg => isDarkMode
    ? _hsv(0.50, 0.25)
    : _hsv(0.30, 0.90);
  
  // ============= SEARCH COLORS =============
  
  Color get search_odd => isDarkMode
    ? _hsv(0.50, 0.10)
    : _hsv(0.20, 0.93);

  Color get search_even => isDarkMode
    ? _hsv(0.50, 0.15)
    : _hsv(0.20, 0.90);
  
  Color get search_selected => isDarkMode
    ? _hsv(0.50, 0.30)
    : _hsv(0.30, 0.95);

  Color get search_star => isDarkMode
    ? _hsv(0.24, 0.95)
    : _hsv(0.64, 0.80);

  // ============= NOTIFICATION ICON COLORS =============

  /// full
  Color get notificationicon_full => isDarkMode
    ? _hsv(0.30, 0.90)
    : _hsv(0.30, 0.50);

  /// vibrate
  Color get notificationicon_vibrate => isDarkMode
    ? _hsv(0.30, 0.83)
    : _hsv(0.30, 0.45);

  /// silent
  Color get notificationicon_silent => isDarkMode
    ? _hsv(0.30, 0.70)
    : _hsv(0.30, 0.40);

  /// off
  Color get notificationicon_off => isDarkMode
    ? _hsv(0.30, 0.55)
    : _hsv(0.30, 0.35);

  // ============= ADDITIONAL UTILITY COLORS =============

  /// Pure color
  Color get pure => isDarkMode
    ? _hsv(0.70, 0.90)
    : _hsv(0.70, 0.90);

  /// Border/Divider color
  Color get border => isDarkMode
    ? _hsv(0.30, 0.80)
    : _hsv(0.30, 0.50);

  /// Divider (more subtle)
  Color get divider => isDarkMode
    ? _hsv(0.10, 0.20)
    : _hsv(0.10, 0.90);

  /// Error state color
  Color get error_txt => _hsv(0.00, 0.90);
  Color get error_bg => isDarkMode
    ? _hsv(0.00, 0.30)
    : _hsv(0.00, 0.88);

  /// Success state color
  Color get success_txt => _hsv(0.33, 0.90);
  Color get success_bg => isDarkMode
    ? _hsv(0.33, 0.30)
    : _hsv(0.33, 0.88);

  /// Warning state color
  Color get warning_txt => _hsv(0.05, 0.90);
  Color get warning_bg => isDarkMode
    ? _hsv(0.05, 0.35)
    : _hsv(0.05, 0.88);

  /// Shadow color
  Color get shadow => isDarkMode
    ? _hsvAlpha(0.10, 0.05, 0.10)
    : _hsvAlpha(0.10, 0.20, 0.08);

  /// Scrim/overlay (modals)
  Color get scrim => isDarkMode
    ? _hsvAlpha(0.00, 0.00, 0.58)
    : _hsvAlpha(0.00, 0.00, 0.25);

  /// link color
  Color get link_txt => isDarkMode
    ? _hsv(0.45, 0.85)
    : _hsv(0.55, 0.75);

  // ============= UTILITY METHODS =============

  /// Create color with custom alpha
  Color withAlpha(Color color, double alpha) {
    return color.withValues(alpha: alpha);
  }

  /// Lighten color
  Color lighten(Color color, [double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    return Color.lerp(color, Colors.white, amount)!;
  }

  /// Darken color
  Color darken(Color color, [double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    return Color.lerp(color, Colors.black, amount)!;
  }

  /// Get contrast color (white/black) for text on background
  Color getContrastColor(Color background) {
    return background.computeLuminance() > 0.5 
      ? Colors.black 
      : Colors.white;
  }
}
