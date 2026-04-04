import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/region_codes.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/real_estate_api.dart';
import '../../../core/services/ai_price_estimator.dart';
import '../../../core/services/api_cache.dart';
import '../../../models/apartment_listing.dart';
import '../../../models/apartment_trade.dart';
import '../../../models/apartment_rent.dart';

/// 싱글턴 API + 캐시 인스턴스
final _api = RealEstateApi();
final _cache = ApiCache();

/// AI 추천 TOP 10 아파트 목록 Provider (실거래 API 기반)
final topListingsProvider = FutureProvider<List<ApartmentListing>>((ref) async {
  final now = DateTime.now();

  // 지역코드별로 그룹핑 (API 호출 최소화)
  final regionCodes = _aptConfigs.map((c) => c.regionCode).toSet();

  // 2개월치로 축소 (빠른 초기 응답)
  final months = <String>[];
  for (int i = 0; i < 2; i++) {
    final date = DateTime(now.year, now.month - i, 1);
    months.add('${date.year}${date.month.toString().padLeft(2, '0')}');
  }

  // 캐시 활용 + 병렬 호출 (스로틀링은 API 레벨에서)
  await _fetchAndCacheAll(regionCodes.toList(), months);

  // 캐시에서 데이터 수집
  final tradesByRegion = <String, List<ApartmentTrade>>{};
  final rentsByRegion = <String, List<ApartmentRent>>{};

  for (final code in regionCodes) {
    final trades = <ApartmentTrade>[];
    final rents = <ApartmentRent>[];
    for (final ym in months) {
      trades.addAll(_cache.getTrades(_cache.tradeKey(code, ym)) ?? []);
      rents.addAll(_cache.getRents(_cache.rentKey(code, ym)) ?? []);
    }
    tradesByRegion[code] = trades;
    rentsByRegion[code] = rents;
  }

  // 각 아파트별 AI 추정가 계산
  final listings = <ApartmentListing>[];

  for (final config in _aptConfigs) {
    final allTrades = tradesByRegion[config.regionCode] ?? [];
    final allRents = rentsByRegion[config.regionCode] ?? [];

    // 아파트명으로 필터링
    final aptTrades = allTrades.where((t) => t.aptName.contains(config.name) || config.name.contains(t.aptName)).toList();
    final aptRents = allRents.where((r) => r.aptName.contains(config.name) || config.name.contains(r.aptName)).toList();

    // 거래 이력 변환
    final tradeHistory = <TradeHistory>[
      ...aptTrades.map((t) => TradeHistory(
        date: t.dealDate, price: t.dealAmount, floor: t.floor, area: t.area,
      )),
      ...aptRents.where((r) => r.isJeonse).map((r) => TradeHistory(
        date: r.dealDate, price: r.deposit, floor: r.floor, area: r.area,
        type: TradeType.jeonse,
      )),
    ];

    // AI 추정가 계산
    final estimate = AiPriceEstimator.estimate(
      trades: aptTrades, rents: aptRents,
      buildYear: config.buildYear, floorAreaRatio: config.floorAreaRatio,
    );

    final currentPrice = estimate?.currentPrice ?? config.fallbackPrice;
    final aiEstimate = estimate?.estimatedPrice ?? config.fallbackPrice;
    final priceGap = estimate?.priceGap ?? 0.0;

    listings.add(ApartmentListing(
      name: config.name, location: config.location,
      currentPrice: currentPrice, aiEstimate: aiEstimate, priceGap: priceGap,
      floorAreaRatio: config.floorAreaRatio, buildYear: config.buildYear,
      regionCode: config.regionCode, units: config.units, tradeHistory: tradeHistory,
    ));
  }

  listings.sort((a, b) =>
      (b.aiEstimate - b.currentPrice).compareTo(a.aiEstimate - a.currentPrice));

  return listings;
});

