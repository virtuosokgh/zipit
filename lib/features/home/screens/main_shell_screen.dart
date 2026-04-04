import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/widget_data_updater.dart';

class MainShellScreen extends ConsumerWidget {
  final Widget child;
  const MainShellScreen({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    if (path.startsWith('/home')) return 0;
    if (path.startsWith('/market-price')) return 1;
    if (path.startsWith('/my-contract')) return 2;
    if (path.startsWith('/subscription')) return 3;
    if (path.startsWith('/settings')) return 4;
    return 0;
  }

  String _title(int index) => switch (index) {
    0 => '집잇',
    1 => '시세',
    2 => '내 계약',
    3 => '청약',
    4 => '설정',
    _ => '집잇',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = _currentIndex(context);
    final unreadCount = ref.watch(notificationHistoryProvider.notifier).unreadCount;

    // 위젯 데이터 자동 업데이트 (shell은 항상 마운트 → dispose 걱정 없음)
    ref.listen(widgetDataUpdaterProvider, (_, __) {});

    return Scaffold(
      appBar: AppBar(
        title: Text(_title(currentIndex)),
        actions: [
          // 가점 계산기 (청약 탭에서만 표시)
          if (currentIndex == 3)
            IconButton(
              icon: const Icon(Icons.calculate_outlined),
              onPressed: () => context.push('/subscription/calculator'),
              tooltip: '가점 계산기',
            ),
          // 알림 아이콘 (모든 탭에 표시)
          IconButton(
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text(
                unreadCount > 9 ? '9+' : '$unreadCount',
                style: const TextStyle(fontSize: 10, color: Colors.white),
              ),
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () => context.push('/notifications'),
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.borderLight)),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (i) {
            const paths = ['/home', '/market-price', '/my-contract', '/subscription', '/settings'];
            context.go(paths[i]);
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: '홈'),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), activeIcon: Icon(Icons.bar_chart), label: '시세'),
            BottomNavigationBarItem(icon: Icon(Icons.description_outlined), activeIcon: Icon(Icons.description), label: '내 계약'),
            BottomNavigationBarItem(icon: Icon(Icons.apartment_outlined), activeIcon: Icon(Icons.apartment), label: '청약'),
            BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), activeIcon: Icon(Icons.settings), label: '설정'),
          ],
        ),
      ),
    );
  }
}
