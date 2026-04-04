import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/app_spacing.dart';
import '../providers/subscription_provider.dart';

/// 청약 가점 계산기
class ScoreCalculatorScreen extends ConsumerStatefulWidget {
  const ScoreCalculatorScreen({super.key});

  @override
  ConsumerState<ScoreCalculatorScreen> createState() => _ScoreCalculatorScreenState();
}

class _ScoreCalculatorScreenState extends ConsumerState<ScoreCalculatorScreen> {
  // 무주택 기간 (0~32점)
  int _noHouseYears = 0;
  // 부양가족 수 (0~35점)
  int _dependents = 0;
  // 청약통장 가입 기간 (0~17점)
  int _accountYears = 0;

  /// 무주택 기간 점수 계산
  int get _noHouseScore {
    if (_noHouseYears < 1) return 2;
    if (_noHouseYears >= 15) return 32;
    return 2 + (_noHouseYears * 2);
  }

  /// 부양가족 점수 계산
  int get _dependentScore {
    if (_dependents == 0) return 5;
    if (_dependents >= 6) return 35;
    return 5 + (_dependents * 5);
  }

  /// 청약통장 기간 점수 계산
  int get _accountScore {
    if (_accountYears < 1) return 1;
    if (_accountYears >= 15) return 17;
    return 1 + _accountYears;
  }

  int get _totalScore => _noHouseScore + _dependentScore + _accountScore;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('가점 계산기')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 총점 카드
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.xxl),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF1B64DA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              ),
              child: Column(
                children: [
                  const Text('내 예상 가점', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '$_totalScore점',
                    style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w700, fontFamily: 'Pretendard'),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text('/ ${AppConstants.maxSubscriptionScore}점 만점', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // 점수 분석
            _scoreBreakdown(),
            const SizedBox(height: AppSpacing.xxl),

            // 무주택 기간
            _sectionTitle('무주택 기간', '$_noHouseScore점'),
            const SizedBox(height: AppSpacing.sm),
            _stepper(
              '무주택 기간 (년)',
              _noHouseYears,
              0,
              15,
              (v) => setState(() => _noHouseYears = v),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // 부양가족
            _sectionTitle('부양가족 수', '$_dependentScore점'),
            const SizedBox(height: AppSpacing.sm),
            _stepper(
              '부양가족 (명)',
              _dependents,
              0,
              6,
              (v) => setState(() => _dependents = v),
            ),
            Text('본인 제외, 배우자·직계존비속 포함', style: AppTypography.caption2.copyWith(color: AppColors.textTertiary)),
            const SizedBox(height: AppSpacing.xxl),

            // 청약통장
            _sectionTitle('청약통장 가입 기간', '$_accountScore점'),
            const SizedBox(height: AppSpacing.sm),
            _stepper(
              '가입 기간 (년)',
              _accountYears,
              0,
              15,
              (v) => setState(() => _accountYears = v),
            ),
            const SizedBox(height: AppSpacing.xxxl),

            // 저장 버튼
            SizedBox(
              width: double.infinity,
              height: AppSpacing.buttonHeight,
              child: ElevatedButton(
                onPressed: () {
                  ref.read(subscriptionScoreProvider.notifier).state = _totalScore;
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('가점이 저장되었어요'), duration: Duration(seconds: 2)),
                  );
                },
                child: const Text('가점 저장하기'),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _scoreBreakdown() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          _breakdownRow('무주택 기간', _noHouseScore, 32),
          const Divider(height: AppSpacing.lg),
          _breakdownRow('부양가족 수', _dependentScore, 35),
          const Divider(height: AppSpacing.lg),
          _breakdownRow('청약통장 기간', _accountScore, 17),
        ],
      ),
    );
  }

  Widget _breakdownRow(String label, int score, int max) {
    return Row(
      children: [
        Expanded(flex: 3, child: Text(label, style: AppTypography.body2)),
        Expanded(
          flex: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / max,
              backgroundColor: AppColors.gray200,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        SizedBox(
          width: 50,
          child: Text('$score/$max', style: AppTypography.label2, textAlign: TextAlign.right),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title, String score) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTypography.heading3),
        Text(score, style: AppTypography.label1.copyWith(color: AppColors.primary)),
      ],
    );
  }

  Widget _stepper(String label, int value, int min, int max, ValueChanged<int> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.body2),
          Row(
            children: [
              _stepBtn(Icons.remove, value > min ? () => onChanged(value - 1) : null),
              SizedBox(
                width: 40,
                child: Text('$value', style: AppTypography.body1Bold, textAlign: TextAlign.center),
              ),
              _stepBtn(Icons.add, value < max ? () => onChanged(value + 1) : null),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: onTap != null ? AppColors.gray100 : AppColors.gray50,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: onTap != null ? AppColors.textPrimary : AppColors.gray300),
      ),
    );
  }
}
