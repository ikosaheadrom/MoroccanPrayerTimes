class HijriParser {
  static const Map<String, int> _monthData = {
    'محرم': 1,
    'صفر': 2,
    'ربيع الأول': 3, 'ربيع اول': 3,
    'ربيع الثاني': 4, 'ربيع الآخر': 4, 'ربيع ثاني': 4, 'ربيع آخر': 4,
    'جمادى الأول': 5, 'جمادى الأولى': 5, 'جمادى أول': 5,
    'جمادى الآخر': 6, 'جمادى الآخرة': 6, 'جمادى الثانية': 6, 'جمادى ثانية': 6, 'جمادى ثاني': 6,
    'رجب': 7,
    'شعبان': 8,
    'رمضان': 9,
    'شوال': 10,
    'ذو القعدة': 11, 'ذي القعدة': 11,
    'ذو الحجة': 12, 'ذي الحجة': 12,
  };

  static const List<String> _transliterations = [
    '', 'Muharram', 'Safar', 'Rabi\' al-Awwal', 'Rabi\' al-Thani',
    'Jumada al-Ula', 'Jumada al-Akhirah', 'Rajab', 'Sha\'ban',
    'Ramadan', 'Shawwal', 'Dhu al-Qa\'dah', 'Dhu al-Hijjah'
  ];

  /// Main parsing function with 2-character tolerance
  static int? getMonthNumber(String input) {
    String cleanInput = input.trim();
    
    // 1. Try exact match first (fastest)
    if (_monthData.containsKey(cleanInput)) {
      return _monthData[cleanInput];
    }

    // 2. Fuzzy match with 2-character tolerance
    String? bestMatch;
    int minDistance = 99;

    for (String key in _monthData.keys) {
      int distance = _levenshtein(cleanInput, key);
      if (distance <= 2 && distance < minDistance) {
        minDistance = distance;
        bestMatch = key;
      }
    }

    return bestMatch != null ? _monthData[bestMatch] : null;
  }

  static String getTransliteration(int monthNumber) {
    if (monthNumber < 1 || monthNumber > 12) return 'Unknown';
    return _transliterations[monthNumber];
  }

  /// Levenshtein Algorithm to calculate edit distance
  static int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.generate(t.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        int cost = (s[i] == t[j]) ? 0 : 1;
        v1[j + 1] = _min3(v1[j] + 1, v0[j + 1] + 1, v0[j] + cost);
      }
      for (int j = 0; j < v0.length; j++) { v0[j] = v1[j]; }
    }
    return v1[t.length];
  }

  static int _min3(int a, int b, int c) => a < b ? (a < c ? a : c) : (b < c ? b : c);
}