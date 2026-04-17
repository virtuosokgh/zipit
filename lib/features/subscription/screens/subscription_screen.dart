import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../models/user_profile.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/user_preferences_provider.dart';
import '../../../widgets/shimmer_loading.dart';
import '../providers/subscription_provider.dart';
import '../providers/subscription_filter_provider.dart';
import '../widgets/subscription_filter_bar.dart';
import '../widgets/subscription_filter_sheets.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      final hasMore = ref.read(hasMoreSubscriptionsProvider);
      if (hasMore) {
        ref.read(subscriptionPageProvider.notifier).state++;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final score = ref.watch(effectiveScoreProvider);
    final authState = ref.watch(authStateProvider);
    final isLoggedIn = authState.valueOrNull != null;
    final filter = ref.watch(subscriptionFilterProvider);
    final paginatedAsync = ref.watch(paginatedSubscriptionListProvider);
    final filteredAsync = ref.watch(filteredSubscriptionListProvider);
    final hasMore = ref.watch(hasMoreSubscriptionsProvider);

    // 필터 변경 시 페이지 리셋
    ref.listen(subscriptionFilterProvider, (prev, next) {
      if (prev != next) {
        ref.read(subscriptionPageProvider.notifier).state = 1;
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(subscriptionListProvider);
          ref.read(subscriptionPageProvider.notifier).state = 1;
          await ref.read(subscriptionListProvider.future);
        },
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 내 가점 카드
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.screenH, AppSpacing.screenH, AppSpacing.md),
                child: isLoggedIn
                    ? _ScoreCard(score: score)
                    : _loginPromptCard(context),
              ),
            ),

            // 필터 바
            const SliverToBoxAdapter(
              child: SubscriptionFilterBar(),
            ),

            // 정렬 + 결과 수
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, AppSpacing.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    filteredAsync.when(
                      data: (list) => Text(
                        '${list.length}건',
                        style: AppTypography.caption1.copyWith(color: AppColors.textTertiary),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                    GestureDetector(
                      onTap: () => _showSortSheet(context),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.swap_vert, size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            filter.sortType.label,
                            style: AppTypography.caption1.copyWith(color: AppColors.textSecondary),
                          ),
                          const Icon(Icons.keyboard_arrow_down, size: 14, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 청약 목록
            paginatedAsync.when(
              loading: () => SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, _) => const Padding(
                      padding: EdgeInsets.only(bottom: AppSpacing.md),
                      child: ShimmerCard(),
                    ),
                    childCount: 3,
                  ),
                ),
              ),
              error: (error, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.screenH),
                  child: _errorWidget(),
                ),
              ),
              data: (subscriptions) {
                if (subscriptions.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.screenH),
                      child: _emptyWidget(),
                    ),
                  );
                }

                // 원본 리스트에서 인덱스 찾기용
                final allList = ref.read(subscriptionListProvider).valueOrNull ?? [];

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index == subscriptions.length) {
                          // 로딩 인디케이터
                          if (hasMore) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        }

                        final sub = subscriptions[index];
                        final originalIndex = allList.indexOf(sub);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: _SubscriptionCard(
                            sub: sub,
                            index: originalIndex >= 0 ? originalIndex : index,
                          ),
                        );
                      },
                      childCount: subscriptions.length + 1,
                    ),
                  ),
                );
              },
            ),

            // 하단 여백
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
          ],
        ),
      ),
    );
  }

  void _showSortSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
      ),
      builder: (_) => SubscriptionSortSheet(
        current: ref.read(subscriptionFilterProvider).sortType,
        onSelect: (sort) => ref.read(subscriptionFilterProvider.notifier).setSortType(sort),
      ),
    );
  }

  Widget _loginPromptCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          const Icon(Icons.lock_outline, size: 36, color: AppColors.gray300),
          const SizedBox(height: AppSpacing.md),
          Text('로그인하면 AI 당첨확률과\n예상 가점을 확인할 수 있어요',
              style: AppTypography.body2Bold, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '청약 정보를 입력하면 더 정확한 분석이 가능해요',
            style: AppTypography.caption1.copyWith(color: AppColors.textTertiary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: AppSpacing.buttonSmallHeight,
            child: ElevatedButton(
              onPressed: () => context.push('/login'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 32),
              ),
              child: const Text('로그인하기'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorWidget() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.gray300),
          const SizedBox(height: AppSpacing.md),
          const Text('청약 정보를 불러오지 못했어요', style: AppTypography.body2Bold),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '네트워크 연결을 확인해주세요',
            style: AppTypography.caption1.copyWith(color: AppColors.textTertiary),
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton(
            onPressed: () {
              ref.invalidate(subscriptionListProvider);
              ref.read(subscriptionPageProvider.notifier).state = 1;
            },
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  Widget _emptyWidget() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          const Icon(Icons.apartment_outlined, size: 48, color: AppColors.gray300),
          const SizedBox(height: AppSpacing.md),
          const Text('조건에 맞는 청약이 없어요', style: AppTypography.body2Bold),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '필터 조건을 변경해보세요',
            style: AppTypography.caption1.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// 개별 청약 카드
class _SubscriptionCard extends ConsumerWidget {
  final SubscriptionInfo sub;
  final int index;

  const _SubscriptionCard({required this.sub, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dDay = sub.dDay;
    final isUrgent = dDay >= 0 && dDay <= 7;

    final authState = ref.watch(authStateProvider);
    final isLoggedIn = authState.valueOrNull != null;

    final userScore = ref.watch(effectiveScoreProvider);
    final prefs = ref.watch(userPreferencesProvider);
    final profile = ref.watch(userProfileProvider);
    final winScore = isLoggedIn
        ? quickWinScore(userScore, sub, prefs.region, profile: profile)
        : 0.0;

    Color winColor;
    if (winScore >= 55) {
      winColor = AppColors.success;
    } else if (winScore >= 35) {
      winColor = AppColors.warning;
    } else {
      winColor = AppColors.error;
    }

    return GestureDetector(
      onTap: () => context.push('/subscription/detail/$index'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상태 배지 + D-day
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(sub.name, style: AppTypography.body1Bold, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: AppSpacing.sm),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: sub.statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                      ),
                      child: Text(sub.status, style: AppTypography.caption2.copyWith(color: sub.statusColor)),
                    ),
                    if (dDay >= 0) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isUrgent ? AppColors.error : AppColors.primary).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                        ),
                        child: Text(
                          'D-$dDay',
                          style: AppTypography.label2.copyWith(
                            color: isUrgent ? AppColors.error : AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // 위치 + 구분 칩
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: AppColors.gray500),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(sub.location, style: AppTypography.caption1, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: AppSpacing.md),
                if (sub.rentSecdNm != null && sub.rentSecdNm!.isNotEmpty && sub.rentSecdNm != 'null')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.gray100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(sub.rentSecdNm!, style: AppTypography.caption2),
                  ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.gray100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(sub.houseDtlSecdNm, style: AppTypography.caption2),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // 상세 정보
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.gray50,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Column(
                children: [
                  _infoRow('총 공급세대', '${sub.totalSupply}세대'),
                  const SizedBox(height: AppSpacing.xs),
                  _infoRow(sub.relevantDateLabel, sub.relevantDateValue),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 당첨예측 + 상세보기
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
              decoration: BoxDecoration(
                color: isLoggedIn ? winColor.withValues(alpha: 0.06) : AppColors.gray50,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Row(
                children: [
                  if (isLoggedIn) ...[
                    Icon(Icons.auto_awesome, size: 16, color: winColor),
                    const SizedBox(width: 6),
                    Text('당첨예측', style: AppTypography.caption1.copyWith(color: winColor)),
                    const SizedBox(width: 4),
                    Text(
                      '${winScore.toStringAsFixed(0)}%',
                      style: AppTypography.body2Bold.copyWith(color: winColor),
                    ),
                  ] else ...[
                    const Icon(Icons.lock_outline, size: 14, color: AppColors.gray400),
                    const SizedBox(width: 6),
                    Text('로그인 시 당첨예측 확인', style: AppTypography.caption1.copyWith(color: AppColors.gray400)),
                  ],
                  const Spacer(),
                  GestureDetector(
                    onTap: () => context.push('/subscription/detail/$index'),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('상세보기', style: AppTypography.caption1.copyWith(color: AppColors.textSecondary)),
                        const SizedBox(width: 2),
                        const Icon(Icons.chevron_right, size: 16, color: AppColors.gray400),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.caption2.copyWith(color: AppColors.textTertiary)),
        Text(value, style: AppTypography.caption1),
      ],
    );
  }
}

/// 내 예상 가점 카드
class _ScoreCard extends ConsumerWidget {
  final int? score;
  const _ScoreCard({required this.score});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3182F6), Color(0xFF1B6EF3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('내 예상 가점', style: AppTypography.body2.copyWith(color: AppColors.white.withValues(alpha: 0.8))),
              const Spacer(),
              GestureDetector(
                onTap: () => _showEditProfileSheet(context, ref, profile),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_outlined, size: 14, color: AppColors.white),
                      const SizedBox(width: 4),
                      Text('조건 수정', style: AppTypography.caption2.copyWith(color: AppColors.white)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            score != null ? '$score점' : '정보를 입력해주세요',
            style: score != null
                ? AppTypography.heading1.copyWith(color: AppColors.white)
                : AppTypography.body1Bold.copyWith(color: AppColors.white.withValues(alpha: 0.7)),
          ),
          if (score != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              score! >= 60 ? '상위권 가점이에요' : score! >= 40 ? '중위권 가점이에요' : '가점을 높이려면 조건을 확인해보세요',
              style: AppTypography.caption1.copyWith(color: AppColors.white.withValues(alpha: 0.7)),
            ),
          ],
          if (profile != null && score != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _miniStat('무주택', '${profile.noHouseYears ?? 0}년'),
                  _miniStat('부양가족', '${profile.dependents ?? 0}명'),
                  _miniStat('통장기간', '${profile.accountYears ?? 0}년'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: AppTypography.body2Bold.copyWith(color: AppColors.white)),
        const SizedBox(height: 2),
        Text(label, style: AppTypography.caption2.copyWith(color: AppColors.white.withValues(alpha: 0.6))),
      ],
    );
  }

  void _showEditProfileSheet(BuildContext context, WidgetRef ref, UserProfile? profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditProfileSheet(profile: profile),
    );
  }
}

/// 조건 수정 바텀시트
class _EditProfileSheet extends ConsumerStatefulWidget {
  final UserProfile? profile;
  const _EditProfileSheet({this.profile});

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late int _noHouseYears;
  late int _dependents;
  late int _accountYears;
  late int _depositCount;
  late bool _isHouseHolder;
  late bool _isMarried;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _noHouseYears = p?.noHouseYears ?? 0;
    _dependents = p?.dependents ?? 0;
    _accountYears = p?.accountYears ?? 0;
    _depositCount = p?.depositCount ?? 0;
    _isHouseHolder = p?.isHouseHolder ?? false;
    _isMarried = p?.isMarried ?? false;
  }

  Future<void> _save() async {
    await ref.read(userProfileProvider.notifier).updateProfile(
      noHouseYears: _noHouseYears,
      dependents: _dependents,
      accountYears: _accountYears,
      depositCount: _depositCount,
      isHouseHolder: _isHouseHolder,
      isMarried: _isMarried,
    );
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('청약 조건이 저장되었어요'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.gray300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('청약 조건 수정', style: AppTypography.heading3),
              const SizedBox(height: AppSpacing.xs),
              Text('수정하면 예상 가점과 당첨확률에 반영돼요',
                  style: AppTypography.caption1.copyWith(color: AppColors.textTertiary)),
              const SizedBox(height: AppSpacing.xxl),

              _buildStepper('무주택 기간 (년)', _noHouseYears, 0, 15,
                  (v) => setState(() => _noHouseYears = v)),
              const SizedBox(height: AppSpacing.md),
              _buildStepper('부양가족 수 (명)', _dependents, 0, 6,
                  (v) => setState(() => _dependents = v)),
              const SizedBox(height: AppSpacing.md),
              _buildStepper('청약통장 가입 기간 (년)', _accountYears, 0, 15,
                  (v) => setState(() => _accountYears = v)),
              const SizedBox(height: AppSpacing.md),
              _buildStepper('납입 횟수 (회)', _depositCount, 0, 240,
                  (v) => setState(() => _depositCount = v)),
              const SizedBox(height: AppSpacing.md),
              _buildSwitch('세대주 여부', _isHouseHolder,
                  (v) => setState(() => _isHouseHolder = v)),
              const SizedBox(height: AppSpacing.md),
              _buildSwitch('혼인 여부', _isMarried,
                  (v) => setState(() => _isMarried = v)),
              const SizedBox(height: AppSpacing.xxl),

              SizedBox(
                width: double.infinity,
                height: AppSpacing.buttonHeight,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                  ),
                  child: Text('저장하기', style: AppTypography.label1.copyWith(color: AppColors.white)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepper(String label, int value, int min, int max, ValueChanged<int> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.gray50,
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
                width: 44,
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
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: onTap != null ? AppColors.gray100 : AppColors.gray50,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: onTap != null ? AppColors.textPrimary : AppColors.gray300),
      ),
    );
  }

  Widget _buildSwitch(String label, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.body2),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
