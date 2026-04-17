import '../core/constants/app_constants.dart';
import '../widgets/price_signal_badge.dart';

/// AI 추천 TOP 10 아파트 매물 모델
class ApartmentListing {
  final String name;             // 아파트명
  final String location;         // 위치 (구 동)
  final String address;          // 도로명 주소 (구체적 주소)
  final int currentPrice;        // 현재시세 (만원)
  final int aiEstimate;          // AI 추정가 (만원)
  final double priceGap;         // 호가와 실거래 차이 (%)
  final double floorAreaRatio;   // 용적률 (%)
  final int buildYear;           // 건축년도
  final String regionCode;       // 지역코드
  final List<ApartmentUnit> units;       // 평형 목록
  final List<TradeHistory> tradeHistory; // 거래 이력

  // 성능 최적화: 최신 전세/월세 거래 캐싱 (getter 반복 호출 방지)
  TradeHistory? _latestJeonse;
  TradeHistory? _latestMonthly;
  bool _latestJeonseCached = false;
  bool _latestMonthlyCached = false;

  ApartmentListing({
    required this.name,
    required this.location,
    this.address = '',
    required this.currentPrice,
    required this.aiEstimate,
    required this.priceGap,
    required this.floorAreaRatio,
    required this.buildYear,
    required this.regionCode,
    required this.units,
    required this.tradeHistory,
  });

  /// 캐싱된 최신 전세 거래 조회
  TradeHistory? _getLatestJeonse() {
    if (_latestJeonseCached) return _latestJeonse;
    TradeHistory? latest;
    for (final t in tradeHistory) {
      if (t.type != TradeType.jeonse) continue;
      if (latest == null || t.date.isAfter(latest.date)) latest = t;
    }
    _latestJeonse = latest;
    _latestJeonseCached = true;
    return latest;
  }

  /// 캐싱된 최신 월세 거래 조회
  TradeHistory? _getLatestMonthly() {
    if (_latestMonthlyCached) return _latestMonthly;
    TradeHistory? latest;
    for (final t in tradeHistory) {
      if (t.type != TradeType.monthly) continue;
      if (latest == null || t.date.isAfter(latest.date)) latest = t;
    }
    _latestMonthly = latest;
    _latestMonthlyCached = true;
    return latest;
  }

  /// AI 추정가 vs 현재시세 비교 → 저평가/적정/고평가
  PriceSignal get priceSignal {
    final ratio = (aiEstimate - currentPrice) / currentPrice;
    if (ratio > AppConstants.priceSignalThreshold) return PriceSignal.safe;       // 저평가 (AI가 더 높음)
    if (ratio < -AppConstants.priceSignalThreshold) return PriceSignal.danger;    // 고평가 (AI가 더 낮음)
    return PriceSignal.caution;                       // 적정
  }

  String get priceSignalLabel => switch (priceSignal) {
    PriceSignal.safe => '저평가',
    PriceSignal.caution => '적정',
    PriceSignal.danger => '고평가',
  };

  /// AI 추정가 대비 차이 비율 (%)
  double get aiGapPercent => ((aiEstimate - currentPrice) / currentPrice) * 100;

  /// 최근 전세가 (전체 평형 중 최신)
  int? get latestJeonsePrice => _getLatestJeonse()?.price;

  /// 안전 보증금 = max(전세보증보험 한도, 3개월내 전세 최저가)
  /// - 보험 한도 >= 전세 최저가 → 보험이 커버 가능 → 보험 한도가 안전금
  /// - 보험 한도 < 전세 최저가 → 시세 자체가 높음 → 전세 최저가가 안전금
  int? get safeJeonsePrice {
    final threeMonthsAgo = DateTime.now().subtract(const Duration(days: 90));
    final recent = tradeHistory
        .where((t) => t.type == TradeType.jeonse && t.date.isAfter(threeMonthsAgo))
        .toList();
    if (recent.isEmpty) return null;
    final lowest = recent.map((t) => t.price).reduce((a, b) => a < b ? a : b);
    final insuranceLimit = (currentPrice * AppConstants.jeonseInsuranceLimitRatio).toInt();
    return insuranceLimit >= lowest ? insuranceLimit : lowest;
  }

