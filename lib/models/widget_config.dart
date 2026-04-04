/// 위젯에 표시할 항목
enum WidgetItem {
  regionPrice('관심지역 평균 시세', true),
  priceChange('시세 변동률', true),
  subscriptionDday('청약 D-day', true),
  aiRecommend('AI 추천 매물', false),
  gapAlert('갭차이 알림', false),
  winProbability('청약 당첨예측', false),
  jeonseRatio('전세가율', false),
  myScore('내 청약 가점', false);

  final String label;
  final bool defaultEnabled;
  const WidgetItem(this.label, this.defaultEnabled);
}

/// 위젯 스타일
enum WidgetStyle {
  compact('컴팩트', '시세 + D-day 1줄씩'),
  expanded('확장형', '시세 + 차트 + 청약 정보');

  final String label;
  final String description;
  const WidgetStyle(this.label, this.description);
}

/// 위젯 설정
class WidgetConfig {
  final List<WidgetItem> enabledItems;
  final WidgetStyle style;

  const WidgetConfig({
    this.enabledItems = const [
      WidgetItem.regionPrice,
      WidgetItem.priceChange,
      WidgetItem.subscriptionDday,
    ],
    this.style = WidgetStyle.compact,
  });

  WidgetConfig copyWith({
    List<WidgetItem>? enabledItems,
    WidgetStyle? style,
  }) {
    return WidgetConfig(
      enabledItems: enabledItems ?? this.enabledItems,
      style: style ?? this.style,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabledItems': enabledItems.map((e) => e.name).toList(),
    'style': style.name,
  };

  factory WidgetConfig.fromJson(Map<String, dynamic> json) {
    final items = (json['enabledItems'] as List<dynamic>?)
        ?.map((e) => WidgetItem.values.firstWhere(
              (v) => v.name == e,
              orElse: () => WidgetItem.regionPrice,
            ))
        .toList() ?? [WidgetItem.regionPrice, WidgetItem.priceChange, WidgetItem.subscriptionDday];

    final style = WidgetStyle.values.firstWhere(
      (v) => v.name == (json['style'] as String?),
      orElse: () => WidgetStyle.compact,
    );

    return WidgetConfig(enabledItems: items, style: style);
  }
}
