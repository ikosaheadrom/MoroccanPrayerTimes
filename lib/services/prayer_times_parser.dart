import 'package:flutter/foundation.dart';

/// Prayer times parser service
/// 
/// This service handles all HTML parsing and data extraction for Islamic prayer times.
/// It converts Ministry website HTML into structured prayer time data and provides
/// helper functions to extract specific information.

/// Sanitize HTML content to prevent malicious code injection
/// Removes all HTML tags and dangerous characters
String _sanitizeHtmlContent(String content) {
  // Remove all HTML tags
  var sanitized = content.replaceAll(RegExp(r'<[^>]+>'), '');
  
  // Decode common HTML entities
  sanitized = sanitized
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&nbsp', ' ')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'");
  
  // Remove any script-like patterns or dangerous characters
  sanitized = sanitized.replaceAll(RegExp(r'javascript:', caseSensitive: false), '');
  sanitized = sanitized.replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '');
  
  // Remove control characters and null bytes
  sanitized = sanitized.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');
  
  return sanitized.trim();
}

/// Represents a single day's prayer times
/// 
/// Format:
/// {
///   'hijriDay': '1',                              // Hijri day number (1-30)
///   'gregorianDate_ISO': '2025-12-01',          // ISO 8601 date format (YYYY-MM-DD)
///   'dayOfWeek_TEXT': 'السبت',                   // Arabic day name
///   'fajr_HHmm': '06:37',                        // Time format (HH:MM 24-hour)
///   'sunrise_HHmm': '08:05',                     // Time format (HH:MM 24-hour)
///   'dhuhr_HHmm': '13:22',                       // Time format (HH:MM 24-hour)
///   'asr_HHmm': '16:05',                         // Time format (HH:MM 24-hour)
///   'maghrib_HHmm': '18:29',                     // Time format (HH:MM 24-hour)
///   'isha_HHmm': '19:46',                        // Time format (HH:MM 24-hour)
///   'solarMonth_TEXT': 'November',               // English month name (text)
///   'solarDay': '22',                            // Solar day number (1-31)
///   'hijriMonth_TEXT': 'جمادى الآخرة'          // Arabic Hijri month name (text)
/// }
typedef PrayerDay = Map<String, String>;

/// Represents the complete parsed calendar month
/// 
/// Format:
/// {
///   'cityId': 58,                                // City ID (for verification)
///   'hijriMonth': 'جمادى الآخرة',               // Arabic month name
///   'hijriMonthLatin': 'Jumada al-Akhirah',     // Latin transliteration
///   'solarMonths': ['November', 'December'],     // Months in Gregorian calendar
///   'totalDays': 30,                             // Number of days in this Hijri month
///   'firstDate_ISO': '2025-11-22',              // First day of calendar (ISO format)
///   'lastDate_ISO': '2025-12-21',               // Last day of calendar (ISO format)
///   'expiresAt_ISO': '2025-12-22',              // Expiration date = last day + 1 (ISO format)
///   'days': {
///     '1': { /* PrayerDay data */ },
///     '2': { /* PrayerDay data */ },
///     ...
///   }
/// }
typedef ParsedMonthlyCalendar = Map<String, dynamic>;

