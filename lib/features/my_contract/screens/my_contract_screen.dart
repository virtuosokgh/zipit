import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../models/contract.dart';
import '../../../providers/auth_provider.dart';
import '../providers/contract_provider.dart';

class MyContractScreen extends ConsumerStatefulWidget {
  const MyContractScreen({super.key});

  @override
  ConsumerState<MyContractScreen> createState() => _MyContractScreenState();
}

class _MyContractScreenState extends ConsumerState<MyContractScreen> {
  Future<void> _onRefresh() async {
    ref.invalidate(contractsProvider);
    ref.invalidate(authStateProvider);
    await Future.delayed(const Duration(milliseconds: AppConstants.refreshDelayMs));
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: _loginPrompt(context),
          );
        }
        return _authenticatedBody(context);
      },
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      ),
      error: (_, _) => Scaffold(
        backgroundColor: AppColors.background,
        body: _loginPrompt(context),
      ),
    );
  }

  Widget _loginPrompt(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Center(
              child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 64, color: AppColors.gray300),
            const SizedBox(height: AppSpacing.lg),
            const Text('로그인이 필요해요', style: AppTypography.body1Bold),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '계약 관리를 위해 로그인해주세요',
              style: AppTypography.body2.copyWith(color: AppColors.textTertiary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),
            SizedBox(
              width: double.infinity,
              height: AppSpacing.buttonHeight,
              child: ElevatedButton(
                onPressed: () => context.push('/login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                ),
                child: Text('로그인하기', style: AppTypography.label1.copyWith(color: AppColors.white)),
              ),
            ),
          ],
        ),
      ),
    ),
    ),
    ],
    ),
    );
  }

  Widget _authenticatedBody(BuildContext context) {
    final contracts = ref.watch(contractsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: contracts.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => context.push('/my-contract/register'),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: AppColors.white),
            )
          : null,
      body: contracts.isEmpty ? _emptyState(context) : _contractList(context, contracts),
    );
  }

  Widget _emptyState(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.screenH),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.description_outlined, size: 64, color: AppColors.gray300),
                    const SizedBox(height: AppSpacing.lg),
                    const Text('아직 등록된 계약이 없어요', style: AppTypography.body1Bold),
                    const SizedBox(height: AppSpacing.sm),
                    Text('계약을 등록하면 체크리스트와\n중요 일정을 알려드려요',
                        style: AppTypography.body2.copyWith(color: AppColors.textTertiary), textAlign: TextAlign.center),
                    const SizedBox(height: AppSpacing.xxl),
                    ElevatedButton.icon(
                      onPressed: () => context.push('/my-contract/register'),
                      icon: const Icon(Icons.add),
                      label: const Text('계약 등록하기'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contractList(BuildContext context, List<Contract> contracts) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.screenH),
        itemCount: contracts.length,
        itemBuilder: (context, index) => _contractCard(context, contracts[index]),
      ),
    );
  }

  Widget _contractCard(BuildContext context, Contract contract) {
    final completedCount = contract.checklist.where((c) => c.isCompleted).length;
    final totalCount = contract.checklist.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

    return GestureDetector(
      onTap: () => context.push('/my-contract/${contract.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
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
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  child: Text(contract.type.label, style: AppTypography.label2.copyWith(color: AppColors.primary)),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.gray100,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  child: Text(contract.status.label, style: AppTypography.caption1),
                ),
                const Spacer(),
                if (contract.nextDday != null)
                  Text(
                    'D-${contract.nextDday}',
                    style: AppTypography.label2.copyWith(
                      color: contract.nextDday! <= 7 ? AppColors.error : AppColors.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(contract.aptName, style: AppTypography.body1Bold),
            const SizedBox(height: AppSpacing.xs),
            Text(contract.address, style: AppTypography.caption1),
            const SizedBox(height: AppSpacing.md),
            Text(
              contract.type == ContractType.monthly
                  ? '${PriceFormatter.format(contract.price)} / 월 ${PriceFormatter.format(contract.monthlyRent ?? 0)}'
                  : PriceFormatter.format(contract.price),
              style: AppTypography.number2.copyWith(color: AppColors.primary),
            ),
            const SizedBox(height: AppSpacing.md),
            // 체크리스트 진행률
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppColors.gray200,
                      valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                      minHeight: 4,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text('$completedCount/$totalCount', style: AppTypography.caption2),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
