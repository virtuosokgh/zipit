import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/real_estate_api.dart';
import '../../../core/services/ai_price_estimator.dart';
import '../../../core/services/api_cache.dart';
import '../../../models/apartment_listing.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/region_codes.dart';
import '../../../models/apartment_trade.dart';
import '../../../models/apartment_rent.dart';
import '../../../models/market_filter.dart';
import 'market_filter_provider.dart';

/// 페이지네이션 상태
class MarketListingsState {
  final List<ApartmentListing> listings;
  final bool isLoading;
  final bool hasMore;
  final int page;
  final String? error;
  final int totalBeforeFilter; // 필터 적용 전 총 아파트 수
  final int apiErrorCount;     // API 호출 실패 횟수
  final int apiTotalCount;     // API 호출 총 횟수

  const MarketListingsState({
    this.listings = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.page = 0,
    this.error,
    this.totalBeforeFilter = 0,
    this.apiErrorCount = 0,
    this.apiTotalCount = 0,
  });

  MarketListingsState copyWith({
    List<ApartmentListing>? listings,
    bool? isLoading,
    bool? hasMore,
    int? page,
    String? Function()? error,
    int? totalBeforeFilter,
    int? apiErrorCount,
    int? apiTotalCount,
  }) {
    return MarketListingsState(
      listings: listings ?? this.listings,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      error: error != null ? error() : this.error,
      totalBeforeFilter: totalBeforeFilter ?? this.totalBeforeFilter,
      apiErrorCount: apiErrorCount ?? this.apiErrorCount,
      apiTotalCount: apiTotalCount ?? this.apiTotalCount,
    );
  }
}

/// 시세 리스트 Provider (디바운스 적용)
final marketListingsProvider =
    StateNotifierProvider<MarketListingsNotifier, MarketListingsState>((ref) {
  final notifier = MarketListingsNotifier(ref);
  ref.listen(marketFilterProvider, (prev, next) {
    notifier._debouncedReload();
  });
  return notifier;
});

class MarketListingsNotifier extends StateNotifier<MarketListingsState> {
  final Ref _ref;
  final _api = RealEstateApi();
  final _cache = ApiCache();
  static const _pageSize = AppConstants.pageSize;

  // 전체 계산된 리스트 (필터+정렬 적용 후)
  List<ApartmentListing> _allListings = [];

  // 디바운스 타이머
  Timer? _debounceTimer;

  // 현재 진행 중인 reload 취소 플래그
  int _reloadGeneration = 0;

  MarketListingsNotifier(this._ref) : super(const MarketListingsState()) {
    reload();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// 디바운스된 reload (필터 변경 시 사용)
  void _debouncedReload() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(
      const Duration(milliseconds: AppConstants.debounceMs),
      () => reload(),
    );
  }