/// Parse Islamic calendar HTML from Ministry website
/// 
/// Input: HTML response from habous.gov.ma prayer times page
/// Input: cityId - The city ID used to fetch this HTML (for verification)
/// Output: ParsedCalendar with all prayer times and metadata including expiration date
/// 
/// Returns empty calendar if parsing fails
Future<ParsedMonthlyCalendar> parseMonthlyCalendarFromHtml(String html, {int cityId = 0}) async {
  try {
    // ═══════════════════════════════════════════════════════════════════════════════
    // 🔍 NEW PRAYER TIMES PARSER SERVICE - CHECKING FOR OLD REMNANT CODE
    // ═══════════════════════════════════════════════════════════════════════════════
    debugPrint('');
    debugPrint('╔═════════════════════════════════════════════════════════════════════╗');
    debugPrint('║     🔍 PRAYER TIMES PARSER - NEW SERVICE ACTIVE                     ║');
    debugPrint('║     ⚠️  IF YOU SEE MULTIPLE PARSERS RUNNING, THERE\'S OLD CODE!     ║');
    debugPrint('╚═════════════════════════════════════════════════════════════════════╝');
    debugPrint('');
    
    // Month info will be extracted from the table header row
    String monthLabel = '';
    List<String> solarMonths = [];

    // Parse prayer times table (which will extract month info from its header)
    final days = parseMonthlyHtmlTable(html, monthLabel, solarMonths);
    
    if (days.isEmpty) {
      debugPrint('[PrayerTimesParser] No prayer times parsed from HTML');
      return {};
    }

    // Extract Hijri month name
    String hijriMonth = '';
    String hijriMonthLatin = '';
    if (days.isNotEmpty) {
      final firstDay = days.values.first;
      hijriMonth = firstDay['hijriMonth_TEXT'] ?? monthLabel;
      hijriMonthLatin = _translateHijriMonth(hijriMonth);
    }

    // Calculate expiration date: find the last calendar date and add 1 day
    DateTime? firstDate;
    DateTime? lastDate;
    
    for (int i = 1; i <= days.length; i++) {
      final day = days[i.toString()];
      if (day != null) {
        final dateStr = day['gregorianDate_ISO'];
        if (dateStr != null && dateStr.isNotEmpty) {
          try {
            final date = DateTime.parse(dateStr);
            if (firstDate == null || date.isBefore(firstDate)) {
              firstDate = date;
            }
            if (lastDate == null || date.isAfter(lastDate)) {
              lastDate = date;
            }
          } catch (e) {
            // Skip invalid dates
          }
        }
      }
    }

    // Calculate expiration date (day after last day in calendar)
    DateTime? expiresAt;
    if (lastDate != null) {
      expiresAt = lastDate.add(const Duration(days: 1));
    }

    final result = {
      'cityId': cityId,
      'hijriMonth': hijriMonth,
      'hijriMonthLatin': hijriMonthLatin,
      'solarMonths': solarMonths,
      'totalDays': days.length,
      'days': days,
    };

    // Add date information if available
    if (firstDate != null) {
      result['firstDate_ISO'] = firstDate.toIso8601String().split('T')[0];
    }
    if (lastDate != null) {
      result['lastDate_ISO'] = lastDate.toIso8601String().split('T')[0];
    }
    if (expiresAt != null) {
      result['expiresAt_ISO'] = expiresAt.toIso8601String().split('T')[0];
      debugPrint('[PrayerTimesParser] Calendar expires at: ${result['expiresAt_ISO']}');
    }

    return result;
  } catch (e, st) {
    debugPrint('[PrayerTimesParser] Error parsing calendar: $e\n$st');
    return {};
  }
}

/// Extract today's prayer times from parsed calendar
/// 
/// Returns PrayerDay or null if today not found
PrayerDay? getTodayPrayerTimes(ParsedMonthlyCalendar calendar, {int? hijriDay}) {
  if (calendar.isEmpty || calendar['days'] == null) return null;

  final days = calendar['days'] as Map<String, dynamic>;
  
  // If hijri day provided, use it
  if (hijriDay != null) {
    return days[hijriDay.toString()] as PrayerDay?;
  }

  // Otherwise find today by matching Gregorian date
  final today = DateTime.now();
  final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
  
  for (final day in days.values) {
    if (day['gregorianDate_ISO'] == todayStr) {
      return day as PrayerDay;
    }
  }
  
  return null;
}

/// Extract tomorrow's prayer times from parsed calendar
PrayerDay? getTomorrowPrayerTimes(ParsedMonthlyCalendar calendar) {
  if (calendar.isEmpty || calendar['days'] == null) return null;

  final tomorrow = DateTime.now().add(const Duration(days: 1));
  final tomorrowStr = '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';
  
  final days = calendar['days'] as Map<String, dynamic>;
  for (final day in days.values) {
    if (day['gregorianDate_ISO'] == tomorrowStr) {
      return day as PrayerDay;
    }
  }
  
  return null;
}

/// Get number of days in parsed calendar
int getCalendarDayCount(ParsedMonthlyCalendar calendar) {
  return calendar['totalDays'] as int? ?? 0;
}

/// Get all Gregorian dates in calendar
/// 
/// Returns list of ISO date strings (YYYY-MM-DD) in order
List<String> getGregorianDates(ParsedMonthlyCalendar calendar) {
  if (calendar.isEmpty || calendar['days'] == null) return [];
  
  final days = calendar['days'] as Map<String, dynamic>;
  final dates = <String>[];
  
  for (int i = 1; i <= calendar['totalDays']; i++) {
    final day = days[i.toString()] as PrayerDay?;
    if (day != null && day['gregorianDate_ISO'] != null) {
      dates.add(day['gregorianDate_ISO']!);
    }
  }
  
  return dates;
}

