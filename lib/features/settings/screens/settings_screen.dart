import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/region_codes.dart';
import '../../../core/services/widget_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../models/user_preferences.dart';
import '../../../providers/user_preferences_provider.dart';
import '../../../providers/auth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Future<void> _onRefresh() async {
    ref.invalidate(userPreferencesProvider);
    await Future.delayed(const Duration(milliseconds: AppConstants.refreshDelayMs));
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(userPreferencesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: AppSpacing.sm),

          _sectionHeader('잠금화면 위젯'),
          _switchTile(
            '잠금화면에 정보 표시',
            '관심 지역 시세, 청약 D-day 등',
            prefs.lockScreenWidgetEnabled,
            (v) {
              ref.read(userPreferencesProvider.notifier).toggleLockScreenWidget(v);
              if (!v) {
                WidgetService.clearWidgetData();
                NotificationService.disableLockScreen();
              }
            },
          ),
          _navTile('위젯 종류 및 조건 설정', () => _showWidgetTypeEditor(context, ref, prefs)),
          _navTile('위젯 표시 항목 설정', () => context.push('/settings/widget-items')),
          _navTile('위젯 스타일 변경', () => context.push('/settings/widget-style')),

          const Divider(height: AppSpacing.xxl),

          _sectionHeader('관심 설정'),
          _infoTile('관심 유형', _interestLabel(prefs.interestTypes)),
          _infoTile('관심 지역', RegionCodes.regionsLabel(prefs.regions)),
          _infoTile('예산 범위', _budgetLabel(prefs.budgetMin, prefs.budgetMax)),
          _navTile('관심 설정 수정하기', () => _showInterestEditor(context, ref, prefs)),

          const Divider(height: AppSpacing.xxl),

          _sectionHeader('알림'),
          _switchTile('푸시 알림', '계약 일정, 청약 마감 등', prefs.pushNotificationEnabled, (v) {
            ref.read(userPreferencesProvider.notifier).togglePushNotification(v);
            if (!v) NotificationService.cancelAll();
          }),

          const Divider(height: AppSpacing.xxl),

          _sectionHeader('계정'),
          _buildAccountSection(context),
          _navTile('서비스 이용약관', () {
            launchUrl(Uri.parse(AppConstants.termsUrl));
          }),
          _navTile('개인정보 처리방침', () {
            launchUrl(Uri.parse(AppConstants.privacyPolicyUrl));
          }),

          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            child: Text('집잇 v1.0.0', style: AppTypography.caption1, textAlign: TextAlign.center),
          ),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
      ),
    );
  }

  String _interestLabel(List<String> types) {
    if (types.isEmpty) return '미설정';
    const map = {'buy': '매매', 'jeonse': '전세', 'monthly': '월세', 'subscription': '청약'};
    return types.map((t) => map[t] ?? t).join(', ');
  }

  String _budgetLabel(double min, double max) {
    String f(double v) {
      if (v >= 10000) return '${(v / 10000).toStringAsFixed(0)}억';
      return '${v.toInt()}만';
    }
    return '${f(min)} ~ ${f(max)}';
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.lg, AppSpacing.screenH, AppSpacing.sm),
        child: Text(title, style: AppTypography.caption1.copyWith(color: AppColors.textTertiary)),
      );

  Widget _switchTile(String title, String subtitle, bool value, ValueChanged<bool> onChanged) => Container(
        color: AppColors.surface,
        child: SwitchListTile(
          title: Text(title, style: AppTypography.body2Bold),
          subtitle: Text(subtitle, style: AppTypography.caption1),
          value: value,
          onChanged: onChanged,
          activeTrackColor: AppColors.primary,
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
        ),
      );

  Widget _navTile(String title, VoidCallback onTap) => Container(
        color: AppColors.surface,
        child: ListTile(
          title: Text(title, style: AppTypography.body2),
          trailing: const Icon(Icons.chevron_right, color: AppColors.gray400, size: 20),
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
        ),
      );

  Widget _infoTile(String title, String value) => Container(
        color: AppColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: AppTypography.body2),
            Flexible(child: Text(value, style: AppTypography.body2.copyWith(color: AppColors.textTertiary), textAlign: TextAlign.end)),
          ],
        ),
      );

  // ──────────────────────────────────────────────
  // 계정 섹션 (로그인 상태에 따라 다르게 표시)
  // ──────────────────────────────────────────────
  Widget _buildAccountSection(BuildContext context) {
    final isLoggedIn = currentUser != null;

    if (isLoggedIn) {
      return Column(
        children: [
          Container(
            color: AppColors.surface,
            child: ListTile(
              title: Text('로그아웃', style: AppTypography.body2),
              trailing: const Icon(Icons.logout, color: AppColors.gray400, size: 20),
              onTap: () => _showLogoutDialog(context),
              contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            ),
          ),
          Container(
            color: AppColors.surface,
            child: ListTile(
              title: Text('회원탈퇴', style: AppTypography.body2.copyWith(color: Colors.red)),
              trailing: const Icon(Icons.person_remove_outlined, color: Colors.red, size: 20),
              onTap: () => _showDeleteAccountDialog(context),
              contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            ),
          ),
        ],
      );
    } else {
      return _navTile('로그인 / 회원가입', () => context.go('/login'));
    }
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃 하시겠어요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('로그아웃', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await logout();
      if (mounted) context.go('/login');
    }
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                  decoration: BoxDecoration(color: AppColors.gray200, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const Text('회원탈퇴', style: AppTypography.heading3),
              const SizedBox(height: AppSpacing.xl),

              // 삭제되는 데이터
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.cardPadding),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.red.shade400, size: 20),
                        const SizedBox(width: AppSpacing.sm),
                        Text('삭제되는 데이터', style: AppTypography.body2Bold.copyWith(color: Colors.red.shade700)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _deleteInfoRow('이메일, 비밀번호 등 계정 인증 정보'),
                    _deleteInfoRow('닉네임, 청약 관련 프로필 정보'),
                    _deleteInfoRow('부동산 계약 관리 데이터'),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // 기기 내 데이터 안내
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.cardPadding),
                decoration: BoxDecoration(
                  color: AppColors.gray50,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('기기 내 저장 데이터', style: AppTypography.body2Bold),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '관심 설정, 위젯 설정, 알림 이력 등 기기에 저장된 데이터는 앱을 삭제하면 자동으로 제거됩니다.',
                      style: AppTypography.caption1.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              Text(
                '탈퇴 후 데이터는 즉시 삭제되며 복구할 수 없습니다.',
                style: AppTypography.caption1.copyWith(color: AppColors.textTertiary),
              ),
              const SizedBox(height: AppSpacing.xl),

              // 버튼
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: const Text('취소', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _executeDeleteAccount();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                      ),
                      child: const Text('탈퇴하기'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  Widget _deleteInfoRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: Colors.red.shade400)),
          Expanded(child: Text(text, style: AppTypography.caption1.copyWith(color: Colors.red.shade700))),
        ],
      ),
    );
  }

  Future<void> _executeDeleteAccount() async {
    try {
      await ref.read(userProfileProvider.notifier).clearProfile();
      await logout();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회원탈퇴가 완료되었어요.')),
        );
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('탈퇴 처리 중 오류가 발생했어요: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  // ──────────────────────────────────────────────
  // 관심 설정 수정 바텀시트
  // ──────────────────────────────────────────────
  void _showInterestEditor(BuildContext context, WidgetRef ref, UserPreferences prefs) {
    String selectedInterest = prefs.interestTypes.isNotEmpty ? prefs.interestTypes.first : 'buy';
    List<String> selectedRegions = List.from(prefs.regions);
    double budgetMin = prefs.budgetMin;
    double budgetMax = prefs.budgetMax;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.screenH),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                        decoration: BoxDecoration(color: AppColors.gray200, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const Text('관심 설정 수정', style: AppTypography.heading3),
                    const SizedBox(height: AppSpacing.xl),

                    // 관심 유형
                    Text('관심 유형', style: AppTypography.body2Bold),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        _interestChip('매매', 'buy', selectedInterest, (v) => setSheetState(() => selectedInterest = v)),
                        _interestChip('전세', 'jeonse', selectedInterest, (v) => setSheetState(() => selectedInterest = v)),
                        _interestChip('월세', 'monthly', selectedInterest, (v) => setSheetState(() => selectedInterest = v)),
                        _interestChip('청약', 'subscription', selectedInterest, (v) => setSheetState(() => selectedInterest = v)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // 관심 지역
                    Text('관심 지역', style: AppTypography.body2Bold),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        '서울 전체', '경기 전체', '인천 전체',
                        ...RegionCodes.seoulGuNames.take(8),
                      ].map((r) => ChoiceChip(
                        label: Text(r),
                        selected: selectedRegions.contains(r),
                        onSelected: (v) => setSheetState(() {
                          if (v) { selectedRegions.add(r); } else { selectedRegions.remove(r); }
                        }),
                        labelStyle: AppTypography.caption1.copyWith(
                          color: selectedRegions.contains(r) ? Colors.white : AppColors.textSecondary,
                        ),
                        selectedColor: AppColors.primary,
                      )).toList(),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // 예산 범위 (매매/전세/월세일 때만)
                    if (selectedInterest != 'subscription') ...[
                      Text('예산 범위', style: AppTypography.body2Bold),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '${_budgetLabel(budgetMin, budgetMax)}',
                        style: AppTypography.body2.copyWith(color: AppColors.primary),
                      ),
                      RangeSlider(
                        values: RangeValues(budgetMin, budgetMax),
                        min: 0,
                        max: 200000,
                        divisions: 40,
                        activeColor: AppColors.primary,
                        labels: RangeLabels(_shortBudget(budgetMin), _shortBudget(budgetMax)),
                        onChanged: (v) => setSheetState(() {
                          budgetMin = v.start;
                          budgetMax = v.end;
                        }),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],

                    // 저장 버튼
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          final notifier = ref.read(userPreferencesProvider.notifier);
                          notifier.setInterestTypes([selectedInterest]);
                          notifier.setRegions(selectedRegions);
                          if (selectedInterest != 'subscription') {
                            notifier.setBudget(budgetMin, budgetMax);
                          }
                          Navigator.pop(context);
                        },
                        child: const Text('저장'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _interestChip(String label, String value, String current, ValueChanged<String> onTap) {
    final selected = current == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(value),
      labelStyle: AppTypography.label2.copyWith(color: selected ? Colors.white : AppColors.textSecondary),
      selectedColor: AppColors.primary,
    );
  }

  String _shortBudget(double v) {
    if (v >= 10000) return '${(v / 10000).toStringAsFixed(0)}억';
    return '${v.toInt()}만';
  }

  // ──────────────────────────────────────────────
  // 위젯 종류 및 조건 설정 바텀시트
  // ──────────────────────────────────────────────
  void _showWidgetTypeEditor(BuildContext context, WidgetRef ref, UserPreferences prefs) {
    // 위젯 전용 설정 (없으면 관심 설정 fallback)
    String widgetType = prefs.effectiveWidgetInterest.isNotEmpty ? prefs.effectiveWidgetInterest : 'buy';
    List<String> widgetRegions = List.from(prefs.effectiveWidgetRegions);
    double wBudgetMin = prefs.widgetBudgetMin > 0 ? prefs.widgetBudgetMin : prefs.budgetMin;
    double wBudgetMax = prefs.widgetBudgetMax > 0 ? prefs.widgetBudgetMax : prefs.budgetMax;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.screenH),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                        decoration: BoxDecoration(color: AppColors.gray200, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const Text('위젯 종류 및 조건', style: AppTypography.heading3),
                    const SizedBox(height: AppSpacing.xs),
                    Text('위젯에 표시할 정보 종류와 조건을 설정해요', style: AppTypography.caption1.copyWith(color: AppColors.textTertiary)),
                    const SizedBox(height: AppSpacing.xl),

                    // 위젯 종류
                    Text('위젯 종류', style: AppTypography.body2Bold),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        _interestChip('매매', 'buy', widgetType, (v) => setSheetState(() => widgetType = v)),
                        _interestChip('전세', 'jeonse', widgetType, (v) => setSheetState(() => widgetType = v)),
                        _interestChip('월세', 'monthly', widgetType, (v) => setSheetState(() => widgetType = v)),
                        _interestChip('청약', 'subscription', widgetType, (v) => setSheetState(() => widgetType = v)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // 위젯 지역
                    Text('표시 지역', style: AppTypography.body2Bold),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        '서울 전체', '경기 전체', '인천 전체',
                        ...RegionCodes.seoulGuNames.take(8),
                      ].map((r) => ChoiceChip(
                        label: Text(r),
                        selected: widgetRegions.contains(r),
                        onSelected: (v) => setSheetState(() {
                          if (v) { widgetRegions.add(r); } else { widgetRegions.remove(r); }
                        }),
                        labelStyle: AppTypography.caption1.copyWith(
                          color: widgetRegions.contains(r) ? Colors.white : AppColors.textSecondary,
                        ),
                        selectedColor: AppColors.primary,
                      )).toList(),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // 가격 범위 (청약 제외)
                    if (widgetType != 'subscription') ...[
                      Text('가격 범위', style: AppTypography.body2Bold),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _budgetLabel(wBudgetMin, wBudgetMax),
                        style: AppTypography.body2.copyWith(color: AppColors.primary),
                      ),
                      RangeSlider(
                        values: RangeValues(wBudgetMin, wBudgetMax),
                        min: 0,
                        max: 200000,
                        divisions: 40,
                        activeColor: AppColors.primary,
                        labels: RangeLabels(_shortBudget(wBudgetMin), _shortBudget(wBudgetMax)),
                        onChanged: (v) => setSheetState(() {
                          wBudgetMin = v.start;
                          wBudgetMax = v.end;
                        }),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],

                    // 저장 버튼 (위젯 전용 설정만 변경)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          ref.read(userPreferencesProvider.notifier).setWidgetSettings(
                            interestType: widgetType,
                            regions: widgetRegions,
                            budgetMin: wBudgetMin,
                            budgetMax: wBudgetMax,
                          );
                          Navigator.pop(context);
                        },
                        child: const Text('저장'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
