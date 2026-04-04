import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../models/widget_config.dart';
import '../../../providers/widget_config_provider.dart';

class WidgetStyleScreen extends ConsumerWidget {
  const WidgetStyleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(widgetConfigProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('위젯 스타일')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        children: [
          const SizedBox(height: AppSpacing.md),
          Text('스타일 선택', style: AppTypography.heading3),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '잠금화면 위젯의 크기와 표시 방식을 선택하세요',
            style: AppTypography.caption1.copyWith(color: AppColors.textTertiary),
          ),
          const SizedBox(height: AppSpacing.xxl),

          ...WidgetStyle.values.map((style) =>
            _styleCard(ref, style, config.style == style),
          ),
        ],
      ),
    );
  }

  Widget _styleCard(WidgetRef ref, WidgetStyle style, bool isSelected) {
    return GestureDetector(
      onTap: () => ref.read(widgetConfigProvider.notifier).setStyle(style),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.lg),
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderLight,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.gray400,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 14, color: AppColors.white)
                      : null,
                ),
                const SizedBox(width: AppSpacing.md),
                Text(style.label, style: AppTypography.body1Bold),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Text(
                style.description,
                style: AppTypography.caption1.copyWith(color: AppColors.textTertiary),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // 미리보기
            _preview(style),
          ],
        ),
      ),
    );
  }

  Widget _preview(WidgetStyle style) {
    if (style == WidgetStyle.compact) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.apartment, size: 14, color: Colors.white70),
                const SizedBox(width: 6),
                Text('강남구 평균', style: AppTypography.caption2.copyWith(color: Colors.white70)),
                const Spacer(),
                Text('18.2억', style: AppTypography.body2Bold.copyWith(color: Colors.white)),
                const SizedBox(width: 4),
                Text('▲0.3%', style: AppTypography.caption2.copyWith(color: AppColors.success)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.event, size: 14, color: Colors.white70),
                const SizedBox(width: 6),
                Text('래미안 원펜타스', style: AppTypography.caption2.copyWith(color: Colors.white70)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('D-3', style: AppTypography.caption2.copyWith(color: AppColors.error)),
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('강남구', style: AppTypography.caption1.copyWith(color: Colors.white70)),
                const Spacer(),
                Text('집잇', style: AppTypography.caption2.copyWith(color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('18.2억', style: AppTypography.heading3.copyWith(color: Colors.white)),
                const SizedBox(width: 6),
                Text('▲0.3%', style: AppTypography.caption1.copyWith(color: AppColors.success)),
              ],
            ),
            const SizedBox(height: 8),
            // 미니 차트 대체
            Container(
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(4),
              ),
              child: CustomPaint(painter: _MiniChartPainter()),
            ),
            const SizedBox(height: 8),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.event, size: 12, color: Colors.white54),
                const SizedBox(width: 4),
                Text('래미안 원펜타스', style: AppTypography.caption2.copyWith(color: Colors.white70)),
                const Spacer(),
                Text('D-3', style: AppTypography.caption2.copyWith(color: AppColors.error)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 12, color: Colors.white54),
                const SizedBox(width: 4),
                Text('당첨예측 62%', style: AppTypography.caption2.copyWith(color: AppColors.success)),
                const Spacer(),
                Text('내 가점 48점', style: AppTypography.caption2.copyWith(color: Colors.white54)),
              ],
            ),
          ],
        ),
      );
    }
  }
}

class _MiniChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    final points = [0.6, 0.5, 0.55, 0.4, 0.45, 0.3, 0.35, 0.2];
    for (int i = 0; i < points.length; i++) {
      final x = (i / (points.length - 1)) * size.width;
      final y = points[i] * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