/// Get prayer times for specific Hijri day (1-30)
PrayerDay? getPrayerTimesForHijriDay(ParsedMonthlyCalendar calendar, int hijriDay) {
  if (calendar.isEmpty || calendar['days'] == null) return null;
  final days = calendar['days'] as Map<String, dynamic>;
  return days[hijriDay.toString()] as PrayerDay?;
}

/// Get all prayer days as list
List<PrayerDay> getAllPrayerDays(ParsedMonthlyCalendar calendar) {
  if (calendar.isEmpty || calendar['days'] == null) return [];
  final days = calendar['days'] as Map<String, dynamic>;
  
  final result = <PrayerDay>[];
  for (int i = 1; i <= calendar['totalDays']; i++) {
    final day = days[i.toString()] as PrayerDay?;
    if (day != null) {
      result.add(day);
    }
  }
  return result;
}

// ============================================================================
// INTERNAL HELPER FUNCTIONS
// ============================================================================

/// Extract Gregorian months from Arabic month label
/// 
/// Input: "جمادى الآخرة نوفمبر / ديسمبر"
/// Output: ["November", "December"]
List<String> _extractSolarMonths(String monthLabel) {
  final solarMonths = <String>[];
  const arabicToEnglish = {
    'يناير': 'January', 'فبراير': 'February', 'مارس': 'March',
    'أبريل': 'April', 'مايو': 'May', 'يونيو': 'June',
    'يوليو': 'July', 'أغسطس': 'August', 'سبتمبر': 'September',
    'أكتوبر': 'October', 'نوفمبر': 'November', 'ديسمبر': 'December',
  };

  if (monthLabel.isNotEmpty) {
    final found = <MapEntry<int, String>>[];
    arabicToEnglish.forEach((arabic, english) {
      final idx = monthLabel.indexOf(arabic);
      if (idx >= 0) found.add(MapEntry(idx, english));
    });
    found.sort((a, b) => a.key.compareTo(b.key));
    solarMonths.addAll(found.map((e) => e.value));
  }

  return solarMonths;
}

