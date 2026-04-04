/// 청약 상태 필터
enum SubscriptionStatusFilter {
  all('전체'),
  upcoming('접수예정'),
  accepting('접수중'),
  closed('마감'),
  announced('당첨발표');

  final String label;
  const SubscriptionStatusFilter(this.label);
}

/// 주택 유형 필터
enum HousingTypeFilter {
  all('전체'),
  privateSector('민영'),
  national('국민');

  final String label;
  const HousingTypeFilter(this.label);
}

/// 청약 정렬 타입
enum SubscriptionSortType {
  aiRecommend('AI 추천 순'),
  dateAsc('청약일 순'),
  priceLow('분양가 낮은 순'),
  priceHigh('분양가 높은 순'),
  competitionLow('경쟁률 낮은 순'),
  householdsHigh('세대수 많은 순'),
  moveInSoon('입주 빠른 순');

  final String label;
  const SubscriptionSortType(this.label);
}

/// 청약 필터 모델
class SubscriptionFilter {
  // ── 대표 필터 ──
  final List<SubscriptionStatusFilter> statuses;  // 복수 선택
  final String region;                             // 지역 (시/도)
  final HousingTypeFilter housingType;             // 주택유형
  final int? householdsMin;                        // 세대수 최소
  final int? householdsMax;                        // 세대수 최대

  // ── 상세 필터 ──
  final String? constructor;                       // 시공사 검색
  final String? moveInYearMin;                     // 입주예정 시작 (YYYYMM)
  final String? moveInYearMax;                     // 입주예정 종료 (YYYYMM)
  final List<String> supplyTypes;                  // 공급유형: 일반, 신혼부부, 생애최초, 다자녀, 노부모, 기관추천
  final String? rentType;                          // 분양/임대

  // ── 정렬 ──
  final SubscriptionSortType sortType;

  const SubscriptionFilter({
    this.statuses = const [],
    this.region = '',
    this.housingType = HousingTypeFilter.all,
    this.householdsMin,
    this.householdsMax,
    this.constructor,
    this.moveInYearMin,
    this.moveInYearMax,
    this.supplyTypes = const [],
    this.rentType,
    this.sortType = SubscriptionSortType.aiRecommend,
  });

  SubscriptionFilter copyWith({
    List<SubscriptionStatusFilter>? statuses,
    String? region,
    HousingTypeFilter? housingType,
    int? Function()? householdsMin,
    int? Function()? householdsMax,
    String? Function()? constructor,
    String? Function()? moveInYearMin,
    String? Function()? moveInYearMax,
    List<String>? supplyTypes,
    String? Function()? rentType,
    SubscriptionSortType? sortType,
  }) {
    return SubscriptionFilter(
      statuses: statuses ?? this.statuses,
      region: region ?? this.region,
      housingType: housingType ?? this.housingType,
      householdsMin: householdsMin != null ? householdsMin() : this.householdsMin,
      householdsMax: householdsMax != null ? householdsMax() : this.householdsMax,
      constructor: constructor != null ? constructor() : this.constructor,
      moveInYearMin: moveInYearMin != null ? moveInYearMin() : this.moveInYearMin,
      moveInYearMax: moveInYearMax != null ? moveInYearMax() : this.moveInYearMax,
      supplyTypes: supplyTypes ?? this.supplyTypes,
      rentType: rentType != null ? rentType() : this.rentType,
      sortType: sortType ?? this.sortType,
    );
  }

  bool get hasActiveMainFilters =>
      statuses.isNotEmpty ||
      region.isNotEmpty ||
      housingType != HousingTypeFilter.all ||
      householdsMin != null ||
      householdsMax != null;

  bool get hasActiveDetailFilters =>
      (constructor != null && constructor!.isNotEmpty) ||
      moveInYearMin != null ||
      moveInYearMax != null ||
      supplyTypes.isNotEmpty ||
      (rentType != null && rentType!.isNotEmpty);

  int get activeDetailFilterCount {
    int count = 0;
    if (constructor != null && constructor!.isNotEmpty) count++;
    if (moveInYearMin != null || moveInYearMax != null) count++;
    if (supplyTypes.isNotEmpty) count++;
    if (rentType != null && rentType!.isNotEmpty) count++;
    return count;
  }
}
