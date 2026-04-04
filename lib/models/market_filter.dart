/// 거래 유형 필터
enum TradeTypeFilter {
  all('전체'),
  sale('매매'),
  jeonse('전세'),
  monthly('월세');

  final String label;
  const TradeTypeFilter(this.label);
}

/// 시세 필터 모델
class MarketFilter {
  // ── 대표 필터 ──
  final List<String> regionCodes;     // 법정동코드 리스트
  final TradeTypeFilter tradeType;    // 거래유형
  final double? priceMin;             // 만원
  final double? priceMax;             // 만원
  final double? areaMin;              // 전용면적 ㎡
  final double? areaMax;              // 전용면적 ㎡
  final int? approvalYearMin;         // 사용승인일 (년도)
  final int? approvalYearMax;
  final int? householdsMin;           // 세대수
  final int? householdsMax;

  // ── 상세 필터 ──
  final double? gapMin;               // 갭차이 최소 (%)
  final double? gapMax;               // 갭차이 최대 (%)
  final double? farMin;               // 용적률 최소 (%)
  final double? farMax;               // 용적률 최대 (%)
  final double? bcrMin;               // 건폐율 최소 (%)
  final double? bcrMax;               // 건폐율 최대 (%)
  final int? roomsMin;                // 방 개수 최소
  final double? jeonseRatioMin;       // 전세가율 최소 (%)
  final double? jeonseRatioMax;       // 전세가율 최대 (%)
  final double? monthlyRentMin;       // 월세 최소 (만원)
  final double? monthlyRentMax;       // 월세 최대 (만원)

  // ── 정렬 ──
  final MarketSortType sortType;

  const MarketFilter({
    this.regionCodes = const [],
    this.tradeType = TradeTypeFilter.sale,
    this.priceMin,
    this.priceMax,
    this.areaMin,
    this.areaMax,
    this.approvalYearMin,
    this.approvalYearMax,
    this.householdsMin,
    this.householdsMax,
    this.gapMin,
    this.gapMax,
    this.farMin,
    this.farMax,
    this.bcrMin,
    this.bcrMax,
    this.roomsMin,
    this.jeonseRatioMin,
    this.jeonseRatioMax,
    this.monthlyRentMin,
    this.monthlyRentMax,
    this.sortType = MarketSortType.aiRecommend,
  });

  MarketFilter copyWith({
    List<String>? regionCodes,
    TradeTypeFilter? tradeType,
    double? Function()? priceMin,
    double? Function()? priceMax,
    double? Function()? areaMin,
    double? Function()? areaMax,
    int? Function()? approvalYearMin,
    int? Function()? approvalYearMax,
    int? Function()? householdsMin,
    int? Function()? householdsMax,
    double? Function()? gapMin,
    double? Function()? gapMax,
    double? Function()? farMin,
    double? Function()? farMax,
    double? Function()? bcrMin,
    double? Function()? bcrMax,
    int? Function()? roomsMin,
    double? Function()? jeonseRatioMin,
    double? Function()? jeonseRatioMax,
    double? Function()? monthlyRentMin,
    double? Function()? monthlyRentMax,
    MarketSortType? sortType,
  }) {
    return MarketFilter(
      regionCodes: regionCodes ?? this.regionCodes,
      tradeType: tradeType ?? this.tradeType,
      priceMin: priceMin != null ? priceMin() : this.priceMin,
      priceMax: priceMax != null ? priceMax() : this.priceMax,
      areaMin: areaMin != null ? areaMin() : this.areaMin,
      areaMax: areaMax != null ? areaMax() : this.areaMax,
      approvalYearMin: approvalYearMin != null ? approvalYearMin() : this.approvalYearMin,
      approvalYearMax: approvalYearMax != null ? approvalYearMax() : this.approvalYearMax,
      householdsMin: householdsMin != null ? householdsMin() : this.householdsMin,
      householdsMax: householdsMax != null ? householdsMax() : this.householdsMax,
      gapMin: gapMin != null ? gapMin() : this.gapMin,
      gapMax: gapMax != null ? gapMax() : this.gapMax,
      farMin: farMin != null ? farMin() : this.farMin,
      farMax: farMax != null ? farMax() : this.farMax,
      bcrMin: bcrMin != null ? bcrMin() : this.bcrMin,
      bcrMax: bcrMax != null ? bcrMax() : this.bcrMax,
      roomsMin: roomsMin != null ? roomsMin() : this.roomsMin,
      jeonseRatioMin: jeonseRatioMin != null ? jeonseRatioMin() : this.jeonseRatioMin,
      jeonseRatioMax: jeonseRatioMax != null ? jeonseRatioMax() : this.jeonseRatioMax,
      monthlyRentMin: monthlyRentMin != null ? monthlyRentMin() : this.monthlyRentMin,
      monthlyRentMax: monthlyRentMax != null ? monthlyRentMax() : this.monthlyRentMax,
      sortType: sortType ?? this.sortType,
    );
  }