/// 검색 결과에서 선택된 아파트 상세 리스팅 (직접 전달용)
final searchDetailListingProvider = StateProvider<ApartmentListing?>((ref) => null);

/// 지역별 평균 시세 (만원) — 캐시 활용
final regionAvgPriceProvider = FutureProvider.family<int, String>((ref, region) async {
  final now = DateTime.now();

  final regionCodes = region.isNotEmpty
      ? RegionCodes.getCodesForRegion(region)
      : [AppConstants.defaultRegionCode];
  if (regionCodes.isEmpty) return 0;
  final regionCode = regionCodes.first;

  final ym = '${now.year}${now.month.toString().padLeft(2, '0')}';

  try {
    // 캐시 확인
    final tKey = _cache.tradeKey(regionCode, ym);
    List<ApartmentTrade> trades;
    if (_cache.hasTrades(tKey)) {
      trades = _cache.getTrades(tKey) ?? [];
    } else {
      trades = await _api.getAptTrades(regionCode: regionCode, dealYmd: ym);
      _cache.putTrades(tKey, trades);
    }

    final validTrades = trades.where((t) => t.dealAmount > 0).toList();
    if (validTrades.isEmpty) {
      // 이번 달 거래 없으면 지난달 조회
      final prevDate = DateTime(now.year, now.month - 1, 1);
      final prevYm = '${prevDate.year}${prevDate.month.toString().padLeft(2, '0')}';
      final prevKey = _cache.tradeKey(regionCode, prevYm);

      List<ApartmentTrade> prevTrades;
      if (_cache.hasTrades(prevKey)) {
        prevTrades = _cache.getTrades(prevKey) ?? [];
      } else {
        prevTrades = await _api.getAptTrades(regionCode: regionCode, dealYmd: prevYm);
        _cache.putTrades(prevKey, prevTrades);
      }
      final prevValid = prevTrades.where((t) => t.dealAmount > 0).toList();
      if (prevValid.isEmpty) return 0;
      return prevValid.map((t) => t.dealAmount).reduce((a, b) => a + b) ~/ prevValid.length;
    }

    return validTrades.map((t) => t.dealAmount).reduce((a, b) => a + b) ~/ validTrades.length;
  } catch (_) {
    return 0;
  }
});

/// 최신 실거래 정보
class LatestTradeInfo {
  final String aptName;
  final int dealAmount;
  final DateTime dealDate;
  final double area;
  final int floor;
  final String regionCode;
  final String dong;

  const LatestTradeInfo({
    required this.aptName, required this.dealAmount, required this.dealDate,
    required this.area, required this.floor,
    this.regionCode = '', this.dong = '',
  });
}

