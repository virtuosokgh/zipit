import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../models/apartment_listing.dart';
import '../../../widgets/price_signal_badge.dart';
import '../providers/apt_address_provider.dart';
import '../providers/listing_provider.dart';
import '../providers/lockscreen_detail_provider.dart';
import '../providers/market_listings_provider.dart';

/// 기간 필터 옵션
enum PeriodFilter {
  threeMonths('3개월', 3),
  sixMonths('6개월', 6),
  oneYear('1년', 12),
  threeYears('3년', 36),
  fiveYears('5년', 60),
  custom('직접 입력', 0);

  final String label;
  final int months;
  const PeriodFilter(this.label, this.months);
}

class ApartmentDetailScreen extends ConsumerStatefulWidget {
  final int index;
  final ApartmentListing? listing; // 직접 전달된 리스팅 (검색용)
  final String? aptName; // 잠금화면에서 이름으로 검색
  final String? regionCode; // 잠금화면에서 지역코드 직접 전달

  const ApartmentDetailScreen({super.key, required this.index, this.listing, this.aptName, this.regionCode});

  @override
  ConsumerState<ApartmentDetailScreen> createState() => _ApartmentDetailScreenState();
}

class _ApartmentDetailScreenState extends ConsumerState<ApartmentDetailScreen> {
  int _selectedUnitIndex = 0;
  TradeType _selectedTradeType = TradeType.sale;
  PeriodFilter _periodFilter = PeriodFilter.sixMonths;
  DateTimeRange? _customRange;
  int _currentPage = 0;
  static const int _pageSize = AppConstants.pageSize;

  /// 기간 필터 적용된 시작일
  DateTime get _periodStart {
    if (_periodFilter == PeriodFilter.custom && _customRange != null) {
      return _customRange!.start;
    }
    final now = DateTime.now();
    return DateTime(now.year, now.month - _periodFilter.months, now.day);
  }

  DateTime get _periodEnd {
    if (_periodFilter == PeriodFilter.custom && _customRange != null) {
      return _customRange!.end;
    }
    return DateTime.now();
  }

