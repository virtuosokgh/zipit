import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/region_codes.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../models/market_filter.dart';
import '../providers/market_filter_provider.dart';
import 'filter_bottom_sheets.dart';

class MarketFilterBar extends ConsumerStatefulWidget {
  const MarketFilterBar({super.key});

  @override
  ConsumerState<MarketFilterBar> createState() => _MarketFilterBarState();
}

class _MarketFilterBarState extends ConsumerState<MarketFilterBar> {
  bool _detailExpanded = false;

  // 상세 필터 임시 값 (적용 전)
  double? _tmpGapMin, _tmpGapMax;
  double? _tmpFarMin, _tmpFarMax;
  double? _tmpBcrMin, _tmpBcrMax;
  int? _tmpRoomsMin;
  double? _tmpJeonseRatioMin, _tmpJeonseRatioMax;

  void _openDetail() {
    final f = ref.read(marketFilterProvider);
    _tmpGapMin = f.gapMin;
    _tmpGapMax = f.gapMax;
    _tmpFarMin = f.farMin;
    _tmpFarMax = f.farMax;
    _tmpBcrMin = f.bcrMin;
    _tmpBcrMax = f.bcrMax;
    _tmpRoomsMin = f.roomsMin;
    _tmpJeonseRatioMin = f.jeonseRatioMin;
    _tmpJeonseRatioMax = f.jeonseRatioMax;
    setState(() => _detailExpanded = true);
  }

  void _applyDetail() {
    ref.read(marketFilterProvider.notifier).applyDetailFilters(
      gapMin: _tmpGapMin,
      gapMax: _tmpGapMax,
      farMin: _tmpFarMin,
      farMax: _tmpFarMax,
      bcrMin: _tmpBcrMin,
      bcrMax: _tmpBcrMax,
      roomsMin: _tmpRoomsMin,
      jeonseRatioMin: _tmpJeonseRatioMin,
      jeonseRatioMax: _tmpJeonseRatioMax,
    );
    setState(() => _detailExpanded = false);
  }