/// 지역별 최신 실거래 내역 (캐시 활용)
final regionLatestTradesProvider = FutureProvider.family<List<LatestTradeInfo>, String>((ref, region) async {
  final now = DateTime.now();

  final regionCodes = region.isNotEmpty
      ? RegionCodes.getCodesForRegion(region)
      : [AppConstants.defaultRegionCode];

  if (regionCodes.isEmpty) return [];

  // 최대 5개 구만 조회
  final codesToFetch = regionCodes.length > AppConstants.homeLatestTradeLimit
      ? regionCodes.sublist(0, AppConstants.homeLatestTradeLimit)
      : regionCodes;

  final ym = '${now.year}${now.month.toString().padLeft(2, '0')}';
  final prevDate = DateTime(now.year, now.month - 1, 1);
  final prevYm = '${prevDate.year}${prevDate.month.toString().padLeft(2, '0')}';

  try {
    final allTrades = <ApartmentTrade>[];

    // 캐시 활용 + 병렬 조회 (개별 에러 격리)
    final futures = codesToFetch.map((code) async {
      try {
        final tKey = _cache.tradeKey(code, ym);
        List<ApartmentTrade> trades;
        if (_cache.hasTrades(tKey)) {
          trades = _cache.getTrades(tKey) ?? [];
        } else {
          trades = await _api.getAptTrades(regionCode: code, dealYmd: ym);
          _cache.putTrades(tKey, trades);
        }

        if (!trades.any((t) => t.dealAmount > 0)) {
          final prevKey = _cache.tradeKey(code, prevYm);
          if (_cache.hasTrades(prevKey)) {
            trades = _cache.getTrades(prevKey) ?? [];
          } else {
            trades = await _api.getAptTrades(regionCode: code, dealYmd: prevYm);
            _cache.putTrades(prevKey, trades);
          }
        }
        return trades;
      } catch (_) {
        return <ApartmentTrade>[];
      }
    });

    final results = await Future.wait(futures);
    for (final trades in results) {
      allTrades.addAll(trades.where((t) => t.dealAmount > 0));
    }

    if (allTrades.isEmpty) return [];

    allTrades.sort((a, b) => b.dealDate.compareTo(a.dealDate));

    return allTrades.take(AppConstants.homeLatestTradeLimit).map((t) => LatestTradeInfo(
      aptName: t.aptName, dealAmount: t.dealAmount, dealDate: t.dealDate,
      area: t.area, floor: t.floor,
      regionCode: t.regionCode, dong: t.dong,
    )).toList();
  } catch (_) {
    return [];
  }
});

/// 지역별 최신 전세/월세 내역 (캐시 활용)
/// rentType: 'jeonse' = 전세만, 'monthly' = 월세만
final regionLatestRentsProvider = FutureProvider.family<List<LatestTradeInfo>, ({String region, String rentType})>((ref, params) async {
  final now = DateTime.now();
  final region = params.region;
  final isJeonse = params.rentType == 'jeonse';

  final regionCodes = region.isNotEmpty
      ? RegionCodes.getCodesForRegion(region)
      : [AppConstants.defaultRegionCode];

  if (regionCodes.isEmpty) return [];

  final codesToFetch = regionCodes.length > AppConstants.homeLatestTradeLimit
      ? regionCodes.sublist(0, AppConstants.homeLatestTradeLimit)
      : regionCodes;

  final ym = '${now.year}${now.month.toString().padLeft(2, '0')}';
  final prevDate = DateTime(now.year, now.month - 1, 1);
  final prevYm = '${prevDate.year}${prevDate.month.toString().padLeft(2, '0')}';

  try {
    final allRents = <ApartmentRent>[];

    final futures = codesToFetch.map((code) async {
      try {
        final rKey = _cache.rentKey(code, ym);
        List<ApartmentRent> rents;
        if (_cache.hasRents(rKey)) {
          rents = _cache.getRents(rKey) ?? [];
        } else {
          rents = await _api.getAptRents(regionCode: code, dealYmd: ym);
          _cache.putRents(rKey, rents);
        }

        final filtered = rents.where((r) => isJeonse ? r.isJeonse : !r.isJeonse).toList();
        if (filtered.isEmpty) {
          final prevKey = _cache.rentKey(code, prevYm);
          List<ApartmentRent> prevRents;
          if (_cache.hasRents(prevKey)) {
            prevRents = _cache.getRents(prevKey) ?? [];
          } else {
            prevRents = await _api.getAptRents(regionCode: code, dealYmd: prevYm);
            _cache.putRents(prevKey, prevRents);
          }
          return prevRents.where((r) => isJeonse ? r.isJeonse : !r.isJeonse).toList();
        }
        return filtered;
      } catch (_) {
        return <ApartmentRent>[];
      }
    });

    final results = await Future.wait(futures);
    for (final rents in results) {
      allRents.addAll(rents.where((r) => r.deposit > 0));
    }

    if (allRents.isEmpty) return [];

    allRents.sort((a, b) => b.dealDate.compareTo(a.dealDate));

    return allRents.take(AppConstants.homeLatestTradeLimit).map((r) => LatestTradeInfo(
      aptName: r.aptName,
      dealAmount: isJeonse ? r.deposit : r.monthlyRent,
      dealDate: r.dealDate,
      area: r.area, floor: r.floor,
      regionCode: r.regionCode, dong: r.dong,
    )).toList();
  } catch (_) {
    return [];
  }
});

