import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/subscription_api.dart';
import '../../../models/subscription_filter.dart';
import '../../../models/user_profile.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/user_preferences_provider.dart';
import 'subscription_filter_provider.dart';

/// 청약 가점 (계산기에서 저장 — 수동 오버라이드용)
final subscriptionScoreProvider = StateProvider<int?>((ref) => null);

/// 프로필 기반 자동 가점 계산
int? _calcAutoScore(UserProfile? profile) {
  if (profile == null) return null;
  if (profile.noHouseYears == null &&
      profile.dependents == null &&
      profile.accountYears == null) return null;

  final noHouseYears = profile.noHouseYears ?? 0;
  final dependents = profile.dependents ?? 0;
  final accountYears = profile.accountYears ?? 0;

  // 무주택 기간 점수 (0~32점)
  int noHouseScore;
  if (noHouseYears < 1) {
    noHouseScore = 2;
  } else if (noHouseYears >= 15) {
    noHouseScore = 32;
  } else {
    noHouseScore = 2 + (noHouseYears * 2);
  }

  // 부양가족 점수 (0~35점, 5점씩)
  int dependentScore = (dependents.clamp(0, 6)) * 5 + 5;
  if (dependents == 0) dependentScore = 5;

  // 통장 가입 기간 점수 (0~17점)
  int accountScore;
  if (accountYears < 1) {
    accountScore = 1;
  } else if (accountYears >= 15) {
    accountScore = 17;
  } else {
    accountScore = 1 + accountYears;
  }

  return noHouseScore + dependentScore + accountScore;
}

/// 최종 가점 (수동 입력 > 자동 계산)
final effectiveScoreProvider = Provider<int?>((ref) {
  final manual = ref.watch(subscriptionScoreProvider);
  if (manual != null) return manual;
  final profile = ref.watch(userProfileProvider);
  return _calcAutoScore(profile);
});

/// SubscriptionApi provider
final subscriptionApiProvider = Provider<SubscriptionApi>((ref) => SubscriptionApi());

/// 평형별 정보 모델
class SubscriptionUnitType {
  final String houseTy;        // "084.9951A" - 주택형
  final String modelNo;        // "01"
  final double supplyArea;     // 113.6646 공급면적
  final int supplyCount;       // 일반공급세대수
  final int specialCount;      // 특별공급세대수
  final int topAmount;         // (만원) 최고분양가
  final int newlyWedCount;     // 신혼부부
  final int firstLifeCount;    // 생애최초
  final int multiChildCount;   // 다자녀
  final int oldParentCount;    // 노부모부양
  final int institutionCount;  // 기관추천

  const SubscriptionUnitType({
    required this.houseTy,
    required this.modelNo,
    required this.supplyArea,
    required this.supplyCount,
    required this.specialCount,
    required this.topAmount,
    required this.newlyWedCount,
    required this.firstLifeCount,
    required this.multiChildCount,
    required this.oldParentCount,
    required this.institutionCount,
  });

  /// 총 공급세대수
  int get totalCount => supplyCount + specialCount;

  /// 평수 (근사치)
  double get pyeong => supplyArea / AppConstants.sqmToPyeong;

  /// 평형 라벨
  String get pyeongLabel => '${pyeong.toStringAsFixed(0)}평 ($houseTy)';

  factory SubscriptionUnitType.fromJson(Map<String, dynamic> json) {
    return SubscriptionUnitType(
      houseTy: json['HOUSE_TY']?.toString() ?? '',
      modelNo: json['MODEL_NO']?.toString() ?? '',
      supplyArea: _parseDouble(json['SUPLY_AR']),
      supplyCount: _parseInt(json['SUPLY_HSHLDCO']),
      specialCount: _parseInt(json['SPSPLY_HSHLDCO']),
      topAmount: _parseInt(json['LTTOT_TOP_AMOUNT']),
      newlyWedCount: _parseInt(json['MNYCH_HSHLDCO']),
      firstLifeCount: _parseInt(json['LFE_FRST_HSHLDCO']),
      multiChildCount: _parseInt(json['MNYCHILD_HSHLDCO']),
      oldParentCount: _parseInt(json['OLD_PARNTS_SUPORT_HSHLDCO']),
      institutionCount: _parseInt(json['INSTT_RECOMEND_HSHLDCO']),
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }
}

/// 평형별 정보 Provider
final subscriptionUnitTypesProvider = FutureProvider.family.autoDispose<List<SubscriptionUnitType>, String>((ref, houseManageNo) async {
  final api = ref.read(subscriptionApiProvider);
  return api.getUnitTypes(houseManageNo);
});

/// AI 당첨확률 - 개별 분석 항목
class ProbabilityFactor {
  final String category;    // 항목 카테고리
  final String title;       // 항목 제목
  final String description; // 상세 설명
  final double score;       // 이 항목의 점수 (0~maxScore)
  final double maxScore;    // 이 항목의 최대 점수
  final bool isPositive;    // 긍정적/부정적
  final bool isMissing;     // 사용자 정보 미입력

  const ProbabilityFactor({
    required this.category,
    required this.title,
    required this.description,
    required this.score,
    required this.maxScore,
    this.isPositive = true,
    this.isMissing = false,
  });

  double get ratio => maxScore > 0 ? score / maxScore : 0;
}

/// AI 당첨확률
class WinProbability {
  final double percentage;  // 0-100
  final String level;       // 매우높음/높음/보통/낮음/매우낮음
  final Color color;
  final List<String> factors;          // 기존 호환 (요약 텍스트)
  final List<ProbabilityFactor> details; // 상세 분석 항목
  final List<String> specialSupplyTypes; // 해당 특별공급 유형
  final bool isFirstPriority;           // 1순위 해당 여부
  final String selectionMethod;          // 선정 방식 (가점제/추첨제/혼합)