  /// 전세 안전도 점수 (안전 보증금 - 현재 전세가, 양수=안전, 음수=위험)
  double get jeonseSafetyScore {
    final safe = safeJeonsePrice;
    final current = latestJeonsePrice;
    if (safe == null || current == null) return double.negativeInfinity;
    return (safe - current).toDouble();
  }

  /// 최근 월세 보증금
  int? get latestMonthlyDeposit => _getLatestMonthly()?.price;

  /// 최근 월세금
  int? get latestMonthlyRent => _getLatestMonthly()?.monthlyRent;

  /// 월세 → 보증금 환산 (1000만원당 월 5만원)
  /// 총 환산 보증금 = 실보증금 + (월세 × 200)
  int? get monthlyRentAsDeposit {
    final deposit = latestMonthlyDeposit;
    final rent = latestMonthlyRent;
    if (deposit == null || rent == null) return null;
    return deposit + (rent * AppConstants.monthlyRentConversionFactor.toInt());
  }

  /// 적정 월세 = (안전보증금 - 환산보증금) ÷ 200 (만원)
  /// 환산보증금 = 실보증금 + 실월세×200
  int? get safeMonthlyRent {
    final safe = safeJeonsePrice;
    final totalDeposit = monthlyRentAsDeposit;
    if (safe == null || totalDeposit == null) return null;
    final remaining = safe - totalDeposit;
    if (remaining <= 0) return 0;
    return (remaining / AppConstants.monthlyRentConversionFactor).round();
  }

  /// 안전 보증금 (월세용) = 실보증금 그대로 (보증금은 이미 낮아서 OK)
  int? get safeMonthlyDeposit => latestMonthlyDeposit;

  /// 월세 안전도 시그널
  /// 적정 월세 < 실제 월세 → 안전 (적정 월세가 낮을수록 더 안전)
  PriceSignal get monthlyRentSafetySignal {
    final safe = safeMonthlyRent;
    final actual = latestMonthlyRent;
    if (safe == null || actual == null || actual == 0) return PriceSignal.caution;
    final diff = (actual - safe) / actual;
    if (diff > AppConstants.priceSignalThreshold) return PriceSignal.safe;       // 적정 월세가 실제보다 낮음 → 안전
    if (diff < -AppConstants.priceSignalThreshold) return PriceSignal.danger;    // 적정 월세가 실제보다 높음 → 주의
    return PriceSignal.caution;                      // 적정
  }

  String get monthlyRentSafetyLabel => switch (monthlyRentSafetySignal) {
    PriceSignal.safe => '안전',
    PriceSignal.caution => '적정',
    PriceSignal.danger => '주의',
  };

  /// 월세 안전도 점수 (실제월세 - 적정월세, 양수=안전, 클수록 더 안전)
  double get monthlyRentSafetyScore {
    final safe = safeMonthlyRent;
    final actual = latestMonthlyRent;
    if (safe == null || actual == null) return double.negativeInfinity;
    return (actual - safe).toDouble();
  }
}

/// 평형별 단위 정보
class ApartmentUnit {
  final int pyeong;              // 평형 (e.g. 34)
  final double supplyArea;       // 공급면적 (㎡)
  final double exclusiveArea;    // 전용면적 (㎡)
  final String entranceType;     // 현관구조 (계단식/복도식/타워형)
  final int rooms;               // 방 개수
  final int bathrooms;           // 화장실 수

  ApartmentUnit({
    required this.pyeong,
    required this.supplyArea,
    required this.exclusiveArea,
    required this.entranceType,
    required this.rooms,
    required this.bathrooms,
  });
}

/// 거래 유형
enum TradeType { sale, jeonse, monthly }

/// 거래 이력
class TradeHistory {
  final DateTime date;
  final int price;     // 만원 (매매: 거래가, 전세: 보증금, 월세: 보증금)
  final int floor;
  final double area;   // 전용면적 (㎡)
  final TradeType type; // 매매/전세/월세
  final int monthlyRent; // 월세금 (만원, 월세일 때만 사용)

  TradeHistory({
    required this.date,
    required this.price,
    required this.floor,
    required this.area,
    this.type = TradeType.sale,
    this.monthlyRent = 0,
  });
}
