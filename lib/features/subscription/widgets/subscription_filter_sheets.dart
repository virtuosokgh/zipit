import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../models/subscription_filter.dart';

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

EdgeInsets get _sheetPadding =>
    const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.lg, AppSpacing.screenH, AppSpacing.xxl);

// ── 청약상태 필터 (복수 선택) ──

class SubscriptionStatusFilterSheet extends StatefulWidget {
  final List<SubscriptionStatusFilter> current;
  final void Function(List<SubscriptionStatusFilter>) onApply;

  const SubscriptionStatusFilterSheet({super.key, required this.current, required this.onApply});

  @override
  State<SubscriptionStatusFilterSheet> createState() => _SubscriptionStatusFilterSheetState();
}

class _SubscriptionStatusFilterSheetState extends State<SubscriptionStatusFilterSheet> {
  late List<SubscriptionStatusFilter> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.current);
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
          const Text('청약상태', style: AppTypography.heading3),
          const SizedBox(height: AppSpacing.lg),
          ...SubscriptionStatusFilter.values.where((s) => s != SubscriptionStatusFilter.all).map((status) {
            final isSelected = _selected.contains(status);
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                status.label,
                style: AppTypography.body2.copyWith(
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              value: isSelected,
              activeColor: AppColors.primary,
              onChanged: (checked) {
                setState(() {
                  if (checked == true) {
                    _selected.add(status);
                  } else {
                    _selected.remove(status);
                  }
                });
              },
            );
          }),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _selected.clear()),
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
                  onPressed: () {
                    widget.onApply(_selected);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
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
}

// ── 지역 필터 ──

class SubscriptionRegionFilterSheet extends StatefulWidget {
  final String current;
  final void Function(String) onApply;

  const SubscriptionRegionFilterSheet({super.key, required this.current, required this.onApply});

  @override
  State<SubscriptionRegionFilterSheet> createState() => _SubscriptionRegionFilterSheetState();
}

class _SubscriptionRegionFilterSheetState extends State<SubscriptionRegionFilterSheet> {
  late String _selected;

  static const _regions = [
    '', '서울', '경기', '인천', '부산', '대구', '광주', '대전', '울산', '세종',
    '강원', '충북', '충남', '전북', '전남', '경북', '경남', '제주',
  ];

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
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
          const Text('지역', style: AppTypography.heading3),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _regions.map((region) {
              final label = region.isEmpty ? '전체' : region;
              final isSelected = _selected == region;
              return ChoiceChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (_) {
                  setState(() => _selected = region);
                },
                selectedColor: AppColors.primary.withValues(alpha: 0.12),
                labelStyle: AppTypography.body2.copyWith(
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  side: BorderSide(color: isSelected ? AppColors.primary : AppColors.gray300),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onApply(_selected);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
              ),
              child: Text('적용', style: AppTypography.label2.copyWith(color: AppColors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 주택유형 필터 ──

class SubscriptionHousingTypeSheet extends StatelessWidget {
  final HousingTypeFilter current;
  final void Function(HousingTypeFilter) onSelect;

  const SubscriptionHousingTypeSheet({super.key, required this.current, required this.onSelect});

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
          const Text('주택유형', style: AppTypography.heading3),
          const SizedBox(height: AppSpacing.lg),
          ...HousingTypeFilter.values.map((type) {
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

// ── 세대수 필터 ──

class SubscriptionHouseholdsSheet extends StatefulWidget {
  final int? currentMin;
  final int? currentMax;
  final void Function(int?, int?) onApply;

  const SubscriptionHouseholdsSheet({
    super.key,
    required this.currentMin,
    required this.currentMax,
    required this.onApply,
  });

  @override
  State<SubscriptionHouseholdsSheet> createState() => _SubscriptionHouseholdsSheetState();
}

class _SubscriptionHouseholdsSheetState extends State<SubscriptionHouseholdsSheet> {
  late double _min;
  late double _max;
  bool _isCustom = false;

  static const _rangeMin = 0.0;
  static const _rangeMax = 5000.0;

  @override
  void initState() {
    super.initState();
    _min = widget.currentMin?.toDouble() ?? _rangeMin;
    _max = widget.currentMax?.toDouble() ?? _rangeMax;
    _isCustom = widget.currentMin != null || widget.currentMax != null;
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
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                !_isCustom ? '전체' : '${_min.toInt()} ~ ${_max.toInt()}세대',
                style: AppTypography.body2.copyWith(
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
              values: RangeValues(_min, _max),
              min: _rangeMin,
              max: _rangeMax,
              divisions: 50,
              onChanged: (v) {
                setState(() {
                  _min = v.start;
                  _max = v.end;
                  _isCustom = v.start > _rangeMin || v.end < _rangeMax;
                });
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _min = _rangeMin;
                      _max = _rangeMax;
                      _isCustom = false;
                    });
                  },
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
                  onPressed: () {
                    widget.onApply(
                      _isCustom && _min > _rangeMin ? _min.toInt() : null,
                      _isCustom && _max < _rangeMax ? _max.toInt() : null,
                    );
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
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
}

// ── 정렬 시트 ──

class SubscriptionSortSheet extends StatelessWidget {
  final SubscriptionSortType current;
  final void Function(SubscriptionSortType) onSelect;

  const SubscriptionSortSheet({super.key, required this.current, required this.onSelect});

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
          const Text('정렬', style: AppTypography.heading3),
          const SizedBox(height: AppSpacing.lg),
          ...SubscriptionSortType.values.map((type) {
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
