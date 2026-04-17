import 'dart:developer' as dev;
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // Notification channels
  static const String _contractChannelId = 'zipit_contract';
  static const String _contractChannelName = '계약 알림';
  static const String _subscriptionChannelId = 'zipit_subscription';
  static const String _subscriptionChannelName = '청약 알림';
  static const String _lockScreenChannelId = 'zipit_lockscreen';
  static const String _lockScreenChannelName = '잠금화면 시세 알림';

  /// Initialize the notification service. Call in main.dart before runApp.
  static Future<void> initialize() async {
    // Initialize timezone
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);

    // Create Android notification channels
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _contractChannelId,
          _contractChannelName,
          importance: Importance.high,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _subscriptionChannelId,
          _subscriptionChannelName,
          importance: Importance.high,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _lockScreenChannelId,
          _lockScreenChannelName,
          importance: Importance.defaultImportance,
          showBadge: false,
          enableVibration: false,
          playSound: false,
        ),
      );
      // 알람 권한은 초기 실행 시 1회만 요청 (매번 설정화면 리다이렉트 방지)
      final prefs = await SharedPreferences.getInstance();
      const key = 'exact_alarm_permission_requested';
      if (prefs.getBool(key) != true) {
        await prefs.setBool(key, true);
        await androidPlugin.requestExactAlarmsPermission();
      }
    }
  }

  /// 실제 알림 예약이 필요할 때 권한 요청 (설정화면 열림)
  static Future<bool> ensureExactAlarmPermission() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return true;
    final granted = await androidPlugin.requestExactAlarmsPermission();
    return granted ?? false;
  }

  /// Generate a consistent notification ID from a string.
  static int _generateId(String value) {
    return value.hashCode & 0x7FFFFFFF;
  }

  /// Convert DateTime to TZDateTime (Asia/Seoul)
  static tz.TZDateTime _toTZ(DateTime dt) {
    return tz.TZDateTime.from(dt, tz.local);
  }

  /// Schedule a reminder notification at 9AM the day before [scheduledDate].
  static Future<void> scheduleContractReminder({
    required String id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    final reminderDate = DateTime(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day - 1,
      9,
    );

    if (reminderDate.isBefore(DateTime.now())) return;

    final notificationId = _generateId('contract_reminder_$id');

    await _plugin.zonedSchedule(
      notificationId,
      title,
      body,
      _toTZ(reminderDate),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _contractChannelId,
          _contractChannelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Schedule a notification at 8AM on the exact [scheduledDate].
  static Future<void> scheduleContractDayOf({
    required String id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    final dayOfDate = DateTime(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      8,
    );

    if (dayOfDate.isBefore(DateTime.now())) return;

    final notificationId = _generateId('contract_dayof_$id');

    await _plugin.zonedSchedule(
      notificationId,
      title,
      body,
      _toTZ(dayOfDate),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _contractChannelId,
          _contractChannelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Schedule all contract-related notifications for a contract.
  /// Handles balance date and move-in date reminders.
  static Future<void> scheduleContractNotifications({
    required String contractId,
    required String aptName,
    required DateTime? balanceDate,
    required DateTime? moveInDate,
  }) async {
    // Cancel existing notifications first
    await cancelAllForContract(contractId);

    if (balanceDate != null) {
      await scheduleContractReminder(
        id: '${contractId}_balance',
        title: '잔금 납부 D-1',
        body: '$aptName 잔금 납부일이 내일이에요!',
        scheduledDate: balanceDate,
      );
      await scheduleContractDayOf(
        id: '${contractId}_balance',
        title: '잔금 납부일',
        body: '$aptName 오늘 잔금 납부일이에요. 준비하셨나요?',
        scheduledDate: balanceDate,
      );
    }

    if (moveInDate != null) {
      await scheduleContractReminder(
        id: '${contractId}_move',
        title: '입주 D-1',
        body: '$aptName 입주일이 내일이에요!',
        scheduledDate: moveInDate,
      );
      await scheduleContractDayOf(
        id: '${contractId}_move',
        title: '입주일',
        body: '$aptName 오늘 입주일이에요. 새 집 축하드려요!',
        scheduledDate: moveInDate,
      );
    }
  }

  /// Cancel a specific notification by its integer ID.
  static Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }

  /// Cancel all notifications associated with a contract ID.
  static Future<void> cancelAllForContract(String contractId) async {
    final ids = [
      _generateId('contract_reminder_${contractId}_balance'),
      _generateId('contract_dayof_${contractId}_balance'),
      _generateId('contract_reminder_${contractId}_move'),
      _generateId('contract_dayof_${contractId}_move'),
    ];

    await Future.wait(ids.map((id) => _plugin.cancel(id)));
  }

  /// Schedule D-3 and D-1 reminder notifications for a subscription deadline.
  static Future<void> scheduleSubscriptionReminder({
    required String name,
    required DateTime deadline,
  }) async {
    final now = DateTime.now();

    // D-3 reminder at 9AM
    final d3Date = DateTime(
      deadline.year,
      deadline.month,
      deadline.day - 3,
      9,
    );
    if (d3Date.isAfter(now)) {
      final d3Id = _generateId('subscription_d3_$name');
      await _plugin.zonedSchedule(
        d3Id,
        '청약 마감 D-3',
        '$name 청약 마감까지 3일 남았어요.',
        _toTZ(d3Date),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _subscriptionChannelId,
            _subscriptionChannelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }

    // D-1 reminder at 9AM
    final d1Date = DateTime(
      deadline.year,
      deadline.month,
      deadline.day - 1,
      9,
    );
    if (d1Date.isAfter(now)) {
      final d1Id = _generateId('subscription_d1_$name');
      await _plugin.zonedSchedule(
        d1Id,
        '청약 마감 D-1',
        '$name 청약 마감이 내일이에요!',
        _toTZ(d1Date),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _subscriptionChannelId,
            _subscriptionChannelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  /// Cancel all pending notifications.
  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// Request notification permission (Android 13+).
  /// Returns true if granted.
  static Future<bool> requestPermission() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }

  /// 잠금화면 Activity 활성화 + 데이터 저장
  static Future<void> enableLockScreen({
    required String title,
    required String interest,
    required List<String> names,
    required List<String> prices,
    required List<String> dates,
    List<String> regionCodes = const [],
  }) async {
    if (names.isEmpty) return;
    try {
      const channel = MethodChannel('com.zipit.app/lockscreen');
      await channel.invokeMethod('enableLockScreen', {
        'title': title,
        'interest': interest,
        'names': names.take(3).toList(),
        'prices': prices.take(3).toList(),
        'dates': dates.take(3).toList(),
        'regionCodes': regionCodes.take(3).toList(),
      });
    } catch (e) {
      dev.log('잠금화면 활성화 실패: $e', name: 'NotificationService');
    }
  }

  /// 잠금화면 데이터 업데이트 (서비스가 이미 실행 중일 때)
  static Future<void> updateLockScreenData({
    required String title,
    required List<String> names,
    required List<String> prices,
    required List<String> dates,
  }) async {
    if (names.isEmpty) return;
    try {
      const channel = MethodChannel('com.zipit.app/lockscreen');
      await channel.invokeMethod('updateData', {
        'title': title,
        'names': names.take(3).toList(),
        'prices': prices.take(3).toList(),
        'dates': dates.take(3).toList(),
      });
    } catch (e) {
      dev.log('잠금화면 업데이트 실패: $e', name: 'NotificationService');
    }
  }

  /// 잠금화면 비활성화
  static Future<void> disableLockScreen() async {
    try {
      const channel = MethodChannel('com.zipit.app/lockscreen');
      await channel.invokeMethod('disableLockScreen');
    } catch (e) {
      dev.log('잠금화면 비활성화 실패: $e', name: 'NotificationService');
    }
  }
}