  void _resetDetail() {
    setState(() {
      _tmpGapMin = null;
      _tmpGapMax = null;
      _tmpFarMin = null;
      _tmpFarMax = null;
      _tmpBcrMin = null;
      _tmpBcrMax = null;
      _tmpRoomsMin = null;
      _tmpJeonseRatioMin = null;
      _tmpJeonseRatioMax = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(marketFilterProvider);

    return Column(
      children: [
        // 대표 필터 칩 (가로 스크롤)
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            children: [
              _FilterChip(
                label: filter.tradeType.label,
                isActive: filter.tradeType != TradeTypeFilter.sale,
                onTap: () => _showTradeTypeSheet(context, ref),
              ),
              const SizedBox(width: 6),
              _FilterChip(
                label: _regionLabel(filter),
                isActive: filter.regionCodes.isNotEmpty,
                onTap: () => _showRegionSheet(context, ref),
              ),
              const SizedBox(width: 6),
              _FilterChip(
                label: _priceLabel(filter),
                isActive: filter.priceMin != null || filter.priceMax != null ||
                    filter.monthlyRentMin != null || filter.monthlyRentMax != null,
                onTap: () => _showPriceSheet(context, ref),
              ),
              const SizedBox(width: 6),
              _FilterChip(
                label: _areaLabel(filter),
                isActive: filter.areaMin != null || filter.areaMax != null,
                onTap: () => _showAreaSheet(context, ref),
              ),
              const SizedBox(width: 6),
              _FilterChip(
                label: _approvalLabel(filter),
                isActive: filter.approvalYearMin != null || filter.approvalYearMax != null,
                onTap: () => _showApprovalSheet(context, ref),
              ),
              const SizedBox(width: 6),
              _FilterChip(
                label: _householdsLabel(filter),
                isActive: filter.householdsMin != null || filter.householdsMax != null,
                onTap: () => _showHouseholdsSheet(context, ref),
              ),
              const SizedBox(width: 6),
              // 상세 필터 버튼
              _FilterChip(
                label: filter.hasActiveDetailFilters
                    ? '상세 ${filter.activeDetailFilterCount}'
                    : '상세',
                isActive: filter.hasActiveDetailFilters,
                icon: Icons.tune,
                onTap: () {
                  if (_detailExpanded) {
                    setState(() => _detailExpanded = false);
                  } else {
                    _openDetail();
                  }
                },
              ),
            ],
          ),
        ),

        // 상세 필터 패널 (펼쳐질 때)
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: _buildDetailPanel(),
          crossFadeState: _detailExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }

  Widget _buildDetailPanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, 0),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('상세 필터', style: AppTypography.body2Bold),
          const SizedBox(height: AppSpacing.lg),

          // 갭차이
          _detailRangeRow(
            label: '갭차이',
            unit: '%',
            minVal: _tmpGapMin,
            maxVal: _tmpGapMax,
            rangeMin: -20,
            rangeMax: 30,
            divisions: 50,
            onChanged: (min, max) => setState(() {
              _tmpGapMin = min;
              _tmpGapMax = max;
            }),
            formatValue: (v) => '${v.toStringAsFixed(0)}%',
          ),
          const SizedBox(height: AppSpacing.md),

          // 용적률
          _detailRangeRow(
            label: '용적률',
            unit: '%',
            minVal: _tmpFarMin,
            maxVal: _tmpFarMax,
            rangeMin: 100,
            rangeMax: 500,
            divisions: 40,
            onChanged: (min, max) => setState(() {
              _tmpFarMin = min;
              _tmpFarMax = max;
            }),
            formatValue: (v) => '${v.toStringAsFixed(0)}%',
          ),
          const SizedBox(height: AppSpacing.md),

          // 건폐율
          _detailRangeRow(
            label: '건폐율',
            unit: '%',
            minVal: _tmpBcrMin,
            maxVal: _tmpBcrMax,
            rangeMin: 10,
            rangeMax: 60,
            divisions: 50,
            onChanged: (min, max) => setState(() {
              _tmpBcrMin = min;
              _tmpBcrMax = max;
            }),
            formatValue: (v) => '${v.toStringAsFixed(0)}%',
          ),
          const SizedBox(height: AppSpacing.md),

          // 방 수
          _detailLabel('방 수'),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 6,
            children: [null, 1, 2, 3, 4].map((rooms) {
              final isSelected = _tmpRoomsMin == rooms;
              final label = rooms == null ? '전체' : '$rooms룸+';
              return ChoiceChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (_) => setState(() => _tmpRoomsMin = rooms),
                selectedColor: AppColors.primary.withValues(alpha: 0.12),
                labelStyle: AppTypography.caption1.copyWith(
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  side: BorderSide(color: isSelected ? AppColors.primary : AppColors.gray300),
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.md),

          // 전세가율
          _detailRangeRow(
            label: '전세가율',
            unit: '%',
            minVal: _tmpJeonseRatioMin,
            maxVal: _tmpJeonseRatioMax,
            rangeMin: 20,
            rangeMax: 100,
            divisions: 40,
            onChanged: (min, max) => setState(() {
              _tmpJeonseRatioMin = min;
              _tmpJeonseRatioMax = max;
            }),
            formatValue: (v) => '${v.toStringAsFixed(0)}%',
          ),
          const SizedBox(height: AppSpacing.xl),

          // 초기화 + 적용 버튼
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _resetDetail,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                    side: const BorderSide(color: AppColors.gray300),
                  ),
                  child: Text('초기화', style: AppTypography.label2.copyWith(color: AppColors.textSecondary)),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _applyDetail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                  ),
                  child: Text('적용', style: AppTypography.label2.copyWith(color: AppColors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailLabel(String text) {
    return Text(text, style: AppTypography.caption1.copyWith(color: AppColors.textSecondary));
  }

  Widget _detailRangeRow({
    required String label,
    required String unit,
    required double? minVal,
    required double? maxVal,
    required double rangeMin,
    required double rangeMax,
    required int divisions,
    required void Function(double? min, double? max) onChanged,
    required String Function(double) formatValue,
  }) {
    final currentMin = minVal ?? rangeMin;
    final currentMax = maxVal ?? rangeMax;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _detailLabel(label),
            Text(
              minVal == null && maxVal == null
                  ? '전체'
                  : '${formatValue(currentMin)} ~ ${formatValue(currentMax)}',
              style: AppTypography.caption1.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: AppColors.gray200,
            thumbColor: AppColors.primary,
            overlayColor: AppColors.primary.withValues(alpha: 0.12),
            rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: RangeSlider(
            values: RangeValues(currentMin, currentMax),
            min: rangeMin,
            max: rangeMax,
            divisions: divisions,
            onChanged: (v) {
              final newMin = v.start > rangeMin ? v.start : null;
              final newMax = v.end < rangeMax ? v.end : null;
              onChanged(newMin, newMax);
            },
          ),
        ),
      ],
    );
  }

  // ── Label helpers ──

  String _regionLabel(MarketFilter filter) {
    if (filter.regionCodes.isEmpty) return '지역';
    if (filter.regionCodes.length == 1) {
      return RegionCodes.codeToName[filter.regionCodes.first] ?? '지역';
    }
    return '${RegionCodes.codeToName[filter.regionCodes.first] ?? '지역'} 외 ${filter.regionCodes.length - 1}';
  }

  String _priceLabel(MarketFilter filter) {
    final hasPrice = filter.priceMin != null || filter.priceMax != null;
    final hasRent = filter.monthlyRentMin != null || filter.monthlyRentMax != null;

    final defaultLabel = switch (filter.tradeType) {
      TradeTypeFilter.jeonse => '보증금',
      TradeTypeFilter.monthly => '보증금/월세',
      _ => '가격',
    };

    if (!hasPrice && !hasRent) return defaultLabel;

    final min = filter.priceMin != null ? PriceFormatter.formatShort(filter.priceMin!.toInt()) : '';
    final max = filter.priceMax != null ? PriceFormatter.formatShort(filter.priceMax!.toInt()) : '';
    String priceStr = '';
    if (min.isNotEmpty && max.isNotEmpty) {
      priceStr = '$min~$max';
    } else if (min.isNotEmpty) {
      priceStr = '$min~';
    } else if (max.isNotEmpty) {
      priceStr = '~$max';
    }

    if (filter.tradeType == TradeTypeFilter.monthly && hasRent) {
      final rMin = filter.monthlyRentMin != null ? '${filter.monthlyRentMin!.toInt()}만' : '';
      final rMax = filter.monthlyRentMax != null ? '${filter.monthlyRentMax!.toInt()}만' : '';
      String rentStr = '';
      if (rMin.isNotEmpty && rMax.isNotEmpty) {
        rentStr = '$rMin~$rMax';
      } else if (rMin.isNotEmpty) {
        rentStr = '$rMin~';
      } else if (rMax.isNotEmpty) {
        rentStr = '~$rMax';
      }
      if (priceStr.isNotEmpty && rentStr.isNotEmpty) return '$priceStr/$rentStr';
      if (rentStr.isNotEmpty) return '월세 $rentStr';
    }

    return priceStr.isNotEmpty ? priceStr : defaultLabel;
  }

  String _areaLabel(MarketFilter filter) {
    if (filter.areaMin == null && filter.areaMax == null) return '면적';
    final min = filter.areaMin != null ? '${(filter.areaMin! / AppConstants.sqmToPyeong).round()}평' : '';
    final max = filter.areaMax != null ? '${(filter.areaMax! / AppConstants.sqmToPyeong).round()}평' : '';
    if (min.isNotEmpty && max.isNotEmpty) return '$min~$max';
    if (min.isNotEmpty) return '$min~';
    return '~$max';
  }

  String _approvalLabel(MarketFilter filter) {
    if (filter.approvalYearMin == null && filter.approvalYearMax == null) return '사용승인일';
    if (filter.approvalYearMin != null && filter.approvalYearMax != null) {
      return '${filter.approvalYearMin}~${filter.approvalYearMax}년';
    }
    if (filter.approvalYearMin != null) return '${filter.approvalYearMin}년~';
    return '~${filter.approvalYearMax}년';
  }

  String _householdsLabel(MarketFilter filter) {
    if (filter.householdsMin == null && filter.householdsMax == null) return '세대수';
    if (filter.householdsMin != null && filter.householdsMax != null) {
      return '${filter.householdsMin}~${filter.householdsMax}세대';
    }
    if (filter.householdsMin != null) return '${filter.householdsMin}세대+';
    return '~${filter.householdsMax}세대';
  }

  // ── Bottom sheet openers ──

  void _showTradeTypeSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
      ),
      builder: (_) => TradeTypeFilterSheet(
        current: ref.read(marketFilterProvider).tradeType,
        onSelect: (type) => ref.read(marketFilterProvider.notifier).setTradeType(type),
      ),
    );
  }

  void _showRegionSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
      ),
      builder: (_) => RegionFilterSheet(
        selectedCodes: ref.read(marketFilterProvider).regionCodes,
        onApply: (codes) => ref.read(marketFilterProvider.notifier).setRegionCodes(codes),
      ),
    );
  }

  void _showPriceSheet(BuildContext context, WidgetRef ref) {
    final filter = ref.read(marketFilterProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
      ),
      builder: (_) => PriceFilterSheet(
        tradeType: filter.tradeType,
        currentMin: filter.priceMin,
        currentMax: filter.priceMax,
        currentMonthlyRentMin: filter.monthlyRentMin,
        currentMonthlyRentMax: filter.monthlyRentMax,
        onApplyPrice: (min, max) => ref.read(marketFilterProvider.notifier).setPriceRange(min, max),
        onApplyMonthlyRent: (min, max) => ref.read(marketFilterProvider.notifier).setMonthlyRentRange(min, max),
      ),
    );
  }

  void _showAreaSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
      ),
      builder: (_) => AreaFilterSheet(
        currentMin: ref.read(marketFilterProvider).areaMin,
        currentMax: ref.read(marketFilterProvider).areaMax,
        onApply: (min, max) => ref.read(marketFilterProvider.notifier).setAreaRange(min, max),
      ),
    );
  }

  void _showApprovalSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
      ),
      builder: (_) => ApprovalYearFilterSheet(
        currentMin: ref.read(marketFilterProvider).approvalYearMin,
        currentMax: ref.read(marketFilterProvider).approvalYearMax,
        onApply: (min, max) => ref.read(marketFilterProvider.notifier).setApprovalYearRange(min, max),
      ),
    );
  }

  void _showHouseholdsSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
      ),
      builder: (_) => HouseholdsFilterSheet(
        currentMin: ref.read(marketFilterProvider).householdsMin,
        currentMax: ref.read(marketFilterProvider).householdsMax,
        onApply: (min, max) => ref.read(marketFilterProvider.notifier).setHouseholdsRange(min, max),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final IconData? icon;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isActive,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.gray300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: isActive ? AppColors.primary : AppColors.textSecondary),
              const SizedBox(width: 3),
            ],
            Text(
              label,
              style: AppTypography.caption1.copyWith(
                color: isActive ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            const SizedBox(width: 1),
            Icon(
              Icons.keyboard_arrow_down,
              size: 14,
              color: isActive ? AppColors.primary : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
