import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/region_codes.dart';
import '../../../core/network/real_estate_api.dart';
import '../../../core/services/ai_price_estimator.dart';
import '../../../core/services/api_cache.dart';
import '../../../models/apartment_listing.dart';
import '../../../models/apartment_trade.dart';
import '../../../models/apartment_rent.dart';
import '../../../providers/user_preferences_provider.dart';

/// 잠금화면에서 매물 클릭 시 빠르게 상세 데이터를 로드하는 provider
/// key: 'regionCode|aptName' (regionCode가 있으면 바로 조회, 없으면 위젯 지역 검색)
final lockscreenDetailProvider = FutureProvider.family<ApartmentListing?, String>((ref, key) async {
  // key 파싱: 'regionCode|aptName' 또는 '|aptName'
  final sepIdx = key.indexOf('|');
  final directRegionCode = sepIdx > 0 ? key.substring(0, sepIdx) : '';
  final aptName = sepIdx >= 0 ? key.substring(sepIdx + 1) : key;

  if (aptName.isEmpty) return null;

  final api = RealEstateApi();
  final cache = ApiCache();
  final now = DateTime.now();

  // 2개월만 우선 로드 (빠른 응답)
  final months = <String>[];
  for (int i = 0; i < 2; i++) {
    final date = DateTime(now.year, now.month - i, 1);
    months.add('${date.year}${date.month.toString().padLeft(2, '0')}');
  }

  List<ApartmentTrade> foundTrades = [];
  List<ApartmentRent> foundRents = [];
  String foundRegionCode = directRegionCode;

  // regionCode가 있으면 바로 조회 (API 호출 최소화)
  if (directRegionCode.isNotEmpty) {
    final futures = months.map((ym) async {
      try {
        final tKey = cache.tradeKey(directRegionCode, ym);
        List<ApartmentTrade> trades;
        if (cache.hasTrades(tKey)) {
          trades = cache.getTrades(tKey) ?? [];
        } else {
          trades = await api.getAptTrades(regionCode: directRegionCode, dealYmd: ym);
          cache.putTrades(tKey, trades);
        }
        return trades.where((t) => t.aptName == aptName).toList();
      } catch (_) {
        return <ApartmentTrade>[];
      }
    }).toList();

    final results = await Future.wait(futures);
    for (final matched in results) {
      foundTrades.addAll(matched);
    }
  }

  // regionCode 없거나 거래 못 찾으면 위젯 지역 검색 (fallback)
  if (foundTrades.isEmpty) {
    final prefs = ref.read(userPreferencesProvider);
    final widgetRegions = prefs.effectiveWidgetRegions;
    final regionCodes = RegionCodes.getCodesForRegions(widgetRegions);
    if (regionCodes.isEmpty) return null;

    for (int batch = 0; batch < regionCodes.length; batch += AppConstants.apiBatchSize) {
      final batchCodes = regionCodes.skip(batch).take(AppConstants.apiBatchSize).toList();

      final futures = batchCodes.expand((code) => months.map((ym) async {
        try {
          final tKey = cache.tradeKey(code, ym);
          List<ApartmentTrade> trades;
          if (cache.hasTrades(tKey)) {
            trades = cache.getTrades(tKey) ?? [];
          } else {
            trades = await api.getAptTrades(regionCode: code, dealYmd: ym);
            cache.putTrades(tKey, trades);
          }
          final matched = trades.where((t) => t.aptName == aptName).toList();
          return (code: code, trades: matched);
        } catch (_) {
          return (code: code, trades: <ApartmentTrade>[]);
        }
      })).toList();

      final results = await Future.wait(futures);
      for (final r in results) {
        if (r.trades.isNotEmpty) {
          foundRegionCode = r.code;
          foundTrades.addAll(r.trades);
        }
      }
      if (foundTrades.isNotEmpty) break;
    }
  }

  if (foundTrades.isEmpty) return null;

  // 전세/월세 병렬 로드 (캐시 활용)
  final rentFutures = months.map((ym) async {
    try {
      final rKey = cache.rentKey(foundRegionCode, ym);
      List<ApartmentRent> rents;
      if (cache.hasRents(rKey)) {
        rents = cache.getRents(rKey) ?? [];
      } else {
        rents = await api.getAptRents(regionCode: foundRegionCode, dealYmd: ym);
        cache.putRents(rKey, rents);
      }
      return rents.where((r) => r.aptName == aptName).toList();
    } catch (_) {
      return <ApartmentRent>[];
    }
  }).toList();

  final rentResults = await Future.wait(rentFutures);
  for (final rents in rentResults) {
    foundRents.addAll(rents);
  }

  return _buildListing(aptName, foundTrades, foundRents, foundRegionCode);
});

ApartmentListing _buildListing(
  String aptName,
  List<ApartmentTrade> trades,
  List<ApartmentRent> rents,
  String regionCode,
) {
  final firstTrade = trades.first;
  final dong = firstTrade.dong;
  final city = RegionCodes.getCity(regionCode);
  final guName = RegionCodes.codeToName[regionCode] ?? '';
  final locationStr = (city.isNotEmpty && guName.isNotEmpty) ? '$city $guName $dong' : dong;

  final areaSet = trades.map((t) => t.area).toSet().toList()..sort();
  final units = areaSet.map((a) => ApartmentUnit(
    pyeong: (a / AppConstants.sqmToPyeong).round(),
    supplyArea: a * AppConstants.supplyAreaRatio,
    exclusiveArea: a,
    entranceType: '-',
    rooms: a > 100 ? 4 : (a > 60 ? 3 : 2),
    bathrooms: a > 100 ? 2 : (a > 60 ? 2 : 1),
  )).toList();

  final oldestYear = trades.map((t) => t.dealYear).reduce((a, b) => a < b ? a : b);
  final buildYear = oldestYear - AppConstants.buildYearEstimateOffset;

  final estimate = AiPriceEstimator.estimate(
    trades: trades, rents: rents, buildYear: buildYear,
  );

  final tradeHistory = <TradeHistory>[
    ...trades.map((t) => TradeHistory(
      date: t.dealDate, price: t.dealAmount, floor: t.floor, area: t.area,
    )),
    ...rents.where((r) => r.isJeonse).map((r) => TradeHistory(
      date: r.dealDate, price: r.deposit, floor: r.floor, area: r.area,
      type: TradeType.jeonse,
    )),
    ...rents.where((r) => !r.isJeonse).map((r) => TradeHistory(
      date: r.dealDate, price: r.deposit, floor: r.floor, area: r.area,
      type: TradeType.monthly, monthlyRent: r.monthlyRent,
    )),
  ];

  return ApartmentListing(
    name: aptName,
    location: locationStr,
    currentPrice: estimate?.currentPrice ?? trades.first.dealAmount,
    aiEstimate: estimate?.estimatedPrice ?? trades.first.dealAmount,
    priceGap: estimate?.priceGap ?? 0,
    floorAreaRatio: 0,
    buildYear: buildYear,
    regionCode: regionCode,
    units: units.isEmpty
        ? [ApartmentUnit(pyeong: 34, supplyArea: 112.0, exclusiveArea: 84.0, entranceType: '-', rooms: 3, bathrooms: 2)]
        : units,
    tradeHistory: tradeHistory,
  );
}
