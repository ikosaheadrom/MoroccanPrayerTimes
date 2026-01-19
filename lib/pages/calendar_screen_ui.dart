import 'package:flutter/material.dart';
import '../utils/responsive_sizes.dart';
import '../utils/app_colors_streamlined.dart';
import '../services/translation_transliteration.dart';

/// Pure UI builders for the Prayer Calendar screen
class CalendarScreenUI {
  final BuildContext context;
  final dynamic state; // State object from _PrayerCalendarScreenState

  CalendarScreenUI({
    required this.context,
    required this.state,
  });

  /// Build the main scaffold
  Widget buildScaffold(
    FutureBuilder<Map<String, dynamic>> futureBuilder,
    AppColorsStreamlined colors,
    VoidCallback onRefresh,
  ) {
    return Scaffold(
      appBar: buildAppBar(colors, onRefresh),
      body: futureBuilder,
    );
  }

  /// Build the app bar with title and refresh button
  AppBar buildAppBar(AppColorsStreamlined colors, VoidCallback onRefresh) {
    return AppBar(
      backgroundColor: colors.header_bg,
      foregroundColor: colors.header_txt,
      title: const Text('Prayer Calendar'),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: onRefresh,
        ),
      ],
    );
  }

  /// Build a day card showing prayer times for that day
  Widget buildDayCard(
    int hijriDayNum,
    String hijriDayDisplay,
    Map dayData,
    String cacheKeyIso,
    AppColorsStreamlined colors,
  ) {
    final isCurrentDay = (hijriDayNum > 0 && state.todayHijriDay == hijriDayNum);
    final responsive = ResponsiveSizes(context);

    final dayOfWeek = state.translateWeekday(dayData['DayOfWeek']?.toString() ?? '');
    // Use cache key as ISO date (format: 2025-11-22T00:00:00.000, we want the date part)
    final gregorianDateIso = cacheKeyIso.split('T')[0]; // Extract 2025-11-22 from 2025-11-22T00:00:00.000
    final hijriMonthArabic = dayData['HijriMonth']?.toString() ?? '';
    final hijriMonthLatin = hijriMonthArabic.isNotEmpty
        ? transliterateHijriMonth(hijriMonthArabic)
        : '';

    // Parse ISO date to get day and month
    String formattedDate = '—';
    String formattedMonth = '—';
    if (gregorianDateIso.isNotEmpty) {
      try {
        final parts = gregorianDateIso.split('-');
        if (parts.length == 3) {
          formattedDate = parts[2]; // Day
          formattedMonth = state.monthNumberToName(int.parse(parts[1])); // Month name
        }
      } catch (e) {
        debugPrint('Error parsing ISO date: $e');
      }
    }

    final fajr = dayData['Fajr']?.toString() ?? '—';
    final sunrise = dayData['Sunrise']?.toString() ?? '—';
    final dhuhr = dayData['Dhuhr']?.toString() ?? '—';
    final asr = dayData['Asr']?.toString() ?? '—';
    final maghrib = dayData['Maghrib']?.toString() ?? '—';
    final isha = dayData['Isha']?.toString() ?? '—';

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: responsive.horizontalPadding,
        vertical: responsive.verticalPadding,
      ),
      padding: EdgeInsets.all(responsive.spacingM),
      decoration: BoxDecoration(
        color: isCurrentDay ? colors.HLcontainer_bg : colors.primarycontainer_bg,
        border: Border.all(
          color: isCurrentDay ? colors.HLcontainer_bg : colors.border,
          width: isCurrentDay ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(responsive.borderRadiusStandard),
      ),
      child: Column(
        children: [
          // Header: Hijri left, Gregorian right, Weekday between
          Row(
            children: [
              // Left: Hijri day + month
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hijriDayDisplay,
                      style: TextStyle(
                        fontSize: hijriDayDisplay == '☽'
                            ? responsive.hijriDaySize * 1.1
                            : responsive.hijriDaySize,
                        fontWeight: FontWeight.bold,
                        color: isCurrentDay
                            ? colors.HLcontainer_txt
                            : colors.primarycontainer_txt,
                        height: 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 4.0),
                      child: Text(
                        hijriMonthLatin.isEmpty
                            ? '—'
                            : hijriMonthLatin.split(' ')[0],
                        style: TextStyle(
                          fontSize: responsive.hijriMonthSize,
                          fontWeight: FontWeight.w600,
                          color: isCurrentDay
                              ? colors.HLcontainer_subtxt
                              : colors.primarycontainer_subtxt,
                          height: 1.1,
                        ),
                      ),
                    )
                  ],
                ),
              ),
              // Center: Weekday
              Expanded(
                child: Text(
                  dayOfWeek.isEmpty ? '—' : dayOfWeek,
                  style: TextStyle(
                    fontSize: responsive.weekdaySize,
                    fontWeight: FontWeight.w600,
                    color: isCurrentDay
                        ? colors.HLcontainer_txt
                        : colors.primarycontainer_txt,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              // Right: Gregorian day + month
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: responsive.gregorianDaySize,
                        fontWeight: FontWeight.bold,
                        color: isCurrentDay
                            ? colors.HLcontainer_txt
                            : colors.primarycontainer_txt,
                        height: 1,
                      ),
                    ),
                    Text(
                      formattedMonth,
                      style: TextStyle(
                        fontSize: responsive.gregorianMonthSize,
                        fontWeight: FontWeight.w600,
                        color: isCurrentDay
                            ? colors.HLcontainer_subtxt
                            : colors.primarycontainer_subtxt,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: responsive.spacingM),
          // Prayer times grid (3 columns x 2 rows)
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.6,
            mainAxisSpacing: responsive.cardSpacing,
            crossAxisSpacing: responsive.cardSpacing,
            children: [
              buildPrayerTimeCell('Fajr', fajr, colors, ResponsiveSizes(context), isCurrentDay),
              buildPrayerTimeCell('Sunrise', sunrise, colors, ResponsiveSizes(context), isCurrentDay),
              buildPrayerTimeCell('Dhuhr', dhuhr, colors, ResponsiveSizes(context), isCurrentDay),
              buildPrayerTimeCell('Asr', asr, colors, ResponsiveSizes(context), isCurrentDay),
              buildPrayerTimeCell('Maghrib', maghrib, colors, ResponsiveSizes(context), isCurrentDay),
              buildPrayerTimeCell('Isha', isha, colors, ResponsiveSizes(context), isCurrentDay),
            ],
          ),
        ],
      ),
    );
  }

  /// Build a single prayer time cell
  Widget buildPrayerTimeCell(
    String name,
    String time,
    AppColorsStreamlined colors,
    ResponsiveSizes responsive,
    bool isCurrentDay,
  ) {
    return Container(
      padding: EdgeInsets.all(responsive.spacingXS),
      decoration: BoxDecoration(
        color: isCurrentDay ? colors.HLsecondarycontainer_bg : colors.secondarycontainer_bg,
        borderRadius: BorderRadius.circular(responsive.borderRadiusSmall),
        border: Border.all(
          color: isCurrentDay ? colors.HLsecondarycontainer_bg : colors.border,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: responsive.cellNameSize,
              fontWeight: FontWeight.w600,
              color: isCurrentDay ? colors.HLsecondarycontainer_subtxt : colors.secondarycontainer_subtxt,
            ),
          ),
          SizedBox(height: responsive.spacingXS),
          Text(
            time,
            style: TextStyle(
              fontSize: responsive.cellTimeSize,
              fontWeight: FontWeight.bold,
              color: isCurrentDay ? colors.HLsecondarycontainer_txt : colors.secondarycontainer_txt,
            ),
          ),
        ],
      ),
    );
  }
}
