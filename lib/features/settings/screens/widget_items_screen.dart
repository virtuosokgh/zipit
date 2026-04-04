import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../models/widget_config.dart';
import '../../../providers/widget_config_provider.dart';

class WidgetItemsScreen extends ConsumerWidget {
  const WidgetItemsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(widgetConfigProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('위젯 표시 항목')),
      body: ListView(
        children: [
          const SizedBox(height: AppSpacing.sm),

          // 기본 항목
          _sectionHeader('기본 항목'),
          ...WidgetItem.values.where((i) => i.defaultEnabled).map((item) =>
            _itemTile(ref, item, config.enabledItems.contains(item)),
          ),

          const SizedBox(height: AppSpacing.md),

          // 선택 항목
          _sectionHeader('추가 항목'),
          ...WidgetItem.values.where((i) => !i.defaultEnabled).map((item) =>
            _itemTile(ref, item, config.enabledItems.contains(item)),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // 안내
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '선택한 항목이 잠금화면 위젯에 표시됩니다.\n위젯 스타일에 따라 표시 가능한 항목 수가 달라요.',
                      style: AppTypography.caption1.copyWith(color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.lg, AppSpacing.screenH, AppSpacing.sm),
    child: Text(title, style: AppTypography.caption1.copyWith(color: AppColors.textTertiary)),
  );

  Widget _itemTile(WidgetRef ref, WidgetItem item, bool enabled) {
    return Container(
      color: AppColors.surface,
      child: SwitchListTile(
        title: Text(item.label, style: AppTypography.body2),
        subtitle: Text(_itemDescription(item), style: AppTypography.caption2.copyWith(color: AppColors.textTertiary)),
        value: enabled,
        onChanged: (_) => ref.read(widgetConfigProvider.notifier).toggleItem(item),
        activeTrackColor: AppColors.primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      ),
    );
  }

  String _itemDescription(WidgetItem item) {
    switch (item) {
      case WidgetItem.regionPrice: return '관심 지역 아파트 평균 매매가';
      case WidgetItem.priceChange: return '전월 대비 시세 변동률';
      case WidgetItem.subscriptionDday: return '가장 임박한 청약 일정';
      case WidgetItem.aiRecommend: return 'AI 추정가 기준 저평가 매물';
      case WidgetItem.gapAlert: return '관심 매물의 AI추정가 대비 갭';
      case WidgetItem.winProbability: return '다음 청약의 내 당첨확률';
      case WidgetItem.jeonseRatio: return '관심지역 평균 전세가율';
      case WidgetItem.myScore: return '현재 예상 청약 가점';
    }
  }
}
