import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/services/notification_history_service.dart';
import '../../../providers/notification_provider.dart';

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    // 화면 진입 시 모두 읽음 처리
    Future.microtask(() {
      ref.read(notificationHistoryProvider.notifier).markAllRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationHistoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('알림')),
      body: notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.notifications_none, size: 56, color: AppColors.gray300),
                  const SizedBox(height: AppSpacing.md),
                  Text('알림이 없어요', style: AppTypography.body2.copyWith(color: AppColors.textTertiary)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '계약 일정, 청약 마감 등\n중요한 알림이 여기에 표시돼요',
                    style: AppTypography.caption1.copyWith(color: AppColors.textTertiary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.screenH),
              itemCount: notifications.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = notifications[index];
                return _notificationTile(item);
              },
            ),
    );
  }

  Widget _notificationTile(NotificationItem item) {
    final icon = switch (item.type) {
      'contract' => Icons.description_outlined,
      'subscription' => Icons.apartment_outlined,
      'trade' => Icons.trending_up,
      _ => Icons.notifications_outlined,
    };
    final iconColor = switch (item.type) {
      'contract' => AppColors.primary,
      'subscription' => AppColors.signalCaution,
      'trade' => AppColors.signalSafe,
      _ => AppColors.gray500,
    };

    final now = DateTime.now();
    final diff = now.difference(item.timestamp);
    String timeStr;
    if (diff.inMinutes < 1) {
      timeStr = '방금 전';
    } else if (diff.inHours < 1) {
      timeStr = '${diff.inMinutes}분 전';
    } else if (diff.inDays < 1) {
      timeStr = '${diff.inHours}시간 전';
    } else if (diff.inDays < 7) {
      timeStr = '${diff.inDays}일 전';
    } else {
      timeStr = '${item.timestamp.month}/${item.timestamp.day}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(item.title, style: AppTypography.body2Bold),
                    ),
                    Text(timeStr, style: AppTypography.caption2.copyWith(color: AppColors.textTertiary)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.body,
                  style: AppTypography.caption1.copyWith(color: AppColors.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
