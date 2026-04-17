import 'dart:convert';
import 'dart:developer' as dev;
import 'package:shared_preferences/shared_preferences.dart';

/// 알림 내역 아이템
class NotificationItem {
  final String title;
  final String body;
  final DateTime timestamp;
  final String type; // 'contract', 'subscription', 'trade'
  final bool isRead;

  NotificationItem({
    required this.title,
    required this.body,
    required this.timestamp,
    required this.type,
    this.isRead = false,
  });

  NotificationItem copyWith({bool? isRead}) => NotificationItem(
    title: title,
    body: body,
    timestamp: timestamp,
    type: type,
    isRead: isRead ?? this.isRead,
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'body': body,
    'timestamp': timestamp.toIso8601String(),
    'type': type,
    'isRead': isRead,
  };

  factory NotificationItem.fromJson(Map<String, dynamic> json) => NotificationItem(
    title: json['title'] ?? '',
    body: json['body'] ?? '',
    timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
    type: json['type'] ?? '',
    isRead: json['isRead'] ?? false,
  );
}

/// 알림 내역 영속 저장 서비스
class NotificationHistoryService {
  static const _key = 'notification_history';
  static const _maxItems = 50;

  /// 알림 추가
  static Future<void> add(NotificationItem item) async {
    final items = await getAll();
    items.insert(0, item);
    // 최대 50개 유지
    if (items.length > _maxItems) {
      items.removeRange(_maxItems, items.length);
    }
    await _save(items);
  }

  /// 전체 알림 조회
  static Future<List<NotificationItem>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json == null) return [];
    try {
      final decoded = jsonDecode(json);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map((e) => NotificationItem.fromJson(e))
          .toList();
    } catch (e) {
      dev.log('알림 내역 파싱 실패, 초기화: $e', name: 'NotificationHistory');
      await prefs.remove(_key);
      return [];
    }
  }

  /// 읽지 않은 알림 수
  static Future<int> unreadCount() async {
    final items = await getAll();
    return items.where((i) => !i.isRead).length;
  }

  /// 모두 읽음 처리
  static Future<void> markAllRead() async {
    final items = await getAll();
    final updated = items.map((i) => i.copyWith(isRead: true)).toList();
    await _save(updated);
  }

  /// 전체 삭제
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<void> _save(List<NotificationItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(items.map((i) => i.toJson()).toList());
    await prefs.setString(_key, json);
  }
}
