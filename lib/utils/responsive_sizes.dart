import 'package:flutter/material.dart';

/// Responsive sizing utilities for percentage-based UI layouts
/// This ensures the app looks good on any screen size
class ResponsiveSizes {
  final BuildContext context;
  late final Size screenSize;
  late final double screenWidth;
  late final double screenHeight;
  late final bool isTablet;
  late final double scale;

  ResponsiveSizes(this.context) {
    screenSize = MediaQuery.of(context).size;
    screenWidth = screenSize.width;
    screenHeight = screenSize.height;
    isTablet = screenWidth > 600;
    scale = MediaQuery.textScalerOf(context).scale(1.0) * (screenWidth / 360.0);
  }

  /// Font size as percentage of screen width
  double fontSize(double percentage) => screenWidth * (percentage / 100);

  /// Height as percentage of screen height
  double heightPercent(double percentage) => screenHeight * (percentage / 100);

  /// Width as percentage of screen width
  double widthPercent(double percentage) => screenWidth * (percentage / 100);

  /// Padding/margin as percentage of screen width
  double spacingPercent(double percentage) => screenWidth * (percentage / 100);

  // ============= Preset Sizes =============

  /// Horizontal padding (left/right margins)
  double get horizontalPadding => isTablet ? widthPercent(6) : widthPercent(3);

  /// Vertical padding (top/bottom margins)
  double get verticalPadding => heightPercent(1.5);

  /// Card spacing between prayer cards
  double get cardSpacing => widthPercent(1.5);

  // ============= Typography =============

  /// Large title font size (for main headers)
  double get titleSize => isTablet ? fontSize(6.5) : fontSize(5.5);

  /// Medium heading font size (for section headers)
  double get headingSize => isTablet ? fontSize(5.5) : fontSize(4.5);

  /// Body text font size
  double get bodySize => isTablet ? fontSize(4.2) : fontSize(3.8);

  /// Small text font size (captions, hints)
  double get captionSize => isTablet ? fontSize(3.2) : fontSize(2.8);

  // ============= Prayer Times Screen =============

  /// Prayer name font size
  double get prayerNameSize => isTablet ? fontSize(6.5) : fontSize(5.5);

  /// Prayer time font size
  double get prayerTimeSize => isTablet ? fontSize(8) : fontSize(6);

  /// Timer display font size
  double get timerSize => isTablet ? fontSize(20) : fontSize(13);

  /// Timer subtitle font size
  double get timerSubtitleSize => isTablet ? fontSize(3.5) : fontSize(2.8);

  // ============= Calendar Screen =============

  /// Hijri day display font size
  double get hijriDaySize => fontSize(8.5);

  /// Hijri month font size
  double get hijriMonthSize => fontSize(3.2);

  /// Gregorian day display font size
  double get gregorianDaySize => fontSize(8.5);

  /// Gregorian month font size
  double get gregorianMonthSize => fontSize(3.2);

  /// Weekday font size
  double get weekdaySize => fontSize(5.2);

  /// Prayer cell name font size (calendar grid)
  double get cellNameSize => fontSize(3.5);

  /// Prayer cell time font size (calendar grid)
  double get cellTimeSize => fontSize(4);

  // ============= Settings Screen =============

  /// Settings section header font size
  double get settingHeaderSize => fontSize(4.4);

  /// Settings item label font size
  double get settingLabelSize => fontSize(4.2);

  /// Settings input text font size
  double get settingInputSize => fontSize(3.8);

  // ============= Spacing Presets =============

  /// Extra small spacing (4% of width)
  double get spacingXS => spacingPercent(1);

  /// Small spacing (8% of width)
  double get spacingS => spacingPercent(2);

  /// Medium spacing (12% of width)
  double get spacingM => spacingPercent(3);

  /// Large spacing (16% of width)
  double get spacingL => spacingPercent(4);

  /// Extra large spacing (24% of width)
  double get spacingXL => spacingPercent(6);

  // ============= Edge Insets =============

  /// Standard horizontal padding
  EdgeInsets get paddingHorizontal =>
      EdgeInsets.symmetric(horizontal: horizontalPadding);

  /// Standard vertical padding
  EdgeInsets get paddingVertical =>
      EdgeInsets.symmetric(vertical: verticalPadding);

  /// Standard all-around padding
  EdgeInsets get paddingAll => EdgeInsets.all(horizontalPadding);

  /// Standard card padding
  EdgeInsets get paddingCard =>
      EdgeInsets.symmetric(vertical: spacingM, horizontal: horizontalPadding);

  /// Prayer card padding
  EdgeInsets get paddingPrayerCard =>
      EdgeInsets.symmetric(vertical: spacingS, horizontal: spacingM);

  // ============= Border Radius =============

  /// Standard border radius
  double get borderRadiusStandard => spacingPercent(2.5);

  /// Small border radius
  double get borderRadiusSmall => spacingPercent(1.5);

  // ============= Icon Sizes =============

  /// Small icon size
  double get iconSizeSmall => fontSize(4);

  /// Medium icon size
  double get iconSizeMedium => fontSize(5.5);

  /// Large icon size
  double get iconSizeLarge => fontSize(7);

  // ============= Helper Methods =============

  /// Get a scaled dimension based on width percentage
  double scaled(double widthPercentage, [double? tabletMultiplier]) {
    final baseSize = screenWidth * (widthPercentage / 100);
    if (isTablet && tabletMultiplier != null) {
      return baseSize * tabletMultiplier;
    }
    return baseSize;
  }

  /// Get a height-based dimension
  double heightScaled(double heightPercentage) =>
      screenHeight * (heightPercentage / 100);

  /// Container width respecting max width for tablet
  double get constrainedWidth => isTablet ? 600 : double.infinity;

  /// Min height for scrollable content
  double get minScrollableHeight => screenHeight - heightPercent(15);
}
