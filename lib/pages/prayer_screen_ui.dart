import 'package:flutter/material.dart';
import '../utils/responsive_sizes.dart';
import '../utils/app_colors_streamlined.dart';
import '../main.dart' show PrayerCalendarScreen, SettingsScreen;

/// Pure UI builders for the Prayer Times screen
/// All methods receive the state instance to access state variables
class PrayerScreenUI {
  final BuildContext context;
  final dynamic state; // State object from _PrayerTimeScreenState

  PrayerScreenUI({
    required this.context,
    required this.state,
  });

  /// Build the main scaffold with loading/error/content states
  Widget buildScaffold() {
    final colors = AppColorsStreamlined(context);
    
    if (state.isLoading) {
      return Scaffold(
        appBar: buildAppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (state.errorMessage != null) {
      return Scaffold(
        appBar: buildAppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: colors.error_txt),
                const SizedBox(height: 16),
                Text(state.errorMessage!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: state.loadTimes,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    // Get screen dimensions for responsive layout
    final responsive = ResponsiveSizes(context);
    
    return Scaffold(
      appBar: buildAppBar(),
      body: RefreshIndicator(
        onRefresh: state.loadTimes,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: responsive.paddingHorizontal,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: responsive.constrainedWidth,
                  minHeight: responsive.minScrollableHeight,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // Date display - aesthetic design
                    Padding(
                      padding: EdgeInsets.only(bottom: responsive.spacingS),
                      child: buildDateDisplay(responsive, colors),
                    ),
                    buildCountdownTimer(responsive, colors),
                    ...buildPrayerCards(responsive.cardSpacing, responsive, colors),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build the app bar with title and action buttons
  AppBar buildAppBar() {
    // Reload settings to get the latest useMinistry value when the AppBar is rebuilt
    state.loadSettings();
    
    final responsive = ResponsiveSizes(context);
    final colors = AppColorsStreamlined(context);
    
    return AppBar(
      backgroundColor: colors.header_bg,
      foregroundColor: colors.header_txt,
      title: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Prayer Times',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: responsive.titleSize,
              color: colors.header_txt,
            ),
          ),
          Text(
            state.latinizeCity(state.currentCity),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w400,
              fontSize: responsive.bodySize,
              color: colors.header_txt,
            ),
          ),
        ],
      ),
      elevation: 4,
      actions: [
        IconButton(
          icon: const Icon(Icons.calendar_today),
          tooltip: 'Calendar',
            onPressed: state.useMinistry ? () async {
              // Ensure calendar cache is populated before opening calendar screen
              await state.maybeRefreshCalendar();
              if (state.mounted) {
                // ignore: use_build_context_synchronously
                await Navigator.of(context).push(MaterialPageRoute(builder: (context) => PrayerCalendarScreen(apiService: state.apiService)));
              }
            } : null,
        ),
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () async {
            final changed = await Navigator.of(context)
                .push(MaterialPageRoute(builder: (context) => const SettingsScreen()));
            // Refresh only if settings changed
            if (changed == true) {
              await state.loadSettings();
              await state.loadTimes();
            }
          },
        )
      ],
    );
  }

  /// Build aesthetic date display with day-of-week emphasized on the right
  Widget buildDateDisplay(ResponsiveSizes responsive, AppColorsStreamlined colors) {
    final now = DateTime.now();
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['January', 'February', 'March', 'April', 'May', 'June',
                    'July', 'August', 'September', 'October', 'November', 'December'];
    
    final dayName = weekdays[now.weekday - 1];
    final monthName = months[now.month - 1];
    final dateStr = '${now.day} $monthName ${now.year}';
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.horizontalPadding,
        vertical: responsive.verticalPadding,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: day of week (Parent rank - bold)
          Text(
            dayName,
            style: TextStyle(
              fontSize: responsive.headingSize,
              fontWeight: FontWeight.w400,
              color: colors.surface_txt,
              letterSpacing: 0.3,
            ),
          ),
          // Right: date (Hint rank - secondary)
          Text(
            dateStr,
            style: TextStyle(
              fontSize: responsive.bodySize,
              fontWeight: FontWeight.normal,
              color: colors.surface_txt,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Build countdown timer display
  Widget buildCountdownTimer(ResponsiveSizes responsive, AppColorsStreamlined colors) {
    return Container(
      margin: EdgeInsets.only(
        top: responsive.spacingS,
        bottom: responsive.spacingM,
      ),
      padding: EdgeInsets.all(responsive.spacingM),
      decoration: BoxDecoration(
        color: colors.primarycontainer_bg,
        borderRadius: BorderRadius.circular(responsive.borderRadiusStandard),
        border: Border.all(
          color: colors.primarycontainer_txt,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // Parent rank title
          Text(
            'Countdown to ${state.nextPrayerName}',
            style: TextStyle(
              fontSize: responsive.titleSize,
              fontWeight: FontWeight.w600,
              color: colors.primarycontainer_subtxt,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: responsive.spacingM),
          // Child rank: Timer display
          Container(
            padding: EdgeInsets.symmetric(
              vertical: responsive.spacingS,
              horizontal: responsive.spacingM,
            ),
            child: SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Text(
                  state.countdownDisplay,
                  style: TextStyle(
                    fontSize: responsive.timerSize,
                    fontWeight: FontWeight.w900,
                    color: colors.primarycontainer_txt,
                    fontFamily: 'monospace',
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          SizedBox(height: responsive.spacingS),
          // Hint rank: Prayer time
          if (state.nextPrayerTime != null)
            Text(
              'Time: ${TimeOfDay.fromDateTime(state.nextPrayerTime!).format(context)}',
              style: TextStyle(
                fontSize: responsive.bodySize,
                color: colors.primarycontainer_subtxt,
                fontWeight: FontWeight.normal,
              ),
            ),
        ],
      ),
    );
  }

  /// Build list of prayer time cards
  List<Widget> buildPrayerCards(double spacing, ResponsiveSizes responsive, AppColorsStreamlined colors) {
    // Extract prayer name, but don't highlight if it's "Fajr (Tomorrow)"
    String next = '';
    if (!state.nextPrayerName.contains('Tomorrow')) {
      next = state.nextPrayerName.split(RegExp(r'\s|\(')).first;
    }
    
    return [
      buildPrayerTimeCard('Fajr', state.todayTimes?.fajr, spacing, responsive.prayerNameSize, responsive.prayerTimeSize, isNext: next == 'Fajr', colors: colors),
      SizedBox(height: spacing / 2),
      buildPrayerTimeCard('Sunrise', state.todayTimes?.sunrise, spacing, responsive.prayerNameSize, responsive.prayerTimeSize, isNext: next == 'Sunrise', colors: colors),
      SizedBox(height: spacing / 2),
      buildPrayerTimeCard('Dhuhr', state.todayTimes?.dhuhr, spacing, responsive.prayerNameSize, responsive.prayerTimeSize, isNext: next == 'Dhuhr', colors: colors),
      SizedBox(height: spacing / 2),
      buildPrayerTimeCard('Asr', state.todayTimes?.asr, spacing, responsive.prayerNameSize, responsive.prayerTimeSize, isNext: next == 'Asr', colors: colors),
      SizedBox(height: spacing / 2),
      buildPrayerTimeCard('Maghrib', state.todayTimes?.maghrib, spacing, responsive.prayerNameSize, responsive.prayerTimeSize, isNext: next == 'Maghrib', colors: colors),
      SizedBox(height: spacing / 2),
      buildPrayerTimeCard('Isha', state.todayTimes?.isha, spacing, responsive.prayerNameSize, responsive.prayerTimeSize, isNext: next == 'Isha', colors: colors),
    ];
  }

  /// Build individual prayer time card
  Widget buildPrayerTimeCard(
    String prayerName,
    String? time,
    double spacing,
    double nameSize,
    double timeSize, {
    bool isNext = false,
    required AppColorsStreamlined colors,
  }) {
    final responsive = ResponsiveSizes(context);
    
    return Container(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.symmetric(
        vertical: responsive.spacingS,
        horizontal: responsive.spacingM,
      ),
      decoration: BoxDecoration(
        color: isNext
            ? colors.HLsecondarycontainer_bg
            : colors.secondarycontainer_bg,
        borderRadius: BorderRadius.circular(responsive.borderRadiusStandard),
        border: Border.all(
          color: isNext
              ? colors.HLsecondarycontainer_txt
              : colors.border,
          width: isNext ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                if (isNext) ...[Icon(Icons.play_arrow, color: colors.HLsecondarycontainer_txt, size: nameSize * 0.9), SizedBox(width: responsive.spacingS)],
                Expanded(
                  child: Text(
                    prayerName,
                    style: TextStyle(
                      fontSize: nameSize,
                      fontWeight: isNext ? FontWeight.w700 : FontWeight.w600,
                      color: isNext ? colors.HLsecondarycontainer_txt : colors.secondarycontainer_txt,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            time ?? 'N/A',
            style: TextStyle(
              fontSize: timeSize,
              fontWeight: FontWeight.bold,
              color: isNext ? colors.HLsecondarycontainer_txt : colors.secondarycontainer_txt,
            ),
          ),
        ],
      ),
    );
  }
}
