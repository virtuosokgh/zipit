import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/region_codes.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../models/market_filter.dart';

// ── 공통 ──

Widget _sheetHandle() {
  return Center(
    child: Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.gray300,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

Widget _sheetButtons({
  required VoidCallback onReset,
  required VoidCallback onApply,
}) {
  return Row(
    children: [
      Expanded(
        child: OutlinedButton(
          onPressed: onReset,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
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
          onPressed: onApply,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
          ),
          child: Text('적용', style: AppTypography.label2.copyWith(color: AppColors.white)),
        ),
      ),
    ],
  );
}

EdgeInsets get _sheetPadding =>
    const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.lg, AppSpacing.screenH, AppSpacing.xxl);

// ── 거래유형 ──

class TradeTypeFilterSheet extends StatelessWidget {
  final TradeTypeFilter current;
  final void Function(TradeTypeFilter) onSelect;

  const TradeTypeFilterSheet({super.key, required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _sheetPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sheetHandle(),
          const SizedBox(height: AppSpacing.lg),
          const Text('거래유형', style: AppTypography.heading3),
          const SizedBox(height: AppSpacing.lg),
          ...TradeTypeFilter.values.map((type) {
            final isSelected = current == type;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                type.label,
                style: AppTypography.body2.copyWith(
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              trailing: isSelected ? const Icon(Icons.check, color: AppColors.primary, size: 20) : null,
              onTap: () {
                onSelect(type);
                Navigator.pop(context);
              },
            );
          }),
        ],
      ),
    );
  }
}

// ── 지역 ──

class RegionFilterSheet extends StatefulWidget {
  final List<String> selectedCodes;
  final void Function(List<String>) onApply;

  const RegionFilterSheet({super.key, required this.selectedCodes, required this.onApply});

  @override
  State<RegionFilterSheet> createState() => _RegionFilterSheetState();
}

class _RegionFilterSheetState extends State<RegionFilterSheet> {
  late Set<String> _selectedCodes;

  @override
  void initState() {
    super.initState();
    _selectedCodes = Set<String>.from(widget.selectedCodes);
  }

  /// 카테고리 "전체" 선택 여부
  bool _isAllSelected(List<String> allCodes) {
    return allCodes.every((c) => _selectedCodes.contains(c));
  }

  /// "전체" 토글: 전체 선택 ↔ 전체 해제
  void _toggleAll(List<String> allCodes) {
    setState(() {
      if (_isAllSelected(allCodes)) {
        _selectedCodes.removeAll(allCodes);
      } else {
        _selectedCodes.addAll(allCodes);
      }
    });
  }

  /// 개별 구/시 토글
  void _toggleCode(String code) {
    setState(() {
      if (_selectedCodes.contains(code)) {
        _selectedCodes.remove(code);
      } else {
        _selectedCodes.add(code);
      }
    });
  }