  const WinProbability({
    required this.percentage,
    required this.level,
    required this.color,
    required this.factors,
    this.details = const [],
    this.specialSupplyTypes = const [],
    this.isFirstPriority = false,
    this.selectionMethod = '',
  });
}

// ==================== 지역별 커트라인 / 경쟁률 참고 데이터 ====================

/// 지역별 평균 당첨 커트라인 (가점제, 85m² 이하 기준)
const Map<String, int> _regionalCutlines = {
  '서울': 62, '경기': 55, '인천': 48,
  '부산': 45, '대구': 42, '광주': 38,
  '대전': 40, '울산': 35, '세종': 50,
  '강원': 28, '충북': 30, '충남': 32,
  '전북': 25, '전남': 22, '경북': 28,
  '경남': 32, '제주': 35,
};

/// 지역별 평균 경쟁률 (최근 추이 기반 추정)
const Map<String, double> _regionalCompetition = {
  '서울': 45.0, '경기': 25.0, '인천': 18.0,
  '부산': 15.0, '대구': 12.0, '광주': 8.0,
  '대전': 10.0, '울산': 7.0, '세종': 30.0,
  '강원': 5.0, '충북': 6.0, '충남': 7.0,
  '전북': 4.0, '전남': 3.0, '경북': 5.0,
  '경남': 8.0, '제주': 10.0,
};

/// 투기과열지구 (2024 기준)
const Set<String> _speculationOverheatAreas = {'서울', '세종'};

/// 청약과열지역 (조정대상지역)
const Set<String> _adjustmentAreas = {'서울', '경기', '인천', '세종'};

/// 수도권 여부
bool _isMetro(String region) =>
    region.startsWith('서울') || region.startsWith('경기') || region.startsWith('인천');

/// 지역 키 추출 (2글자)
String _regionKey(String region) {
  if (region.length >= 2) return region.substring(0, 2);
  return region;
}

// ==================== 1순위 자격 판정 ====================

class _FirstPriorityResult {
  final bool qualified;
  final String reason;
  final double score; // 0~1

