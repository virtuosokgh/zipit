import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/widget_service.dart';
import '../models/widget_config.dart';

/// 위젯 설정 프로바이더
final widgetConfigProvider =
    StateNotifierProvider<WidgetConfigNotifier, WidgetConfig>((ref) {
  return WidgetConfigNotifier();
});

class WidgetConfigNotifier extends StateNotifier<WidgetConfig> {
  WidgetConfigNotifier() : super(const WidgetConfig()) {
    _load();
  }

  Future<void> _load() async {
    state = await WidgetService.loadConfig();
  }

  Future<void> toggleItem(WidgetItem item) async {
    final items = List<WidgetItem>.from(state.enabledItems);
    if (items.contains(item)) {
      items.remove(item);
    } else {
      items.add(item);
    }
    state = state.copyWith(enabledItems: items);
    await WidgetService.saveConfig(state);
  }

  Future<void> setStyle(WidgetStyle style) async {
    state = state.copyWith(style: style);
    await WidgetService.saveConfig(state);
  }
}