  Widget _categorySection(String title, List<String> allCodes, Map<String, String> nameToCode) {
    final isAll = _isAllSelected(allCodes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.label1.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            // "전체" 칩 (맨 앞)
            ChoiceChip(
              label: Text('$title 전체'),
              selected: isAll,
              onSelected: (_) => _toggleAll(allCodes),
              selectedColor: AppColors.primary.withValues(alpha: 0.12),
              labelStyle: AppTypography.body2.copyWith(
                color: isAll ? AppColors.primary : AppColors.textPrimary,
                fontWeight: isAll ? FontWeight.w600 : FontWeight.w400,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                side: BorderSide(color: isAll ? AppColors.primary : AppColors.gray300),
              ),
            ),
            // 개별 구/시 칩
            ...nameToCode.entries.map((entry) {
              final code = entry.value;
              final isSelected = _selectedCodes.contains(code);
              return ChoiceChip(
                label: Text(entry.key),
                selected: isSelected,
                onSelected: (_) => _toggleCode(code),
                selectedColor: AppColors.primary.withValues(alpha: 0.12),
                labelStyle: AppTypography.body2.copyWith(
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  side: BorderSide(color: isSelected ? AppColors.primary : AppColors.gray300),
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _sheetPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sheetHandle(),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('지역 선택', style: AppTypography.heading3),
              if (_selectedCodes.isNotEmpty)
                Text(
                  '${_selectedCodes.length}개 선택',
                  style: AppTypography.caption1.copyWith(color: AppColors.primary),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('복수 선택 가능해요', style: AppTypography.caption1.copyWith(color: AppColors.textTertiary)),
          const SizedBox(height: AppSpacing.lg),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 서울
                  _categorySection('서울', RegionCodes.seoulAll, RegionCodes.seoulGu),
                  const SizedBox(height: AppSpacing.lg),
                  const Divider(height: 1, color: AppColors.borderLight),
                  const SizedBox(height: AppSpacing.lg),
                  // 인천
                  _categorySection('인천', RegionCodes.incheonAll, RegionCodes.incheonGu),
                  const SizedBox(height: AppSpacing.lg),
                  const Divider(height: 1, color: AppColors.borderLight),
                  const SizedBox(height: AppSpacing.lg),
                  // 경기
                  _categorySection('경기', RegionCodes.gyeonggiAll, RegionCodes.gyeonggiSi),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          _sheetButtons(
            onReset: () => setState(() => _selectedCodes.clear()),
            onApply: () {
              widget.onApply(_selectedCodes.toList());
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

// ── 가격 ──

class PriceFilterSheet extends StatefulWidget {
  final TradeTypeFilter tradeType;
  final double? currentMin;
  final double? currentMax;
  final double? currentMonthlyRentMin;
  final double? currentMonthlyRentMax;
  final void Function(double? min, double? max) onApplyPrice;
  final void Function(double? min, double? max)? onApplyMonthlyRent;

  const PriceFilterSheet({
    super.key,
    this.tradeType = TradeTypeFilter.sale,
    this.currentMin,
    this.currentMax,
    this.currentMonthlyRentMin,
    this.currentMonthlyRentMax,
    required this.onApplyPrice,
    this.onApplyMonthlyRent,
  });

  @override
  State<PriceFilterSheet> createState() => _PriceFilterSheetState();
}

class _PriceFilterSheetState extends State<PriceFilterSheet> {
  late RangeValues _priceRange;
  late RangeValues _rentRange;

  // 매매: 0~30억, 전세: 0~15억, 월세 보증금: 0~5억
  double get _priceMin => 0.0;
  double get _priceMax => switch (widget.tradeType) {
    TradeTypeFilter.monthly => 50000.0,   // 5억
    TradeTypeFilter.jeonse => 150000.0,   // 15억
    _ => 300000.0,                         // 30억
  };
  int get _priceDivisions => switch (widget.tradeType) {
    TradeTypeFilter.monthly => 50,
    TradeTypeFilter.jeonse => 60,
    _ => 60,
  };
  String get _priceMaxLabel => switch (widget.tradeType) {
    TradeTypeFilter.monthly => '5억+',
    TradeTypeFilter.jeonse => '15억+',
    _ => '30억+',
  };
  String get _title => switch (widget.tradeType) {
    TradeTypeFilter.jeonse => '전세 보증금',
    TradeTypeFilter.monthly => '월세 보증금',
    _ => '매매가',
  };

  // 월세: 0~500만원
  static const _rentMin = 0.0;
  static const _rentMax = 500.0;

  @override
  void initState() {
    super.initState();
    _priceRange = RangeValues(widget.currentMin ?? _priceMin, widget.currentMax ?? _priceMax);
    _rentRange = RangeValues(widget.currentMonthlyRentMin ?? _rentMin, widget.currentMonthlyRentMax ?? _rentMax);
  }

  String _formatPriceLabel(RangeValues range, double max, String maxLabel) {
    return '${PriceFormatter.formatShort(range.start.toInt())} ~ ${range.end >= max ? maxLabel : PriceFormatter.formatShort(range.end.toInt())}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _sheetPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sheetHandle(),
          const SizedBox(height: AppSpacing.lg),
          Text(_title, style: AppTypography.heading3),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Text(
              _formatPriceLabel(_priceRange, _priceMax, _priceMaxLabel),
              style: AppTypography.body1Bold.copyWith(color: AppColors.primary),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          RangeSlider(
            values: _priceRange,
            min: _priceMin, max: _priceMax, divisions: _priceDivisions,
            activeColor: AppColors.primary,
            inactiveColor: AppColors.gray200,
            onChanged: (v) => setState(() => _priceRange = v),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text('0', style: AppTypography.caption2), Text(_priceMaxLabel, style: AppTypography.caption2)],
          ),

          // 월세 필터일 때 월세금 슬라이더 추가
          if (widget.tradeType == TradeTypeFilter.monthly) ...[
            const SizedBox(height: AppSpacing.xxl),
            const Text('월세', style: AppTypography.heading3),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: Text(
                '${_rentRange.start.toInt()}만 ~ ${_rentRange.end >= _rentMax ? '500만+' : '${_rentRange.end.toInt()}만'}',
                style: AppTypography.body1Bold.copyWith(color: AppColors.primary),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            RangeSlider(
              values: _rentRange,
              min: _rentMin, max: _rentMax, divisions: 50,
              activeColor: AppColors.primary,
              inactiveColor: AppColors.gray200,
              onChanged: (v) => setState(() => _rentRange = v),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Text('0만', style: AppTypography.caption2), Text('500만+', style: AppTypography.caption2)],
            ),
          ],

          const SizedBox(height: AppSpacing.xxl),
          _sheetButtons(
            onReset: () => setState(() {
              _priceRange = RangeValues(_priceMin, _priceMax);
              _rentRange = const RangeValues(_rentMin, _rentMax);
            }),
            onApply: () {
              widget.onApplyPrice(
                _priceRange.start > _priceMin ? _priceRange.start : null,
                _priceRange.end < _priceMax ? _priceRange.end : null,
              );
              if (widget.tradeType == TradeTypeFilter.monthly && widget.onApplyMonthlyRent != null) {
                widget.onApplyMonthlyRent!(
                  _rentRange.start > _rentMin ? _rentRange.start : null,
                  _rentRange.end < _rentMax ? _rentRange.end : null,
                );
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

// ── 면적 ──

class AreaFilterSheet extends StatefulWidget {
  final double? currentMin;
  final double? currentMax;
  final void Function(double? min, double? max) onApply;

  const AreaFilterSheet({super.key, this.currentMin, this.currentMax, required this.onApply});

  @override
  State<AreaFilterSheet> createState() => _AreaFilterSheetState();
}

class _AreaFilterSheetState extends State<AreaFilterSheet> {
  late RangeValues _range;
  static const _min = 0.0;
  static const _max = 250.0; // ㎡

  @override
  void initState() {
    super.initState();
    _range = RangeValues(widget.currentMin ?? _min, widget.currentMax ?? _max);
  }

  String _toPyeong(double sqm) => '${(sqm / AppConstants.sqmToPyeong).round()}평';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _sheetPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sheetHandle(),
          const SizedBox(height: AppSpacing.lg),
          const Text('전용면적', style: AppTypography.heading3),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Text(
              '${_toPyeong(_range.start)} ~ ${_range.end >= _max ? '75평+' : _toPyeong(_range.end)}',
              style: AppTypography.body1Bold.copyWith(color: AppColors.primary),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Center(
            child: Text(
              '${_range.start.toStringAsFixed(0)}㎡ ~ ${_range.end >= _max ? '250㎡+' : '${_range.end.toStringAsFixed(0)}㎡'}',
              style: AppTypography.caption2,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          RangeSlider(
            values: _range,
            min: _min, max: _max, divisions: 50,
            activeColor: AppColors.primary,
            inactiveColor: AppColors.gray200,
            onChanged: (v) => setState(() => _range = v),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text('0평', style: AppTypography.caption2), Text('75평+', style: AppTypography.caption2)],
          ),
          const SizedBox(height: AppSpacing.xxl),
          _sheetButtons(
            onReset: () => setState(() => _range = const RangeValues(_min, _max)),
            onApply: () {
              widget.onApply(_range.start > _min ? _range.start : null, _range.end < _max ? _range.end : null);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

// ── 사용승인일 ──

class ApprovalYearFilterSheet extends StatefulWidget {
  final int? currentMin;
  final int? currentMax;
  final void Function(int? min, int? max) onApply;

  const ApprovalYearFilterSheet({super.key, this.currentMin, this.currentMax, required this.onApply});

  @override
  State<ApprovalYearFilterSheet> createState() => _ApprovalYearFilterSheetState();
}

class _ApprovalYearFilterSheetState extends State<ApprovalYearFilterSheet> {
  late RangeValues _range;
  static const _min = 1980.0;
  late final double _max;

  @override
  void initState() {
    super.initState();
    _max = DateTime.now().year.toDouble();
    _range = RangeValues(
      widget.currentMin?.toDouble() ?? _min,
      widget.currentMax?.toDouble() ?? _max,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _sheetPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sheetHandle(),
          const SizedBox(height: AppSpacing.lg),
          const Text('사용승인일', style: AppTypography.heading3),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Text(
              '${_range.start.toInt()}년 ~ ${_range.end.toInt()}년',
              style: AppTypography.body1Bold.copyWith(color: AppColors.primary),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          RangeSlider(
            values: _range,
            min: _min, max: _max,
            divisions: (_max - _min).toInt(),
            activeColor: AppColors.primary,
            inactiveColor: AppColors.gray200,
            onChanged: (v) => setState(() => _range = v),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_min.toInt()}년', style: AppTypography.caption2),
              Text('${_max.toInt()}년', style: AppTypography.caption2),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          _sheetButtons(
            onReset: () => setState(() => _range = RangeValues(_min, _max)),
            onApply: () {
              widget.onApply(
                _range.start > _min ? _range.start.toInt() : null,
                _range.end < _max ? _range.end.toInt() : null,
              );
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

// ── 세대수 ──

class HouseholdsFilterSheet extends StatefulWidget {
  final int? currentMin;
  final int? currentMax;
  final void Function(int? min, int? max) onApply;

  const HouseholdsFilterSheet({super.key, this.currentMin, this.currentMax, required this.onApply});

  @override
  State<HouseholdsFilterSheet> createState() => _HouseholdsFilterSheetState();
}

class _HouseholdsFilterSheetState extends State<HouseholdsFilterSheet> {
  late RangeValues _range;
  static const _min = 0.0;
  static const _max = 5000.0;

  @override
  void initState() {
    super.initState();
    _range = RangeValues(
      widget.currentMin?.toDouble() ?? _min,
      widget.currentMax?.toDouble() ?? _max,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _sheetPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sheetHandle(),
          const SizedBox(height: AppSpacing.lg),
          const Text('세대수', style: AppTypography.heading3),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Text(
              '${_range.start.toInt()}세대 ~ ${_range.end >= _max ? '5,000+' : '${_range.end.toInt()}'}세대',
              style: AppTypography.body1Bold.copyWith(color: AppColors.primary),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          RangeSlider(
            values: _range,
            min: _min, max: _max, divisions: 50,
            activeColor: AppColors.primary,
            inactiveColor: AppColors.gray200,
            onChanged: (v) => setState(() => _range = v),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text('0', style: AppTypography.caption2), Text('5,000+', style: AppTypography.caption2)],
          ),
          const SizedBox(height: AppSpacing.xxl),
          _sheetButtons(
            onReset: () => setState(() => _range = const RangeValues(_min, _max)),
            onApply: () {
              widget.onApply(
                _range.start > _min ? _range.start.toInt() : null,
                _range.end < _max ? _range.end.toInt() : null,
              );
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

// ── 정렬 ──

class SortSheet extends StatelessWidget {
  final MarketSortType currentSort;
  final void Function(MarketSortType) onSelect;
  final TradeTypeFilter tradeType;

  const SortSheet({super.key, required this.currentSort, required this.onSelect, this.tradeType = TradeTypeFilter.sale});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, AppSpacing.lg, 0, AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetHandle(),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            child: const Align(
              alignment: Alignment.centerLeft,
              child: Text('정렬', style: AppTypography.heading3),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...MarketSortType.valuesFor(tradeType).map((sort) {
            final isSelected = currentSort == sort;
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
              title: Text(
                sort.labelFor(tradeType),
                style: AppTypography.body2.copyWith(
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              trailing: isSelected ? const Icon(Icons.check, color: AppColors.primary, size: 20) : null,
              onTap: () {
                onSelect(sort);
                Navigator.pop(context);
              },
            );
          }),
        ],
      ),
    );
  }
}
