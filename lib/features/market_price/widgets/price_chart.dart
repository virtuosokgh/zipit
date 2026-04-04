import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../models/apartment_trade.dart';

class PriceChart extends StatelessWidget {
  final List<ApartmentTrade> trades;
  final String title;

  const PriceChart({super.key, required this.trades, this.title = '매매 실거래가'});

  @override
  Widget build(BuildContext context) {
    if (trades.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: const Center(child: Text('거래 데이터가 없어요', style: AppTypography.caption1)),
      );
    }

    // 월별 평균가 계산
    final monthlyAvg = <String, List<int>>{};
    for (final t in trades) {
      final key = '${t.dealYear}-${t.dealMonth.toString().padLeft(2, '0')}';
      monthlyAvg.putIfAbsent(key, () => []).add(t.dealAmount);
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

    final rawMinY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final rawMaxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final minY = rawMinY == rawMaxY ? rawMinY * 0.9 : rawMinY * 0.9;
    final maxY = rawMinY == rawMaxY ? rawMaxY * AppConstants.chartYAxisMaxMultiplier : rawMaxY * AppConstants.chartYAxisMaxMultiplier;

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
          Text(title, style: AppTypography.body2Bold),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxY - minY) > 0 ? (maxY - minY) / 4 : 1,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.borderLight,
                    strokeWidth: 1,
                  ),
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
                        return Text(
                          PriceFormatter.formatShort(value.toInt()),
                          style: AppTypography.caption2,
                        );
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
                    color: AppColors.primary,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) =>
                          FlDotCirclePainter(
                        radius: 3,
                        color: AppColors.primary,
                        strokeWidth: 2,
                        strokeColor: AppColors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withValues(alpha: 0.08),
                    ),
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
}
