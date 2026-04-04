import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/region_codes.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../models/contract.dart';
import '../../../providers/user_preferences_provider.dart';
import '../../../models/apartment_listing.dart';
import '../../../providers/auth_provider.dart';
import '../../my_contract/providers/contract_provider.dart';
import '../../market_price/providers/listing_provider.dart';
import '../../subscription/providers/subscription_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Future<void> _onRefresh() async {
    ref.invalidate(contractsProvider);
    ref.invalidate(subscriptionListProvider);
    ref.invalidate(regionLatestTradesProvider);
    await Future.delayed(const Duration(milliseconds: AppConstants.refreshDelayMs));
  }

  @override
  Widget build(BuildContext context) {
    // select로 필요한 값만 구독 → 불필요한 리빌드 방지
    final authState = ref.watch(authStateProvider);
    final isLoggedIn = authState.valueOrNull != null;
    final nickname = ref.watch(
      userProfileProvider.select((p) => p?.nickname),
    );
    final contracts = ref.watch(contractsProvider);
    final regions = ref.watch(
      userPreferencesProvider.select((p) => p.regions),
    );
    final region = ref.watch(
      userPreferencesProvider.select((p) => p.region),
    );

    final greeting = isLoggedIn && nickname != null
        ? '안녕하세요, $nickname님!'
        : '안녕하세요!';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.screenH),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(greeting, style: AppTypography.heading2),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '오늘의 부동산 소식을 확인해보세요',
              style: AppTypography.body2.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // 계약 섹션
            if (!isLoggedIn)
              _loginCard(context)
            else if (contracts.isEmpty)
              _emptyContractCard(context)
            else
              ...contracts.take(AppConstants.homeContractLimit).map((c) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _contractSummaryCard(context, c),
              )),

            const SizedBox(height: AppSpacing.xxl),
            Row(
              children: [
                Expanded(
                  child: Text(
                    regions.isNotEmpty
                        ? '${RegionCodes.regionsLabel(regions)} 최신 실거래'
                        : '최신 실거래',
                    style: AppTypography.heading3,
                  ),
                ),
                GestureDetector(
                  onTap: () => context.go('/market-price'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('전체보기', style: AppTypography.caption1.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 2),
                        Icon(Icons.chevron_right, size: 16, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _LatestTradesCard(region: region),
            const SizedBox(height: AppSpacing.xxl),

            // 다가오는 청약
            _SubscriptionSection(region: region),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
      ),
    );
  }

  Widget _loginCard(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.xxl),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      border: Border.all(color: AppColors.borderLight),
    ),
    child: Column(
      children: [
        const Icon(Icons.lock_outline, size: 48, color: AppColors.gray300),
        const SizedBox(height: AppSpacing.md),
        const Text('로그인하고 계약을 관리해보세요', style: AppTypography.body1Bold),
        const SizedBox(height: AppSpacing.xs),
        Text('로그인하면 내 계약 체크리스트와\n중요 일정을 알려드려요',
            style: AppTypography.caption1.copyWith(color: AppColors.textTertiary), textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          height: AppSpacing.buttonSmallHeight,
          child: ElevatedButton(
            onPressed: () => context.push('/login'),
            child: const Text('로그인하기'),
          ),
        ),
      ],
    ),
  );

  Widget _emptyContractCard(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.xxl),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      border: Border.all(color: AppColors.borderLight),
    ),
    child: Column(
      children: [
        const Icon(Icons.description_outlined, size: 48, color: AppColors.gray300),
        const SizedBox(height: AppSpacing.md),
        const Text('진행 중인 계약이 없어요', style: AppTypography.body1Bold),
        const SizedBox(height: AppSpacing.xs),
        Text('계약을 등록하면 체크리스트와 일정을 관리할 수 있어요', style: AppTypography.caption1, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          height: AppSpacing.buttonSmallHeight,
          child: ElevatedButton(
            onPressed: () => context.push('/my-contract/register'),
            child: const Text('계약 등록하기'),
          ),
        ),
      ],
    ),
  );

  Widget _contractSummaryCard(BuildContext context, Contract contract) {
    final completedCount = contract.checklist.where((c) => c.isCompleted).length;
    final totalCount = contract.checklist.length;

    return GestureDetector(
      onTap: () => context.push('/my-contract/${contract.id}'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  child: Text(contract.type.label, style: AppTypography.caption2.copyWith(color: AppColors.primary)),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(contract.status.label, style: AppTypography.caption1),
                const Spacer(),
                if (contract.nextDday != null)
                  Text('D-${contract.nextDday}', style: AppTypography.label2.copyWith(
                    color: contract.nextDday! <= 7 ? AppColors.error : AppColors.primary,
                  )),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(contract.aptName, style: AppTypography.body1Bold),
            const SizedBox(height: AppSpacing.xs),
            Text(
              contract.type == ContractType.monthly
                  ? '${PriceFormatter.format(contract.price)} / 월 ${PriceFormatter.format(contract.monthlyRent ?? 0)}'
                  : PriceFormatter.format(contract.price),
              style: AppTypography.body2.copyWith(color: AppColors.primary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: totalCount > 0 ? completedCount / totalCount : 0,
                      backgroundColor: AppColors.gray200,
                      valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                      minHeight: 4,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text('$completedCount/$totalCount', style: AppTypography.caption2),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 최신 실거래 카드 — 별도 ConsumerWidget (자체 리빌드 격리)
class _LatestTradesCard extends ConsumerWidget {
  final String region;
  const _LatestTradesCard({required this.region});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tradesAsync = ref.watch(regionLatestTradesProvider(region));

    return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: tradesAsync.when(
              data: (trades) {
                if (trades.isEmpty) {
                  return Text(
                    '최근 거래 내역이 없어요',
                    style: AppTypography.caption1.copyWith(color: AppColors.textTertiary),
                  );
                }
                return Column(
                  children: trades.take(AppConstants.homeLatestTradeLimit).map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: GestureDetector(
                      onTap: () {
                        // 최소한의 ApartmentListing 생성 → 상세 페이지로 이동
                        final listing = ApartmentListing(
                          name: t.aptName,
                          location: t.dong.isNotEmpty ? t.dong : region,
                          currentPrice: t.dealAmount,
                          aiEstimate: t.dealAmount,
                          priceGap: 0,
                          floorAreaRatio: 0,
                          buildYear: t.dealDate.year,
                          regionCode: t.regionCode,
                          units: [ApartmentUnit(
                            pyeong: (t.area / AppConstants.sqmToPyeong).round(),
                            supplyArea: t.area * AppConstants.supplyAreaRatio,
                            exclusiveArea: t.area,
                            entranceType: '-', rooms: 3, bathrooms: 2,
                          )],
                          tradeHistory: [TradeHistory(
                            date: t.dealDate, price: t.dealAmount,
                            floor: t.floor, area: t.area,
                          )],
                        );
                        context.push('/market-price/detail/-1', extra: listing);
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.aptName,
                                  style: AppTypography.body2Bold,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${t.area.toStringAsFixed(0)}㎡ · ${t.floor}층 · ${t.dealDate.month}/${t.dealDate.day}',
                                  style: AppTypography.caption2.copyWith(color: AppColors.textTertiary),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            PriceFormatter.formatShort(t.dealAmount),
                            style: AppTypography.body2Bold.copyWith(color: AppColors.primary),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right, color: AppColors.gray300, size: 16),
                        ],
                      ),
                    ),
                  )).toList(),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              ),
              error: (e, st) => Text(
                '실거래 정보를 불러오지 못했어요',
                style: AppTypography.caption1.copyWith(color: AppColors.textTertiary),
              ),
            ),
    );
  }
}