  bool get hasActiveMainFilters =>
      regionCodes.isNotEmpty ||
      tradeType != TradeTypeFilter.sale ||
      priceMin != null ||
      priceMax != null ||
      areaMin != null ||
      areaMax != null ||
      approvalYearMin != null ||
      approvalYearMax != null ||
      householdsMin != null ||
      householdsMax != null;

  bool get hasActiveDetailFilters =>
      gapMin != null ||
      gapMax != null ||
      farMin != null ||
      farMax != null ||
      bcrMin != null ||
      bcrMax != null ||
      roomsMin != null ||
      jeonseRatioMin != null ||
      jeonseRatioMax != null;

  int get activeDetailFilterCount {
    int count = 0;
    if (gapMin != null || gapMax != null) count++;
    if (farMin != null || farMax != null) count++;
    if (bcrMin != null || bcrMax != null) count++;
    if (roomsMin != null) count++;
    if (jeonseRatioMin != null || jeonseRatioMax != null) count++;
    return count;
  }
}

enum MarketSortType {
  aiRecommend('AI 적정가 순'),
  priceLow('낮은 가격 순'),
  priceHigh('높은 가격 순'),
  monthlyRentLow('낮은 월세 순'),
  monthlyRentHigh('높은 월세 순'),
  gapHigh('갭차이 큰 순'),
  newest('최신 거래 순');

  final String label;
  const MarketSortType(this.label);

  /// 거래유형별 정렬 라벨
  String labelFor(TradeTypeFilter tradeType) {
    return switch (this) {
      MarketSortType.aiRecommend => switch (tradeType) {
        TradeTypeFilter.jeonse => '안전한 순',
        TradeTypeFilter.monthly => '안전한 순',
        _ => 'AI 적정가 순',
      },
      MarketSortType.priceLow => switch (tradeType) {
        TradeTypeFilter.jeonse => '낮은 전세가 순',
        TradeTypeFilter.monthly => '낮은 보증금 순',
        _ => '낮은 가격 순',
      },
      MarketSortType.priceHigh => switch (tradeType) {
        TradeTypeFilter.jeonse => '높은 전세가 순',
        TradeTypeFilter.monthly => '높은 보증금 순',
        _ => '높은 가격 순',
      },
      MarketSortType.monthlyRentLow => '낮은 월세 순',
      MarketSortType.monthlyRentHigh => '높은 월세 순',
      _ => label,
    };
  }

  /// 해당 거래유형에서 표시할 정렬 옵션 목록
  static List<MarketSortType> valuesFor(TradeTypeFilter tradeType) {
    if (tradeType == TradeTypeFilter.monthly) {
      return [aiRecommend, priceLow, priceHigh, monthlyRentLow, monthlyRentHigh, gapHigh, newest];
    }
    return [aiRecommend, priceLow, priceHigh, gapHigh, newest];
  }
}
