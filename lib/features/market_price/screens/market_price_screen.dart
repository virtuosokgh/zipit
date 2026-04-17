import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/network/real_estate_api.dart';
import '../../../core/services/api_cache.dart';
import '../../../models/address_result.dart';
import '../../../models/apartment_listing.dart';
import '../../../models/apartment_trade.dart';
import '../../../models/apartment_rent.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/ai_price_estimator.dart';
import '../../../widgets/shimmer_loading.dart';
import '../providers/market_price_provider.dart';
import '../providers/market_filter_provider.dart';
import '../providers/market_listings_provider.dart';
import '../widgets/market_filter_bar.dart';
import '../widgets/filter_bottom_sheets.dart';
import '../widgets/apartment_list_card.dart';

class MarketPriceScreen extends ConsumerStatefulWidget {
  const MarketPriceScreen({super.key});

  @override
  ConsumerState<MarketPriceScreen> createState() => _MarketPriceScreenState();
}

class _MarketPriceScreenState extends ConsumerState<MarketPriceScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;
  bool _showResults = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - AppConstants.scrollLoadThreshold) {
      ref.read(marketListingsProvider.notifier).loadMore();
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: AppConstants.debounceMs), () {
      ref.read(searchQueryProvider.notifier).state = query;
      setState(() => _showResults = query.length >= AppConstants.searchMinLength);
    });
  }

  void _selectAddress(AddressResult address) async {
    _searchController.text = address.buildingName ?? address.addressName;
    setState(() => _showResults = false);
    FocusScope.of(context).unfocus();

    if (address.needsRegionCode && address.latitude != 0) {
      final api = ref.read(kakaoApiProvider);
      final code = await api.getRegionCode(address.latitude, address.longitude);
      address = address.withRegionCode(code);
    }

    if (address.buildingName != null && address.buildingName!.isNotEmpty) {
      _navigateToDetail(address);
    }
  }

  void _navigateToDetail(AddressResult address) async {
    final aptName = address.buildingName!;
    final regionCode = address.regionCode;
    final api = RealEstateApi();
    final cache = ApiCache();
    final now = DateTime.now();

    _searchController.clear();
    setState(() => _showResults = false);

    // 3개월치로 축소 (캐시 활용)
    final months = <String>[];
    for (int i = 0; i < AppConstants.tradeMonthsShort; i++) {
      final date = DateTime(now.year, now.month - i, 1);
      months.add('${date.year}${date.month.toString().padLeft(2, '0')}');
    }

    // 캐시 확인 후 필요한 것만 API 호출
    final futures = <Future>[];
    for (final ym in months) {
      final tKey = cache.tradeKey(regionCode, ym);
      if (!cache.hasTrades(tKey)) {
        futures.add(() async {
          try {
            final trades = await api.getAptTrades(regionCode: regionCode, dealYmd: ym);
            cache.putTrades(tKey, trades);
          } catch (e) {
            dev.log('검색 API 오류 (매매 $regionCode/$ym): $e', name: 'MarketSearch');
            cache.putTrades(tKey, <ApartmentTrade>[]);
          }
        }());
      }
      final rKey = cache.rentKey(regionCode, ym);
      if (!cache.hasRents(rKey)) {
        futures.add(() async {
          try {
            final rents = await api.getAptRents(regionCode: regionCode, dealYmd: ym);
            cache.putRents(rKey, rents);
          } catch (e) {
            dev.log('검색 API 오류 (전월세 $regionCode/$ym): $e', name: 'MarketSearch');
            cache.putRents(rKey, <ApartmentRent>[]);
          }
        }());
      }
    }
    if (futures.isNotEmpty) await Future.wait(futures);

    // 캐시에서 데이터 수집
    final allTrades = <ApartmentTrade>[];
    final allRents = <ApartmentRent>[];
    for (final ym in months) {
      allTrades.addAll(cache.getTrades(cache.tradeKey(regionCode, ym)) ?? []);
      allRents.addAll(cache.getRents(cache.rentKey(regionCode, ym)) ?? []);
    }

    // 정확한 아파트 이름 매칭 (동명이인 방지)
    // "신동아4차" 검색 시 "신동아1차"가 매칭되지 않도록
    final aptTrades = allTrades.where((t) {
      final apiName = t.aptName.replaceAll(' ', '');
      final searchName = aptName.replaceAll(' ', '').replaceAll('아파트', '');
      // 정확 매칭 또는 API이름이 검색명 전체를 포함
      return apiName == searchName ||
             apiName.contains(searchName) ||
             searchName.contains(apiName) && apiName.length >= searchName.length - 3;
    }).toList();
    final aptRents = allRents.where((r) {
      final apiName = r.aptName.replaceAll(' ', '');
      final searchName = aptName.replaceAll(' ', '').replaceAll('아파트', '');
      return apiName == searchName ||
             apiName.contains(searchName) ||
             searchName.contains(apiName) && apiName.length >= searchName.length - 3;
    }).toList();

    final tradeHistory = <TradeHistory>[
      ...aptTrades.map((t) => TradeHistory(date: t.dealDate, price: t.dealAmount, floor: t.floor, area: t.area)),
      ...aptRents.where((r) => r.isJeonse).map((r) => TradeHistory(date: r.dealDate, price: r.deposit, floor: r.floor, area: r.area, type: TradeType.jeonse)),
    ];

    // 건축년도: 실거래 데이터에서 추정 (최초 거래일 기반) 또는 기본 20년
    final oldestTrade = aptTrades.isNotEmpty
        ? aptTrades.map((t) => t.dealYear).reduce((a, b) => a < b ? a : b)
        : now.year;
    // API에 건축년도 없으므로 거래 이력 기반으로 추정 (최초거래-2년 또는 기본 20년)
    final estimatedBuildYear = aptTrades.length >= AppConstants.buildYearEstimateMinTrades
        ? oldestTrade - AppConstants.buildYearEstimateOffset
        : now.year - AppConstants.defaultBuildingAge;
    final estimate = AiPriceEstimator.estimate(
      trades: aptTrades,
      rents: aptRents,
      buildYear: estimatedBuildYear,
    );

    final areaSet = aptTrades.map((t) => t.area).toSet().toList()..sort();
    final units = areaSet.map((a) => ApartmentUnit(
      pyeong: (a / AppConstants.sqmToPyeong).round(),
      supplyArea: a * AppConstants.supplyAreaRatio,
      exclusiveArea: a,
      entranceType: '-',
      rooms: 3,
      bathrooms: 2,
    )).toList();

    final currentPrice = estimate?.currentPrice ?? 0;
    final aiEstimate = estimate?.estimatedPrice ?? currentPrice;
    final priceGap = estimate?.priceGap ?? 0.0;

    final listing = ApartmentListing(
      name: aptName,
      location: address.addressName,
      currentPrice: currentPrice,
      aiEstimate: aiEstimate,
      priceGap: priceGap,
      floorAreaRatio: 0, // API에서 용적률 정보 미제공
      buildYear: estimatedBuildYear,
      regionCode: regionCode,
      units: units.isEmpty ? [ApartmentUnit(pyeong: 34, supplyArea: 112.0, exclusiveArea: 84.0, entranceType: '-', rooms: 3, bathrooms: 2)] : units,
      tradeHistory: tradeHistory,
    );

    if (!mounted) return;
    context.push('/market-price/detail/-1', extra: listing);
  }

  Future<void> _onRefresh() async {
    await ref.read(marketListingsProvider.notifier).reload(clearCache: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // 검색 바
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.sm, AppSpacing.screenH, 0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: '아파트, 주소를 검색해보세요',
                prefixIcon: const Icon(Icons.search, color: AppColors.gray500),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, color: AppColors.gray500, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(searchQueryProvider.notifier).state = '';
                          setState(() => _showResults = false);
                        },
                      )
                    : null,
              ),
            ),
          ),

          // 검색 결과 or 필터+리스트
          Expanded(
            child: _showResults ? _buildSearchResults() : _buildFilteredList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    final searchAsync = ref.watch(addressSearchProvider);

    return searchAsync.when(
      data: (results) {
        if (results.isEmpty) {
          return const Center(child: Text('검색 결과가 없어요', style: AppTypography.caption1));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          itemCount: results.length,
          separatorBuilder: (_, _) => const Divider(),
          itemBuilder: (_, i) {
            final r = results[i];
            return ListTile(
              leading: const Icon(Icons.location_on_outlined, color: AppColors.primary),
              title: Text(r.buildingName ?? r.addressName, style: AppTypography.body2Bold),
              subtitle: Text(r.addressName, style: AppTypography.caption1),
              contentPadding: EdgeInsets.zero,
              onTap: () => _selectAddress(r),
            );
          },
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        child: Column(children: List.generate(5, (_) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: ShimmerLoading(height: 56),
        ))),
      ),
      error: (e, _) => const Center(child: Text('검색 중 오류가 발생했어요', style: AppTypography.caption1)),
    );
  }

  Widget _buildFilteredList() {
    final listingsState = ref.watch(marketListingsProvider);
    final filter = ref.watch(marketFilterProvider);

    return Column(
      children: [
        // 필터 바
        const SizedBox(height: AppSpacing.md),
        const MarketFilterBar(),
        const SizedBox(height: AppSpacing.sm),

        // 정렬 + 결과 수
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${listingsState.listings.length}건',
                style: AppTypography.caption1,
              ),
              GestureDetector(
                onTap: () => _showSortSheet(context),
                child: Row(
                  children: [
                    Text(
                      filter.sortType.labelFor(filter.tradeType),
                      style: AppTypography.caption1.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.swap_vert, size: 16, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // 리스트
        Expanded(
          child: _buildListContent(listingsState),
        ),
      ],
    );
  }

  void _showSortSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
      ),
      builder: (_) => SortSheet(
        currentSort: ref.read(marketFilterProvider).sortType,
        tradeType: ref.read(marketFilterProvider).tradeType,
        onSelect: (sort) => ref.read(marketFilterProvider.notifier).setSortType(sort),
      ),
    );
  }

  Widget _buildListContent(MarketListingsState state) {
    if (state.isLoading && state.listings.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: AppSpacing.lg),
              Text('AI가 매물을 분석하고 있어요...', style: AppTypography.caption1),
            ],
          ),
        ),
      );
    }

    if (state.error != null && state.listings.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, color: AppColors.gray400, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text(state.error!, style: AppTypography.caption1),
            const SizedBox(height: AppSpacing.lg),
            TextButton(
              onPressed: () => ref.read(marketListingsProvider.notifier).reload(clearCache: true),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (state.listings.isEmpty) {
      // 필터 전에도 데이터가 없으면 → 해당 지역에 거래 데이터 부족
      final isNoData = state.totalBeforeFilter == 0;
      // 일부 API 실패가 있었다면 안내
      final hasPartialError = state.apiErrorCount > 0 && state.apiTotalCount > 0;

      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isNoData ? Icons.apartment_outlined : Icons.search_off,
              color: AppColors.gray400,
              size: 48,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              isNoData
                  ? (hasPartialError
                      ? '일부 데이터를 불러오지 못했어요'
                      : '최근 거래 데이터가 없어요')
                  : '조건에 맞는 매물이 없어요',
              style: AppTypography.caption1,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              isNoData
                  ? (hasPartialError
                      ? '네트워크 확인 후 다시 시도해주세요'
                      : '다른 지역을 선택해보세요')
                  : '필터를 조정해보세요',
              style: AppTypography.caption2,
            ),
            if (isNoData && hasPartialError) ...[
              const SizedBox(height: AppSpacing.lg),
              TextButton(
                onPressed: () => ref.read(marketListingsProvider.notifier).reload(clearCache: true),
                child: const Text('다시 시도'),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _onRefresh,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
        itemCount: state.listings.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= state.listings.length) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.xxl),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final listing = state.listings[index];
        final currentFilter = ref.read(marketFilterProvider);
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: ApartmentListCard(
            listing: listing,
            rank: index + 1,
            tradeType: currentFilter.tradeType,
            onTap: () => context.push('/market-price/detail/-1', extra: listing),
          ),
        );
      },
    ),
    );
  }
}
