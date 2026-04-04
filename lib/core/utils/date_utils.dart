class AppDateUtils {
  AppDateUtils._();

  /// D-day 계산
  static int dDay(DateTime target) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(target.year, target.month, target.day);
    return targetDate.difference(today).inDays;
  }

  /// "2026-03" 형태로 현재 년월
  static String currentYearMonth() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}';
  }

  /// "2026년 3월" 형태
  static String formatKorean(DateTime date) {
    return '${date.year}년 ${date.month}월';
  }
}
