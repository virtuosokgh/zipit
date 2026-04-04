import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_preferences.dart';

final userPreferencesProvider =
    StateNotifierProvider<UserPreferencesNotifier, UserPreferences>((ref) {
  return UserPreferencesNotifier();
});

class UserPreferencesNotifier extends StateNotifier<UserPreferences> {
  UserPreferencesNotifier() : super(UserPreferences()) {
    _load();
  }

  static const _key = 'user_preferences';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json != null) {
      state = UserPreferences.fromJson(jsonDecode(json));
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.toJson()));
  }

  void setInterestTypes(List<String> types) {
    state = state.copyWith(interestTypes: types);
    _save();
  }

  void setBudget(double min, double max) {
    state = state.copyWith(budgetMin: min, budgetMax: max);
    _save();
  }

  void setRegions(List<String> regions) {
    state = state.copyWith(regions: regions);
    _save();
  }

  /// 하위 호환: 단일 지역 설정
  void setRegion(String region) {
    if (region.isEmpty) {
      state = state.copyWith(regions: []);
    } else {
      state = state.copyWith(regions: [region]);
    }
    _save();
  }

  void completeOnboarding() {
    state = state.copyWith(onboardingCompleted: true);
    _save();
  }

  void toggleLockScreenWidget(bool enabled) {
    state = state.copyWith(lockScreenWidgetEnabled: enabled);
    _save();
  }

  void togglePushNotification(bool enabled) {
    state = state.copyWith(pushNotificationEnabled: enabled);
    _save();
  }

  void setHomeSubscriptionRegion(String region) {
    state = state.copyWith(homeSubscriptionRegion: region);
    _save();
  }

  /// 위젯 전용 설정 변경
  void setWidgetSettings({
    required String interestType,
    required List<String> regions,
    double? budgetMin,
    double? budgetMax,
  }) {
    state = state.copyWith(
      widgetInterestType: interestType,
      widgetRegions: regions,
      widgetBudgetMin: budgetMin ?? state.widgetBudgetMin,
      widgetBudgetMax: budgetMax ?? state.widgetBudgetMax,
    );
    _save();
  }
}
