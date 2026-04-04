import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../models/apartment_trade.dart';

class TradeListItem extends StatelessWidget {
  final ApartmentTrade trade;

  const TradeListItem({super.key, required this.trade});

  @override
  Widget build(BuildContext context) {
    return Container(
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
                Text(trade.aptName, style: AppTypography.body2Bold, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(
                  '${trade.dong} · ${trade.area.toStringAsFixed(1)}㎡ (${trade.pyeongStr}) · ${trade.floor}층',
                  style: AppTypography.caption1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                PriceFormatter.format(trade.dealAmount),
                style: AppTypography.body1Bold.copyWith(color: AppColors.primary),
              ),
              const SizedBox(height: 2),
              Text(
                '${trade.dealYear}.${trade.dealMonth}.${trade.dealDay}',
                style: AppTypography.caption2,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
