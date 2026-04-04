import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/real_estate_api.dart';
import '../../../core/network/kakao_api.dart';
import '../../../core/services/api_cache.dart';
import '../../../core/constants/app_constants.dart';

import '../../../models/apartment_trade.dart';
import '../../../models/apartment_rent.dart';
import '../../../models/address_result.dart';

// API 인스턴스 (싱글턴)
final realEstateApiProvider = Provider((ref) => RealEstateApi());
final kakaoApiProvider = Provider((ref) => KakaoApi());

// 검색어
final searchQueryProvider = StateProvider<String>((ref) => '');

// 주소 검색 결과
final addressSearchProvider = FutureProvider.autoDispose<List<AddressResult>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.length < 2) return [];
  final api = ref.read(kakaoApiProvider);
  return api.searchAddress(query);
});

// 선택된 주소
final selectedAddressProvider = StateProvider<AddressResult?>((ref) => null);

// 매매 실거래 데이터 (캐시 활용 + 병렬 호출)
final aptTradesProvider = FutureProvider.autoDispose<List<ApartmentTrade>>((ref) async {
  final address = ref.watch(selectedAddressProvider);
  if (address == null) return [];
  final api = RealEstateApi();
  final cache = ApiCache();

  final now = DateTime.now();
  final futures = <Future>[];

  for (int i = 0; i < AppConstants.tradeMonthsShort; i++) {
    final date = DateTime(now.year, now.month - i, 1);
    final ym = '${date.year}${date.month.toString().padLeft(2, '0')}';
    final key = cache.tradeKey(address.regionCode, ym);
    if (!cache.hasTrades(key)) {
      futures.add(() async {
        try {
          final trades = await api.getAptTrades(regionCode: address.regionCode, dealYmd: ym);
          cache.putTrades(key, trades);
        } catch (_) {
          cache.putTrades(key, <ApartmentTrade>[]);
        }
      }());
    }
  }

  if (futures.isNotEmpty) await Future.wait(futures);

  final trades = <ApartmentTrade>[];
  for (int i = 0; i < AppConstants.tradeMonthsShort; i++) {
    final date = DateTime(now.year, now.month - i, 1);
    final ym = '${date.year}${date.month.toString().padLeft(2, '0')}';
    trades.addAll(cache.getTrades(cache.tradeKey(address.regionCode, ym)) ?? []);
  }
  return trades;
});

// 전월세 실거래 데이터 (캐시 활용 + 병렬 호출)
final aptRentsProvider = FutureProvider.autoDispose<List<ApartmentRent>>((ref) async {
  final address = ref.watch(selectedAddressProvider);
  if (address == null) return [];
  final api = RealEstateApi();
  final cache = ApiCache();

  final now = DateTime.now();
  final futures = <Future>[];

  for (int i = 0; i < AppConstants.tradeMonthsShort; i++) {
    final date = DateTime(now.year, now.month - i, 1);
    final ym = '${date.year}${date.month.toString().padLeft(2, '0')}';
    final key = cache.rentKey(address.regionCode, ym);
    if (!cache.hasRents(key)) {
      futures.add(() async {
        try {
          final rents = await api.getAptRents(regionCode: address.regionCode, dealYmd: ym);
          cache.putRents(key, rents);
        } catch (_) {
          cache.putRents(key, <ApartmentRent>[]);
        }
      }());
    }
  }

  if (futures.isNotEmpty) await Future.wait(futures);

  final rents = <ApartmentRent>[];
  for (int i = 0; i < AppConstants.tradeMonthsShort; i++) {
    final date = DateTime(now.year, now.month - i, 1);
    final ym = '${date.year}${date.month.toString().padLeft(2, '0')}';
    rents.addAll(cache.getRents(cache.rentKey(address.regionCode, ym)) ?? []);
  }
  return rents;
});

// 선택된 아파트 필터링
final selectedAptNameProvider = StateProvider<String?>((ref) => null);

final filteredTradesProvider = Provider<List<ApartmentTrade>>((ref) {
  final trades = ref.watch(aptTradesProvider).valueOrNull ?? [];
  final aptName = ref.watch(selectedAptNameProvider);
  if (aptName == null) return trades;
  return trades.where((t) => t.aptName == aptName).toList();
});

// 아파트 이름 목록 (중복 제거)
final aptNamesProvider = Provider<List<String>>((ref) {
  final trades = ref.watch(aptTradesProvider).valueOrNull ?? [];
  return trades.map((t) => t.aptName).toSet().toList()..sort();
});
