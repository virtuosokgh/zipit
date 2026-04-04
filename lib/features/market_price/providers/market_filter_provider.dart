import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/region_codes.dart';
import '../../../models/market_filter.dart';
import '../../../providers/user_preferences_provider.dart';

/// 시세 필터 상태 관리
final marketFilterProvider =
    StateNotifierProvider<MarketFilterNotifier, MarketFilter>((ref) {
  final prefs = ref.read(userPreferencesProvider);
  return MarketFilterNotifier(prefs.regions, prefs.budgetMin, prefs.budgetMax);
});

class MarketFilterNotifier extends StateNotifier<MarketFilter> {
  MarketFilterNotifier(List<String> regions, double budgetMin, double budgetMax)
      : super(MarketFilter(
          regionCodes: RegionCodes.getCodesForRegions(regions),
          priceMin: budgetMin > 0 ? budgetMin : null,
          priceMax: budgetMax < 200000 ? budgetMax : null,
        ));

  void setRegionCodes(List<String> codes) {
    state = state.copyWith(regionCodes: codes);
  }

  void setTradeType(TradeTypeFilter type) {
    // 거래유형 변경 시 가격 필터 초기화 (범위가 다르므로)
    // 월세 전용 정렬이 선택된 상태에서 다른 유형으로 변경 시 기본 정렬로 리셋
    final resetSort = type != TradeTypeFilter.monthly &&
        (state.sortType == MarketSortType.monthlyRentLow ||
         state.sortType == MarketSortType.monthlyRentHigh);
    state = state.copyWith(
      tradeType: type,
      priceMin: () => null,
      priceMax: () => null,
      monthlyRentMin: () => null,
      monthlyRentMax: () => null,
      sortType: resetSort ? MarketSortType.aiRecommend : null,
    );
  }

  void setPriceRange(double? min, double? max) {
    state = state.copyWith(priceMin: () => min, priceMax: () => max);
  }

  void setMonthlyRentRange(double? min, double? max) {
    state = state.copyWith(monthlyRentMin: () => min, monthlyRentMax: () => max);
  }

  void setAreaRange(double? min, double? max) {
    state = state.copyWith(areaMin: () => min, areaMax: () => max);
  }

  void setApprovalYearRange(int? min, int? max) {
    state = state.copyWith(approvalYearMin: () => min, approvalYearMax: () => max);
  }

  void setHouseholdsRange(int? min, int? max) {
    state = state.copyWith(householdsMin: () => min, householdsMax: () => max);
  }

  void setGapRange(double? min, double? max) {
    state = state.copyWith(gapMin: () => min, gapMax: () => max);
  }

  void setFarRange(double? min, double? max) {
    state = state.copyWith(farMin: () => min, farMax: () => max);
  }

  void setBcrRange(double? min, double? max) {
    state = state.copyWith(bcrMin: () => min, bcrMax: () => max);
  }

  void setRoomsMin(int? rooms) {
    state = state.copyWith(roomsMin: () => rooms);
  }

  void setJeonseRatioRange(double? min, double? max) {
    state = state.copyWith(jeonseRatioMin: () => min, jeonseRatioMax: () => max);
  }

  void setSortType(MarketSortType sort) {
    state = state.copyWith(sortType: sort);
  }

  /// 상세 필터만 일괄 적용
  void applyDetailFilters({
    double? gapMin,
    double? gapMax,
    double? farMin,
    double? farMax,
    double? bcrMin,
    double? bcrMax,
    int? roomsMin,
    double? jeonseRatioMin,
    double? jeonseRatioMax,
  }) {
    state = state.copyWith(
      gapMin: () => gapMin,
      gapMax: () => gapMax,
      farMin: () => farMin,
      farMax: () => farMax,
      bcrMin: () => bcrMin,
      bcrMax: () => bcrMax,
      roomsMin: () => roomsMin,
      jeonseRatioMin: () => jeonseRatioMin,
      jeonseRatioMax: () => jeonseRatioMax,
    );
  }

  void resetDetailFilters() {
    state = state.copyWith(
      gapMin: () => null,
      gapMax: () => null,
      farMin: () => null,
      farMax: () => null,
      bcrMin: () => null,
      bcrMax: () => null,
      roomsMin: () => null,
      jeonseRatioMin: () => null,
      jeonseRatioMax: () => null,
    );
  }

  void reset(List<String> regions, double budgetMin, double budgetMax) {
    state = MarketFilter(
      regionCodes: RegionCodes.getCodesForRegions(regions),
      priceMin: budgetMin > 0 ? budgetMin : null,
      priceMax: budgetMax < 200000 ? budgetMax : null,
    );
  }
}
