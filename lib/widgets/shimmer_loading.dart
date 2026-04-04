import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_spacing.dart';

class ShimmerLoading extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const ShimmerLoading({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.radius = AppSpacing.radiusMd,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.gray100,
      highlightColor: AppColors.gray50,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.gray100,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class ShimmerCard extends StatelessWidget {
  const ShimmerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.gray100,
      highlightColor: AppColors.gray50,
      child: Container(
        width: double.infinity,
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.gray100,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
      ),
    );
  }
}