  const _FirstPriorityResult(this.qualified, this.reason, this.score);
}

_FirstPriorityResult _checkFirstPriority({
  required SubscriptionInfo sub,
  required UserProfile? profile,
  required String userRegion,
}) {
  if (profile == null) {
    return const _FirstPriorityResult(false, '프로필 미입력으로 판단 불가', 0.3);
  }

  final isNational = sub.houseDtlSecdNm == '국민';
  final subRegionKey = _regionKey(sub.subscrptAreaCodeNm);
  final isSpeculationArea = _speculationOverheatAreas.contains(subRegionKey);
  final isAdjustmentArea = _adjustmentAreas.contains(subRegionKey);

  // 무주택 확인
  final noHouseYears = profile.noHouseYears ?? 0;
  if (noHouseYears <= 0) {
    return const _FirstPriorityResult(false, '무주택 기간 없음 (1순위 불가)', 0.0);
  }

  // 세대주 확인 (투기과열/조정대상지역)
  if (isSpeculationArea || isAdjustmentArea) {
    if (profile.isHouseHolder != true) {
      return _FirstPriorityResult(false, '${isSpeculationArea ? "투기과열지구" : "조정대상지역"}에서 세대주만 1순위 가능', 0.1);
    }
  }

  // 통장 가입기간 확인
  final accountYears = profile.accountYears ?? 0;
  int requiredMonths;
  if (isSpeculationArea) {
    requiredMonths = AppConstants.accountMonthsSpeculation;
  } else if (_isMetro(subRegionKey)) {
    requiredMonths = AppConstants.accountMonthsMetro;
  } else {
    requiredMonths = AppConstants.accountMonthsOther;
  }
  final accountMonths = accountYears * 12;
  if (accountMonths < requiredMonths) {
    return _FirstPriorityResult(false, '통장 가입기간 부족 (${accountMonths}개월/${requiredMonths}개월 필요)', 0.2);
  }

  // 납입횟수 확인 (국민주택)
  if (isNational) {
    final depositCount = profile.depositCount ?? 0;
    int requiredDeposit;
    if (_isMetro(subRegionKey)) {
      requiredDeposit = AppConstants.depositCountMetro;
    } else {
      requiredDeposit = AppConstants.depositCountOther;
    }
    if (depositCount < requiredDeposit) {
      return _FirstPriorityResult(false, '납입횟수 부족 (${depositCount}회/${requiredDeposit}회 필요)', 0.3);
    }
  }

  return const _FirstPriorityResult(true, '1순위 자격 충족', 1.0);
}

// ==================== 특별공급 해당 여부 ====================

List<String> _checkSpecialSupply({
  required UserProfile? profile,
  required List<SubscriptionUnitType> units,
}) {
  if (profile == null) return [];
  final types = <String>[];

  final hasSpecial = units.any((u) => u.specialCount > 0);
  if (!hasSpecial) return [];

  // 신혼부부
  if (profile.isMarried == true && units.any((u) => u.newlyWedCount > 0)) {
    types.add('신혼부부');
  }

  // 생애최초 (무주택 + 혼인 또는 미혼이어도 가능하지만 소득 기준 필요)
  if ((profile.noHouseYears ?? 0) > 0 && units.any((u) => u.firstLifeCount > 0)) {
    types.add('생애최초');
  }

  // 다자녀 (부양가족 3명 이상 → 미성년 자녀 3명으로 추정)
  if ((profile.dependents ?? 0) >= 3 && units.any((u) => u.multiChildCount > 0)) {
    types.add('다자녀');
  }

  // 노부모부양 (세대주 + 직계존속 3년 이상 부양 → 부양가족 수로 추정)
  if (profile.isHouseHolder == true &&
      (profile.dependents ?? 0) >= 1 &&
      units.any((u) => u.oldParentCount > 0)) {
    types.add('노부모부양');
  }

  return types;
}

// ==================== 선정 방식 판정 ====================

String _selectionMethod(SubscriptionInfo sub) {
  final isNational = sub.houseDtlSecdNm == '국민';
  final subRegionKey = _regionKey(sub.subscrptAreaCodeNm);
  final isSpeculation = _speculationOverheatAreas.contains(subRegionKey);

  if (isNational) return '순차제 (납입횟수)';
  if (isSpeculation) return '가점제 100%';
  if (_adjustmentAreas.contains(subRegionKey)) return '가점제 75% + 추첨제 25%';
  return '가점제 40% + 추첨제 60%';
}

// ==================== 메인 당첨확률 계산 ====================

WinProbability calculateWinProbability({
  required int? userScore,
  required SubscriptionInfo sub,
  required List<SubscriptionUnitType> units,
  required String userRegion,
  UserProfile? userProfile,
}) {
  final details = <ProbabilityFactor>[];
  final factors = <String>[];
  double totalScore = 0;
  const totalMax = 100.0;

  final subRegionKey = _regionKey(sub.subscrptAreaCodeNm);
  final userRegionKey = userRegion.isNotEmpty ? _regionKey(userRegion) : '';
  final isNational = sub.houseDtlSecdNm == '국민';
  final selMethod = _selectionMethod(sub);

  // ── 1. 가점 커트라인 대비 분석 (25점) ──
  {
    const maxPts = 25.0;
    final cutline = _regionalCutlines[subRegionKey] ?? 40;

    if (userScore != null) {
      final diff = userScore - cutline;
      double pts;
      String desc;

      if (diff >= 15) {
        pts = maxPts;
        desc = '가점 $userScore점 — $subRegionKey 평균 커트라인($cutline점) 대비 +${diff}점 (상위권)';
      } else if (diff >= 5) {
        pts = maxPts * 0.8;
        desc = '가점 $userScore점 — 커트라인($cutline점) 소폭 상회 (+${diff}점)';
      } else if (diff >= 0) {
        pts = maxPts * 0.6;
        desc = '가점 $userScore점 — 커트라인($cutline점) 근접 (경쟁 치열)';
      } else if (diff >= -10) {
        pts = maxPts * 0.3;
        desc = '가점 $userScore점 — 커트라인($cutline점) 미달 (${diff}점)';
      } else {
        pts = maxPts * 0.1;
        desc = '가점 $userScore점 — 커트라인($cutline점) 크게 미달 (${diff}점)';
      }

      details.add(ProbabilityFactor(
        category: '가점 분석', title: '커트라인 대비',
        description: desc, score: pts, maxScore: maxPts,
        isPositive: diff >= 0,
      ));
      factors.add(desc);
      totalScore += pts;
    } else {
      details.add(ProbabilityFactor(
        category: '가점 분석', title: '가점 미입력',
        description: '가점 정보를 입력하면 더 정확한 분석이 가능해요 ($subRegionKey 커트라인: $cutline점)',
        score: maxPts * 0.3, maxScore: maxPts,
        isMissing: true,
      ));
      factors.add('가점 미입력 — $subRegionKey 커트라인 $cutline점 참고');
      totalScore += maxPts * 0.3;
    }
  }

  // ── 2. 1순위 자격 충족 여부 (20점) ──
  {
    const maxPts = 20.0;
    final result = _checkFirstPriority(
      sub: sub, profile: userProfile, userRegion: userRegion,
    );
    final pts = maxPts * result.score;

    details.add(ProbabilityFactor(
      category: '자격 분석', title: '1순위 자격',
      description: result.reason,
      score: pts, maxScore: maxPts,
      isPositive: result.qualified,
      isMissing: userProfile == null,
    ));
    if (!result.qualified) factors.add(result.reason);
    if (result.qualified) factors.add('1순위 자격 충족');
    totalScore += pts;
  }

  // ── 3. 지역 우선순위 (15점) ──
  {
    const maxPts = 15.0;
    double pts;
    String desc;

    if (userRegionKey.isEmpty) {
      pts = maxPts * 0.4;
      desc = '거주지역 미설정 — 설정에서 관심지역을 등록해주세요';
      details.add(ProbabilityFactor(
        category: '지역 분석', title: '지역 우선순위',
        description: desc, score: pts, maxScore: maxPts,
        isMissing: true,
      ));
    } else if (userRegionKey == subRegionKey) {
      pts = maxPts;
      desc = '해당지역 거주 — 1순위 우선 배정 (100% 물량)';
      details.add(ProbabilityFactor(
        category: '지역 분석', title: '해당지역 거주',
        description: desc, score: pts, maxScore: maxPts,
      ));
    } else if (_isMetro(userRegionKey) && _isMetro(subRegionKey)) {
      pts = maxPts * 0.6;
      desc = '기타수도권 거주 — 해당지역 미달 시 잔여 물량 배정';
      details.add(ProbabilityFactor(
        category: '지역 분석', title: '기타수도권',
        description: desc, score: pts, maxScore: maxPts,
        isPositive: false,
      ));
    } else {
      pts = maxPts * 0.2;
      desc = '기타지역 거주 — 3순위 이후 잔여 물량만 배정 가능';
      details.add(ProbabilityFactor(
        category: '지역 분석', title: '기타지역',
        description: desc, score: pts, maxScore: maxPts,
        isPositive: false,
      ));
    }
    factors.add(desc);
    totalScore += pts;
  }

  // ── 4. 공급세대수 & 예상 경쟁률 (15점) ──
  {
    const maxPts = 15.0;
    final totalUnits = sub.totalSupply;
    final estCompetition = _regionalCompetition[subRegionKey] ?? 10.0;

    // 세대수 기반 기본 점수
    double sizePts;
    if (totalUnits >= 1500) {
      sizePts = 1.0;
    } else if (totalUnits >= 800) {
      sizePts = 0.8;
    } else if (totalUnits >= 400) {
      sizePts = 0.6;
    } else if (totalUnits >= 150) {
      sizePts = 0.4;
    } else {
      sizePts = 0.2;
    }

    // 경쟁률 보정 (경쟁률 낮을수록 유리)
    double compAdj;
    if (estCompetition <= 5) {
      compAdj = 1.0;
    } else if (estCompetition <= 15) {
      compAdj = 0.8;
    } else if (estCompetition <= 30) {
      compAdj = 0.5;
    } else {
      compAdj = 0.3;
    }

    final combined = (sizePts * 0.5 + compAdj * 0.5);
    final pts = maxPts * combined;

    final desc = '$totalUnits세대 · $subRegionKey 평균 경쟁률 ${estCompetition.toStringAsFixed(0)}:1 추정';
    details.add(ProbabilityFactor(
      category: '경쟁 분석', title: '공급규모 & 경쟁률',
      description: desc, score: pts, maxScore: maxPts,
      isPositive: combined >= 0.5,
    ));
    factors.add(desc);
    totalScore += pts;
  }

  // ── 5. 특별공급 해당 여부 (10점) ──
  {
    const maxPts = 10.0;
    final specialTypes = _checkSpecialSupply(profile: userProfile, units: units);

    if (userProfile == null) {
      details.add(ProbabilityFactor(
        category: '특별공급', title: '특별공급 분석',
        description: '프로필 정보를 입력하면 특별공급 해당 여부를 분석해드려요',
        score: maxPts * 0.3, maxScore: maxPts,
        isMissing: true,
      ));
      totalScore += maxPts * 0.3;
    } else if (specialTypes.isNotEmpty) {
      final pts = maxPts;
      final desc = '${specialTypes.join(", ")} 특별공급 신청 가능';
      details.add(ProbabilityFactor(
        category: '특별공급', title: '특별공급 해당',
        description: '$desc (일반공급과 별도 경쟁)',
        score: pts, maxScore: maxPts,
      ));
      factors.add(desc);
      totalScore += pts;
    } else {
      final hasSpecialUnits = units.any((u) => u.specialCount > 0);
      final desc = hasSpecialUnits
          ? '해당 특별공급 유형 없음 — 일반공급으로 접수'
          : '특별공급 물량 없음';
      details.add(ProbabilityFactor(
        category: '특별공급', title: '일반공급 대상',
        description: desc, score: 0, maxScore: maxPts,
        isPositive: false,
      ));
      totalScore += 0;
    }
  }

  // ── 6. 선정방식 유불리 (8점) ──
  {
    const maxPts = 8.0;
    double pts;
    String desc;

    if (isNational) {
      // 국민주택: 순차제 → 납입횟수 많으면 유리
      final depositCount = userProfile?.depositCount ?? 0;
      if (depositCount >= 120) {
        pts = maxPts;
        desc = '순차제 — 납입 ${depositCount}회로 상위권';
      } else if (depositCount >= 60) {
        pts = maxPts * 0.6;
        desc = '순차제 — 납입 ${depositCount}회로 중위권';
      } else if (depositCount > 0) {
        pts = maxPts * 0.3;
        desc = '순차제 — 납입 ${depositCount}회로 하위권';
      } else {
        pts = maxPts * 0.2;
        desc = '순차제 (납입횟수 기준) — 납입 정보 미입력';
      }
    } else {
      // 민영주택: 가점제 or 추첨제
      final hasHighScore = (userScore ?? 0) >= (_regionalCutlines[subRegionKey] ?? 40);
      if (selMethod.contains('100%')) {
        pts = hasHighScore ? maxPts : maxPts * 0.3;
        desc = '가점제 100% — ${hasHighScore ? "가점 높아 유리" : "가점 부족 시 불리"}';
      } else if (selMethod.contains('75%')) {
        pts = hasHighScore ? maxPts * 0.8 : maxPts * 0.5;
        desc = '가점제 75% + 추첨 25% — ${hasHighScore ? "가점제 유리" : "추첨 기대 가능"}';
      } else {
        pts = hasHighScore ? maxPts * 0.6 : maxPts * 0.7;
        desc = '가점제 40% + 추첨 60% — ${hasHighScore ? "가점+추첨 모두 기회" : "추첨 비중 높아 기회 있음"}';
      }
    }

    details.add(ProbabilityFactor(
      category: '선정방식', title: selMethod,
      description: desc, score: pts, maxScore: maxPts,
      isPositive: pts >= maxPts * 0.5,
    ));
    factors.add(desc);
    totalScore += pts;
  }

  // ── 7. 분양가 매력도 (5점) ──
  {
    const maxPts = 5.0;
    if (units.isNotEmpty) {
      final avgPrice = units.map((u) => u.topAmount).reduce((a, b) => a + b) / units.length;
      double pts;
      String desc;

      // 분양가 높을수록 경쟁 완화
      if (avgPrice >= 120000) {
        pts = maxPts;
        desc = '고분양가 (평균 ${(avgPrice / 10000).toStringAsFixed(1)}억) — 경쟁 완화 예상';
      } else if (avgPrice >= 70000) {
        pts = maxPts * 0.7;
        desc = '중고가 (평균 ${(avgPrice / 10000).toStringAsFixed(1)}억) — 보통 경쟁';
      } else if (avgPrice >= 40000) {
        pts = maxPts * 0.4;
        desc = '중저가 (평균 ${(avgPrice / 10000).toStringAsFixed(1)}억) — 높은 경쟁 예상';
      } else {
        pts = maxPts * 0.2;
        desc = '저분양가 (평균 ${(avgPrice / 10000).toStringAsFixed(1)}억) — 매우 높은 경쟁 예상';
      }

      details.add(ProbabilityFactor(
        category: '분양가 분석', title: '분양가 매력도',
        description: desc, score: pts, maxScore: maxPts,
        isPositive: pts >= maxPts * 0.5,
      ));
      factors.add(desc);
      totalScore += pts;
    } else {
      details.add(ProbabilityFactor(
        category: '분양가 분석', title: '분양가 정보 없음',
        description: '평형 정보 로딩 후 분석 가능',
        score: maxPts * 0.3, maxScore: maxPts,
        isMissing: true,
      ));
      totalScore += maxPts * 0.3;
    }
  }

  // ── 8. 프로필 완성도 보너스 (2점) ──
  {
    const maxPts = 2.0;
    if (userProfile != null) {
      int filled = 0;
      if (userProfile.noHouseYears != null) filled++;
      if (userProfile.dependents != null) filled++;
      if (userProfile.accountYears != null) filled++;
      if (userProfile.depositCount != null) filled++;
      if (userProfile.isHouseHolder != null) filled++;
      if (userProfile.isMarried != null) filled++;

      final ratio = filled / 6.0;
      final pts = maxPts * ratio;
      final pct = (ratio * 100).toStringAsFixed(0);
      details.add(ProbabilityFactor(
        category: '프로필', title: '프로필 완성도 $pct%',
        description: filled == 6 ? '모든 청약 정보 입력 완료' : '미입력 항목이 있어 정확도가 낮아요 ($filled/6)',
        score: pts, maxScore: maxPts,
        isPositive: ratio >= 0.8,
        isMissing: ratio < 0.5,
      ));
      totalScore += pts;
    } else {
      details.add(ProbabilityFactor(
        category: '프로필', title: '프로필 미등록',
        description: '회원가입 후 청약 정보를 입력하면 맞춤 분석이 가능해요',
        score: 0, maxScore: maxPts,
        isMissing: true,
      ));
    }
  }

  // ── 최종 결과 ──
  final clamped = totalScore.clamp(0.0, totalMax);
  final firstPriority = _checkFirstPriority(sub: sub, profile: userProfile, userRegion: userRegion);
  final specialTypes = _checkSpecialSupply(profile: userProfile, units: units);

  String level;
  Color color;
  if (clamped >= 75) {
    level = '매우 높음';
    color = AppColors.success;
  } else if (clamped >= 55) {
    level = '높음';
    color = const Color(0xFF22C55E);
  } else if (clamped >= 35) {
    level = '보통';
    color = AppColors.warning;
  } else if (clamped >= 20) {
    level = '낮음';
    color = const Color(0xFFEF4444);
  } else {
    level = '매우 낮음';
    color = AppColors.error;
  }

  return WinProbability(
    percentage: clamped,
    level: level,
    color: color,
    factors: factors,
    details: details,
    specialSupplyTypes: specialTypes,
    isFirstPriority: firstPriority.qualified,
    selectionMethod: selMethod,
  );
}

/// 간이 당첨확률 (카드용, 프로필 기반 경량 계산)
double quickWinScore(int? userScore, SubscriptionInfo sub, String userRegion, {UserProfile? profile}) {
  double score = 0;

  final subRegionKey = _regionKey(sub.subscrptAreaCodeNm);
  final userRegionKey = userRegion.isNotEmpty ? _regionKey(userRegion) : '';
  final cutline = _regionalCutlines[subRegionKey] ?? 40;
  final estCompetition = _regionalCompetition[subRegionKey] ?? 10.0;

  // 1. 가점 vs 커트라인 (30점)
  if (userScore != null) {
    final diff = userScore - cutline;
    if (diff >= 15) {
      score += 30;
    } else if (diff >= 5) {
      score += 24;
    } else if (diff >= 0) {
      score += 18;
    } else if (diff >= -10) {
      score += 10;
    } else {
      score += 4;
    }
  } else {
    score += 12;
  }

  // 2. 1순위 자격 (20점)
  if (profile != null) {
    final accountMonths = (profile.accountYears ?? 0) * 12;
    final requiredMonths = _isMetro(subRegionKey) ? 12 : 6;
    if ((profile.noHouseYears ?? 0) > 0 && accountMonths >= requiredMonths) {
      score += 20;
    } else if ((profile.noHouseYears ?? 0) > 0) {
      score += 10;
    } else {
      score += 2;
    }
  } else {
    score += 8;
  }

  // 3. 지역 일치 (15점)
  if (userRegionKey.isNotEmpty && userRegionKey == subRegionKey) {
    score += 15;
  } else if (_isMetro(userRegionKey) && _isMetro(subRegionKey)) {
    score += 9;
  } else if (userRegionKey.isEmpty) {
    score += 6;
  } else {
    score += 3;
  }

  // 4. 공급규모 & 경쟁률 (15점)
  final totalUnits = sub.totalSupply;
  double sizeScore = totalUnits >= 1000 ? 1.0 : totalUnits >= 400 ? 0.6 : 0.3;
  double compScore = estCompetition <= 10 ? 1.0 : estCompetition <= 25 ? 0.6 : 0.3;
  score += 15 * (sizeScore * 0.5 + compScore * 0.5);

  // 5. 선정방식 (10점)
  if (sub.houseDtlSecdNm == '국민') {
    score += 5;
  } else {
    final isSpeculation = _speculationOverheatAreas.contains(subRegionKey);
    if (isSpeculation) {
      score += (userScore ?? 0) >= cutline ? 10 : 3;
    } else {
      score += 6; // 추첨 비중이 있으므로 중간
    }
  }

  // 6. 특별공급 보너스 (10점)
  if (profile != null) {
    if (profile.isMarried == true) score += 4;
    if ((profile.dependents ?? 0) >= 3) score += 4;
    if ((profile.noHouseYears ?? 0) > 0) score += 2;
  } else {
    score += 3;
  }

  return score.clamp(0, 100);
}

/// 당첨확률 Provider (상세 화면용)
final winProbabilityProvider = Provider.family<WinProbability, ({SubscriptionInfo sub, List<SubscriptionUnitType> units})>((ref, params) {
  final userScore = ref.watch(effectiveScoreProvider);
  final prefs = ref.watch(userPreferencesProvider);
  final profile = ref.watch(userProfileProvider);
  return calculateWinProbability(
    userScore: userScore,
    sub: params.sub,
    units: params.units,
    userRegion: prefs.region,
    userProfile: profile,
  );
});

/// 청약 정보 모델 (공공데이터포털 odcloud API 기반)
class SubscriptionInfo {
  final String houseNm;              // 단지명
  final String houseSecdNm;          // 주택구분 (APT 등)
  final String houseDtlSecdNm;       // 주택상세구분 (민영/국민)
  final String hssplyAdres;          // 공급위치 주소
  final String subscrptAreaCodeNm;   // 공급지역
  final int totSuplyHshldco;         // 총공급세대수
  final String? rcritPblancDe;       // 모집공고일
  final String? rceptBgnde;          // 접수시작일
  final String? rceptEndde;          // 접수종료일
  final String? spsplyRceptBgnde;    // 특별공급접수시작
  final String? spsplyRceptEndde;    // 특별공급접수종료
  final String? gnrlRnk1CrspareaRcptde; // 1순위접수일
  final String? gnrlRnk2CrspareaRcptde; // 2순위접수일
  final String? przwnerPresnatnDe;   // 당첨자발표일
  final String? cntrctCnclsBgnde;    // 계약시작일
  final String? cntrctCnclsEndde;    // 계약종료일
  final String? mvnPrearngeYm;       // 입주예정월
  final String? pblancUrl;           // 청약홈 상세 URL
  final String? houseManageNo;       // 주택관리번호
  final String? pblancNo;            // 공고번호
  final String? bsnsMbyNm;           // 사업주체
  final String? cnstrctEntrpsNm;     // 시공사
  final String? rentSecdNm;          // 분양/임대 구분

