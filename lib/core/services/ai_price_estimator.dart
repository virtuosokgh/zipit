import '../constants/app_constants.dart';
import '../../models/apartment_trade.dart';
import '../../models/apartment_rent.dart';

/// AI 추정가 계산 결과
class AiEstimateResult {
  final int estimatedPrice;   // AI 추정가 (만원)
  final int currentPrice;     // 현재 시세 (만원) - 최근 거래가 기준
  final double priceGap;      // 괴리율 (%)
  final double trendRate;     // 6개월 추세 (%)
  final double jeonseRatio;   // 전세가율 (%)
  final double ageFactor;     // 연식 보정 계수
  final double farFactor;     // 용적률 보정 계수

  AiEstimateResult({
    required this.estimatedPrice,
    required this.currentPrice,
    required this.priceGap,
    required this.trendRate,
    required this.jeonseRatio,
    required this.ageFactor,
    required this.farFactor,
  });
}

class AiPriceEstimator {
  /// 아파트의 AI 추정가 계산
  ///
  /// [trades] - 해당 아파트의 최근 6개월 매매 실거래 데이터
  /// [rents] - 해당 아파트의 최근 6개월 전월세 실거래 데이터
  /// [buildYear] - 건축년도
  /// [floorAreaRatio] - 용적률 (%), null이면 FAR 보정 미적용
  static AiEstimateResult? estimate({
    required List<ApartmentTrade> trades,
    required List<ApartmentRent> rents,
    required int buildYear,
    double? floorAreaRatio,
  }) {
    if (trades.isEmpty) return null;

    // 1. 현재 시세 = 최근 3개월 거래 평균
    final currentPrice = _calcCurrentPrice(trades);

    // 2. 가중 평균 실거래가 (최신 거래일수록 가중치 높음)
    final weightedAvg = _calcWeightedAverage(trades);

    // 3. 가격 추세 (6개월 선형회귀 기울기)
    final trendRate = _calcTrendRate(trades);

    // 4. 전세가율 보정
    final jeonseRatio = _calcJeonseRatio(trades, rents);
    final jeonseFactor = _calcJeonseFactor(jeonseRatio);

    // 5. 연식 보정 (신축 프리미엄 + 재건축 기대감)
    final ageFactor = _calcAgeFactor(buildYear);

    // 6. 용적률 보정 (낮을수록 재건축 사업성 좋음) — 용적률 정보 없으면 보정 안 함
    final farFactor = floorAreaRatio != null ? _calcFarFactor(floorAreaRatio, buildYear) : 1.0;

    // 최종 AI 추정가 계산
    // 기본값 = 가중평균 × (1 + 추세보정) × 전세가율보정 × 연식보정 × 용적률보정
    final baseEstimate = weightedAvg * (1 + trendRate / 100);
    final adjusted = baseEstimate * jeonseFactor * ageFactor * farFactor;
    final estimatedPrice = adjusted.round();

    final priceGap = currentPrice > 0
        ? ((estimatedPrice - currentPrice) / currentPrice) * 100
        : 0.0;

    return AiEstimateResult(
      estimatedPrice: estimatedPrice,
      currentPrice: currentPrice,
      priceGap: double.parse(priceGap.toStringAsFixed(1)),
      trendRate: double.parse(trendRate.toStringAsFixed(1)),
      jeonseRatio: double.parse(jeonseRatio.toStringAsFixed(1)),
      ageFactor: ageFactor,
      farFactor: farFactor,
    );
  }

  /// 현재 시세: 최근 3개월 매매 거래 평균
  static int _calcCurrentPrice(List<ApartmentTrade> trades) {
    final now = DateTime.now();
    final recent = trades.where((t) {
      final diff = now.difference(t.dealDate).inDays;
      return diff <= AppConstants.recentTradeDays;
    }).toList();

    if (recent.isEmpty) {
      // 3개월 내 거래 없으면 전체 평균
      final total = trades.fold<int>(0, (sum, t) => sum + t.dealAmount);
      return total ~/ trades.length;
    }

    final total = recent.fold<int>(0, (sum, t) => sum + t.dealAmount);
    return total ~/ recent.length;
  }

  /// 가중 평균: 최신 거래일수록 가중치 높음
  /// 가중치 = 1 / (1 + 경과월수)
  static double _calcWeightedAverage(List<ApartmentTrade> trades) {
    final now = DateTime.now();
    double weightedSum = 0;
    double totalWeight = 0;

    for (final trade in trades) {
      final monthsAgo = (now.year - trade.dealYear) * 12 +
          (now.month - trade.dealMonth);
      final weight = 1.0 / (1.0 + monthsAgo.clamp(0, 12));
      weightedSum += trade.dealAmount * weight;
      totalWeight += weight;
    }

    return totalWeight > 0 ? weightedSum / totalWeight : 0;
  }