  /// 필터 변경 시 전체 리로드
  Future<void> reload({bool clearCache = false}) async {
    _debounceTimer?.cancel();
    final generation = ++_reloadGeneration;

    state = const MarketListingsState(isLoading: true);
    _allListings = [];

    if (clearCache) _cache.clearAll();

    try {
      final filter = _ref.read(marketFilterProvider);
      var regionCodes = filter.regionCodes;

      // 지역 미선택 시 기본 서울 주요 5개 구
      if (regionCodes.isEmpty) {
        regionCodes = AppConstants.defaultMarketRegionCodes;
      }

      // 지역 수에 따라 조회 범위 조절 (성능 최적화)
      // 5개 이하: 3개월, 6~10개: 2개월, 11개 이상: 1개월
      final int monthCount;
      if (regionCodes.length <= 5) {
        monthCount = AppConstants.tradeMonthsShort; // 3개월
      } else if (regionCodes.length <= 10) {
        monthCount = 2;
      } else {
        monthCount = 1;
      }

      // 지역이 너무 많으면 제한 (성능)
      if (regionCodes.length > 15) {
        regionCodes = regionCodes.sublist(0, 15);
      }

      final now = DateTime.now();
      final months = <String>[];
      for (int i = 0; i < monthCount; i++) {
        final date = DateTime(now.year, now.month - i, 1);
        months.add('${date.year}${date.month.toString().padLeft(2, '0')}');
      }

      // 캐시 히트 먼저 체크
      final needsRents = filter.tradeType == TradeTypeFilter.jeonse ||
          filter.tradeType == TradeTypeFilter.monthly;
      final cachedCodes = <String>[];
      final uncachedTrades = <(String, String)>[]; // (code, ym)
      final uncachedRents = <(String, String)>[]; // (code, ym)

      for (final code in regionCodes) {
        bool allCached = true;
        for (final ym in months) {
          final tKey = _cache.tradeKey(code, ym);
          if (!_cache.hasTrades(tKey)) {
            uncachedTrades.add((code, ym));
            allCached = false;
          }
          if (needsRents) {
            final rKey = _cache.rentKey(code, ym);
            if (!_cache.hasRents(rKey)) {
              uncachedRents.add((code, ym));
              allCached = false;
            }
          }
        }
        if (allCached) cachedCodes.add(code);
      }

      // 캐시 히트가 있으면 즉시 첫 결과 표시
      if (cachedCodes.isNotEmpty && (uncachedTrades.isNotEmpty || uncachedRents.isNotEmpty)) {
        _allListings = _buildListings(cachedCodes, months, filter);
        final firstPage = _allListings.take(_pageSize).toList();
        if (generation == _reloadGeneration && mounted) {
          state = MarketListingsState(
            listings: firstPage,
            isLoading: true,
            hasMore: _allListings.length > _pageSize,
            page: 1,
          );
        }
      }

      // 미캐시 데이터 병렬 호출 (동시 요청 수 제한으로 안정성 확보)
      final allPairs = <(String, String, bool)>[]; // (code, ym, isRent)
      for (final pair in uncachedTrades) {
        allPairs.add((pair.$1, pair.$2, false));
      }
      for (final pair in uncachedRents) {
        allPairs.add((pair.$1, pair.$2, true));
      }

      // API 에러 추적
      int apiErrorCount = 0;
      final int apiTotalCount = allPairs.length;

      // 최대 5개씩 병렬 호출 (API 서버 부담 감소 + 속도 균형)
      const batchSize = AppConstants.apiBatchSize;
      for (var i = 0; i < allPairs.length; i += batchSize) {
        if (generation != _reloadGeneration) return;
        final batch = allPairs.skip(i).take(batchSize);
        await Future.wait(batch.map((item) async {
          final (code, ym, isRent) = item;
          if (isRent) {
            try {
              final rents = await _api.getAptRents(regionCode: code, dealYmd: ym);
              _cache.putRents(_cache.rentKey(code, ym), rents);
            } catch (e) {
              dev.log('API 오류 (전월세 $code/$ym): $e', name: 'MarketListings');
              apiErrorCount++;
              _cache.putRents(_cache.rentKey(code, ym), <ApartmentRent>[]);
            }
          } else {
            try {
              final trades = await _api.getAptTrades(regionCode: code, dealYmd: ym);
              _cache.putTrades(_cache.tradeKey(code, ym), trades);
            } catch (e) {
              dev.log('API 오류 (매매 $code/$ym): $e', name: 'MarketListings');
              apiErrorCount++;
              _cache.putTrades(_cache.tradeKey(code, ym), <ApartmentTrade>[]);
            }
          }
        }));

        // 배치 완료 후 중간 결과 즉시 표시 (프로그레시브 로딩)
        if (generation == _reloadGeneration && mounted) {
          final partialListings = _buildListings(regionCodes, months, filter);
          if (partialListings.isNotEmpty) {
            _allListings = partialListings;
            final firstPage = _allListings.take(_pageSize).toList();
            state = MarketListingsState(
              listings: firstPage,
              isLoading: true,
              hasMore: _allListings.length > _pageSize,
              page: 1,
            );
          }
        }
      }

      // 취소 확인: 더 새로운 reload가 시작됐으면 결과 버림
      if (generation != _reloadGeneration) return;

      // 아파트별 그룹핑 + AI 추정가 계산
      final buildResult = _buildListingsWithCount(regionCodes, months, filter);
      _allListings = buildResult.$1;
      final totalBeforeFilter = buildResult.$2;

      // 모든 API가 실패한 경우 에러로 처리
      if (apiTotalCount > 0 && apiErrorCount == apiTotalCount) {
        state = MarketListingsState(
          isLoading: false,
          error: '서버 연결에 실패했어요. 네트워크를 확인해주세요.',
          apiErrorCount: apiErrorCount,
          apiTotalCount: apiTotalCount,
        );
        return;
      }

      // 첫 페이지 표시
      final firstPage = _allListings.take(_pageSize).toList();
      state = MarketListingsState(
        listings: firstPage,
        isLoading: false,
        hasMore: _allListings.length > _pageSize,
        page: 1,
        totalBeforeFilter: totalBeforeFilter,
        apiErrorCount: apiErrorCount,
        apiTotalCount: apiTotalCount,
      );
    } catch (e) {
      dev.log('reload 전체 오류: $e', name: 'MarketListings');
      if (generation != _reloadGeneration) return;
      state = MarketListingsState(
        isLoading: false,
        error: '데이터를 불러오지 못했어요',
      );
    }
  }

