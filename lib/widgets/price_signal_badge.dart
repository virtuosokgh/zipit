import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_typography.dart';
import '../core/constants/app_spacing.dart';

enum PriceSignal { safe, caution, danger }

class PriceSignalBadge extends StatelessWidget {
  final PriceSignal signal;
  final String label;

  const PriceSignalBadge({super.key, required this.signal, required this.label});

  Color get _color => switch (signal) {
        PriceSignal.safe => AppColors.signalSafe,
        PriceSignal.caution => AppColors.signalCaution,
        PriceSignal.danger => AppColors.signalDanger,
      };

  String get _emoji => switch (signal) {
        PriceSignal.safe => '🟢',
        PriceSignal.caution => '🟡',
        PriceSignal.danger => '🔴',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(label, style: AppTypography.label2.copyWith(color: _color)),
        ],
      ),
    );
  }
}
