import 'package:intl/intl.dart';

class PriceFormatter {
  PriceFormatter._();

  static final _numberFormat = NumberFormat('#,###');

  /// 만원 단위 → "6억 2,000만원"
  static String format(int manWon) {
    if (manWon >= 10000) {
      final eok = manWon ~/ 10000;
      final remainder = manWon % 10000;
      if (remainder == 0) return '$eok억';
      return '$eok억 ${_numberFormat.format(remainder)}만원';
    }
    return '${_numberFormat.format(manWon)}만원';
  }

  /// 만원 단위 → "6.2억"
  static String formatShort(int manWon) {
    if (manWon >= 10000) {
      final value = manWon / 10000;
      if (value == value.roundToDouble()) return '${value.toInt()}억';
      return '${value.toStringAsFixed(1)}억';
    }
    return '${_numberFormat.format(manWon)}만';
  }

  /// 숫자에 콤마
  static String comma(num value) => _numberFormat.format(value);
}
