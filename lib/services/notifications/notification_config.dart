// Notification state and sound type enums

/// Notification state for prayer and reminder notifications
enum NotificationState {
  off(-1, 'Off'),            // Disabled for this prayer/reminder
  silent(0, 'Silent'),       // No vibration, no sound
  vibrate(1, 'Vibration'),   // Vibration only, no sound
  full(2, 'Full');           // Vibration + Sound

  final int value;
  final String label;
  const NotificationState(this.value, this.label);

  static NotificationState fromValue(int v) {
    return NotificationState.values.firstWhere(
      (e) => e.value == v,
      orElse: () => NotificationState.full, // default to full
    );
  }
}

/// Athan sound type enum for prayer notifications
enum AthanSoundType {
  system(0, 'System', 'Uses standard notification system sound'),
  shortAthan(1, 'Short Athan', 'Play 4-second athan (no dismiss button)'),
  fullAthan(2, 'Full Athan', 'Play full athan with dismiss button');

  final int value;
  final String label;
  final String description;
  const AthanSoundType(this.value, this.label, this.description);

  static AthanSoundType fromValue(int v) {
    return AthanSoundType.values.firstWhere(
      (e) => e.value == v,
      orElse: () => AthanSoundType.system, // default to system
    );
  }
}

/// Helper function to get the appropriate prayer channel ID based on notification state and athan type
/// When state is "Full", the athan sound type determines which channel to use
/// When state is "Silent" or "Vibrate", regular channels are used
String getPrayerChannelId(NotificationState state, {AthanSoundType athanType = AthanSoundType.system}) {
  switch (state) {
    case NotificationState.off:
      return 'pray_times_channel_silent'; // Default fallback (won't be used if disabled)
    case NotificationState.silent:
      return 'pray_times_channel_silent';
    case NotificationState.vibrate:
      return 'pray_times_channel_vibrate';
    case NotificationState.full:
      // When in full mode, choose sound based on athan type preference
      switch (athanType) {
        case AthanSoundType.system:
          return 'pray_times_channel_full_v2'; // Use regular full notification channel with system sound
        case AthanSoundType.shortAthan:
          return 'athan_channel_short_v2'; // Use 4-second athan channel
        case AthanSoundType.fullAthan:
          return 'athan_channel_normal_v2'; // Use full athan channel with dismiss button
      }
  }
}

/// Helper function to get the appropriate reminder channel ID based on notification state
String getReminderChannelId(NotificationState state) {
  switch (state) {
    case NotificationState.off:
      return 'prayer_warnings_channel_silent'; // Default fallback (won't be used if disabled)
    case NotificationState.silent:
      return 'prayer_warnings_channel_silent';
    case NotificationState.vibrate:
      return 'prayer_warnings_channel_vibrate';
    case NotificationState.full:
      return 'prayer_warnings_channel_full';
  }
}

/// Notification channel configuration
class NotificationChannelConfig {
  static const String prayerChannelSilent = 'pray_times_channel_silent';
  static const String prayerChannelVibrate = 'pray_times_channel_vibrate';
  static const String prayerChannelFull = 'pray_times_channel_full_v2';
  static const String athanChannelShort = 'athan_channel_short_v2';
  static const String athanChannelNormal = 'athan_channel_normal_v2';
  static const String reminderChannelSilent = 'prayer_warnings_channel_silent';
  static const String reminderChannelVibrate = 'prayer_warnings_channel_vibrate';
  static const String reminderChannelFull = 'prayer_warnings_channel_full';
}

/// Prayer name constants
class PrayerNames {
  static const String fajr = 'Fajr';
  static const String sunrise = 'Sunrise';
  static const String dhuhr = 'Dhuhr';
  static const String asr = 'Asr';
  static const String maghrib = 'Maghrib';
  static const String isha = 'Isha';

  static const List<String> allPrayers = [fajr, sunrise, dhuhr, asr, maghrib, isha];
}
