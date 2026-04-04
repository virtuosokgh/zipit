import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../models/subscription_filter.dart';
import '../providers/subscription_filter_provider.dart';
import 'subscription_filter_sheets.dart';

class SubscriptionFilterBar extends ConsumerStatefulWidget {
  const SubscriptionFilterBar({super.key});

  @override
  ConsumerState<SubscriptionFilterBar> createState() => _SubscriptionFilterBarState();
}

class _SubscriptionFilterBarState extends ConsumerState<SubscriptionFilterBar> {
  bool _detailExpanded = false;

  // 상세 필터 임시 값
  String? _tmpConstructor;
  String? _tmpMoveInYearMin;
  String? _tmpMoveInYearMax;
  List<String> _tmpSupplyTypes = [];
  String? _tmpRentType;

  void _openDetail() {
    final f = ref.read(subscriptionFilterProvider);
    _tmpConstructor = f.constructor;
    _tmpMoveInYearMin = f.moveInYearMin;
    _tmpMoveInYearMax = f.moveInYearMax;
    _tmpSupplyTypes = List.from(f.supplyTypes);
    _tmpRentType = f.rentType;
    setState(() => _detailExpanded = true);
  }

  void _applyDetail() {
    ref.read(subscriptionFilterProvider.notifier).applyDetailFilters(
      constructor: _tmpConstructor,
      moveInYearMin: _tmpMoveInYearMin,
      moveInYearMax: _tmpMoveInYearMax,
      supplyTypes: _tmpSupplyTypes,
      rentType: _tmpRentType,
    );
    setState(() => _detailExpanded = false);
  }