  const SubscriptionInfo({
    required this.houseNm,
    required this.houseSecdNm,
    required this.houseDtlSecdNm,
    required this.hssplyAdres,
    required this.subscrptAreaCodeNm,
    required this.totSuplyHshldco,
    this.rcritPblancDe,
    this.rceptBgnde,
    this.rceptEndde,
    this.spsplyRceptBgnde,
    this.spsplyRceptEndde,
    this.gnrlRnk1CrspareaRcptde,
    this.gnrlRnk2CrspareaRcptde,
    this.przwnerPresnatnDe,
    this.cntrctCnclsBgnde,
    this.cntrctCnclsEndde,
    this.mvnPrearngeYm,
    this.pblancUrl,
    this.houseManageNo,
    this.pblancNo,
    this.bsnsMbyNm,
    this.cnstrctEntrpsNm,
    this.rentSecdNm,
  });

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) {
    return SubscriptionInfo(
      houseNm: json['HOUSE_NM']?.toString() ?? '',
      houseSecdNm: json['HOUSE_SECD_NM']?.toString() ?? '',
      houseDtlSecdNm: json['HOUSE_DTL_SECD_NM']?.toString() ?? '',
      hssplyAdres: json['HSSPLY_ADRES']?.toString() ?? '',
      subscrptAreaCodeNm: json['SUBSCRPT_AREA_CODE_NM']?.toString() ?? '',
      totSuplyHshldco: _parseInt(json['TOT_SUPLY_HSHLDCO']),
      rcritPblancDe: json['RCRIT_PBLANC_DE']?.toString(),
      rceptBgnde: json['RCEPT_BGNDE']?.toString(),
      rceptEndde: json['RCEPT_ENDDE']?.toString(),
      spsplyRceptBgnde: json['SPSPLY_RCEPT_BGNDE']?.toString(),
      spsplyRceptEndde: json['SPSPLY_RCEPT_ENDDE']?.toString(),
      gnrlRnk1CrspareaRcptde: json['GNRL_RNK1_CRSPAREA_RCPTDE']?.toString(),
      gnrlRnk2CrspareaRcptde: json['GNRL_RNK2_CRSPAREA_RCPTDE']?.toString(),
      przwnerPresnatnDe: json['PRZWNER_PRESNATN_DE']?.toString(),
      cntrctCnclsBgnde: json['CNTRCT_CNCLS_BGNDE']?.toString(),
      cntrctCnclsEndde: json['CNTRCT_CNCLS_ENDDE']?.toString(),
      mvnPrearngeYm: json['MVN_PREARNGE_YM']?.toString(),
      pblancUrl: json['PBLANC_URL']?.toString(),
      houseManageNo: json['HOUSE_MANAGE_NO']?.toString(),
      pblancNo: json['PBLANC_NO']?.toString(),
      bsnsMbyNm: json['BSNS_MBY_NM']?.toString(),
      cnstrctEntrpsNm: json['CNSTRCT_ENTRPS_NM']?.toString(),
      rentSecdNm: json['RENT_SECD_NM']?.toString(),
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  // --- Convenience getters ---

  /// 단지명
  String get name => houseNm;

  /// 공급위치 (주소 또는 지역명)
  String get location => hssplyAdres.isNotEmpty ? hssplyAdres : subscrptAreaCodeNm;

  /// 주택구분
  String get houseDivision => houseSecdNm;

  /// 총공급세대수
  int get totalSupply => totSuplyHshldco;

  // --- Date parsing ---

  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty || value == 'null') return null;
    try {
      final cleaned = value.replaceAll('-', '');
      if (cleaned.length == 8) {
        return DateTime(
          int.parse(cleaned.substring(0, 4)),
          int.parse(cleaned.substring(4, 6)),
          int.parse(cleaned.substring(6, 8)),
        );
      }
      return DateTime.tryParse(value);
    } catch (_) {
      return null;
    }
  }

