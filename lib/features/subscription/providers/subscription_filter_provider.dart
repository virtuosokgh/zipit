import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/subscription_filter.dart';
import '../../../providers/user_preferences_provider.dart';

/// 청약 필터 상태 관리
final subscriptionFilterProvider =
    StateNotifierProvider<SubscriptionFilterNotifier, SubscriptionFilter>((ref) {
  final prefs = ref.read(userPreferencesProvider);
  return SubscriptionFilterNotifier(prefs.region);
});

class SubscriptionFilterNotifier extends StateNotifier<SubscriptionFilter> {
  SubscriptionFilterNotifier(String region)
      : super(SubscriptionFilter(
          region: region,
          statuses: const [
            SubscriptionStatusFilter.upcoming,
            SubscriptionStatusFilter.accepting,
          ],
        ));

  void setStatuses(List<SubscriptionStatusFilter> statuses) {
    state = state.copyWith(statuses: statuses);
  }

  void setRegion(String region) {
    state = state.copyWith(region: region);
  }

  void setHousingType(HousingTypeFilter type) {
    state = state.copyWith(housingType: type);
  }

  void setHouseholdsRange(int? min, int? max) {
    state = state.copyWith(
      householdsMin: () => min,
      householdsMax: () => max,
    );
  }

  void setSortType(SubscriptionSortType sort) {
    state = state.copyWith(sortType: sort);
  }

  void applyDetailFilters({
    String? constructor,
    String? moveInYearMin,
    String? moveInYearMax,
    List<String>? supplyTypes,
    String? rentType,
  }) {
    state = state.copyWith(
      constructor: () => constructor,
      moveInYearMin: () => moveInYearMin,
      moveInYearMax: () => moveInYearMax,
      supplyTypes: supplyTypes ?? const [],
      rentType: () => rentType,
    );
  }

  void resetDetailFilters() {
    state = state.copyWith(
      constructor: () => null,
      moveInYearMin: () => null,
      moveInYearMax: () => null,
      supplyTypes: const [],
      rentType: () => null,
    );
  }

  void reset(String region) {
    state = SubscriptionFilter(
      region: region,
      statuses: const [
        SubscriptionStatusFilter.upcoming,
        SubscriptionStatusFilter.accepting,
      ],
    );
  }
}
