/// 사용자 온보딩 설정
class UserPreferences {
  final List<String> interestTypes;   // ['buy', 'jeonse', 'monthly', 'subscription']
  final double budgetMin;             // 만원 단위
  final double budgetMax;             // 만원 단위
  final List<String> regions;         // 관심 지역 (다중 선택: ['서울 전체', '인천 연수구'])
  final bool onboardingCompleted;
  final bool lockScreenWidgetEnabled;
  final bool pushNotificationEnabled;
  final String homeSubscriptionRegion; // 홈 청약 필터 지역 (영속)

  // 위젯 전용 설정 (설정에서 별도 변경 가능)
  final String widgetInterestType;    // 위젯 종류: buy/jeonse/monthly/subscription
  final List<String> widgetRegions;   // 위젯 표시 지역
  final double widgetBudgetMin;
  final double widgetBudgetMax;

  UserPreferences({
    this.interestTypes = const [],
    this.budgetMin = 10000,
    this.budgetMax = 50000,
    this.regions = const [],
    this.onboardingCompleted = false,
    this.lockScreenWidgetEnabled = false,
    this.pushNotificationEnabled = true,
    this.homeSubscriptionRegion = '',
    this.widgetInterestType = '',
    this.widgetRegions = const [],
    this.widgetBudgetMin = 0,
    this.widgetBudgetMax = 0,
  });

  /// 하위 호환: 기존 단일 region → 첫 번째 지역
  String get region => regions.isNotEmpty ? regions.first : '';

  /// 위젯용 실질적 관심유형 (위젯 전용 설정 > 온보딩 설정 fallback)
  String get effectiveWidgetInterest =>
      widgetInterestType.isNotEmpty ? widgetInterestType
      : (interestTypes.isNotEmpty ? interestTypes.first : '');

  /// 위젯용 실질적 지역 목록 (위젯 전용 > 온보딩 fallback)
  List<String> get effectiveWidgetRegions =>
      widgetRegions.isNotEmpty ? widgetRegions : regions;

  /// 위젯용 실질적 지역 (첫 번째)
  String get effectiveWidgetRegion =>
      effectiveWidgetRegions.isNotEmpty ? effectiveWidgetRegions.first : '';

  UserPreferences copyWith({
    List<String>? interestTypes,
    double? budgetMin,
    double? budgetMax,
    List<String>? regions,
    bool? onboardingCompleted,
    bool? lockScreenWidgetEnabled,
    bool? pushNotificationEnabled,
    String? homeSubscriptionRegion,
    String? widgetInterestType,
    List<String>? widgetRegions,
    double? widgetBudgetMin,
    double? widgetBudgetMax,
  }) {
    return UserPreferences(
      interestTypes: interestTypes ?? this.interestTypes,
      budgetMin: budgetMin ?? this.budgetMin,
      budgetMax: budgetMax ?? this.budgetMax,
      regions: regions ?? this.regions,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      lockScreenWidgetEnabled: lockScreenWidgetEnabled ?? this.lockScreenWidgetEnabled,
      pushNotificationEnabled: pushNotificationEnabled ?? this.pushNotificationEnabled,
      homeSubscriptionRegion: homeSubscriptionRegion ?? this.homeSubscriptionRegion,
      widgetInterestType: widgetInterestType ?? this.widgetInterestType,
      widgetRegions: widgetRegions ?? this.widgetRegions,
      widgetBudgetMin: widgetBudgetMin ?? this.widgetBudgetMin,
      widgetBudgetMax: widgetBudgetMax ?? this.widgetBudgetMax,
    );
  }

  Map<String, dynamic> toJson() => {
        'interestTypes': interestTypes,
        'budgetMin': budgetMin,
        'budgetMax': budgetMax,
        'regions': regions,
        'onboardingCompleted': onboardingCompleted,
        'lockScreenWidgetEnabled': lockScreenWidgetEnabled,
        'pushNotificationEnabled': pushNotificationEnabled,
        'homeSubscriptionRegion': homeSubscriptionRegion,
        'widgetInterestType': widgetInterestType,
        'widgetRegions': widgetRegions,
        'widgetBudgetMin': widgetBudgetMin,
        'widgetBudgetMax': widgetBudgetMax,
      };

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    // 하위 호환: 기존 'region' (String) → 'regions' (List)
    List<String> regions;
    if (json.containsKey('regions') && json['regions'] is List) {
      regions = List<String>.from(json['regions']);
    } else if (json.containsKey('region') && json['region'] is String && (json['region'] as String).isNotEmpty) {
      regions = [json['region'] as String];
    } else {
      regions = [];
    }

    return UserPreferences(
      interestTypes: List<String>.from(json['interestTypes'] ?? []),
      budgetMin: (json['budgetMin'] ?? 10000).toDouble(),
      budgetMax: (json['budgetMax'] ?? 50000).toDouble(),
      regions: regions,
      onboardingCompleted: json['onboardingCompleted'] ?? false,
      lockScreenWidgetEnabled: json['lockScreenWidgetEnabled'] ?? false,
      pushNotificationEnabled: json['pushNotificationEnabled'] ?? true,
      homeSubscriptionRegion: json['homeSubscriptionRegion'] ?? '',
      widgetInterestType: json['widgetInterestType'] ?? '',
      widgetRegions: List<String>.from(json['widgetRegions'] ?? []),
      widgetBudgetMin: (json['widgetBudgetMin'] ?? 0).toDouble(),
      widgetBudgetMax: (json['widgetBudgetMax'] ?? 0).toDouble(),
    );
  }
}