  /// 다음 페이지 로드
  void loadMore() {
    if (state.isLoading || !state.hasMore) return;

    final nextPage = state.page + 1;
    final start = state.page * _pageSize;
    final end = (start + _pageSize).clamp(0, _allListings.length);
    if (start >= _allListings.length) return;

    final nextItems = _allListings.sublist(start, end);
    state = state.copyWith(
      listings: [...state.listings, ...nextItems],
      page: nextPage,
      hasMore: end < _allListings.length,
    );
  }

  /// 캐시 데이터에서 리스팅 생성 (필터 전 총 수 포함)
  (List<ApartmentListing>, int) _buildListingsWithCount(
    List<String> regionCodes,
    List<String> months,
    MarketFilter filter,
  ) {
    final result = _buildListingsInternal(regionCodes, months, filter);
    return result;
  }

  /// 캐시 데이터에서 리스팅 생성 (기존 호환)
  List<ApartmentListing> _buildListings(
    List<String> regionCodes,
    List<String> months,
    MarketFilter filter,
  ) {
    return _buildListingsInternal(regionCodes, months, filter).$1;
  }

  (List<ApartmentListing>, int) _buildListingsInternal(
    List<String> regionCodes,
    List<String> months,
    MarketFilter filter,
  ) {
    // 지역+월별 캐시에서 거래 수집
    final allTrades = <ApartmentTrade>[];
    final allRents = <ApartmentRent>[];

    for (final code in regionCodes) {
      for (final ym in months) {
        final trades = _cache.getTrades(_cache.tradeKey(code, ym));
        if (trades != null) allTrades.addAll(trades);
        final rents = _cache.getRents(_cache.rentKey(code, ym));
        if (rents != null) allRents.addAll(rents);
      }
    }

    // 아파트명별 그룹핑
    final tradesByApt = <String, List<ApartmentTrade>>{};
    for (final t in allTrades) {
      if (t.aptName.isEmpty || t.dealAmount <= 0) continue;
      tradesByApt.putIfAbsent(t.aptName, () => []).add(t);
    }

    final rentsByApt = <String, List<ApartmentRent>>{};
    for (final r in allRents) {
      if (r.aptName.isEmpty) continue;
      rentsByApt.putIfAbsent(r.aptName, () => []).add(r);
    }

    // 각 아파트별 리스팅 생성
    final listings = <ApartmentListing>[];
    int totalBeforeFilter = 0;

    for (final entry in tradesByApt.entries) {
      final aptName = entry.key;
      final aptTrades = entry.value;
      final aptRents = rentsByApt[aptName] ?? [];

      if (aptTrades.length < AppConstants.minTradesForListing) continue;

      final firstTrade = aptTrades.first;
      final dong = firstTrade.dong;
      final regionCode = firstTrade.regionCode;
      final city = RegionCodes.getCity(regionCode);
      final guName = RegionCodes.codeToName[regionCode] ?? '';
      final locationStr = (city.isNotEmpty && guName.isNotEmpty) ? '$city $guName $dong' : dong;

      // 면적별 유니크한 평형
      final areaSet = aptTrades.map((t) => t.area).toSet().toList()..sort();
      final units = areaSet.map((a) => ApartmentUnit(
        pyeong: (a / AppConstants.sqmToPyeong).round(),
        supplyArea: a * AppConstants.supplyAreaRatio,
        exclusiveArea: a,
        entranceType: '-',
        rooms: _estimateRooms(a),
        bathrooms: a > 100 ? 2 : (a > 60 ? 2 : 1),
      )).toList();

      // 건축년도 추정
      final oldestYear = aptTrades.map((t) => t.dealYear).reduce((a, b) => a < b ? a : b);
      final estimatedBuildYear = oldestYear - AppConstants.buildYearEstimateOffset;
      final estimate = AiPriceEstimator.estimate(
        trades: aptTrades,
        rents: aptRents,
        buildYear: estimatedBuildYear,
      );

      if (estimate == null) {
        dev.log('AI 추정 실패: $aptName (거래 ${aptTrades.length}건)', name: 'MarketListings');
        continue;
      }

      // 거래 이력 (매매 + 전세 + 월세)
      final tradeHistory = <TradeHistory>[
        ...aptTrades.map((t) => TradeHistory(
          date: t.dealDate, price: t.dealAmount, floor: t.floor, area: t.area,
        )),
        ...aptRents.where((r) => r.isJeonse).map((r) => TradeHistory(
          date: r.dealDate, price: r.deposit, floor: r.floor, area: r.area,
          type: TradeType.jeonse,
        )),
        ...aptRents.where((r) => !r.isJeonse).map((r) => TradeHistory(
          date: r.dealDate, price: r.deposit, floor: r.floor, area: r.area,
          type: TradeType.monthly, monthlyRent: r.monthlyRent,
        )),
      ];

      final listing = ApartmentListing(
        name: aptName,
        location: locationStr,
        currentPrice: estimate.currentPrice,
        aiEstimate: estimate.estimatedPrice,
        priceGap: estimate.priceGap,
        floorAreaRatio: 0,
        buildYear: estimatedBuildYear,
        regionCode: regionCode,
        units: units.isEmpty
            ? [ApartmentUnit(pyeong: 34, supplyArea: 112.0, exclusiveArea: 84.0, entranceType: '-', rooms: 3, bathrooms: 2)]
            : units,
        tradeHistory: tradeHistory,
      );

      totalBeforeFilter++;

      // 필터 적용
      if (!_matchesFilter(listing, filter)) continue;

      listings.add(listing);
    }

    // 정렬
    _sortListings(listings, filter.sortType, filter.tradeType);

    return (listings, totalBeforeFilter);
  }

