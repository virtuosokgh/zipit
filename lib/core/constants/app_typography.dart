import 'package:flutter/material.dart';
import 'app_colors.dart';

/// TDS 기반 타이포그래피
class AppTypography {
  AppTypography._();

  static const String _fontFamily = 'Pretendard';

  // Heading
  static const TextStyle heading1 = TextStyle(
    fontFamily: _fontFamily, fontSize: 26, fontWeight: FontWeight.w700,
    height: 1.35, letterSpacing: -0.3, color: AppColors.textPrimary,
  );
  static const TextStyle heading2 = TextStyle(
    fontFamily: _fontFamily, fontSize: 22, fontWeight: FontWeight.w700,
    height: 1.35, letterSpacing: -0.3, color: AppColors.textPrimary,
  );
  static const TextStyle heading3 = TextStyle(
    fontFamily: _fontFamily, fontSize: 20, fontWeight: FontWeight.w600,
    height: 1.4, letterSpacing: -0.3, color: AppColors.textPrimary,
  );

  // Body
  static const TextStyle body1 = TextStyle(
    fontFamily: _fontFamily, fontSize: 17, fontWeight: FontWeight.w400,
    height: 1.5, letterSpacing: -0.3, color: AppColors.textPrimary,
  );
  static const TextStyle body1Bold = TextStyle(
    fontFamily: _fontFamily, fontSize: 17, fontWeight: FontWeight.w600,
    height: 1.5, letterSpacing: -0.3, color: AppColors.textPrimary,
  );
  static const TextStyle body2 = TextStyle(
    fontFamily: _fontFamily, fontSize: 15, fontWeight: FontWeight.w400,
    height: 1.5, letterSpacing: -0.3, color: AppColors.textPrimary,
  );
  static const TextStyle body2Bold = TextStyle(
    fontFamily: _fontFamily, fontSize: 15, fontWeight: FontWeight.w600,
    height: 1.5, letterSpacing: -0.3, color: AppColors.textPrimary,
  );

  // Caption
  static const TextStyle caption1 = TextStyle(
    fontFamily: _fontFamily, fontSize: 13, fontWeight: FontWeight.w400,
    height: 1.5, letterSpacing: -0.3, color: AppColors.textTertiary,
  );
  static const TextStyle caption2 = TextStyle(
    fontFamily: _fontFamily, fontSize: 11, fontWeight: FontWeight.w400,
    height: 1.45, letterSpacing: -0.3, color: AppColors.textTertiary,
  );

  // Label (Buttons)
  static const TextStyle label1 = TextStyle(
    fontFamily: _fontFamily, fontSize: 17, fontWeight: FontWeight.w600,
    height: 1.4, letterSpacing: -0.3, color: AppColors.textPrimary,
  );
  static const TextStyle label2 = TextStyle(
    fontFamily: _fontFamily, fontSize: 15, fontWeight: FontWeight.w600,
    height: 1.4, letterSpacing: -0.3, color: AppColors.textPrimary,
  );

  // Number (가격, 통계)
  static const TextStyle number1 = TextStyle(
    fontFamily: _fontFamily, fontSize: 28, fontWeight: FontWeight.w700,
    height: 1.3, letterSpacing: -0.3, color: AppColors.textPrimary,
  );
  static const TextStyle number2 = TextStyle(
    fontFamily: _fontFamily, fontSize: 22, fontWeight: FontWeight.w700,
    height: 1.3, letterSpacing: -0.3, color: AppColors.textPrimary,
  );
}
