import '../core/constants/app_constants.dart';

const _sqmToPyeong = AppConstants.sqmToPyeong;

/// 아파트 매매 실거래 데이터
class ApartmentTrade {
  final String aptName;       // 아파트명
  final int dealAmount;       // 거래금액 (만원)
  final double area;          // 전용면적 (㎡)
  final int floor;            // 층
  final int dealYear;         // 거래년도
  final int dealMonth;        // 거래월
  final int dealDay;          // 거래일
  final String dong;          // 법정동
  final String jibun;         // 지번
  final String regionCode;    // 지역코드

  ApartmentTrade({
    required this.aptName,
    required this.dealAmount,
    required this.area,
    required this.floor,
    required this.dealYear,
    required this.dealMonth,
    required this.dealDay,
    required this.dong,
    required this.jibun,
    required this.regionCode,
  });

  /// XML 파싱용 factory
  factory ApartmentTrade.fromXml(Map<String, dynamic> map) {
    return ApartmentTrade(
      aptName: (map['aptNm'] ?? map['아파트'] ?? '').toString().trim(),
      dealAmount: int.tryParse((map['dealAmount'] ?? map['거래금액'] ?? '').toString().trim().replaceAll(',', '')) ?? 0,
      area: double.tryParse((map['excluUseAr'] ?? map['전용면적'] ?? '').toString().trim()) ?? 0,
      floor: int.tryParse((map['floor'] ?? map['층'] ?? '').toString().trim()) ?? 0,
      dealYear: int.tryParse((map['dealYear'] ?? map['년'] ?? '').toString().trim()) ?? 0,
      dealMonth: int.tryParse((map['dealMonth'] ?? map['월'] ?? '').toString().trim()) ?? 0,
      dealDay: int.tryParse((map['dealDay'] ?? map['일'] ?? '').toString().trim()) ?? 0,
      dong: (map['umdNm'] ?? map['법정동'] ?? '').toString().trim(),
      jibun: (map['jibun'] ?? map['지번'] ?? '').toString().trim(),
      regionCode: (map['sggCd'] ?? map['지역코드'] ?? '').toString().trim(),
    );
  }

  DateTime get dealDate => DateTime(dealYear, dealMonth, dealDay);

  /// 평수 변환 (㎡ → 평)
  double get pyeong => area / _sqmToPyeong;
  String get pyeongStr => '${pyeong.toStringAsFixed(0)}평';
}