// ──────────────────────────────────────────────
// 공통 캐시 활용 API 호출 헬퍼
// ──────────────────────────────────────────────

/// 여러 지역코드 x 월 조합을 캐시 확인 후 필요한 것만 배치 API 호출
Future<void> _fetchAndCacheAll(List<String> regionCodes, List<String> months) async {
  final tasks = <Future Function()>[];

  for (final code in regionCodes) {
    for (final ym in months) {
      final tKey = _cache.tradeKey(code, ym);
      if (!_cache.hasTrades(tKey)) {
        tasks.add(() async {
          try {
            final trades = await _api.getAptTrades(regionCode: code, dealYmd: ym);
            _cache.putTrades(tKey, trades);
          } catch (_) {
            _cache.putTrades(tKey, <ApartmentTrade>[]);
          }
        });
      }
      final rKey = _cache.rentKey(code, ym);
      if (!_cache.hasRents(rKey)) {
        tasks.add(() async {
          try {
            final rents = await _api.getAptRents(regionCode: code, dealYmd: ym);
            _cache.putRents(rKey, rents);
          } catch (_) {
            _cache.putRents(rKey, <ApartmentRent>[]);
          }
        });
      }
    }
  }

  // 배치 처리: 한번에 최대 6개씩 (스로틀러와 별도로 네트워크 부하 분산)
  const batchSize = 6;
  for (var i = 0; i < tasks.length; i += batchSize) {
    final batch = tasks.skip(i).take(batchSize).map((fn) => fn());
    await Future.wait(batch);
  }
}

// ──────────────────────────────────────────────
// 상세화면용 확장 거래 이력 Provider
// ──────────────────────────────────────────────

/// 상세화면 진입 시 24개월치 거래 이력을 가져오는 Provider
/// key: 'regionCode|aptName'
final detailTradeHistoryProvider =
    FutureProvider.family<List<TradeHistory>, String>((ref, key) async {
  final parts = key.split('|');
  if (parts.length < 2) return [];
  final regionCode = parts[0];
  final aptName = parts[1];

  final now = DateTime.now();

  final months = <String>[];
  for (int i = 0; i < AppConstants.tradeMonthsDetail; i++) {
    final date = DateTime(now.year, now.month - i, 1);
    months.add('${date.year}${date.month.toString().padLeft(2, '0')}');
  }

  // 캐시 활용 API 호출
  await _fetchAndCacheAll([regionCode], months);

  // 캐시에서 수집
  final allTrades = <ApartmentTrade>[];
  final allRents = <ApartmentRent>[];
  for (final ym in months) {
    allTrades.addAll(_cache.getTrades(_cache.tradeKey(regionCode, ym)) ?? []);
    allRents.addAll(_cache.getRents(_cache.rentKey(regionCode, ym)) ?? []);
  }

  // 아파트명 매칭
  final searchName = aptName.replaceAll(' ', '').replaceAll('아파트', '');
  final aptTrades = allTrades.where((t) {
    final apiName = t.aptName.replaceAll(' ', '');
    return apiName == searchName ||
        apiName.contains(searchName) ||
        searchName.contains(apiName) && apiName.length >= searchName.length - 3;
  }).toList();
  final aptRents = allRents.where((r) {
    final apiName = r.aptName.replaceAll(' ', '');
    return apiName == searchName ||
        apiName.contains(searchName) ||
        searchName.contains(apiName) && apiName.length >= searchName.length - 3;
  }).toList();

  return <TradeHistory>[
    ...aptTrades.map((t) => TradeHistory(
      date: t.dealDate, price: t.dealAmount, floor: t.floor, area: t.area,
    )),
    ...aptRents.where((r) => r.isJeonse).map((r) => TradeHistory(
      date: r.dealDate, price: r.deposit, floor: r.floor, area: r.area,
      type: TradeType.jeonse,
    )),
  ];
});