  DateTime? get announcementDate => _parseDate(rcritPblancDe);
  DateTime? get receptionStart => _parseDate(rceptBgnde);
  DateTime? get receptionEnd => _parseDate(rceptEndde);
  DateTime? get specialSupplyStart => _parseDate(spsplyRceptBgnde);
  DateTime? get specialSupplyEnd => _parseDate(spsplyRceptEndde);
  DateTime? get rank1Date => _parseDate(gnrlRnk1CrspareaRcptde);
  DateTime? get rank2Date => _parseDate(gnrlRnk2CrspareaRcptde);
  DateTime? get winnerDate => _parseDate(przwnerPresnatnDe);
  DateTime? get contractStart => _parseDate(cntrctCnclsBgnde);
  DateTime? get contractEnd => _parseDate(cntrctCnclsEndde);

  /// 입주예정월 (YYYYMM 형식)
  String get moveInMonth {
    if (mvnPrearngeYm == null || mvnPrearngeYm!.isEmpty || mvnPrearngeYm == 'null') return '-';
    final s = mvnPrearngeYm!;
    if (s.length >= 6) {
      return '${s.substring(0, 4)}년 ${s.substring(4, 6)}월';
    }
    return s;
  }

  // --- Status computation ---

  /// 상태 계산 (세분화)
  String get status {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 당첨자 발표 완료
    if (winnerDate != null && !today.isBefore(winnerDate!)) {
      return '발표완료';
    }

    // 접수 종료 후 -> 발표 예정
    if (receptionEnd != null && today.isAfter(receptionEnd!)) {
      if (winnerDate != null && today.isBefore(winnerDate!)) {
        return '발표예정';
      }
      return '접수마감';
    }

    // 2순위 접수중
    if (rank2Date != null && _isToday(rank2Date!)) {
      return '2순위접수중';
    }

    // 1순위 접수중
    if (rank1Date != null && _isToday(rank1Date!)) {
      return '1순위접수중';
    }

    // 특별공급 접수중
    if (specialSupplyStart != null && specialSupplyEnd != null) {
      if (!today.isBefore(specialSupplyStart!) && !today.isAfter(specialSupplyEnd!)) {
        return '특별공급접수중';
      }
    }

    // 일반 접수중
    if (receptionStart != null && receptionEnd != null) {
      if (!today.isBefore(receptionStart!) && !today.isAfter(receptionEnd!)) {
        return '접수중';
      }
    }

    return '공고중';
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  /// 필터 카테고리
  String get filterCategory {
    final s = status;
    if (s == '공고중') return '접수예정';
    if (s.contains('접수') && s != '접수마감') return '접수중';
    return '마감';
  }

  /// D-Day 계산 (가장 가까운 미래 일정 기준)
  int get dDay {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 가장 가까운 미래 날짜 찾기
    final futureDates = <DateTime>[
      if (specialSupplyStart != null && today.isBefore(specialSupplyStart!)) specialSupplyStart!,
      if (receptionStart != null && today.isBefore(receptionStart!)) receptionStart!,
      if (rank1Date != null && today.isBefore(rank1Date!)) rank1Date!,
      if (rank2Date != null && today.isBefore(rank2Date!)) rank2Date!,
      if (receptionEnd != null && !today.isAfter(receptionEnd!)) receptionEnd!,
      if (winnerDate != null && today.isBefore(winnerDate!)) winnerDate!,
    ];

    if (futureDates.isEmpty) return -1;

    futureDates.sort();
    return futureDates.first.difference(today).inDays;
  }

  /// 상태별 색상
  Color get statusColor {
    switch (status) {
      case '공고중':
        return AppColors.success;
      case '특별공급접수중':
        return const Color(0xFF8B5CF6); // purple
      case '1순위접수중':
        return AppColors.primary;
      case '2순위접수중':
        return AppColors.primaryLight;
      case '접수중':
        return AppColors.primary;
      case '접수마감':
        return AppColors.gray500;
      case '발표예정':
        return AppColors.warning;
      case '발표완료':
        return AppColors.gray500;
      default:
        return AppColors.gray500;
    }
  }

  /// 접수기간 포맷
  String get receptionPeriod {
    final start = receptionStart != null ? _formatDate(receptionStart!) : '-';
    final end = receptionEnd != null ? _formatDate(receptionEnd!) : '-';
    return '$start ~ $end';
  }

  /// 당첨자발표일 포맷
  String get winnerDateFormatted {
    return winnerDate != null ? _formatDate(winnerDate!) : '-';
  }

  static String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  /// 상태에 따라 표시할 주요 일정 텍스트
  String get relevantDateLabel {
    final s = status;
    if (s == '공고중') return '접수시작';
    if (s.contains('접수') && s != '접수마감') return '접수마감';
    if (s == '발표예정') return '당첨발표';
    return '접수기간';
  }

  String get relevantDateValue {
    final s = status;
    if (s == '공고중') {
      return receptionStart != null ? _formatDate(receptionStart!) : '-';
    }
    if (s.contains('접수') && s != '접수마감') {
      return receptionEnd != null ? _formatDate(receptionEnd!) : '-';
    }
    if (s == '발표예정') {
      return winnerDate != null ? _formatDate(winnerDate!) : '-';
    }
    return receptionPeriod;
  }
}

/// APT 경쟁률 모델 (추후 사용)
class SubscriptionCompetition {
  final String houseManageNo;
  final String pblancNo;
  final String houseTy;          // 주택형
  final int suplyHshldco;        // 공급세대수
  final int rceptCnt;            // 접수건수
  final double competitionRate;  // 경쟁률