  /// 가격 추세: 6개월간 월별 평균가 선형회귀 기울기 (%)
  static double _calcTrendRate(List<ApartmentTrade> trades) {
    // 월별 평균가 계산
    final monthlyAvg = <int, List<int>>{};
    for (final trade in trades) {
      final key = trade.dealYear * 100 + trade.dealMonth;
      monthlyAvg.putIfAbsent(key, () => []).add(trade.dealAmount);
    }

    if (monthlyAvg.length < 2) return 0;

    // 시간순 정렬
    final sortedKeys = monthlyAvg.keys.toList()..sort();
    final avgPrices = sortedKeys.map((k) {
      final prices = monthlyAvg[k]!;
      return prices.reduce((a, b) => a + b) / prices.length;
    }).toList();

    // 단순 선형회귀 (최소자승법)
    final n = avgPrices.length;
    double sumX = 0, sumY = 0, sumXY = 0, sumXX = 0;
    for (int i = 0; i < n; i++) {
      sumX += i;
      sumY += avgPrices[i];
      sumXY += i * avgPrices[i];
      sumXX += i * i;
    }

    final denominator = n * sumXX - sumX * sumX;
    if (denominator == 0) return 0;

    final slope = (n * sumXY - sumX * sumY) / denominator;
    final avgPrice = sumY / n;

    // 6개월 누적 변화율 (%) — ±15% 캡
    final rate = avgPrice > 0 ? (slope * 6 / avgPrice) * 100 : 0.0;
    return rate.clamp(-AppConstants.trendRateCap, AppConstants.trendRateCap);
  }

  /// 전세가율 계산: 전세 평균가 / 매매 평균가
  static double _calcJeonseRatio(
    List<ApartmentTrade> trades,
    List<ApartmentRent> rents,
  ) {
    final jeonseRents = rents.where((r) => r.isJeonse).toList();
    if (jeonseRents.isEmpty || trades.isEmpty) return 60; // 기본값 60%

    final avgTrade = trades.fold<int>(0, (s, t) => s + t.dealAmount) / trades.length;
    final avgJeonse = jeonseRents.fold<int>(0, (s, r) => s + r.deposit) / jeonseRents.length;

    return avgTrade > 0 ? (avgJeonse / avgTrade) * 100 : 60;
  }

  /// 전세가율 보정 계수
  /// 전세가율이 낮으면 → 매매가 상승 여력 있음 (상향 보정)
  /// 전세가율이 높으면 → 갭이 적어 가격 하방 리스크 (하향 보정)
  static double _calcJeonseFactor(double jeonseRatio) {
    if (jeonseRatio < 40) return 1.03;      // 전세가율 40% 미만: +3%
    if (jeonseRatio < 50) return 1.015;     // 40~50%: +1.5%
    if (jeonseRatio < 60) return 1.005;     // 50~60%: +0.5%
    if (jeonseRatio < 70) return 1.0;       // 60~70%: 보정 없음
    if (jeonseRatio < 80) return 0.99;      // 70~80%: -1%
    return 0.97;                             // 80% 이상: -3%
  }

  /// 연식 보정 계수
  /// 신축 프리미엄 + 재건축 기대감 반영
  static double _calcAgeFactor(int buildYear) {
    final age = DateTime.now().year - buildYear;

    if (age <= 3) return 1.04;        // 3년 이내 신축: +4%
    if (age <= 5) return 1.025;       // 5년 이내: +2.5%
    if (age <= 10) return 1.01;       // 10년 이내: +1%
    if (age <= 15) return 1.0;        // 15년 이내: 보정 없음
    if (age <= 25) return 0.99;       // 15~25년: -1%
    if (age <= 30) return 1.0;        // 25~30년: 재건축 기대 시작
    if (age <= 35) return 1.02;       // 30~35년: 재건축 기대감 +2%
    return 1.04;                       // 35년 이상: 재건축 임박 +4%
  }

  /// 용적률 보정 계수 (재건축 사업성 관점)
  /// 연식 25년 이상일 때만 적용 (재건축 대상)
  static double _calcFarFactor(double floorAreaRatio, int buildYear) {
    final age = DateTime.now().year - buildYear;
    if (age < 25) return 1.0; // 재건축 대상 아니면 보정 없음

    if (floorAreaRatio < 200) return 1.02;   // 용적률 200% 미만: +2%
    if (floorAreaRatio < 250) return 1.01;   // 200~250%: +1%
    if (floorAreaRatio < 300) return 1.0;    // 250~300%: 보정 없음
    return 0.99;                              // 300% 이상: -1% (사업성 낮음)
  }
}