/// 다가오는 청약 섹션 — 별도 ConsumerWidget (자체 리빌드 격리)
class _SubscriptionSection extends ConsumerWidget {
  final String region;
  const _SubscriptionSection({required this.region});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionsAsync = ref.watch(subscriptionListProvider);
    // homeSubscriptionRegion: '전체' = 전지역, '' = 미설정(온보딩 지역 사용), 그 외 = 선택 지역
    final homeSubRegion = ref.watch(
      userPreferencesProvider.select((p) => p.homeSubscriptionRegion),
    );
    final fallbackRegion = ref.watch(
      userPreferencesProvider.select((p) => p.region),
    );
    // '전체' → 필터 없음, '' → 온보딩 지역 fallback
    final selectedRegion = homeSubRegion == '전체' ? '' : (homeSubRegion.isNotEmpty ? homeSubRegion : fallbackRegion);

    // 헤더 표시용 라벨 (selectedRegion='' 이면 "전체")
    final displayLabel = selectedRegion.isNotEmpty ? selectedRegion : '전체';
    // 피커에서 현재 선택값 (homeSubRegion 원본)
    final pickerCurrent = homeSubRegion == '전체' || homeSubRegion.isEmpty ? '전체' : homeSubRegion;

    return subscriptionsAsync.when(
      loading: () => _buildHeader(context, ref, displayLabel, pickerCurrent, child: const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      )),
      error: (e, st) => _buildHeader(context, ref, displayLabel, pickerCurrent, child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.xxl),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Text(
          '청약 정보를 불러오지 못했어요',
          textAlign: TextAlign.center,
          style: AppTypography.caption1.copyWith(color: AppColors.textTertiary),
        ),
      )),
      data: (subscriptions) {
        var upcoming = subscriptions.where((s) {
          final cat = s.filterCategory;
          return cat == '접수예정' || cat == '접수중';
        }).toList();

        List<SubscriptionInfo> filtered = upcoming;
        if (selectedRegion.isNotEmpty) {
          final matchKeys = RegionCodes.getSubscriptionMatchKeys([selectedRegion]);
          filtered = upcoming.where((s) =>
            matchKeys.any((key) => s.subscrptAreaCodeNm.contains(key))
          ).toList();
        }

        filtered.sort((a, b) {
          final aD = a.dDay;
          final bD = b.dDay;
          if (aD < 0 && bD < 0) return 0;
          if (aD < 0) return 1;
          if (bD < 0) return -1;
          return aD.compareTo(bD);
        });

        return _buildHeader(context, ref, displayLabel, pickerCurrent, child: Column(
          children: [
            if (filtered.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.xxl),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.apartment_outlined, size: 40, color: AppColors.gray300),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      selectedRegion.isNotEmpty
                          ? '$selectedRegion 지역에 예정된 청약이 없어요'
                          : '예정된 청약이 없어요',
                      style: AppTypography.caption1.copyWith(color: AppColors.textTertiary),
                    ),
                  ],
                ),
              )
            else
              ...filtered.take(AppConstants.homeSubscriptionLimit).map((s) {
                // 원본 리스트에서 해당 청약의 인덱스 찾기
                final originalIndex = subscriptions.indexOf(s);
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _subscriptionCard(context, s, originalIndex),
                );
              }),
          ],
        ));
      },
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, String displayLabel, String pickerCurrent, {required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('다가오는 청약', style: AppTypography.heading3),
            const Spacer(),
            GestureDetector(
              onTap: () => _showRegionPicker(context, ref, pickerCurrent),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayLabel,
                      style: AppTypography.caption1.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        child,
      ],
    );
  }

  void _showRegionPicker(BuildContext context, WidgetRef ref, String current) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text('지역 선택', style: AppTypography.body1Bold),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _regionPickerChip('전체', current == '전체' || current.isEmpty, () {
                      ref.read(userPreferencesProvider.notifier).setHomeSubscriptionRegion('전체');
                      Navigator.pop(context);
                    }),
                    const SizedBox(height: AppSpacing.md),
                    Text('서울', style: AppTypography.caption1.copyWith(color: AppColors.textTertiary)),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: ['서울 전체', ...RegionCodes.seoulGuNames].map((gu) =>
                        _regionPickerChip(gu, current == gu, () {
                          ref.read(userPreferencesProvider.notifier).setHomeSubscriptionRegion(gu);
                          Navigator.pop(context);
                        }),
                      ).toList(),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('인천', style: AppTypography.caption1.copyWith(color: AppColors.textTertiary)),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: ['인천 전체', ...RegionCodes.incheonGuNames].map((gu) =>
                        _regionPickerChip(gu, current == gu, () {
                          ref.read(userPreferencesProvider.notifier).setHomeSubscriptionRegion(gu);
                          Navigator.pop(context);
                        }),
                      ).toList(),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('경기', style: AppTypography.caption1.copyWith(color: AppColors.textTertiary)),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: ['경기 전체', ...RegionCodes.gyeonggiSiNames].map((gu) =>
                        _regionPickerChip(gu, current == gu, () {
                          ref.read(userPreferencesProvider.notifier).setHomeSubscriptionRegion(gu);
                          Navigator.pop(context);
                        }),
                      ).toList(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  Widget _regionPickerChip(String label, bool isSelected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      labelStyle: AppTypography.label2.copyWith(
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
      ),
    );
  }

  Widget _subscriptionCard(BuildContext context, SubscriptionInfo sub, int index) {
    final dDay = sub.dDay;
    final isUrgent = dDay >= 0 && dDay <= 7;
    final dDayColor = isUrgent ? AppColors.error : AppColors.primary;

    return GestureDetector(
      onTap: () => context.push('/subscription/detail/$index'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            if (dDay >= 0)
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: dDayColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Center(
                  child: Text('D-$dDay', style: AppTypography.label2.copyWith(color: dDayColor)),
                ),
              )
            else
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: AppColors.gray100,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Center(
                  child: Text(sub.status, style: AppTypography.caption2.copyWith(color: AppColors.gray500)),
                ),
              ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sub.name, style: AppTypography.body2Bold, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('${sub.location} · ${sub.houseDivision}', style: AppTypography.caption1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.gray400),
          ],
        ),
      ),
    );
  }
}
