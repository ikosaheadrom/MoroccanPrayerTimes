/// Translation and Transliteration Service
/// 
/// Provides translation maps and functions for converting Arabic text to English
/// and other transliteration operations used throughout the app.
library;

// ═══════════════════════════════════════════════════════════════════════════════
// ARABIC TO ENGLISH TRANSLATION MAPS
// ═══════════════════════════════════════════════════════════════════════════════

/// Map Arabic weekday names to English equivalents
const Map<String, String> arabicWeekdayToEnglish = {
  'الأحد': 'Sunday',
  'الإثنين': 'Monday',
  'الثلاثاء': 'Tuesday',
  'الأربعاء': 'Wednesday',
  'الخميس': 'Thursday',
  'الجمعة': 'Friday',
  'السبت': 'Saturday',
};

/// Map Arabic Gregorian month names to English equivalents
/// Includes multiple transliterations for the same month
const Map<String, String> arabicSolarMonthToEnglish = {
  'يناير': 'January',
  'فبراير': 'February',
  'مارس': 'March',
  'أبريل': 'April',
  'ماي': 'May',
  'ماى': 'May',
  'يونيو': 'June',
  'يوليوز': 'July',
  'يوليو': 'July',
  'غشت': 'August',
  'أغسطس': 'August',
  'شتنبر': 'September',
  'سبتمبر': 'September',
  'أكتوبر': 'October',
  'نونبر': 'November',
  'نوفمبر': 'November',
  'دجنبر': 'December',
  'ديسمبر': 'December',
};

/// Map Arabic Hijri month names to English/Latin transliterations
const Map<String, String> arabicHijriMonthToLatin = {
  'محرم': 'Muharram',
  'صفر': 'Safar',
  'ربيع الأول': 'Rabi\' al-Awwal',
  'ربيع الثاني': 'Rabi\' al-Thani',
  'جمادى الأولى': 'Jumada al-Awwal',
  'جمادى الآخرة': 'Jumada al-Akhirah',
  'رجب': 'Rajab',
  'شعبان': 'Sha\'ban',
  'رمضان': 'Ramadan',
  'شوال': 'Shawwal',
  'ذو القعدة': 'Dhu al-Qi\'dah',
  'ذو الحجة': 'Dhu al-Hijjah',
};

// ═══════════════════════════════════════════════════════════════════════════════
// TRANSLATION HELPER FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Translate an Arabic weekday name to English
/// Returns the input string if no translation is found
String translateWeekday(String arabicWeekday) {
  if (arabicWeekday.isEmpty) return '';
  return arabicWeekdayToEnglish[arabicWeekday.trim()] ?? arabicWeekday;
}

/// Translate an Arabic Gregorian month name to English
/// Handles multi-month labels like "نوفمبر / ديسمبر" by translating each part
String translateSolarMonth(String arabicMonth) {
  if (arabicMonth.isEmpty) return '';
  
  // Handle multi-month labels like "نوفمبر / ديسمبر"
  final parts = arabicMonth.split(RegExp(r'[/,؛]+')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  final translated = parts.map((p) => arabicSolarMonthToEnglish[p] ?? p).toList();
  return translated.join(' / ');
}

/// Transliterate an Arabic Hijri month name to Latin script
/// Returns the input string if no transliteration is found
String transliterateHijriMonth(String arabicMonth) {
  if (arabicMonth.isEmpty) return '';
  return arabicHijriMonthToLatin[arabicMonth.trim()] ?? arabicMonth;
}

/// Convert a month number (1-12) to English month name
String monthNumberToEnglish(int month) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  if (month < 1 || month > 12) return '';
  return months[month - 1];
}

/// Convert English month name to month number (1-12)
int englishMonthToNumber(String monthName) {
  const months = {
    'January': 1, 'February': 2, 'March': 3, 'April': 4,
    'May': 5, 'June': 6, 'July': 7, 'August': 8,
    'September': 9, 'October': 10, 'November': 11, 'December': 12,
  };
  return months[monthName] ?? 0;
}