  const SubscriptionCompetition({
    required this.houseManageNo,
    required this.pblancNo,
    required this.houseTy,
    required this.suplyHshldco,
    required this.rceptCnt,
    required this.competitionRate,
  });

  factory SubscriptionCompetition.fromJson(Map<String, dynamic> json) {
    final supply = int.tryParse(json['SUPLY_HSHLDCO']?.toString() ?? '') ?? 0;
    final receipt = int.tryParse(json['RCEPT_CNT']?.toString() ?? '') ?? 0;
    return SubscriptionCompetition(
      houseManageNo: json['HOUSE_MANAGE_NO']?.toString() ?? '',
      pblancNo: json['PBLANC_NO']?.toString() ?? '',
      houseTy: json['HOUSE_TY']?.toString() ?? '',
      suplyHshldco: supply,
      rceptCnt: receipt,
      competitionRate: supply > 0 ? receipt / supply : 0,
    );
  }
}

/// 청약 목록 (API 연동, 원본 데이터 — 캐시 유지)
final subscriptionListProvider = FutureProvider<List<SubscriptionInfo>>((ref) async {
  final api = ref.read(subscriptionApiProvider);
  final list = await api.getSubscriptions();

  // 모집공고일 기준 최신순 정렬
  list.sort((a, b) {
    final aDate = a.announcementDate ?? DateTime(2000);
    final bDate = b.announcementDate ?? DateTime(2000);
    return bDate.compareTo(aDate);
  });

  return list;
});

/// 필터 + 정렬이 적용된 청약 목록
final filteredSubscriptionListProvider = Provider.autoDispose<AsyncValue<List<SubscriptionInfo>>>((ref) {
  final listAsync = ref.watch(subscriptionListProvider);
  final filter = ref.watch(subscriptionFilterProvider);
  final userScore = ref.watch(effectiveScoreProvider);
  final prefs = ref.watch(userPreferencesProvider);
  final profile = ref.watch(userProfileProvider);

  return listAsync.whenData((list) {
    // 필터링
    var filtered = list.where((sub) {
      // 청약상태 필터
      if (filter.statuses.isNotEmpty) {
        final category = sub.filterCategory;
        final statusStr = sub.status;
        bool matches = false;
        for (final s in filter.statuses) {
          if (s == SubscriptionStatusFilter.all) {
            matches = true;
            break;
          }
          if (s == SubscriptionStatusFilter.upcoming && category == '접수예정') matches = true;
          if (s == SubscriptionStatusFilter.accepting && category == '접수중') matches = true;
          if (s == SubscriptionStatusFilter.closed && category == '마감') matches = true;
          if (s == SubscriptionStatusFilter.announced && (statusStr == '발표완료' || statusStr == '발표예정')) matches = true;
        }
        if (!matches) return false;
      }

      // 지역 필터
      if (filter.region.isNotEmpty) {
        if (!sub.subscrptAreaCodeNm.contains(filter.region.substring(0, min(2, filter.region.length)))) {
          return false;
        }
      }

      // 주택유형 필터
      if (filter.housingType != HousingTypeFilter.all) {
        if (sub.houseDtlSecdNm != filter.housingType.label) return false;
      }

      // 세대수 필터
      if (filter.householdsMin != null && sub.totalSupply < filter.householdsMin!) return false;
      if (filter.householdsMax != null && sub.totalSupply > filter.householdsMax!) return false;

      // 상세: 시공사
      if (filter.constructor != null && filter.constructor!.isNotEmpty) {
        final searchTerm = filter.constructor!.toLowerCase();
        final constructorName = (sub.cnstrctEntrpsNm ?? '').toLowerCase();
        final businessName = (sub.bsnsMbyNm ?? '').toLowerCase();
        if (!constructorName.contains(searchTerm) && !businessName.contains(searchTerm)) {
          return false;
        }
      }

      // 상세: 입주예정일
      if (filter.moveInYearMin != null) {
        final moveIn = sub.mvnPrearngeYm ?? '';
        if (moveIn.isEmpty || moveIn.compareTo(filter.moveInYearMin!) < 0) return false;
      }
      if (filter.moveInYearMax != null) {
        final moveIn = sub.mvnPrearngeYm ?? '';
        if (moveIn.isEmpty || moveIn.compareTo(filter.moveInYearMax!) > 0) return false;
      }

      // 상세: 분양/임대
      if (filter.rentType != null && filter.rentType!.isNotEmpty) {
        if (sub.rentSecdNm != filter.rentType) return false;
      }

      return true;
    }).toList();

    // 정렬
    switch (filter.sortType) {
      case SubscriptionSortType.aiRecommend:
        filtered.sort((a, b) {
          final aScore = quickWinScore(userScore, a, prefs.region, profile: profile);
          final bScore = quickWinScore(userScore, b, prefs.region, profile: profile);
          return bScore.compareTo(aScore);
        });
        break;
      case SubscriptionSortType.dateAsc:
        filtered.sort((a, b) {
          final aDate = a.receptionStart ?? a.announcementDate ?? DateTime(2099);
          final bDate = b.receptionStart ?? b.announcementDate ?? DateTime(2099);
          return aDate.compareTo(bDate);
        });
        break;
      case SubscriptionSortType.priceLow:
      case SubscriptionSortType.priceHigh:
        // 분양가는 unit type 필요 → 공고일 기준으로 대체
        filtered.sort((a, b) {
          final aDate = a.announcementDate ?? DateTime(2000);
          final bDate = b.announcementDate ?? DateTime(2000);
          return bDate.compareTo(aDate);
        });
        break;
      case SubscriptionSortType.competitionLow:
        // 경쟁률 데이터 없으면 세대수 큰 순 (경쟁 낮을 확률)
        filtered.sort((a, b) => b.totalSupply.compareTo(a.totalSupply));
        break;
      case SubscriptionSortType.householdsHigh:
        filtered.sort((a, b) => b.totalSupply.compareTo(a.totalSupply));
        break;
      case SubscriptionSortType.moveInSoon:
        filtered.sort((a, b) {
          final aMove = a.mvnPrearngeYm ?? '999999';
          final bMove = b.mvnPrearngeYm ?? '999999';
          return aMove.compareTo(bMove);
        });
        break;
    }

    return filtered;
  });
});

/// 페이지네이션을 위한 현재 페이지 수
final subscriptionPageProvider = StateProvider.autoDispose<int>((ref) => 1);

/// 페이지네이션된 청약 목록 (10개씩)
final paginatedSubscriptionListProvider = Provider.autoDispose<AsyncValue<List<SubscriptionInfo>>>((ref) {
  final filteredAsync = ref.watch(filteredSubscriptionListProvider);
  final page = ref.watch(subscriptionPageProvider);
  const pageSize = 10;

  return filteredAsync.whenData((list) {
    final end = (page * pageSize).clamp(0, list.length);
    return list.sublist(0, end);
  });
});

/// 더 불러올 항목이 있는지
final hasMoreSubscriptionsProvider = Provider.autoDispose<bool>((ref) {
  final filteredAsync = ref.watch(filteredSubscriptionListProvider);
  final page = ref.watch(subscriptionPageProvider);
  const pageSize = 10;

  return filteredAsync.whenOrNull(data: (list) => list.length > page * pageSize) ?? false;
});
