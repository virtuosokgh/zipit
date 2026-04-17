import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/region_codes.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/widget_service.dart';
import '../../../providers/user_preferences_provider.dart';

enum InterestType {
  buy('매매', '내 집 마련을 준비하고 있어요', Icons.home_work),
  jeonse('전세', '전세로 이사를 계획하고 있어요', Icons.key),
  monthly('월세', '월세 방을 찾고 있어요', Icons.payments),
  subscription('청약', '청약 당첨을 노리고 있어요', Icons.apartment);

  final String label;
  final String description;
  final IconData icon;
  const InterestType(this.label, this.description, this.icon);
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  InterestType? _selectedInterest;
  RangeValues _budgetRange = const RangeValues(10000, 50000);
  final Set<String> _selectedRegions = {};
  bool _lockScreenEnabled = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: AppConstants.animPageMs),
        curve: Curves.easeInOut,
      );
    } else {
      final notifier = ref.read(userPreferencesProvider.notifier);
      notifier.setInterestTypes([_selectedInterest!.name]);
      notifier.setBudget(_budgetRange.start, _budgetRange.end);
      notifier.setRegions(_selectedRegions.toList());
      notifier.toggleLockScreenWidget(_lockScreenEnabled);
      notifier.completeOnboarding();

      // 알림 권한 요청 (잠금화면 알림에 필요)
      NotificationService.requestPermission();

      // 온보딩 완료 직후 위젯에 초기 데이터 즉시 push
      final regionLabel = _selectedRegions.length <= 2
          ? _selectedRegions.join(', ')
          : '${_selectedRegions.first} 외 ${_selectedRegions.length - 1}곳';
      final interestLabel = switch (_selectedInterest!) {
        InterestType.buy => '$regionLabel 최신 매매',
        InterestType.jeonse => '$regionLabel 최신 전세',
        InterestType.monthly => '$regionLabel 최신 월세',
        InterestType.subscription => '다가오는 청약',
      };
      WidgetService.updateWidget(
        regionName: interestLabel,
        avgPrice: '불러오는 중...',
      );

      if (mounted) context.go('/home');
    }
  }

  bool _canProceed() => switch (_currentPage) {
        0 => _selectedInterest != null,
        2 => _selectedRegions.isNotEmpty,
        _ => true,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: AppSpacing.lg),
              child: Row(
                children: List.generate(3, (i) => Expanded(
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: i <= _currentPage ? AppColors.primary : AppColors.gray200,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                    ),
                  ),
                )),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (p) => setState(() => _currentPage = p),
                children: [_interestPage(), _conditionPage(), _regionPage()],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screenH),
              child: ElevatedButton(
                onPressed: _canProceed() ? _next : null,
                child: Text(_currentPage == 2 ? '시작하기' : '다음'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _interestPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.xxl),
            const Text('어떤 부동산에\n관심이 있으세요?', style: AppTypography.heading1),
            const SizedBox(height: AppSpacing.sm),
            Text('하나를 선택해주세요', style: AppTypography.body2.copyWith(color: AppColors.textTertiary)),
            const SizedBox(height: AppSpacing.xxxl),
            ...InterestType.values.map((t) => _InterestTile(
                  type: t,
                  isSelected: _selectedInterest == t,
                  onTap: () => setState(() => _selectedInterest = t),
                )),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  Widget _conditionPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          const SizedBox(height: AppSpacing.xxl),
          const Text('예산 범위를\n알려주세요', style: AppTypography.heading1),
          const SizedBox(height: AppSpacing.sm),
          Text('대략적인 범위면 충분해요', style: AppTypography.body2.copyWith(color: AppColors.textTertiary)),
          const SizedBox(height: 40),
          Text(
            '${(_budgetRange.start / 10000).toStringAsFixed(0)}억 ~ ${(_budgetRange.end / 10000).toStringAsFixed(0)}억',
            style: AppTypography.number2.copyWith(color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.lg),
          RangeSlider(
            values: _budgetRange,
            min: AppConstants.budgetSliderMin, max: AppConstants.budgetSliderMax, divisions: AppConstants.budgetSliderDivisions,
            activeColor: AppColors.primary,
            inactiveColor: AppColors.gray200,
            onChanged: (v) => setState(() => _budgetRange = v),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0', style: AppTypography.caption1),
              Text('20억+', style: AppTypography.caption1),
            ],
          ),
        ],
        ),
      ),
    );
  }

  Widget _regionPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xxl),
          const Text('관심 지역을\n선택해주세요', style: AppTypography.heading1),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '복수 선택 가능해요 (${_selectedRegions.length}개 선택)',
            style: AppTypography.body2.copyWith(color: AppColors.textTertiary),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 서울
                  _regionCategory('서울', '서울 전체', RegionCodes.seoulGuNames),
                  const SizedBox(height: AppSpacing.lg),
                  // 인천
                  _regionCategory('인천', '인천 전체', RegionCodes.incheonGuNames),
                  const SizedBox(height: AppSpacing.lg),
                  // 경기
                  _regionCategory('경기', '경기 전체', RegionCodes.gyeonggiSiNames),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
          // 잠금화면 노출 체크박스
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xs,
              right: AppSpacing.screenH,
              bottom: AppSpacing.sm,
            ),
            child: GestureDetector(
              onTap: () => setState(() => _lockScreenEnabled = !_lockScreenEnabled),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: Checkbox(
                      value: _lockScreenEnabled,
                      onChanged: (v) => setState(() => _lockScreenEnabled = v ?? false),
                      activeColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      side: BorderSide(
                        color: _lockScreenEnabled ? AppColors.primary : AppColors.gray300,
                        width: 1.5,
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '잠금화면에 시세 정보 표시',
                            style: AppTypography.body2.copyWith(color: AppColors.textPrimary),
                          ),
                          TextSpan(
                            text: '  선택사항',
                            style: AppTypography.caption1.copyWith(color: AppColors.textTertiary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _regionCategory(String title, String allLabel, List<String> items) {
    final isAllSelected = _selectedRegions.contains(allLabel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.body1Bold),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            // "전체" 칩
            ChoiceChip(
              label: Text(allLabel),
              selected: isAllSelected,
              onSelected: (_) {
                setState(() {
                  if (isAllSelected) {
                    _selectedRegions.remove(allLabel);
                  } else {
                    // 전체 선택 시 해당 지역의 개별 선택 해제
                    _selectedRegions.removeWhere((r) => items.contains(r));
                    _selectedRegions.add(allLabel);
                  }
                });
              },
              labelStyle: AppTypography.label2.copyWith(
                color: isAllSelected ? AppColors.white : AppColors.textSecondary,
              ),
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.gray100,
            ),
            // 개별 구/시 칩
            ...items.map((item) {
              final isSelected = _selectedRegions.contains(item);
              return ChoiceChip(
                label: Text(item),
                selected: isSelected,
                onSelected: isAllSelected ? null : (_) {
                  setState(() {
                    if (isSelected) {
                      _selectedRegions.remove(item);
                    } else {
                      _selectedRegions.add(item);
                    }
                  });
                },
                labelStyle: AppTypography.label2.copyWith(
                  color: isSelected ? AppColors.primary
                      : isAllSelected ? AppColors.gray300
                      : AppColors.textSecondary,
                ),
              );
            }),
          ],
        ),
      ],
    );
  }
}

class _InterestTile extends StatelessWidget {
  final InterestType type;
  final bool isSelected;
  final VoidCallback onTap;
  const _InterestTile({required this.type, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: AppConstants.animCardMs),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.05) : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.gray100,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Icon(type.icon, color: isSelected ? AppColors.primary : AppColors.gray500, size: 22),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type.label, style: AppTypography.body1Bold),
                    const SizedBox(height: 2),
                    Text(type.description, style: AppTypography.caption1),
                  ],
                ),
              ),
              Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                color: isSelected ? AppColors.primary : AppColors.gray300,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