  /// 선택한 평형 + 거래유형 + 기간으로 필터링
  List<TradeHistory> _filteredTrades(ApartmentListing apt) {
    final selectedUnit = apt.units[_selectedUnitIndex];
    final start = _periodStart;
    final end = _periodEnd;
    return apt.tradeHistory
        .where((t) =>
            t.type == _selectedTradeType &&
            (t.area - selectedUnit.exclusiveArea).abs() < AppConstants.areaTolerance &&
            !t.date.isBefore(start) &&
            !t.date.isAfter(end))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  /// 갭가격 계산 (최근 매매가 - 최근 전세가)
  int? _gapPrice(ApartmentListing apt) {
    final selectedUnit = apt.units[_selectedUnitIndex];
    final saleTrades = apt.tradeHistory
        .where((t) => t.type == TradeType.sale && (t.area - selectedUnit.exclusiveArea).abs() < AppConstants.areaTolerance)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final jeonseTrades = apt.tradeHistory
        .where((t) => t.type == TradeType.jeonse && (t.area - selectedUnit.exclusiveArea).abs() < AppConstants.areaTolerance)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    if (saleTrades.isEmpty || jeonseTrades.isEmpty) return null;
    return saleTrades.first.price - jeonseTrades.first.price;
  }

  /// 최근 전세가 (해당 평형)
  int? _latestJeonsePrice(ApartmentListing apt) {
    final selectedUnit = apt.units[_selectedUnitIndex];
    final jeonseTrades = apt.tradeHistory
        .where((t) => t.type == TradeType.jeonse && (t.area - selectedUnit.exclusiveArea).abs() < AppConstants.areaTolerance)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return jeonseTrades.isNotEmpty ? jeonseTrades.first.price : null;
  }

  /// 안전 전세금 계산
  /// = min(전세보증보험 한도, 최근 1년 전세금 중 최저)
  /// 전세보증보험 한도: HUG 기준 시세의 150% 이하 → 시세의 80% 수준으로 가정
  int? _safeJeonsePrice(ApartmentListing apt) {
    final selectedUnit = apt.units[_selectedUnitIndex];
    final oneYearAgo = DateTime.now().subtract(const Duration(days: 365));
    final recentJeonse = apt.tradeHistory
        .where((t) =>
            t.type == TradeType.jeonse &&
            (t.area - selectedUnit.exclusiveArea).abs() < AppConstants.areaTolerance &&
            t.date.isAfter(oneYearAgo))
        .toList();

    if (recentJeonse.isEmpty) return null;

    final lowestRecentJeonse = recentJeonse.map((t) => t.price).reduce((a, b) => a < b ? a : b);
    // 전세보증보험 가입 가능 금액: 시세의 80%
    final insuranceLimit = (apt.currentPrice * AppConstants.jeonseInsuranceLimitRatio).toInt();

    return lowestRecentJeonse < insuranceLimit ? lowestRecentJeonse : insuranceLimit;
  }

  /// 잠금화면에서 진입했는지 여부
  bool get _isFromLockScreen => widget.aptName != null && widget.aptName!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    late ApartmentListing apt;
    if (widget.listing != null) {
      apt = widget.listing!;
    } else if (_isFromLockScreen) {
      // 잠금화면에서 aptName으로 진입 — topListingsProvider를 watch하지 않음 (무거움)
      // 이미 로드된 marketListings 캐시만 확인 (가벼움)
      final marketListings = ref.read(marketListingsProvider).listings;
      final cached = marketListings.where((l) => l.name == widget.aptName).firstOrNull;

      if (cached != null) {
        apt = cached;
      } else {
        // regionCode|aptName 키로 전용 provider 호출 (regionCode 있으면 초고속)
        final providerKey = widget.regionCode != null && widget.regionCode!.isNotEmpty
            ? '${widget.regionCode}|${widget.aptName}'
            : '|${widget.aptName}';
        final detailAsync = ref.watch(lockscreenDetailProvider(providerKey));
        return detailAsync.when(
          data: (listing) {
            if (listing == null) {
              return Scaffold(
                appBar: _buildAppBar(widget.aptName!),
                body: Center(child: Text('거래 데이터를 찾을 수 없어요', style: AppTypography.caption1)),
              );
            }
            return _buildDetailBody(listing);
          },
          loading: () => Scaffold(
            appBar: _buildAppBar(widget.aptName!),
            body: const Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Scaffold(
            appBar: _buildAppBar(widget.aptName!),
            body: Center(child: Text('데이터를 불러올 수 없어요', style: AppTypography.caption1)),
          ),
        );
      }
    } else {
      final listingsAsync = ref.watch(topListingsProvider);
      final listings = listingsAsync.valueOrNull ?? [];
      if (listingsAsync.isLoading) {
        return Scaffold(
          appBar: _buildAppBar('상세 정보'),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      if (widget.index < 0 || widget.index >= listings.length) {
        return Scaffold(
          appBar: _buildAppBar('상세 정보'),
          body: const Center(child: Text('데이터를 찾을 수 없어요', style: AppTypography.caption1)),
        );
      }
      apt = listings[widget.index];
    }

    return _buildDetailBody(apt);
  }

  /// 공통 AppBar (뒤로가기 버튼 포함)
  PreferredSizeWidget _buildAppBar(String title) {
    return AppBar(
      title: Text(title),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        onPressed: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            // 잠금화면에서 직접 진입 시 뒤로갈 곳이 없으면 시세 화면으로
            GoRouter.of(context).go('/market-price');
          }
        },
      ),
    );
  }

