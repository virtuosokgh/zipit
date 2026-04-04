import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/widget_config.dart';

/// 잠금화면/홈 위젯 데이터 관리 서비스
class WidgetService {
  static const _configKey = 'widget_config';
  static const _androidWidgetName = 'ZipitWidgetProvider';
  static const _qualifiedAndroidName = 'com.zipit.app.ZipitWidgetProvider';
  static const _iosWidgetName = 'ZipitWidget';

  /// 위젯 설정 저장
  static Future<void> saveConfig(WidgetConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_configKey, jsonEncode(config.toJson()));
  }

  /// 위젯 설정 불러오기
  static Future<WidgetConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_configKey);
    if (json != null) {
      return WidgetConfig.fromJson(jsonDecode(json));
    }
    return const WidgetConfig();
  }

  /// 위젯에 데이터 전달 및 업데이트
  static Future<void> updateWidget({
    String? regionName,
    String? avgPrice,
    String? priceChange,
    String? subscriptionName,
    String? subscriptionDday,
    List<WidgetTradeItem>? trades,
  }) async {
    try {
      if (regionName != null) {
        await HomeWidget.saveWidgetData('region_name', regionName);
      }
      if (avgPrice != null) {
        await HomeWidget.saveWidgetData('avg_price', avgPrice);
      }
      if (priceChange != null) {
        await HomeWidget.saveWidgetData('price_change', priceChange);
      }
      if (subscriptionName != null) {
        await HomeWidget.saveWidgetData('sub_name', subscriptionName);
      }
      if (subscriptionDday != null) {
        await HomeWidget.saveWidgetData('sub_dday', subscriptionDday);
      }

      // 실거래 내역 (최대 5건)
      if (trades != null) {
        for (int i = 0; i < 5; i++) {
          if (i < trades.length) {
            await HomeWidget.saveWidgetData('trade_name_$i', trades[i].name);
            await HomeWidget.saveWidgetData('trade_price_$i', trades[i].price);
            await HomeWidget.saveWidgetData('trade_date_$i', trades[i].date);
          } else {
            await HomeWidget.saveWidgetData('trade_name_$i', '');
            await HomeWidget.saveWidgetData('trade_price_$i', '');
            await HomeWidget.saveWidgetData('trade_date_$i', '');
          }
        }
      }

      // 네이티브 위젯 업데이트 트리거
      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
        qualifiedAndroidName: _qualifiedAndroidName,
        iOSName: _iosWidgetName,
      );
    } catch (e) {
      // 위젯 업데이트 실패 시 무시
    }
  }

  /// 앱 시작 시 위젯 데이터 초기화
  static Future<void> initialize() async {
    try {
      await HomeWidget.setAppGroupId('group.com.zipit.app');
    } catch (_) {}
  }

  /// 위젯 비활성화 시 데이터 클리어
  static Future<void> clearWidgetData() async {
    try {
      await HomeWidget.saveWidgetData('region_name', '');
      await HomeWidget.saveWidgetData('avg_price', '');
      for (int i = 0; i < 5; i++) {
        await HomeWidget.saveWidgetData('trade_name_$i', '');
        await HomeWidget.saveWidgetData('trade_price_$i', '');
        await HomeWidget.saveWidgetData('trade_date_$i', '');
      }
      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
        qualifiedAndroidName: _qualifiedAndroidName,
        iOSName: _iosWidgetName,
      );
    } catch (_) {}
  }
}

/// 위젯용 실거래 항목
class WidgetTradeItem {
  final String name;
  final String price;
  final String date;
  final String regionCode;

  const WidgetTradeItem({
    required this.name,
    required this.price,
    required this.date,
    this.regionCode = '',
  });
}
