import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../providers/auth_provider.dart';
import '../providers/subscription_provider.dart';

class SubscriptionDetailScreen extends ConsumerWidget {
  final int index;

  const SubscriptionDetailScreen({super.key, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionsAsync = ref.watch(subscriptionListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('청약 상세'),
      ),
      body: subscriptionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.gray300),
              const SizedBox(height: AppSpacing.md),
              const Text('정보를 불러오지 못했어요', style: AppTypography.body2Bold),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton(
                onPressed: () => ref.invalidate(subscriptionListProvider),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
        data: (subscriptions) {
          if (index < 0 || index >= subscriptions.length) {
            return const Center(child: Text('청약 정보를 찾을 수 없습니다', style: AppTypography.body2Bold));
          }

          final sub = subscriptions[index];
          return _DetailBody(sub: sub);
        },
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  final SubscriptionInfo sub;

  const _DetailBody({required this.sub});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final houseManageNo = sub.houseManageNo ?? '';
    final unitTypesAsync = houseManageNo.isNotEmpty
        ? ref.watch(subscriptionUnitTypesProvider(houseManageNo))
        : const AsyncValue<List<SubscriptionUnitType>>.data([]);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header
          _buildHeader(context, sub),
          const SizedBox(height: AppSpacing.lg),

          // 2. AI 당첨확률 카드 (로그인 시) / 로그인 유도 (비로그인)
          _buildProbabilitySection(context, ref, sub, unitTypesAsync),
          const SizedBox(height: AppSpacing.lg),

          // 3. 기본 정보 카드
          _buildInfoCard(sub),
          const SizedBox(height: AppSpacing.lg),

          // 4. 평형별 정보
          unitTypesAsync.when(
            loading: () => _buildUnitTypesShimmer(),
            error: (error, _) => _buildUnitTypesError(),
            data: (units) => units.isNotEmpty ? _buildUnitTypesSection(units) : const SizedBox.shrink(),
          ),
          if (unitTypesAsync is AsyncData<List<SubscriptionUnitType>> &&
              unitTypesAsync.value.isNotEmpty)
            const SizedBox(height: AppSpacing.lg),

          // 5. 청약 일정 타임라인
          _buildTimelineCard(sub),
          const SizedBox(height: AppSpacing.lg),

          // 6. 청약 조건 정보
          _buildConditionsCard(sub),
          const SizedBox(height: AppSpacing.lg),

          // 7. 경쟁률 (placeholder)
          _buildCompetitionCard(sub),
          const SizedBox(height: AppSpacing.xxl),

          // 청약홈 바로가기
          if (sub.pblancUrl != null && sub.pblancUrl!.isNotEmpty && sub.pblancUrl != 'null')
            SizedBox(
              width: double.infinity,
              height: AppSpacing.buttonHeight,
              child: ElevatedButton(
                onPressed: () => _openUrl(sub.pblancUrl!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.open_in_new, size: 18),
                    const SizedBox(width: AppSpacing.sm),
                    Text('청약홈에서 보기', style: AppTypography.label1.copyWith(color: AppColors.white)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  // ==================== 1. Header ====================

  Widget _buildHeader(BuildContext context, SubscriptionInfo sub) {
    final dDay = sub.dDay;
    final isUrgent = dDay >= 0 && dDay <= 7;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: sub.statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text(sub.status, style: AppTypography.label2.copyWith(color: sub.statusColor)),
              ),
              if (dDay >= 0) ...[
                const SizedBox(width: AppSpacing.sm),
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
          const SizedBox(height: AppSpacing.md),
          Text(sub.name, style: AppTypography.heading2),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 16, color: AppColors.gray500),
              const SizedBox(width: 4),
              Expanded(
                child: Text(sub.location, style: AppTypography.body2.copyWith(color: AppColors.textSecondary)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== 2. AI 당첨확률 카드 ====================

  Widget _buildProbabilitySection(
    BuildContext context,
    WidgetRef ref,
    SubscriptionInfo sub,
    AsyncValue<List<SubscriptionUnitType>> unitTypesAsync,
  ) {
    final authState = ref.watch(authStateProvider);
    final isLoggedIn = authState.valueOrNull != null;

    if (!isLoggedIn) {
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
            const Icon(Icons.lock_outline, size: 40, color: AppColors.gray300),
            const SizedBox(height: AppSpacing.md),
            Text('로그인하면 AI 당첨확률 분석을\n확인할 수 있어요',
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

    return unitTypesAsync.when(
      loading: () => _buildProbabilityShimmer(),
      error: (_, st) => _buildProbabilityCard(ref, sub, const []),
      data: (units) => _buildProbabilityCard(ref, sub, units),
    );
  }

  Widget _buildProbabilityShimmer() {
    return Shimmer.fromColors(
      baseColor: AppColors.gray100,
      highlightColor: AppColors.gray50,
      child: Container(
        width: double.infinity,
        height: 180,
        decoration: BoxDecoration(
          color: AppColors.gray100,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
      ),
    );
  }

  Widget _buildProbabilityCard(WidgetRef ref, SubscriptionInfo sub, List<SubscriptionUnitType> units) {
    final probability = ref.watch(winProbabilityProvider((sub: sub, units: units)));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 18, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text('AI 당첨확률 분석', style: AppTypography.body1Bold),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // 원형 프로그레스 + 레벨 배지 + 요약
          Row(
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: CircularProgressIndicator(
                        value: probability.percentage / 100,
                        strokeWidth: 8,
                        backgroundColor: AppColors.gray100,
                        valueColor: AlwaysStoppedAnimation(probability.color),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${probability.percentage.toStringAsFixed(0)}%',
                          style: AppTypography.number2.copyWith(color: probability.color),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xl),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: probability.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                      ),
                      child: Text(
                        '당첨확률 ${probability.level}',
                        style: AppTypography.label2.copyWith(color: probability.color),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // 1순위 여부 + 선정방식
                    Row(
                      children: [
                        Icon(
                          probability.isFirstPriority ? Icons.check_circle : Icons.cancel,
                          size: 14,
                          color: probability.isFirstPriority ? AppColors.success : AppColors.gray400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          probability.isFirstPriority ? '1순위 해당' : '1순위 미달',
                          style: AppTypography.caption2.copyWith(
                            color: probability.isFirstPriority ? AppColors.success : AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      probability.selectionMethod,
                      style: AppTypography.caption2.copyWith(color: AppColors.textTertiary),
                    ),
                    if (probability.specialSupplyTypes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        children: probability.specialSupplyTypes.map((t) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(t, style: AppTypography.caption2.copyWith(color: const Color(0xFF8B5CF6))),
                        )).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // 상세 분석 항목별 바
          if (probability.details.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            const Divider(height: 1, color: AppColors.gray200),
            const SizedBox(height: AppSpacing.lg),
            Text('항목별 분석', style: AppTypography.body2Bold),
            const SizedBox(height: AppSpacing.md),
            ...probability.details.map((d) => _buildFactorBar(d)),
          ],
        ],
      ),
    );
  }

  Widget _buildFactorBar(ProbabilityFactor factor) {
    final ratio = factor.ratio;
    Color barColor;
    if (factor.isMissing) {
      barColor = AppColors.gray300;
    } else if (ratio >= 0.7) {
      barColor = AppColors.success;
    } else if (ratio >= 0.4) {
      barColor = AppColors.warning;
    } else {
      barColor = AppColors.error;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                factor.isMissing
                    ? Icons.help_outline
                    : factor.isPositive
                        ? Icons.trending_up
                        : Icons.trending_down,
                size: 14,
                color: factor.isMissing ? AppColors.gray400 : barColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  factor.title,
                  style: AppTypography.caption1.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${factor.score.toStringAsFixed(0)}/${factor.maxScore.toStringAsFixed(0)}',
                style: AppTypography.caption2.copyWith(color: AppColors.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: AppColors.gray100,
              valueColor: AlwaysStoppedAnimation(barColor),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            factor.description,
            style: AppTypography.caption2.copyWith(
              color: factor.isMissing ? AppColors.primary : AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 3. 기본 정보 카드 ====================

  Widget _buildInfoCard(SubscriptionInfo sub) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('기본 정보', style: AppTypography.body1Bold),
          const SizedBox(height: AppSpacing.lg),
          if (_isValidStr(sub.bsnsMbyNm))
            _detailRow('사업주체', sub.bsnsMbyNm!),
          if (_isValidStr(sub.cnstrctEntrpsNm))
            _detailRow('시공사', sub.cnstrctEntrpsNm!),
          _detailRow('주택구분', '${sub.houseSecdNm} (${sub.houseDtlSecdNm})'),
          if (_isValidStr(sub.rentSecdNm))
            _detailRow('분양/임대', sub.rentSecdNm!),
          _detailRow('공급지역', sub.subscrptAreaCodeNm),
          _detailRow('총 공급세대', '${sub.totalSupply}세대'),
          _detailRow('입주예정', sub.moveInMonth),
        ],
      ),
    );
  }

  // ==================== 4. 평형별 정보 ====================

  Widget _buildUnitTypesShimmer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Shimmer.fromColors(
          baseColor: AppColors.gray100,
          highlightColor: AppColors.gray50,
          child: Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: AppColors.gray100,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Widget _buildUnitTypesError() {
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
          const Icon(Icons.info_outline, size: 32, color: AppColors.gray400),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '평형별 정보를 불러오지 못했어요',
            style: AppTypography.body2.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitTypesSection(List<SubscriptionUnitType> units) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('평형별 정보', style: AppTypography.body1Bold),
          const SizedBox(height: AppSpacing.lg),
          ...units.asMap().entries.map((entry) {
            final isLast = entry.key == units.length - 1;
            return Column(
              children: [
                _UnitTypeCard(unit: entry.value),
                if (!isLast) const SizedBox(height: AppSpacing.md),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ==================== 5. 청약 일정 타임라인 ====================

  Widget _buildTimelineCard(SubscriptionInfo sub) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final events = <_TimelineEvent>[
      _TimelineEvent('모집공고일', sub.announcementDate, today),
      _TimelineEvent('특별공급접수', sub.specialSupplyStart, today, endDate: sub.specialSupplyEnd),
      _TimelineEvent('1순위 접수', sub.rank1Date, today),
      _TimelineEvent('2순위 접수', sub.rank2Date, today),
      _TimelineEvent('일반접수기간', sub.receptionStart, today, endDate: sub.receptionEnd),
      _TimelineEvent('당첨자발표', sub.winnerDate, today),
      _TimelineEvent('계약기간', sub.contractStart, today, endDate: sub.contractEnd),
      _TimelineEvent('입주예정', null, today, label2: sub.moveInMonth != '-' ? sub.moveInMonth : null),
    ];

    final visibleEvents = events.where((e) => e.hasData).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('청약 일정', style: AppTypography.body1Bold),
          const SizedBox(height: AppSpacing.lg),
          ...visibleEvents.asMap().entries.map((entry) {
            final isLast = entry.key == visibleEvents.length - 1;
            return _buildTimelineItem(entry.value, isLast);
          }),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(_TimelineEvent event, bool isLast) {
    final isPast = event.isPast;
    final isCurrent = event.isCurrent;
    final dotColor = isCurrent
        ? AppColors.primary
        : isPast
            ? AppColors.gray300
            : AppColors.gray200;
    final textColor = isPast ? AppColors.textTertiary : AppColors.textPrimary;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: isCurrent ? 14 : 10,
                  height: isCurrent ? 14 : 10,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    border: isCurrent ? Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 3) : null,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.gray200,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: (isCurrent ? AppTypography.body2Bold : AppTypography.body2).copyWith(color: textColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    event.dateText,
                    style: AppTypography.caption1.copyWith(
                      color: isCurrent ? AppColors.primary : AppColors.textTertiary,
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

  // ==================== 6. 청약 조건 ====================

  Widget _buildConditionsCard(SubscriptionInfo sub) {
    final isNational = sub.houseDtlSecdNm == '국민';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('청약 조건', style: AppTypography.body1Bold),
          const SizedBox(height: AppSpacing.lg),

          // 청약통장 가입기간
          _conditionSection(
            icon: Icons.account_balance_wallet_outlined,
            title: '청약통장 가입기간',
            content: isNational
                ? '국민주택: 투기과열지구 24개월, 수도권 12개월, 비수도권 6개월 이상'
                : '민영주택: 투기과열지구 24개월, 수도권 12개월, 비수도권 6개월 이상',
          ),
          const SizedBox(height: AppSpacing.lg),

          // 무주택 조건
          _conditionSection(
            icon: Icons.home_outlined,
            title: '무주택 조건',
            content: isNational
                ? '세대원 전원 무주택이어야 합니다. 국민주택은 무주택 세대 구성원만 청약 가능합니다.'
                : '민영주택은 1순위 청약 시 무주택 세대 구성원이어야 합니다. 추첨제의 경우 일부 유주택자도 가능합니다.',
          ),
          const SizedBox(height: AppSpacing.lg),

          // 예치금 기준
          _conditionSection(
            icon: Icons.savings_outlined,
            title: '예치금 기준',
            content: isNational
                ? '매월 약정 납입일에 월납입금을 납입해야 합니다. (월 2~10만원)'
                : '전용면적 기준:\n'
                    '  85m 이하: 서울 300만원, 기타 200~250만원\n'
                    '  102m 이하: 서울 600만원, 기타 300~400만원\n'
                    '  135m 이하: 서울 1,000만원, 기타 400~700만원\n'
                    '  전용 초과: 서울 1,500만원, 기타 500~1,000만원',
          ),
        ],
      ),
    );
  }

  Widget _conditionSection({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Text(title, style: AppTypography.body2Bold),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.gray50,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          child: Text(
            content,
            style: AppTypography.caption1.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  // ==================== 7. 경쟁률 ====================

  Widget _buildCompetitionCard(SubscriptionInfo sub) {
    final isPastReception = sub.receptionEnd != null &&
        DateTime.now().isAfter(sub.receptionEnd!);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('경쟁률', style: AppTypography.body1Bold),
          const SizedBox(height: AppSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Column(
              children: [
                Icon(
                  isPastReception ? Icons.bar_chart : Icons.schedule,
                  size: 32,
                  color: AppColors.gray400,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  isPastReception
                      ? '경쟁률 데이터 준비 중입니다'
                      : '접수 마감 후 경쟁률이 공개됩니다',
                  style: AppTypography.body2.copyWith(color: AppColors.textTertiary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Helpers ====================

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: AppTypography.body2.copyWith(color: AppColors.textTertiary)),
          ),
          Expanded(
            child: Text(value, style: AppTypography.body2Bold),
          ),
        ],
      ),
    );
  }

  bool _isValidStr(String? s) => s != null && s.isNotEmpty && s != 'null';

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// 평형별 정보 카드 (expandable)
class _UnitTypeCard extends StatefulWidget {
  final SubscriptionUnitType unit;

  const _UnitTypeCard({required this.unit});

  @override
  State<_UnitTypeCard> createState() => _UnitTypeCardState();
}

class _UnitTypeCardState extends State<_UnitTypeCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final unit = widget.unit;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: _expanded ? AppColors.primary.withValues(alpha: 0.03) : AppColors.gray50,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: _expanded ? AppColors.primary.withValues(alpha: 0.2) : AppColors.gray200,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 요약 행
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(unit.pyeongLabel, style: AppTypography.body2Bold),
                      const SizedBox(height: 2),
                      Text(
                        '공급면적 ${unit.supplyArea.toStringAsFixed(2)}m\u00B2',
                        style: AppTypography.caption2.copyWith(color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (unit.topAmount > 0)
                      Text(
                        PriceFormatter.format(unit.topAmount),
                        style: AppTypography.body2Bold.copyWith(color: AppColors.primary),
                      ),
                    Text(
                      '${unit.totalCount}세대',
                      style: AppTypography.caption1.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 20,
                  color: AppColors.gray500,
                ),
              ],
            ),
            // 확장 상세
            if (_expanded) ...[
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1, color: AppColors.gray200),
              const SizedBox(height: AppSpacing.md),
              _unitDetailRow('일반공급', '${unit.supplyCount}세대'),
              _unitDetailRow('특별공급', '${unit.specialCount}세대'),
              if (unit.specialCount > 0) ...[
                const SizedBox(height: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.lg),
                  child: Column(
                    children: [
                      if (unit.newlyWedCount > 0)
                        _unitDetailRow('신혼부부', '${unit.newlyWedCount}세대', isSubItem: true),
                      if (unit.firstLifeCount > 0)
                        _unitDetailRow('생애최초', '${unit.firstLifeCount}세대', isSubItem: true),
                      if (unit.multiChildCount > 0)
                        _unitDetailRow('다자녀', '${unit.multiChildCount}세대', isSubItem: true),
                      if (unit.oldParentCount > 0)
                        _unitDetailRow('노부모부양', '${unit.oldParentCount}세대', isSubItem: true),
                      if (unit.institutionCount > 0)
                        _unitDetailRow('기관추천', '${unit.institutionCount}세대', isSubItem: true),
                    ],
                  ),
                ),
              ],
              if (unit.topAmount > 0) ...[
                const SizedBox(height: AppSpacing.sm),
                _unitDetailRow('최고 분양가', PriceFormatter.format(unit.topAmount)),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _unitDetailRow(String label, String value, {bool isSubItem = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: (isSubItem ? AppTypography.caption2 : AppTypography.caption1).copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          Text(
            value,
            style: (isSubItem ? AppTypography.caption2 : AppTypography.caption1).copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 타임라인 이벤트 헬퍼
class _TimelineEvent {
  final String title;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime today;
  final String? label2;

  _TimelineEvent(this.title, this.startDate, this.today, {this.endDate, this.label2});

  bool get hasData => startDate != null || label2 != null;

  bool get isPast {
    if (startDate == null) return false;
    final checkDate = endDate ?? startDate!;
    return today.isAfter(checkDate);
  }

  bool get isCurrent {
    if (startDate == null) return false;
    if (endDate != null) {
      return !today.isBefore(startDate!) && !today.isAfter(endDate!);
    }
    return startDate!.year == today.year &&
        startDate!.month == today.month &&
        startDate!.day == today.day;
  }

  String get dateText {
    if (label2 != null) return label2!;
    if (startDate == null) return '-';
    final start = _fmt(startDate!);
    if (endDate != null) {
      return '$start ~ ${_fmt(endDate!)}';
    }
    return start;
  }

  String _fmt(DateTime d) {
    return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
  }
}