  /// 필터 매칭 확인
  bool _matchesFilter(ApartmentListing listing, MarketFilter filter) {
    // 전세 필터: 전세 데이터 없으면 제외
    if (filter.tradeType == TradeTypeFilter.jeonse && listing.latestJeonsePrice == null) return false;
    // 월세 필터: 월세 데이터 없으면 제외
    if (filter.tradeType == TradeTypeFilter.monthly && listing.latestMonthlyRent == null) return false;

    // 거래유형별 가격 필터 적용
    if (filter.tradeType == TradeTypeFilter.jeonse) {
      // 전세: priceMin/Max → 전세 보증금 기준
      final jeonse = listing.latestJeonsePrice;
      if (jeonse != null) {
        if (filter.priceMin != null && jeonse < filter.priceMin!) return false;
        if (filter.priceMax != null && jeonse > filter.priceMax!) return false;
      }
    } else if (filter.tradeType == TradeTypeFilter.monthly) {
      // 월세: priceMin/Max → 보증금 기준, monthlyRentMin/Max → 월세 기준
      final deposit = listing.latestMonthlyDeposit;
      if (deposit != null) {
        if (filter.priceMin != null && deposit < filter.priceMin!) return false;
        if (filter.priceMax != null && deposit > filter.priceMax!) return false;
      }
      final rent = listing.latestMonthlyRent;
      if (rent != null) {
        if (filter.monthlyRentMin != null && rent < filter.monthlyRentMin!) return false;
        if (filter.monthlyRentMax != null && rent > filter.monthlyRentMax!) return false;
      }
    } else {
      // 매매: priceMin/Max → 매매가 기준
      if (filter.priceMin != null && listing.currentPrice < filter.priceMin!) return false;
      if (filter.priceMax != null && listing.currentPrice > filter.priceMax!) return false;
    }

    if (filter.areaMin != null || filter.areaMax != null) {
      final areas = listing.units.map((u) => u.exclusiveArea).toList();
      if (areas.isNotEmpty) {
        final maxArea = areas.reduce((a, b) => a > b ? a : b);
        final minArea = areas.reduce((a, b) => a < b ? a : b);
        if (filter.areaMin != null && maxArea < filter.areaMin!) return false;
        if (filter.areaMax != null && minArea > filter.areaMax!) return false;
      }
    }

    if (filter.roomsMin != null) {
      final maxRooms = listing.units.map((u) => u.rooms).fold(0, (a, b) => a > b ? a : b);
      if (maxRooms < filter.roomsMin!) return false;
    }

    if (filter.gapMin != null && listing.aiGapPercent < filter.gapMin!) return false;
    if (filter.gapMax != null && listing.aiGapPercent > filter.gapMax!) return false;

    if (filter.approvalYearMin != null && listing.buildYear < filter.approvalYearMin!) return false;
    if (filter.approvalYearMax != null && listing.buildYear > filter.approvalYearMax!) return false;

    if (filter.farMin != null && listing.floorAreaRatio < filter.farMin!) return false;
    if (filter.farMax != null && listing.floorAreaRatio > filter.farMax!) return false;

    return true;
  }