/// Parse HTML table into prayer day entries
/// Table structure:
///   Row 0: Header row with months in cells [1] and [2]
///     - Cell[0]: "الأيام" (Days)
///     - Cell[1]: Hijri month (e.g., "جمادى الآخرة")
///     - Cell[2]: Solar months (e.g., "نوفمبر / ديسمبر")
///     - Cells[3-8]: Prayer time headers
///   Rows 1-30: Data rows with:
///     - Cell[0]: Day of week
///     - Cell[1]: Hijri day number (or "حسب نتيجة المراقبة" for day 30)
///     - Cell[2]: Solar day number
///     - Cells[3-8]: Prayer times
/// Parse HTML table to extract monthly prayer times for each day
/// Returns a map of day number -> prayer day data
Map<String, PrayerDay> parseMonthlyHtmlTable(String html, String monthLabel, List<String> solarMonths) {
  final result = <String, PrayerDay>{};

  // Find the main prayer times table
  final tableRx = RegExp('<table[^>]*id=(["\\\']?)horaire\\1[^>]*>([\\s\\S]*?)</table>', caseSensitive: false);
  final tableMatch = tableRx.firstMatch(html);
  if (tableMatch == null) {
    debugPrint('[PrayerTimesParser] Could not find prayer times table');
    return result;
  }

  final tableContent = tableMatch.group(2)!;

  // Extract table rows
  final trRx = RegExp('<tr[^>]*>([\\s\\S]*?)</tr>', caseSensitive: false);
  final tdRx = RegExp('<td[^>]*>([\\s\\S]*?)</td>', caseSensitive: false);

  final allMatches = trRx.allMatches(tableContent).toList();
  
  // Process header row (index 0) to extract month info
  if (allMatches.isNotEmpty) {
    final headerRowContent = allMatches[0].group(1)!;
    final headerCells = tdRx
        .allMatches(headerRowContent)
        .map((m) => _sanitizeHtmlContent(m.group(1)!))
        .toList();

    // Extract Hijri month from header cell[1]
    if (headerCells.length > 1 && monthLabel.isEmpty) {
      monthLabel = headerCells[1];
      debugPrint('[PrayerTimesParser] Extracted Hijri month from header: $monthLabel');
    }

    // Extract solar months from header cell[2]
    if (headerCells.length > 2 && solarMonths.isEmpty) {
      final solarMonthStr = headerCells[2]; // e.g., "نوفمبر / ديسمبر"
      solarMonths = _extractSolarMonths(solarMonthStr);
      debugPrint('[PrayerTimesParser] Extracted solar months from header: ${solarMonths.join(", ")}');
    }
  }

  // Process data rows (indices 1-30)
  int? previousSolarNum; // Track previous solar day to detect month transition
  int? monthTransitionDay; // Day when we transition to second month
  int maxHijriDay = 0; // Track the highest hijri day number for moon observation detection
  
  for (int rowIdx = 1; rowIdx < allMatches.length; rowIdx++) {
    final rowContent = allMatches[rowIdx].group(1)!;
    final cells = tdRx
        .allMatches(rowContent)
        .map((m) => _sanitizeHtmlContent(m.group(1)!))
        .toList();

    if (cells.length < 9) continue;

    // Cell structure: [dayOfWeek, hijriDay, solarDay, fajr, sunrise, dhuhr, asr, maghrib, isha]
    final hijriStr = cells[1].trim();
    final solarStr = cells[2].trim();

    // Extract numeric day values
    int? hijriNum = int.tryParse(hijriStr.replaceAll(RegExp('[^0-9]'), ''));
    int? solarNum = int.tryParse(solarStr.replaceAll(RegExp('[^0-9]'), ''));

    // If no hijri number found, this is the last day (moon observation day) - assign it the next number
    if (hijriNum == null) {
      debugPrint('[PrayerTimesParser] Last day (moon observation - "حسب نتيجة المراقبة") detected after day $maxHijriDay');
      hijriNum = maxHijriDay + 1; // Use max+1 instead of hardcoding 30
    } else {
      // Track the maximum hijri day we've seen
      maxHijriDay = hijriNum;
    }

    // Solar day should always be present, but provide fallback
    if (solarNum == null || solarNum == 0) {
      // Try to infer from position or use a default
      solarNum = 21; // Fallback for parsing errors
    }

    // DETECT MONTH TRANSITION: When solar day drops significantly from previous
    // This indicates we've moved to the next month
    if (previousSolarNum != null && monthTransitionDay == null) {
      // If previous solar was high (>20) and current is low (<=10), we transitioned months
      if (previousSolarNum > 20 && solarNum <= 10) {
        monthTransitionDay = hijriNum;
        debugPrint('[PrayerTimesParser] Month transition detected at Hijri day $hijriNum (solar: $previousSolarNum → $solarNum)');
      }
    }
    previousSolarNum = solarNum;

    // Determine which solar month this day belongs to
    String currentSolarMonth = '';
    if (solarMonths.isNotEmpty) {
      if (solarMonths.length == 1) {
        currentSolarMonth = solarMonths[0];
      } else if (solarMonths.length > 1) {
        // Use month transition detection if available
        if (monthTransitionDay != null && hijriNum >= monthTransitionDay) {
          currentSolarMonth = solarMonths[1];
        } else {
          currentSolarMonth = solarMonths[0];
        }
      }
    }

    // Build Gregorian date (ISO format) from solar day and month
    String gregorianDateIso = '';
    if (currentSolarMonth.isNotEmpty && solarNum > 0) {
      final month = _monthNameToNumber(currentSolarMonth);
      if (month > 0) {
        try {
          // Determine the correct year based on month context
          final targetYear = _determineTargetYear(month, solarMonths);
          DateTime date = DateTime(targetYear, month, solarNum);
          
          gregorianDateIso = date.toIso8601String().split('T')[0];
        } catch (e) {
          debugPrint('[PrayerTimesParser] Error building date for day $hijriNum ($currentSolarMonth/$solarNum): $e');
        }
      }
    }

    result[hijriNum.toString()] = {
      'hijriDay': hijriNum > maxHijriDay ? '☽' : hijriNum.toString(),
      'gregorianDate_ISO': gregorianDateIso,
      'dayOfWeek_TEXT': cells[0].trim(),
      'fajr_HHmm': cells[3].trim(),
      'sunrise_HHmm': cells[4].trim(),
      'dhuhr_HHmm': cells[5].trim(),
      'asr_HHmm': cells[6].trim(),
      'maghrib_HHmm': cells[7].trim(),
      'isha_HHmm': cells.length > 8 ? cells[8].trim() : 'N/A',
      'solarMonth_TEXT': currentSolarMonth,
      'solarDay': solarNum.toString(),
      'hijriMonth_TEXT': monthLabel,
    };
  }

  debugPrint('[PrayerTimesParser] Parsed ${result.length} days from HTML table');
  debugPrint('[PrayerTimesParser] Hijri month: $monthLabel');
  debugPrint('[PrayerTimesParser] Solar months: ${solarMonths.join(", ")}');
  return result;
}

