import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/region_codes.dart';
import '../core/services/notification_service.dart';
import '../core/services/widget_service.dart';
import '../core/utils/price_formatter.dart';
import '../features/market_price/providers/listing_provider.dart';
import '../features/my_contract/providers/contract_provider.dart';
import '../features/subscription/providers/subscription_provider.dart';
import '../providers/user_preferences_provider.dart';

/// 위젯 데이터 자동 업데이트 프로바이더
/// 위젯 전용 설정 사용 (설정 > 위젯 종류 및 조건)
/// 온보딩 시에는 위젯 전용 값이 비어있으므로 관심 설정을 fallback으로 사용
final widgetDataUpdaterProvider = Provider<void>((ref) {
  final prefs = ref.watch(userPreferencesProvider);
  if (!prefs.lockScreenWidgetEnabled) return;

  // 위젯 전용 설정 사용 (fallback: 온보딩 관심 설정)
  final interest = prefs.effectiveWidgetInterest;
  final widgetRegions = prefs.effectiveWidgetRegions;
  final widgetRegion = prefs.effectiveWidgetRegion;

  final regionName = widgetRegions.isNotEmpty
      ? RegionCodes.regionsLabel(widgetRegions)
      : '관심지역';

  String topLabel = regionName;
  String mainValue = '';
  List<WidgetTradeItem> tradeItems = [];
  bool isLoading = false;

  switch (interest) {
    case 'subscription':
      topLabel = '다가오는 청약';
      final subscriptionsAsync = ref.watch(subscriptionListProvider);

      if (subscriptionsAsync is AsyncLoading) {
        isLoading = true;
      } else if (subscriptionsAsync is AsyncError) {
        mainValue = '데이터를 불러올 수 없습니다';
      } else {
        subscriptionsAsync.whenData((list) {
          var upcoming = list.where((s) {
            final cat = s.filterCategory;
            return cat == '접수예정' || cat == '접수중';
          }).toList();

          if (widgetRegions.isNotEmpty) {
            final matchKeys = RegionCodes.getSubscriptionMatchKeys(widgetRegions);
            upcoming = upcoming.where((s) =>
              matchKeys.any((key) => s.subscrptAreaCodeNm.contains(key))
            ).toList();
          }

          if (upcoming.isNotEmpty) {
            upcoming.sort((a, b) {
              final aD = a.dDay;
              final bD = b.dDay;
              if (aD < 0 && bD < 0) return 0;
              if (aD < 0) return 1;
              if (bD < 0) return -1;
              return aD.compareTo(bD);
            });
            mainValue = upcoming.first.name;
            for (final s in upcoming.take(AppConstants.widgetItemLimit)) {
              final d = s.dDay;
              tradeItems.add(WidgetTradeItem(
                name: s.name,
                price: d >= 0 ? 'D-$d' : s.status,
                date: s.subscrptAreaCodeNm,
              ));
            }
          } else {
            mainValue = '예정된 청약 없음';
          }
        });
      }

    case 'jeonse':
      topLabel = '$regionName 최신 전세';
      final rentsAsync = ref.watch(regionLatestRentsProvider((region: widgetRegion, rentType: 'jeonse')));
      if (rentsAsync is AsyncLoading) {
        isLoading = true;
      } else if (rentsAsync is AsyncError) {
        mainValue = '데이터를 불러올 수 없습니다';
      } else {
        rentsAsync.whenData((rents) {
          if (rents.isNotEmpty) {
            final latest = rents.first;
            mainValue = '${latest.aptName} ${PriceFormatter.formatShort(latest.dealAmount)}';
            tradeItems = rents.map((r) => WidgetTradeItem(
              name: '${r.aptName}${r.dong.isNotEmpty ? " (${r.dong})" : ""}',
              price: PriceFormatter.formatShort(r.dealAmount),
              date: '${r.dealDate.month}/${r.dealDate.day}',
              regionCode: r.regionCode,
            )).toList();
          } else {
            mainValue = '최근 전세 내역 없음';
          }
        });
      }

    case 'monthly':
      topLabel = '$regionName 최신 월세';
      final rentsAsync = ref.watch(regionLatestRentsProvider((region: widgetRegion, rentType: 'monthly')));
      if (rentsAsync is AsyncLoading) {
        isLoading = true;
      } else if (rentsAsync is AsyncError) {
        mainValue = '데이터를 불러올 수 없습니다';
      } else {
        rentsAsync.whenData((rents) {
          if (rents.isNotEmpty) {
            final latest = rents.first;
            mainValue = '${latest.aptName} ${PriceFormatter.formatShort(latest.dealAmount)}/월';
            tradeItems = rents.map((r) => WidgetTradeItem(
              name: '${r.aptName}${r.dong.isNotEmpty ? " (${r.dong})" : ""}',
              price: '${PriceFormatter.formatShort(r.dealAmount)}/월',
              date: '${r.dealDate.month}/${r.dealDate.day}',
              regionCode: r.regionCode,
            )).toList();
          } else {
            mainValue = '최근 월세 내역 없음';
          }
        });
      }

    default:
      topLabel = '$regionName 최신 매매';
      final tradesAsync = ref.watch(regionLatestTradesProvider(widgetRegion));
      if (tradesAsync is AsyncLoading) {
        isLoading = true;
      } else if (tradesAsync is AsyncError) {
        mainValue = '데이터를 불러올 수 없습니다';
      } else {
        tradesAsync.whenData((trades) {
          if (trades.isNotEmpty) {
            final latest = trades.first;
            mainValue = '${latest.aptName} ${PriceFormatter.formatShort(latest.dealAmount)}';
            tradeItems = trades.map((t) => WidgetTradeItem(
              name: '${t.aptName}${t.dong.isNotEmpty ? " (${t.dong})" : ""}',
              price: PriceFormatter.formatShort(t.dealAmount),
              date: '${t.dealDate.month}/${t.dealDate.day}',
              regionCode: t.regionCode,
            )).toList();
          } else {
            mainValue = '최근 거래 내역 없음';
          }
        });
      }
  }

  // 계약 진행 중이면 메인에 표시
  if (!isLoading) {
    final contracts = ref.watch(contractsProvider);
    if (contracts.isNotEmpty && interest != 'subscription') {
      final contract = contracts.first;
      final dday = contract.nextDday;
      mainValue = '${contract.aptName} ${dday != null ? "D-$dday" : contract.status.label}';
    }
  }

  WidgetService.updateWidget(
    regionName: topLabel,
    avgPrice: isLoading ? '불러오는 중...' : mainValue,
    priceChange: '',
    trades: isLoading ? [] : tradeItems,
  );

  // 잠금화면 Activity 데이터 업데이트 (3건)
  if (!isLoading && prefs.lockScreenWidgetEnabled && tradeItems.isNotEmpty) {
    final items = tradeItems.take(3).toList();
    NotificationService.enableLockScreen(
      title: topLabel,
      interest: interest,
      names: items.map((t) => t.name).toList(),
      prices: items.map((t) => t.price).toList(),
      dates: items.map((t) => t.date).toList(),
      regionCodes: items.map((t) => t.regionCode).toList(),
    );
  }
});