// ──────────────────────────────────────────────
// 아파트 설정 (메타데이터 - API에서 가져올 수 없는 정보)
// ──────────────────────────────────────────────

class _AptConfig {
  final String name;
  final String location;
  final String regionCode;
  final int buildYear;
  final double floorAreaRatio;
  final int fallbackPrice;
  final List<ApartmentUnit> units;

  const _AptConfig({
    required this.name, required this.location, required this.regionCode,
    required this.buildYear, required this.floorAreaRatio, required this.fallbackPrice,
    required this.units,
  });
}

final _aptConfigs = <_AptConfig>[
  _AptConfig(
    name: '래미안원베일리', location: '서울 서초구 반포동', regionCode: '11650',
    buildYear: 2023, floorAreaRatio: 299, fallbackPrice: 450000,
    units: [
      ApartmentUnit(pyeong: 34, supplyArea: 112.92, exclusiveArea: 84.97, entranceType: '타워형', rooms: 3, bathrooms: 2),
      ApartmentUnit(pyeong: 46, supplyArea: 152.38, exclusiveArea: 114.78, entranceType: '타워형', rooms: 4, bathrooms: 2),
      ApartmentUnit(pyeong: 59, supplyArea: 195.63, exclusiveArea: 148.21, entranceType: '타워형', rooms: 4, bathrooms: 3),
    ],
  ),
  _AptConfig(
    name: '반포자이', location: '서울 서초구 반포동', regionCode: '11650',
    buildYear: 2009, floorAreaRatio: 249, fallbackPrice: 380000,
    units: [
      ApartmentUnit(pyeong: 33, supplyArea: 109.44, exclusiveArea: 84.43, entranceType: '타워형', rooms: 3, bathrooms: 2),
      ApartmentUnit(pyeong: 45, supplyArea: 149.58, exclusiveArea: 115.52, entranceType: '타워형', rooms: 4, bathrooms: 2),
    ],
  ),
  _AptConfig(
    name: '아크로리버파크', location: '서울 서초구 반포동', regionCode: '11650',
    buildYear: 2016, floorAreaRatio: 249, fallbackPrice: 420000,
    units: [
      ApartmentUnit(pyeong: 34, supplyArea: 112.37, exclusiveArea: 84.98, entranceType: '타워형', rooms: 3, bathrooms: 2),
      ApartmentUnit(pyeong: 47, supplyArea: 155.76, exclusiveArea: 117.22, entranceType: '타워형', rooms: 4, bathrooms: 2),
      ApartmentUnit(pyeong: 59, supplyArea: 196.54, exclusiveArea: 148.71, entranceType: '타워형', rooms: 4, bathrooms: 3),
    ],
  ),
  _AptConfig(
    name: '힐스테이트갤러리', location: '서울 용산구 한남동', regionCode: '11170',
    buildYear: 2022, floorAreaRatio: 220, fallbackPrice: 320000,
    units: [
      ApartmentUnit(pyeong: 29, supplyArea: 96.13, exclusiveArea: 74.85, entranceType: '계단식', rooms: 3, bathrooms: 2),
      ApartmentUnit(pyeong: 39, supplyArea: 129.28, exclusiveArea: 100.64, entranceType: '계단식', rooms: 4, bathrooms: 2),
    ],
  ),
  _AptConfig(
    name: '잠실엘스', location: '서울 송파구 잠실동', regionCode: '11710',
    buildYear: 2008, floorAreaRatio: 204, fallbackPrice: 270000,
    units: [
      ApartmentUnit(pyeong: 25, supplyArea: 82.85, exclusiveArea: 59.96, entranceType: '계단식', rooms: 3, bathrooms: 1),
      ApartmentUnit(pyeong: 33, supplyArea: 109.52, exclusiveArea: 84.82, entranceType: '계단식', rooms: 3, bathrooms: 2),
      ApartmentUnit(pyeong: 44, supplyArea: 145.84, exclusiveArea: 112.98, entranceType: '계단식', rooms: 4, bathrooms: 2),
    ],
  ),
  _AptConfig(
    name: '잠실리센츠', location: '서울 송파구 잠실동', regionCode: '11710',
    buildYear: 2008, floorAreaRatio: 204, fallbackPrice: 260000,
    units: [
      ApartmentUnit(pyeong: 25, supplyArea: 82.68, exclusiveArea: 59.97, entranceType: '계단식', rooms: 3, bathrooms: 1),
      ApartmentUnit(pyeong: 33, supplyArea: 109.37, exclusiveArea: 84.82, entranceType: '계단식', rooms: 3, bathrooms: 2),
    ],
  ),
  _AptConfig(
    name: '올림픽파크포레온', location: '서울 강동구 둔촌동', regionCode: '11740',
    buildYear: 2024, floorAreaRatio: 274, fallbackPrice: 230000,
    units: [
      ApartmentUnit(pyeong: 29, supplyArea: 96.08, exclusiveArea: 74.98, entranceType: '타워형', rooms: 3, bathrooms: 2),
      ApartmentUnit(pyeong: 34, supplyArea: 112.56, exclusiveArea: 84.91, entranceType: '타워형', rooms: 3, bathrooms: 2),
      ApartmentUnit(pyeong: 39, supplyArea: 129.24, exclusiveArea: 99.86, entranceType: '타워형', rooms: 4, bathrooms: 2),
      ApartmentUnit(pyeong: 49, supplyArea: 162.38, exclusiveArea: 124.68, entranceType: '타워형', rooms: 4, bathrooms: 2),
    ],
  ),
  _AptConfig(
    name: '디에이치아너힐즈', location: '서울 강남구 개포동', regionCode: '11680',
    buildYear: 2020, floorAreaRatio: 199, fallbackPrice: 350000,
    units: [
      ApartmentUnit(pyeong: 34, supplyArea: 112.63, exclusiveArea: 84.44, entranceType: '타워형', rooms: 3, bathrooms: 2),
      ApartmentUnit(pyeong: 46, supplyArea: 152.14, exclusiveArea: 114.56, entranceType: '타워형', rooms: 4, bathrooms: 2),
    ],
  ),
  _AptConfig(
    name: '래미안퍼스티지', location: '서울 서초구 반포동', regionCode: '11650',
    buildYear: 2009, floorAreaRatio: 249, fallbackPrice: 360000,
    units: [
      ApartmentUnit(pyeong: 34, supplyArea: 112.42, exclusiveArea: 84.78, entranceType: '타워형', rooms: 3, bathrooms: 2),
      ApartmentUnit(pyeong: 45, supplyArea: 149.24, exclusiveArea: 112.92, entranceType: '타워형', rooms: 4, bathrooms: 2),
      ApartmentUnit(pyeong: 59, supplyArea: 195.41, exclusiveArea: 148.07, entranceType: '타워형', rooms: 4, bathrooms: 3),
    ],
  ),
  _AptConfig(
    name: '아크로비스타', location: '서울 서초구 반포동', regionCode: '11650',
    buildYear: 2004, floorAreaRatio: 239, fallbackPrice: 290000,
    units: [
      ApartmentUnit(pyeong: 33, supplyArea: 109.28, exclusiveArea: 84.79, entranceType: '계단식', rooms: 3, bathrooms: 2),
      ApartmentUnit(pyeong: 45, supplyArea: 149.06, exclusiveArea: 115.32, entranceType: '계단식', rooms: 4, bathrooms: 2),
    ],
  ),
];
