import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../models/contract.dart';
import '../providers/contract_provider.dart';

class ContractDetailScreen extends ConsumerWidget {
  final String contractId;
  const ContractDetailScreen({super.key, required this.contractId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contracts = ref.watch(contractsProvider);
    final contract = contracts.where((c) => c.id == contractId).firstOrNull;

    if (contract == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('계약을 찾을 수 없어요')),
      );
    }

    final completedCount = contract.checklist.where((c) => c.isCompleted).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(contract.aptName)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 계약 요약 카드
            Container(
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
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(contract.aptName, style: AppTypography.heading3),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    contract.detailAddress != null
                        ? '${contract.address} ${contract.detailAddress}'
                        : contract.address,
                    style: AppTypography.caption1,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    contract.type == ContractType.monthly
                        ? '${PriceFormatter.format(contract.price)} / 월 ${PriceFormatter.format(contract.monthlyRent ?? 0)}'
                        : PriceFormatter.format(contract.price),
                    style: AppTypography.number2.copyWith(color: AppColors.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // 타임라인
            const Text('진행 상황', style: AppTypography.heading3),
            const SizedBox(height: AppSpacing.md),
            ...ContractStatus.values.map((s) => _TimelineItem(
              step: s,
              contract: contract,
              onDateTap: () => _pickStepDate(context, ref, contract, s),
            )),
            const SizedBox(height: AppSpacing.xxl),

            // 체크리스트
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('체크리스트', style: AppTypography.heading3),
                Text('$completedCount/${contract.checklist.length}', style: AppTypography.caption1),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: contract.checklist.isEmpty ? 0 : completedCount / contract.checklist.length,
                backgroundColor: AppColors.gray200,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            ...contract.checklist.map((item) => _checklistTile(ref, contract.id, item)),

            const SizedBox(height: AppSpacing.xxl),

            // 주요 일정
            if (contract.balanceDate != null || contract.moveInDate != null) ...[
              const Text('주요 일정', style: AppTypography.heading3),
              const SizedBox(height: AppSpacing.md),
              if (contract.balanceDate != null)
                _scheduleTile('잔금일', contract.balanceDate!),
              if (contract.moveInDate != null)
                _scheduleTile('입주일', contract.moveInDate!),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickStepDate(
    BuildContext context,
    WidgetRef ref,
    Contract contract,
    ContractStatus step,
  ) async {
    // 완료 단계는 날짜 설정 불가
    if (step == ContractStatus.completed) return;

    final currentDate = contract.dateForStatus(step);
    final date = await showDatePicker(
      context: context,
      initialDate: currentDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: '${step.label} 날짜 선택',
    );

    if (date != null) {
      ref.read(contractsProvider.notifier).updateStepDate(contract.id, step, date);

      // 잔금일 변경 시 입주일이 미설정이면 자동 동기화
      if (step == ContractStatus.balance && contract.moveInDate == null) {
        ref.read(contractsProvider.notifier).updateStepDate(
          contract.id,
          ContractStatus.move,
          date,
        );
      }
    }
  }

  Widget _checklistTile(WidgetRef ref, String contractId, ChecklistItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: ListTile(
        leading: Checkbox(
          value: item.isCompleted,
          onChanged: (_) => ref.read(contractsProvider.notifier).toggleChecklist(contractId, item.id),
          activeColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        title: Text(
          item.title,
          style: item.isCompleted
              ? AppTypography.body2.copyWith(decoration: TextDecoration.lineThrough, color: AppColors.textTertiary)
              : AppTypography.body2,
        ),
        subtitle: item.description != null ? Text(item.description!, style: AppTypography.caption2) : null,
        contentPadding: const EdgeInsets.only(right: 16),
      ),
    );
  }

  Widget _scheduleTile(String label, DateTime date) {
    final dDay = date.difference(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)).inDays;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTypography.body2Bold),
              Text('${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}', style: AppTypography.caption1),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: dDay <= 7 ? AppColors.error.withValues(alpha: 0.1) : AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            ),
            child: Text(
              dDay > 0 ? 'D-$dDay' : dDay == 0 ? 'D-Day' : 'D+${-dDay}',
              style: AppTypography.label2.copyWith(color: dDay <= 7 ? AppColors.error : AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

/// 타임라인 아이템 위젯 (날짜 표시 + 탭하여 날짜 입력)
class _TimelineItem extends StatelessWidget {
  final ContractStatus step;
  final Contract contract;
  final VoidCallback onDateTap;

  const _TimelineItem({
    required this.step,
    required this.contract,
    required this.onDateTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = step.order <= contract.status.order;
    final isCurrent = step == contract.status;
    final stepDate = contract.dateForStatus(step);
    final isCompletedStep = step == ContractStatus.completed;

    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 원형 + 연결선
          Column(
            children: [
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted ? AppColors.primary : AppColors.gray200,
                  border: isCurrent ? Border.all(color: AppColors.primary, width: 3) : null,
                ),
                child: isCompleted
                    ? const Icon(Icons.check, color: AppColors.white, size: 14)
                    : null,
              ),
              if (step != ContractStatus.completed)
                Container(width: 2, height: 36, color: isCompleted ? AppColors.primary : AppColors.gray200),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          // 단계 이름 + 날짜
          Expanded(
            child: GestureDetector(
              onTap: isCompletedStep ? null : onDateTap,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      step.label,
                      style: isCurrent
                          ? AppTypography.body2Bold.copyWith(color: AppColors.primary)
                          : isCompleted
                              ? AppTypography.body2.copyWith(color: AppColors.textSecondary)
                              : AppTypography.body2.copyWith(color: AppColors.textDisabled),
                    ),
                    if (!isCompletedStep)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            stepDate != null
                                ? '${stepDate.year}.${stepDate.month.toString().padLeft(2, '0')}.${stepDate.day.toString().padLeft(2, '0')}'
                                : '미정',
                            style: AppTypography.caption1.copyWith(
                              color: stepDate != null ? AppColors.textSecondary : AppColors.textTertiary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            stepDate != null ? Icons.edit_outlined : Icons.add_circle_outline,
                            size: 14,
                            color: AppColors.textTertiary,
                          ),
                        ],
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
}
