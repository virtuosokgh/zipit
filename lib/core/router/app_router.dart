import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/onboarding/screens/onboarding_screen.dart';
import '../../features/home/screens/main_shell_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/market_price/screens/market_price_screen.dart';
import '../../features/my_contract/screens/my_contract_screen.dart';
import '../../features/my_contract/screens/contract_register_screen.dart';
import '../../features/my_contract/screens/contract_detail_screen.dart';
import '../../features/subscription/screens/subscription_screen.dart';
import '../../features/subscription/screens/subscription_detail_screen.dart';
import '../../features/subscription/screens/score_calculator_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/settings/screens/widget_items_screen.dart';
import '../../features/settings/screens/widget_style_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/market_price/screens/apartment_detail_screen.dart';
import '../../features/home/screens/notification_screen.dart';
import '../../models/apartment_listing.dart';

class AppRouter {
  AppRouter._();

  static final _rootKey = GlobalKey<NavigatorState>();
  static final _shellKey = GlobalKey<NavigatorState>();

  static GoRouter router(bool onboardingCompleted) => GoRouter(
    navigatorKey: _rootKey,
    initialLocation: onboardingCompleted ? '/home' : '/onboarding',
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellKey,
        builder: (context, state, child) => MainShellScreen(child: child),
        routes: [
          GoRoute(path: '/home', pageBuilder: (context, state) => const NoTransitionPage(child: HomeScreen())),
          GoRoute(path: '/market-price', pageBuilder: (context, state) => const NoTransitionPage(child: MarketPriceScreen())),
          GoRoute(path: '/my-contract', pageBuilder: (context, state) => const NoTransitionPage(child: MyContractScreen())),
          GoRoute(path: '/subscription', pageBuilder: (context, state) => const NoTransitionPage(child: SubscriptionScreen())),
          GoRoute(path: '/settings', pageBuilder: (context, state) => const NoTransitionPage(child: SettingsScreen())),
        ],
      ),
      // 계약 등록 (ShellRoute 밖 → 전체 화면)
      GoRoute(
        path: '/my-contract/register',
        builder: (context, state) => const ContractRegisterScreen(),
      ),
      // 계약 상세
      GoRoute(
        path: '/my-contract/:id',
        builder: (context, state) => ContractDetailScreen(contractId: state.pathParameters['id']!),
      ),
      // 청약 상세
      GoRoute(
        path: '/subscription/detail/:index',
        builder: (context, state) => SubscriptionDetailScreen(
          index: int.tryParse(state.pathParameters['index'] ?? '0') ?? 0,
        ),
      ),
      // 가점 계산기
      GoRoute(
        path: '/subscription/calculator',
        builder: (context, state) => const ScoreCalculatorScreen(),
      ),
      // 아파트 상세 (시세 TOP 10 + 검색)
      GoRoute(
        path: '/market-price/detail/:index',
        builder: (context, state) {
          final index = int.tryParse(state.pathParameters['index'] ?? '0') ?? 0;
          final listing = state.extra as ApartmentListing?;
          final aptName = state.uri.queryParameters['aptName'];
          final regionCode = state.uri.queryParameters['regionCode'];
          return ApartmentDetailScreen(index: index, listing: listing, aptName: aptName, regionCode: regionCode);
        },
      ),
      // 알림 내역
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationScreen(),
      ),
      // 위젯 표시 항목 설정
      GoRoute(
        path: '/settings/widget-items',
        builder: (context, state) => const WidgetItemsScreen(),
      ),
      // 위젯 스타일 변경
      GoRoute(
        path: '/settings/widget-style',
        builder: (context, state) => const WidgetStyleScreen(),
      ),
      // 로그인
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      // 회원가입
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
    ],
  );

  /// 온보딩 완료 여부 확인
  static Future<bool> checkOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('user_preferences');
    if (json == null) return false;
    final data = jsonDecode(json);
    return data['onboardingCompleted'] == true;
  }
}