  void _resetDetail() {
    setState(() {
      _tmpConstructor = null;
      _tmpMoveInYearMin = null;
      _tmpMoveInYearMax = null;
      _tmpSupplyTypes = [];
      _tmpRentType = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(subscriptionFilterProvider);

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
                label: _statusLabel(filter),
                isActive: filter.statuses.isNotEmpty,
                onTap: () => _showStatusSheet(context, ref),
              ),
              const SizedBox(width: 6),
              _FilterChip(
                label: filter.region.isEmpty ? '지역' : filter.region,
                isActive: filter.region.isNotEmpty,
                onTap: () => _showRegionSheet(context, ref),
              ),
              const SizedBox(width: 6),
              _FilterChip(
                label: filter.housingType.label,
                isActive: filter.housingType != HousingTypeFilter.all,
                onTap: () => _showHousingTypeSheet(context, ref),
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

        // 상세 필터 패널
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

          // 공급유형
          _detailLabel('공급유형'),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: ['일반공급', '신혼부부', '생애최초', '다자녀', '노부모부양', '기관추천'].map((type) {
              final isSelected = _tmpSupplyTypes.contains(type);
              return ChoiceChip(
                label: Text(type),
                selected: isSelected,
                onSelected: (_) {
                  setState(() {
                    if (isSelected) {
                      _tmpSupplyTypes.remove(type);
                    } else {
                      _tmpSupplyTypes.add(type);
                    }
                  });
                },
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
          const SizedBox(height: AppSpacing.lg),

          // 시공사 검색
          _detailLabel('시공사 / 시행사'),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: TextEditingController(text: _tmpConstructor),
            onChanged: (v) => _tmpConstructor = v.isEmpty ? null : v,
            style: AppTypography.body2,
            decoration: InputDecoration(
              hintText: '시공사 또는 시행사명 입력',
              hintStyle: AppTypography.body2.copyWith(color: AppColors.gray400),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                borderSide: const BorderSide(color: AppColors.gray300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                borderSide: const BorderSide(color: AppColors.gray300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
              prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.gray400),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // 입주예정일
          _detailLabel('입주예정일'),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _MoveInSelector(
                  value: _tmpMoveInYearMin,
                  hint: '시작',
                  onChanged: (v) => setState(() => _tmpMoveInYearMin = v),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('~', style: AppTypography.body2),
              ),
              Expanded(
                child: _MoveInSelector(
                  value: _tmpMoveInYearMax,
                  hint: '종료',
                  onChanged: (v) => setState(() => _tmpMoveInYearMax = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // 분양/임대 구분
          _detailLabel('분양/임대'),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 6,
            children: [null, '분양', '임대'].map((type) {
              final isSelected = _tmpRentType == type;
              final label = type ?? '전체';
              return ChoiceChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (_) => setState(() => _tmpRentType = type),
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

  // ── Label helpers ──

  String _statusLabel(SubscriptionFilter filter) {
    if (filter.statuses.isEmpty) return '청약상태';
    if (filter.statuses.length == 1) return filter.statuses.first.label;
    return '${filter.statuses.first.label} 외 ${filter.statuses.length - 1}';
  }

  String _householdsLabel(SubscriptionFilter filter) {
    if (filter.householdsMin == null && filter.householdsMax == null) return '세대수';
    if (filter.householdsMin != null && filter.householdsMax != null) {
      return '${filter.householdsMin}~${filter.householdsMax}세대';
    }
    if (filter.householdsMin != null) return '${filter.householdsMin}세대+';
    return '~${filter.householdsMax}세대';
  }

  // ── Bottom sheet openers ──

  void _showStatusSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
      ),
      builder: (_) => SubscriptionStatusFilterSheet(
        current: ref.read(subscriptionFilterProvider).statuses,
        onApply: (statuses) => ref.read(subscriptionFilterProvider.notifier).setStatuses(statuses),
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
      builder: (_) => SubscriptionRegionFilterSheet(
        current: ref.read(subscriptionFilterProvider).region,
        onApply: (region) => ref.read(subscriptionFilterProvider.notifier).setRegion(region),
      ),
    );
  }

  void _showHousingTypeSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
      ),
      builder: (_) => SubscriptionHousingTypeSheet(
        current: ref.read(subscriptionFilterProvider).housingType,
        onSelect: (type) => ref.read(subscriptionFilterProvider.notifier).setHousingType(type),
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
      builder: (_) => SubscriptionHouseholdsSheet(
        currentMin: ref.read(subscriptionFilterProvider).householdsMin,
        currentMax: ref.read(subscriptionFilterProvider).householdsMax,
        onApply: (min, max) => ref.read(subscriptionFilterProvider.notifier).setHouseholdsRange(min, max),
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

/// 입주예정 월 선택기
class _MoveInSelector extends StatelessWidget {
  final String? value;
  final String hint;
  final ValueChanged<String?> onChanged;

  const _MoveInSelector({
    required this.value,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final options = <String>[];
    for (int y = now.year; y <= now.year + 5; y++) {
      for (int m = 1; m <= 12; m++) {
        options.add('$y${m.toString().padLeft(2, '0')}');
      }
    }

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: AppColors.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
          ),
          builder: (_) => _MoveInPickerSheet(
            options: options,
            current: value,
            onSelect: (v) {
              onChanged(v);
              Navigator.pop(context);
            },
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.gray300),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value != null ? _formatYm(value!) : hint,
                style: AppTypography.body2.copyWith(
                  color: value != null ? AppColors.textPrimary : AppColors.gray400,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.gray400),
          ],
        ),
      ),
    );
  }

  String _formatYm(String ym) {
    if (ym.length >= 6) {
      return '${ym.substring(0, 4)}년 ${ym.substring(4, 6)}월';
    }
    return ym;
  }
}

class _MoveInPickerSheet extends StatelessWidget {
  final List<String> options;
  final String? current;
  final ValueChanged<String?> onSelect;

  const _MoveInPickerSheet({
    required this.options,
    required this.current,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 350,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.gray300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('입주예정일', style: AppTypography.heading3),
                if (current != null)
                  GestureDetector(
                    onTap: () => onSelect(null),
                    child: Text('초기화', style: AppTypography.caption1.copyWith(color: AppColors.primary)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: options.length,
              itemBuilder: (context, index) {
                final opt = options[index];
                final isSelected = opt == current;
                final label = '${opt.substring(0, 4)}년 ${opt.substring(4, 6)}월';
                return ListTile(
                  title: Text(
                    label,
                    style: AppTypography.body2.copyWith(
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  trailing: isSelected ? const Icon(Icons.check, color: AppColors.primary, size: 20) : null,
                  onTap: () => onSelect(opt),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
