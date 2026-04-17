import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/services/widget_service.dart';
import 'core/constants/app_constants.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // edge-to-edge 디스플레이: 상태표시줄/네비게이션바가 앱 위에 자연스럽게 오버레이
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
  ));

  await Supabase.initialize(
    url: 'https://cfxrkulgnycrsnczatvm.supabase.co',
    anonKey: 'sb_publishable_55Kt0wSia4ATUlasrXgWdw_bqv5JsI9',
  );

  // 위젯 서비스 초기화
  await WidgetService.initialize();

  // 알림 서비스 초기화
  await NotificationService.initialize();

  final onboardingDone = await AppRouter.checkOnboardingCompleted();
  runApp(ProviderScope(child: ZipitApp(onboardingCompleted: onboardingDone)));
}

class ZipitApp extends StatefulWidget {
  final bool onboardingCompleted;
  const ZipitApp({super.key, required this.onboardingCompleted});

  @override
  State<ZipitApp> createState() => _ZipitAppState();
}

class _ZipitAppState extends State<ZipitApp> {
  static const _navChannel = MethodChannel('com.zipit.app/navigation');
  static const _lockChannel = MethodChannel('com.zipit.app/lockscreen');
  late final _router = AppRouter.router(widget.onboardingCompleted);

  @override
  void initState() {
    super.initState();
    _setupDeepLinkListener();
    _checkPendingRoute();
  }

  void _setupDeepLinkListener() {
    _navChannel.setMethodCallHandler((call) async {
      if (call.method == 'navigate') {
        final route = call.arguments as String?;
        if (route != null) {
          _handleLockScreenRoute(route);
        }
      }
    });
  }

  Future<void> _checkPendingRoute() async {
    try {
      final route = await _lockChannel.invokeMethod<String>('getPendingRoute');
      if (route != null) {
        // 약간의 딜레이로 라우터 초기화 대기
        await Future.delayed(const Duration(milliseconds: AppConstants.refreshDelayMs));
        _handleLockScreenRoute(route);
      }
    } catch (e) {
      dev.log('pending route 확인 실패: $e', name: 'main');
    }
  }

  void _handleLockScreenRoute(String route) {
    if (route.startsWith('detail:')) {
      // detail:interest:regionCode:aptName → 시세 상세화면으로 직접 이동
      final parts = route.split(':');
      if (parts.length >= 4) {
        final regionCode = parts[2];
        var aptName = parts.sublist(3).join(':');
        final parenIdx = aptName.indexOf(' (');
        if (parenIdx > 0) aptName = aptName.substring(0, parenIdx);
        _router.go('/market-price/detail/-1?aptName=${Uri.encodeComponent(aptName)}&regionCode=$regionCode');
      } else if (parts.length >= 3) {
        // 하위 호환: regionCode 없는 기존 형식
        var aptName = parts.sublist(2).join(':');
        final parenIdx = aptName.indexOf(' (');
        if (parenIdx > 0) aptName = aptName.substring(0, parenIdx);
        _router.go('/market-price/detail/-1?aptName=${Uri.encodeComponent(aptName)}');
      }
    } else if (route.startsWith('market:')) {
      _router.go('/market-price');
    } else if (route == 'subscription') {
      _router.go('/subscription');
    } else {
      _router.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(
          MediaQuery.of(context).textScaler.scale(1.0).clamp(0.8, 1.1),
        ),
      ),
      child: MaterialApp.router(
        title: '집잇',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: _router,
      ),
    );
  }
}
