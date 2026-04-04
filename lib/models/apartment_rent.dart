import '../core/constants/app_constants.dart';

/// 아파트 전월세 실거래 데이터
class ApartmentRent {
  final String aptName;
  final int deposit;          // 보증금 (만원)
  final int monthlyRent;      // 월세 (만원, 0이면 전세)
  final double area;
  final int floor;
  final int dealYear;
  final int dealMonth;
  final int dealDay;
  final String dong;
  final String jibun;
  final String regionCode;

  ApartmentRent({
    required this.aptName,
    required this.deposit,
    required this.monthlyRent,
    required this.area,
    required this.floor,
    required this.dealYear,
    required this.dealMonth,
    required this.dealDay,
    required this.dong,
    required this.jibun,
    required this.regionCode,
  });

  factory ApartmentRent.fromXml(Map<String, dynamic> map) {
    return ApartmentRent(
      aptName: (map['aptNm'] ?? map['아파트'] ?? '').toString().trim(),
      deposit: int.tryParse((map['deposit'] ?? map['보증금액'] ?? '').toString().trim().replaceAll(',', '')) ?? 0,
      monthlyRent: int.tryParse((map['monthlyRent'] ?? map['월세금액'] ?? '').toString().trim().replaceAll(',', '')) ?? 0,
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

  bool get isJeonse => monthlyRent == 0;
  DateTime get dealDate => DateTime(dealYear, dealMonth, dealDay);
  double get pyeong => area / AppConstants.sqmToPyeong;
}
