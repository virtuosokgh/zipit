import 'package:flutter/material.dart';

/// TDS (Toss Design System) 기반 컬러
class AppColors {
  AppColors._();

  // Primary
  static const Color primary = Color(0xFF3182F6);
  static const Color primaryLight = Color(0xFF5B9CF6);
  static const Color primaryDark = Color(0xFF1B64DA);

  // Semantic
  static const Color success = Color(0xFF2BD97C);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFFF4545);

  // Signal (시세 신호등)
  static const Color signalSafe = Color(0xFF2BD97C);
  static const Color signalCaution = Color(0xFFF59E0B);
  static const Color signalDanger = Color(0xFFFF4545);

  // Grayscale
  static const Color white = Color(0xFFFFFFFF);
  static const Color gray50 = Color(0xFFF9FAFB);
  static const Color gray100 = Color(0xFFF2F4F6);
  static const Color gray200 = Color(0xFFE5E8EB);
  static const Color gray300 = Color(0xFFD1D6DB);
  static const Color gray400 = Color(0xFFB0B8C1);
  static const Color gray500 = Color(0xFF8B95A1);
  static const Color gray600 = Color(0xFF6B7684);
  static const Color gray700 = Color(0xFF4E5968);
  static const Color gray800 = Color(0xFF333D4B);
  static const Color gray900 = Color(0xFF191F28);
  static const Color black = Color(0xFF000000);

  // Background & Surface
  static const Color background = Color(0xFFF9FAFB);
  static const Color surface = Color(0xFFFFFFFF);

  // Text
  static const Color textPrimary = Color(0xFF191F28);
  static const Color textSecondary = Color(0xFF4E5968);
  static const Color textTertiary = Color(0xFF8B95A1);
  static const Color textDisabled = Color(0xFFB0B8C1);

  // Border
  static const Color border = Color(0xFFE5E8EB);
  static const Color borderLight = Color(0xFFF2F4F6);
  static const Color borderFocused = Color(0xFF3182F6);

  // Dim
  static const Color dim = Color(0x52000000);
}
