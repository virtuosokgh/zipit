import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../models/apartment_listing.dart';
import '../../../models/market_filter.dart';
import '../../../widgets/price_signal_badge.dart';

class ApartmentListCard extends StatelessWidget {
  final ApartmentListing listing;
  final int? rank;
  final VoidCallback onTap;
  final TradeTypeFilter tradeType;

  const ApartmentListCard({
    super.key,
    required this.listing,
    this.rank,
    required this.onTap,
    this.tradeType = TradeTypeFilter.sale,
  });

  @override
  Widget build(BuildContext context) {
    // 전세/월세일 때는 안전도 시그널, 매매일 때는 가격 시그널
    final PriceSignal badgeSignal;
    final String badgeLabel;
    if (tradeType == TradeTypeFilter.jeonse) {
      final jeonse = listing.latestJeonsePrice;
      final safe = listing.safeJeonsePrice;
      if (jeonse != null && safe != null) {
        final ratio = (safe - jeonse) / safe;
        badgeSignal = ratio > 0.05 ? PriceSignal.safe : (ratio < -0.05 ? PriceSignal.danger : PriceSignal.caution);
      } else {
        badgeSignal = PriceSignal.caution;
      }
      badgeLabel = switch (badgeSignal) { PriceSignal.safe => '안전', PriceSignal.caution => '적정', PriceSignal.danger => '주의' };
    } else if (tradeType == TradeTypeFilter.monthly) {
      badgeSignal = listing.monthlyRentSafetySignal;
      badgeLabel = listing.monthlyRentSafetyLabel;
    } else {
      badgeSignal = listing.priceSignal;
      badgeLabel = listing.priceSignalLabel;
    }

    final signalColor = switch (badgeSignal) {
      PriceSignal.safe => AppColors.signalSafe,
      PriceSignal.caution => AppColors.signalCaution,
      PriceSignal.danger => AppColors.signalDanger,
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 순위 뱃지 (있으면)
                if (rank != null) ...[
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: rank! <= 3 ? AppColors.primary : AppColors.gray200,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Center(
                      child: Text(
                        '$rank',
                        style: AppTypography.label2.copyWith(
                          color: rank! <= 3 ? AppColors.white : AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(listing.name, style: AppTypography.body1Bold),
                      const SizedBox(height: 2),
                      Text(listing.location, style: AppTypography.caption1),
                    ],
                  ),
                ),
                PriceSignalBadge(signal: badgeSignal, label: badgeLabel),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            // 거래유형별 가격 정보
            if (tradeType == TradeTypeFilter.jeonse)
              _buildJeonsePriceRow()
            else if (tradeType == TradeTypeFilter.monthly)
              _buildMonthlyPriceRow()
            else
              _buildSalePriceRow(signalColor),
            // 평형 정보
            if (listing.units.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Icon(Icons.meeting_room_outlined, size: 14, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Text(
                    listing.units.map((u) => '${u.pyeong}평(${u.rooms}룸)').take(3).join(' / '),
                    style: AppTypography.caption2,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 매매 가격 표시 (기본)
  Widget _buildSalePriceRow(Color signalColor) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('현재 시세', style: AppTypography.caption1),
              const SizedBox(height: 2),
              Text(
                PriceFormatter.format(listing.currentPrice),
                style: AppTypography.body2Bold.copyWith(color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('적정가', style: AppTypography.caption1),
              const SizedBox(height: 2),
              Text(
                PriceFormatter.format(listing.aiEstimate),
                style: AppTypography.body2Bold.copyWith(color: AppColors.primary),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: signalColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          child: Text(
            '${listing.aiGapPercent > 0 ? '+' : ''}${listing.aiGapPercent.toStringAsFixed(1)}%',
            style: AppTypography.label2.copyWith(color: signalColor, fontSize: 13),
          ),
        ),
      ],
    );
  }

  /// 전세 가격 표시 (안전 뱃지는 상단으로 이동, 여기서는 가격만)
  Widget _buildJeonsePriceRow() {
    final jeonsePrice = listing.latestJeonsePrice;
    final safeDeposit = listing.safeJeonsePrice;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('전세가', style: AppTypography.caption1),
              const SizedBox(height: 2),
              Text(
                jeonsePrice != null ? PriceFormatter.format(jeonsePrice) : '-',
                style: AppTypography.body2Bold.copyWith(color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('안전 보증금', style: AppTypography.caption1),
              const SizedBox(height: 2),
              Text(
                safeDeposit != null ? PriceFormatter.format(safeDeposit) : '-',
                style: AppTypography.body2Bold.copyWith(color: AppColors.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 월세 가격 표시 (안전 뱃지는 상단으로 이동, 여기서는 가격만)
  Widget _buildMonthlyPriceRow() {
    final deposit = listing.latestMonthlyDeposit;
    final monthlyRent = listing.latestMonthlyRent;
    final safeRent = listing.safeMonthlyRent;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('보증금/월세', style: AppTypography.caption1),
              const SizedBox(height: 2),
              Text(
                deposit != null && monthlyRent != null
                    ? '${PriceFormatter.format(deposit)}/${PriceFormatter.format(monthlyRent)}'
                    : '-',
                style: AppTypography.body2Bold.copyWith(color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('적정 월세', style: AppTypography.caption1),
              const SizedBox(height: 2),
              Text(
                deposit != null && safeRent != null
                    ? '${PriceFormatter.format(deposit)}/${PriceFormatter.format(safeRent)}'
                    : '-',
                style: AppTypography.body2Bold.copyWith(color: AppColors.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