  /// 정렬
  void _sortListings(List<ApartmentListing> listings, MarketSortType sort, TradeTypeFilter tradeType) {
    switch (sort) {
      case MarketSortType.aiRecommend:
        if (tradeType == TradeTypeFilter.jeonse) {
          // 전세: 안전한 것부터 (안전보증금 - 현재전세가 차이가 큰 순)
          listings.sort((a, b) => b.jeonseSafetyScore.compareTo(a.jeonseSafetyScore));
        } else if (tradeType == TradeTypeFilter.monthly) {
          // 월세: 안전한 것부터 (환산보증금 vs 안전보증금 차이 큰 순)
          listings.sort((a, b) => b.monthlyRentSafetyScore.compareTo(a.monthlyRentSafetyScore));
        } else {
          listings.sort((a, b) =>
              (b.aiEstimate - b.currentPrice).compareTo(a.aiEstimate - a.currentPrice));
        }
      case MarketSortType.priceLow:
        if (tradeType == TradeTypeFilter.jeonse) {
          listings.sort((a, b) =>
              (a.latestJeonsePrice ?? 999999).compareTo(b.latestJeonsePrice ?? 999999));
        } else if (tradeType == TradeTypeFilter.monthly) {
          listings.sort((a, b) =>
              (a.latestMonthlyRent ?? 999999).compareTo(b.latestMonthlyRent ?? 999999));
        } else {
          listings.sort((a, b) => a.currentPrice.compareTo(b.currentPrice));
        }
      case MarketSortType.priceHigh:
        if (tradeType == TradeTypeFilter.jeonse) {
          listings.sort((a, b) =>
              (b.latestJeonsePrice ?? 0).compareTo(a.latestJeonsePrice ?? 0));
        } else if (tradeType == TradeTypeFilter.monthly) {
          listings.sort((a, b) =>
              (b.latestMonthlyRent ?? 0).compareTo(a.latestMonthlyRent ?? 0));
        } else {
          listings.sort((a, b) => b.currentPrice.compareTo(a.currentPrice));
        }
      case MarketSortType.monthlyRentLow:
        listings.sort((a, b) =>
            (a.latestMonthlyRent ?? 999999).compareTo(b.latestMonthlyRent ?? 999999));
      case MarketSortType.monthlyRentHigh:
        listings.sort((a, b) =>
            (b.latestMonthlyRent ?? 0).compareTo(a.latestMonthlyRent ?? 0));
      case MarketSortType.gapHigh:
        listings.sort((a, b) => b.aiGapPercent.compareTo(a.aiGapPercent));
      case MarketSortType.newest:
        // 미리 최신 거래일 계산하여 반복 연산 방지
        final latestDates = <String, DateTime>{};
        final defaultDate = DateTime(2000);
        for (final listing in listings) {
          if (listing.tradeHistory.isNotEmpty) {
            latestDates[listing.name] = listing.tradeHistory
                .map((t) => t.date)
                .reduce((a, b) => a.isAfter(b) ? a : b);
          }
        }
        listings.sort((a, b) {
          final aDate = latestDates[a.name] ?? defaultDate;
          final bDate = latestDates[b.name] ?? defaultDate;
          return bDate.compareTo(aDate);
        });
    }
  }

  int _estimateRooms(double area) {
    if (area < 40) return 1;
    if (area < 60) return 2;
    if (area < 85) return 3;
    return 4;
  }
}
