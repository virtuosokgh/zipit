import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/notification_history_service.dart';

/// 알림 내역 Provider
final notificationHistoryProvider =
    StateNotifierProvider<NotificationHistoryNotifier, List<NotificationItem>>((ref) {
  return NotificationHistoryNotifier();
});

class NotificationHistoryNotifier extends StateNotifier<List<NotificationItem>> {
  NotificationHistoryNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    state = await NotificationHistoryService.getAll();
  }

  Future<void> addNotification(NotificationItem item) async {
    await NotificationHistoryService.add(item);
    state = await NotificationHistoryService.getAll();
  }

  Future<void> markAllRead() async {
    await NotificationHistoryService.markAllRead();
    state = await NotificationHistoryService.getAll();
  }

  Future<void> refresh() async {
    state = await NotificationHistoryService.getAll();
  }

  int get unreadCount => state.where((i) => !i.isRead).length;
}