  Widget _buildDetailBody(ApartmentListing apt) {
    // 24개월치 확장 거래 이력 로드 (비동기)
    final detailKey = '${apt.regionCode}|${apt.name}';
    final detailAsync = ref.watch(detailTradeHistoryProvider(detailKey));
    final extendedHistory = detailAsync.valueOrNull;

    // 확장 데이터가 로드되면 기존 데이터 대체
    if (extendedHistory != null && extendedHistory.isNotEmpty) {
      // 기존 유닛 정보는 유지하되, 확장 데이터에서 새로운 면적 추가
      final existingAreas = apt.units.map((u) => u.exclusiveArea).toSet();
      final newAreas = extendedHistory
          .where((t) => t.type == TradeType.sale)
          .map((t) => t.area)
          .toSet()
          .where((a) => !existingAreas.any((ea) => (ea - a).abs() < AppConstants.areaTolerance))
          .toList()
        ..sort();
      final extraUnits = newAreas.map((a) => ApartmentUnit(
            pyeong: (a / AppConstants.sqmToPyeong).round(),
            supplyArea: a * AppConstants.supplyAreaRatio,
            exclusiveArea: a,
            entranceType: '-',
            rooms: a < 40 ? 1 : (a < 60 ? 2 : (a < 85 ? 3 : 4)),
            bathrooms: a > 100 ? 2 : (a > 60 ? 2 : 1),
          ));

      apt = ApartmentListing(
        name: apt.name,
        location: apt.location,
        currentPrice: apt.currentPrice,
        aiEstimate: apt.aiEstimate,
        priceGap: apt.priceGap,
        floorAreaRatio: apt.floorAreaRatio,
        buildYear: apt.buildYear,
        regionCode: apt.regionCode,
        units: [...apt.units, ...extraUnits],
        tradeHistory: extendedHistory,
      );
    }

    final selectedUnit = apt.units[_selectedUnitIndex];
    final trades = _filteredTrades(apt);
    final gapPrice = _gapPrice(apt);

    // 페이지네이션
    final totalPages = (trades.length / _pageSize).ceil();
    final reversedTrades = trades.reversed.toList();
    final pageStart = _currentPage * _pageSize;
    final pageEnd = (pageStart + _pageSize).clamp(0, reversedTrades.length);
    final pageTrades = pageStart < reversedTrades.length
        ? reversedTrades.sublist(pageStart, pageEnd)
        : <TradeHistory>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(apt.name),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPriceSection(apt, trades, gapPrice),
            const SizedBox(height: AppSpacing.lg),

            // 투자금 정보
            _buildInvestmentSection(apt, gapPrice),
            const SizedBox(height: AppSpacing.xxl),

            _buildInfoSection(apt),
            const SizedBox(height: AppSpacing.xxl),

            // 평형 선택
            const Text('평형 선택', style: AppTypography.heading3),
            const SizedBox(height: AppSpacing.md),
            _buildUnitChips(apt),
            const SizedBox(height: AppSpacing.lg),
            _buildUnitInfoCard(selectedUnit),
            const SizedBox(height: AppSpacing.lg),

            // 안전 전세금 (평형 선택 바로 아래)
            _buildSafeJeonseCard(apt),
            const SizedBox(height: AppSpacing.xxl),

            // 매매/전세 토글
            _buildTradeTypeToggle(),
            const SizedBox(height: AppSpacing.lg),

            // 기간 필터
            _buildPeriodFilter(context),
            const SizedBox(height: AppSpacing.lg),

            // 실거래 추이 그래프
            _buildTradeChart(trades),
            const SizedBox(height: AppSpacing.xxl),

            // 실거래 내역 + 페이지네이션
            if (detailAsync.isLoading && (extendedHistory == null || extendedHistory.isEmpty))
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Center(
                  child: Column(
                    children: [
                      SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(height: AppSpacing.sm),
                      Text('실거래 내역을 불러오는 중...', style: AppTypography.caption1),
                    ],
                  ),
                ),
              )
            else
              _buildTradeList(pageTrades, trades.length),
            if (totalPages > 1) ...[
              const SizedBox(height: AppSpacing.md),
              _buildPagination(totalPages),
            ],
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  // ── 기간 필터 ──
  Widget _buildPeriodFilter(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: PeriodFilter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final filter = PeriodFilter.values[i];
          final isSelected = _periodFilter == filter;
          return GestureDetector(
            onTap: () async {
              if (filter == PeriodFilter.custom) {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2015),
                  lastDate: DateTime.now(),
                  initialDateRange: _customRange ??
                      DateTimeRange(
                        start: DateTime.now().subtract(const Duration(days: 180)),
                        end: DateTime.now(),
                      ),
                );
                if (picked != null) {
                  setState(() {
                    _customRange = picked;
                    _periodFilter = PeriodFilter.custom;
                    _currentPage = 0;
                  });
                }
              } else {
                setState(() {
                  _periodFilter = filter;
                  _currentPage = 0;
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.borderLight,
                ),
              ),
              child: Center(
                child: Text(
                  filter == PeriodFilter.custom && _customRange != null && isSelected
                      ? '${_customRange!.start.month}/${_customRange!.start.day} ~ ${_customRange!.end.month}/${_customRange!.end.day}'
                      : filter.label,
                  style: AppTypography.caption1.copyWith(
                    color: isSelected ? AppColors.white : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── 매매/전세 토글 ──
  Widget _buildTradeTypeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.gray100,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          Expanded(child: _toggleButton('매매', TradeType.sale)),
          const SizedBox(width: 3),
          Expanded(child: _toggleButton('전세', TradeType.jeonse)),
        ],
      ),
    );
  }

  Widget _toggleButton(String label, TradeType type) {
    final isSelected = _selectedTradeType == type;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedTradeType = type;
        _currentPage = 0;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: AppConstants.animCardMs),
        height: 40,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 1))]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.label1.copyWith(
              color: isSelected ? AppColors.primary : AppColors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }

  // ── 가격 정보 (+ 갭가격) ──
  Widget _buildPriceSection(ApartmentListing apt, List<TradeHistory> trades, int? gapPrice) {
    final latestPrice = trades.isNotEmpty ? trades.last.price : apt.currentPrice;

    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('가격 정보', style: AppTypography.heading3),
              PriceSignalBadge(signal: apt.priceSignal, label: apt.priceSignalLabel),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('실거래가 (최근)', style: AppTypography.caption1),
                    const SizedBox(height: 4),
                    Text(
                      PriceFormatter.format(latestPrice),
                      style: AppTypography.number2.copyWith(color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(child: _priceTile('호가 (현재시세)', apt.currentPrice)),
              const SizedBox(width: AppSpacing.lg),
              Expanded(child: _priceTile('AI 추정 적정가', apt.aiEstimate)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // 갭가격
          if (gapPrice != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('갭가격 (매매-전세)', style: AppTypography.caption1.copyWith(color: AppColors.textSecondary)),
                  Text(
                    PriceFormatter.format(gapPrice),
                    style: AppTypography.body2Bold.copyWith(color: AppColors.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: apt.priceSignal == PriceSignal.safe
                  ? AppColors.signalSafe.withValues(alpha: 0.08)
                  : apt.priceSignal == PriceSignal.danger
                      ? AppColors.signalDanger.withValues(alpha: 0.08)
                      : AppColors.signalCaution.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Text(
              'AI 추정 적정가 대비 ${apt.aiGapPercent > 0 ? '+' : ''}${apt.aiGapPercent.toStringAsFixed(1)}%',
              style: AppTypography.caption1.copyWith(
                color: apt.priceSignal == PriceSignal.safe
                    ? AppColors.signalSafe
                    : apt.priceSignal == PriceSignal.danger
                        ? AppColors.signalDanger
                        : AppColors.signalCaution,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceTile(String label, int price) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.caption1),
        const SizedBox(height: 4),
        Text(PriceFormatter.format(price), style: AppTypography.body1Bold),
      ],
    );
  }

  // ── 투자금 정보 ──
  Widget _buildInvestmentSection(ApartmentListing apt, int? gapPrice) {
    final selectedUnit = apt.units[_selectedUnitIndex];
    final latestJeonse = _latestJeonsePrice(apt);

    // 대출 매입 계산
    final maxLoan = (apt.currentPrice * AppConstants.loanCollateralRatio).toInt() - (selectedUnit.rooms * AppConstants.loanRoomPenalty);
    final loanAmount = maxLoan > 0 ? maxLoan : 0;
    final cashNeeded = apt.currentPrice - loanAmount;
    final annualRate = AppConstants.mortgageInterestRate;
    final monthlyInterest = (loanAmount * 10000 * annualRate / 12).round();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet, size: 20, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              const Text('매입 필요 자금', style: AppTypography.heading3),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // 필요 현금 비교 히어로
          Row(
            children: [
              Expanded(
                child: _cashHeroCard(
                  title: '전세자 보유 매입',
                  cash: gapPrice,
                  color: const Color(0xFF34C759),
                  icon: Icons.swap_vert,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _cashHeroCard(
                  title: '대출 매입',
                  cash: cashNeeded,
                  color: AppColors.primary,
                  icon: Icons.account_balance,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // 상세 내역
          // 전세자 보유 매입
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: const Color(0xFF34C759).withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: const Color(0xFF34C759).withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('전세자 보유 매입 상세', style: AppTypography.label2.copyWith(color: const Color(0xFF34C759))),
                const SizedBox(height: AppSpacing.sm),
                if (gapPrice != null && latestJeonse != null) ...[
                  _investRow('매매가 - 전세가', PriceFormatter.format(gapPrice)),
                  const SizedBox(height: 4),
                  _investRow('전세 보증금', PriceFormatter.format(latestJeonse)),
                ] else
                  Text('전세 거래 데이터가 부족해요', style: AppTypography.caption1.copyWith(color: AppColors.textTertiary)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // 대출 매입
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('대출 매입 상세', style: AppTypography.label2.copyWith(color: AppColors.primary)),
                const SizedBox(height: AppSpacing.sm),
                _investRow('최대 대출금', PriceFormatter.format(loanAmount)),
                const SizedBox(height: 4),
                _investRow('필요 현금', PriceFormatter.format(cashNeeded)),
                const Divider(height: AppSpacing.lg),
                _investRow('월 이자 (${AppConstants.mortgageInterestLabel})', _formatWon(monthlyInterest)),
                const SizedBox(height: 2),
                Text(
                  '* 대출 = 시세 80% - (방 수 × 5,000만원)',
                  style: AppTypography.caption2.copyWith(color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cashHeroCard({
    required String title,
    required int? cash,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg, horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 24),
          const SizedBox(height: AppSpacing.sm),
          Text(title, style: AppTypography.caption1.copyWith(color: Colors.white.withValues(alpha: 0.9))),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              cash != null ? PriceFormatter.format(cash) : '- -',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontFamily: 'Pretendard',
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text('필요 현금', style: AppTypography.caption2.copyWith(color: Colors.white.withValues(alpha: 0.7))),
        ],
      ),
    );
  }

  Widget _investRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.caption1.copyWith(color: AppColors.textSecondary)),
        Text(value, style: AppTypography.body2Bold),
      ],
    );
  }

  /// 원 단위를 만원/억으로 포맷
  String _formatWon(int won) {
    if (won >= 100000000) {
      return '${(won / 100000000).toStringAsFixed(1)}억원';
    } else if (won >= 10000) {
      return '${(won / 10000).toStringAsFixed(0)}만원';
    }
    return '${_addComma(won)}원';
  }

  String _addComma(int n) {
    return n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  // ── 안전 전세금 ──
  Widget _buildSafeJeonseCard(ApartmentListing apt) {
    final safePrice = _safeJeonsePrice(apt);
    final latestJeonse = _latestJeonsePrice(apt);

    if (safePrice == null) return const SizedBox();

    final isSafe = latestJeonse != null && latestJeonse <= safePrice;
    final insuranceLimit = (apt.currentPrice * AppConstants.jeonseInsuranceLimitRatio).toInt();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: isSafe
              ? AppColors.signalSafe.withValues(alpha: 0.3)
              : AppColors.signalCaution.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.shield_outlined,
                size: 20,
                color: isSafe ? AppColors.signalSafe : AppColors.signalCaution,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '안전 전세금',
                style: AppTypography.heading3.copyWith(
                  color: isSafe ? AppColors.signalSafe : AppColors.signalCaution,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('안전 전세금', style: AppTypography.caption1),
                    const SizedBox(height: 4),
                    Text(
                      PriceFormatter.format(safePrice),
                      style: AppTypography.body1Bold.copyWith(
                        color: isSafe ? AppColors.signalSafe : AppColors.signalCaution,
                      ),
                    ),
                  ],
                ),
              ),
              if (latestJeonse != null)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('최근 전세가', style: AppTypography.caption1),
                      const SizedBox(height: 4),
                      Text(PriceFormatter.format(latestJeonse), style: AppTypography.body1Bold),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: (isSafe ? AppColors.signalSafe : AppColors.signalCaution).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSafe ? '현재 전세가가 안전 범위 내에 있어요' : '현재 전세가가 안전 범위를 초과해요',
                  style: AppTypography.caption1.copyWith(
                    color: isSafe ? AppColors.signalSafe : AppColors.signalCaution,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '전세보증보험 한도: ${PriceFormatter.format(insuranceLimit)}',
                  style: AppTypography.caption2.copyWith(color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 기본 정보 ──
  Widget _buildInfoSection(ApartmentListing apt) {
    final addressQuery = '${apt.name} ${apt.location}';
    final addressAsync = ref.watch(aptAddressProvider(addressQuery));
    final displayAddress = addressAsync.when(
      data: (address) => address.isNotEmpty ? address : apt.location,
      loading: () => apt.location,
      error: (_, __) => apt.location,
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('기본 정보', style: AppTypography.heading3),
          const SizedBox(height: AppSpacing.lg),
          _addressRow(displayAddress),
          const SizedBox(height: AppSpacing.md),
          _infoRow('건축년도', '${apt.buildYear}년'),
          const SizedBox(height: AppSpacing.md),
          _infoRow('용적률', '${apt.floorAreaRatio.toStringAsFixed(0)}%'),
        ],
      ),
    );
  }

  Widget _addressRow(String address) {
    return Row(
      children: [
        Text('위치', style: AppTypography.body2.copyWith(color: AppColors.textSecondary)),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            address,
            style: AppTypography.body2Bold,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: address));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('주소가 복사되었어요'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          child: Icon(Icons.copy_rounded, size: 16, color: AppColors.textTertiary),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.body2.copyWith(color: AppColors.textSecondary)),
        Text(value, style: AppTypography.body2Bold),
      ],
    );
  }

  // ── 평형 선택 ──
  Widget _buildUnitChips(ApartmentListing apt) {
    return SizedBox(
      height: AppSpacing.buttonSmallHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: apt.units.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, i) {
          final unit = apt.units[i];
          final isSelected = _selectedUnitIndex == i;
          return ChoiceChip(
            label: Text('${unit.pyeong}평'),
            selected: isSelected,
            onSelected: (_) => setState(() {
              _selectedUnitIndex = i;
              _currentPage = 0;
            }),
            labelStyle: AppTypography.label2.copyWith(
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
          );
        },
      ),
    );
  }

  Widget _buildUnitInfoCard(ApartmentUnit unit) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${unit.pyeong}평형 상세', style: AppTypography.body1Bold),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(child: _unitDetail('공급면적', '${unit.supplyArea.toStringAsFixed(2)}㎡')),
              Expanded(child: _unitDetail('전용면적', '${unit.exclusiveArea.toStringAsFixed(2)}㎡')),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: _unitDetail('현관구조', unit.entranceType)),
              Expanded(child: _unitDetail('방/화장실', '${unit.rooms}개 / ${unit.bathrooms}개')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _unitDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.caption1),
        const SizedBox(height: 4),
        Text(value, style: AppTypography.body2Bold),
      ],
    );
  }

  // ── 실거래 추이 차트 ──
  Widget _buildTradeChart(List<TradeHistory> trades) {
    if (trades.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Center(
          child: Text(
            '${_selectedTradeType == TradeType.sale ? '매매' : '전세'} 거래 데이터가 없어요',
            style: AppTypography.caption1,
          ),
        ),
      );
    }

    final monthlyAvg = <String, List<int>>{};
    for (final t in trades) {
      final key = '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}';
      monthlyAvg.putIfAbsent(key, () => []).add(t.price);
    }

    final sortedKeys = monthlyAvg.keys.toList()..sort();
    final spots = <FlSpot>[];
    final labels = <String>[];

    for (int i = 0; i < sortedKeys.length; i++) {
      final prices = monthlyAvg[sortedKeys[i]]!;
      final avg = prices.reduce((a, b) => a + b) / prices.length;
      spots.add(FlSpot(i.toDouble(), avg));
      final parts = sortedKeys[i].split('-');
      labels.add('${parts[1]}월');
    }

    if (spots.length < 2) {
      spots.insert(0, FlSpot(-1, spots.first.y));
      labels.insert(0, '');
    }

    final rawMinY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final rawMaxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final minY = rawMinY == rawMaxY ? rawMinY * 0.9 : rawMinY * 0.95;
    final maxY = rawMinY == rawMaxY ? rawMaxY * AppConstants.chartYAxisMaxMultiplier : rawMaxY * AppConstants.chartYAxisEstimateMultiplier;
    final chartColor = _selectedTradeType == TradeType.sale ? AppColors.primary : const Color(0xFF34C759);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_selectedTradeType == TradeType.sale ? '매매' : '전세'} 실거래 추이',
            style: AppTypography.body2Bold,
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxY - minY) > 0 ? (maxY - minY) / 4 : 1,
                  getDrawingHorizontalLine: (value) => FlLine(color: AppColors.borderLight, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= labels.length) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(labels[idx], style: AppTypography.caption2),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 52,
                      getTitlesWidget: (value, meta) {
                        return Text(PriceFormatter.formatShort(value.toInt()), style: AppTypography.caption2);
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minY: minY,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: chartColor,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                        radius: 3,
                        color: chartColor,
                        strokeWidth: 2,
                        strokeColor: AppColors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(show: true, color: chartColor.withValues(alpha: 0.08)),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          PriceFormatter.format(spot.y.toInt()),
                          AppTypography.caption1.copyWith(color: AppColors.white),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 실거래 내역 (페이지네이션) ──
  Widget _buildTradeList(List<TradeHistory> pageTrades, int totalCount) {
    final typeLabel = _selectedTradeType == TradeType.sale ? '매매' : '전세';
    final priceColor = _selectedTradeType == TradeType.sale ? AppColors.primary : const Color(0xFF34C759);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$typeLabel 실거래 내역', style: AppTypography.heading3),
            Text('$totalCount건', style: AppTypography.caption1),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (pageTrades.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.xxl),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Center(
              child: Text('해당 조건의 $typeLabel 거래 내역이 없어요', style: AppTypography.caption1),
            ),
          )
        else
          ...pageTrades.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.cardPadding),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${t.date.year}.${t.date.month.toString().padLeft(2, '0')}.${t.date.day.toString().padLeft(2, '0')}',
                              style: AppTypography.body2Bold,
                            ),
                            const SizedBox(height: 4),
                            Text('${t.area.toStringAsFixed(2)}㎡ · ${t.floor}층', style: AppTypography.caption1),
                          ],
                        ),
                      ),
                      Text(
                        PriceFormatter.format(t.price),
                        style: AppTypography.body1Bold.copyWith(color: priceColor),
                      ),
                    ],
                  ),
                ),
              )),
      ],
    );
  }

  // ── 페이지네이션 ──
  Widget _buildPagination(int totalPages) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 이전
        GestureDetector(
          onTap: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _currentPage > 0 ? AppColors.surface : AppColors.gray50,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Icon(
              Icons.chevron_left,
              size: 20,
              color: _currentPage > 0 ? AppColors.textPrimary : AppColors.gray300,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),

        // 페이지 번호
        ...List.generate(totalPages, (i) {
          final isSelected = i == _currentPage;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: GestureDetector(
              onTap: () => setState(() => _currentPage = i),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  border: Border.all(color: isSelected ? AppColors.primary : AppColors.borderLight),
                ),
                child: Center(
                  child: Text(
                    '${i + 1}',
                    style: AppTypography.label2.copyWith(
                      color: isSelected ? AppColors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),

        const SizedBox(width: AppSpacing.sm),
        // 다음
        GestureDetector(
          onTap: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _currentPage < totalPages - 1 ? AppColors.surface : AppColors.gray50,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Icon(
              Icons.chevron_right,
              size: 20,
              color: _currentPage < totalPages - 1 ? AppColors.textPrimary : AppColors.gray300,
            ),
          ),
        ),
      ],
    );
  }
}