/// Determines the correct year for a solar date based on the months present in the calendar header
/// 
/// **Logic:**
/// - If both December and January are in header: Use context to determine which is current
///   - If today is in January, January = current year, December = previous year
///   - If today is in December, December = current year, January = next year
/// - If only one month: compare with today's month to determine if it's current or next year
/// 
/// This handles the Islamic calendar which spans solar year boundaries
int _determineTargetYear(int month, List<String> solarMonths) {
  final today = DateTime.now();
  
  if (solarMonths.isEmpty) {
    return today.year;
  }
  
  // Convert month names to numbers for comparison
  final monthNumbers = solarMonths
      .map((m) => _monthNameToNumber(m))
      .where((n) => n > 0)
      .toList();
  
  if (monthNumbers.isEmpty) {
    return today.year;
  }
  
  // **Case 1: Calendar spans two months**
  if (monthNumbers.length > 1) {
    final hasDecember = monthNumbers.contains(12);
    final hasJanuary = monthNumbers.contains(1);
    
    // December/January transition (year boundary)
    if (hasDecember && hasJanuary) {
      // Determine which year based on current date context
      // If today is in January, January = current year, December = previous year
      // If today is in December, December = current year, January = next year
      if (today.month == 1) {
        // We're in January now
        return month == 1 ? today.year : today.year - 1; // January is current, December is previous
      } else if (today.month == 12) {
        // We're in December now
        return month == 12 ? today.year : today.year + 1; // December is current, January is next
      } else {
        // We're in some other month, use the older logic
        return month == 12 ? today.year : today.year + 1;
      }
    }
    
    // For other month combinations, assume they're in the same year
    // Use the earlier month to determine the year
    final minMonth = monthNumbers.reduce((a, b) => a < b ? a : b);
    if (minMonth < today.month) {
      // This set of months already happened this year or will next year
      // Use the fact that it's a 30-day Hijri month aligned to a specific solar period
      return today.year;
    }
  }
  
  // **Case 2: Single month calendar**
  if (monthNumbers.length == 1) {
    final calendarMonth = monthNumbers[0];
    
    // If calendar month is earlier in the year than today, it likely belongs to next year
    if (calendarMonth < today.month) {
      return today.year + 1;
    }
    
    // If calendar month is later than or equal to today, use current year
    return today.year;
  }
  
  return today.year;
}

/// Convert month name (e.g., "November") to month number (1-12)
int _monthNameToNumber(String monthName) {
  const monthNames = {
    'January': 1, 'February': 2, 'March': 3, 'April': 4,
    'May': 5, 'June': 6, 'July': 7, 'August': 8,
    'September': 9, 'October': 10, 'November': 11, 'December': 12,
  };
  return monthNames[monthName] ?? 0;
}

/// Translate Hijri month name to Latin transliteration
String _translateHijriMonth(String arabicMonth) {
  const hijriArabicToLatin = {
    'محرم': 'Muharram',
    'صفر': 'Safar',
    'ربيع الأول': "Rabi' al-Awwal",
    'ربيع الآخر': "Rabi' al-Akhir",
    'ربيع الثاني': "Rabi' al-Thani",
    'جمادى الأولى': 'Jumada al-Ula',
    'جمادى الأول': 'Jumada al-Ula',
    'جمادى الآخرة': 'Jumada al-Akhirah',
    'جمادى الاخرة': 'Jumada al-Akhirah',
    'رجب': 'Rajab',
    'شعبان': "Sha'ban",
    'رمضان': 'Ramadan',
    'شوال': 'Shawwal',
    'ذو القعدة': "Dhu al-Qa'dah",
    'ذو الحجة': 'Dhu al-Hijjah',
  };

  for (final entry in hijriArabicToLatin.entries) {
    if (arabicMonth.contains(entry.key)) {
      return entry.value;
    }
  }

  return arabicMonth; // Return original if no match
}
