import 'dart:developer' as dev;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';

final _supabase = Supabase.instance.client;

/// Supabase Auth 상태 감시
final authStateProvider = StreamProvider<Session?>((ref) {
  // 현재 세션으로 초기값 발행 후 변경 감시
  return _supabase.auth.onAuthStateChange.map((event) => event.session);
});

/// 현재 로그인된 유저
User? get currentUser => _supabase.auth.currentUser;

/// 사용자 프로필 관리 (Supabase DB 연동)
final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, UserProfile?>((ref) {
  return UserProfileNotifier(ref);
});

class UserProfileNotifier extends StateNotifier<UserProfile?> {
  final Ref _ref;

  UserProfileNotifier(this._ref) : super(null) {
    _loadProfile();
    // Auth 상태 변경 감시
    _ref.listen(authStateProvider, (prev, next) {
      final session = next.valueOrNull;
      if (session != null) {
        _loadProfile();
      } else {
        state = null;
      }
    });
  }

  Future<void> _loadProfile() async {
    final user = currentUser;
    if (user == null) return;

    try {
      final data = await _supabase
          .from('user_profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (data != null) {
        state = UserProfile(
          email: user.email ?? '',
          nickname: data['nickname'] ?? '',
          noHouseYears: data['no_house_years'] as int?,
          dependents: data['dependents'] as int?,
          accountYears: data['account_years'] as int?,
          depositCount: data['deposit_count'] as int?,
          isHouseHolder: data['is_house_holder'] as bool?,
          isMarried: data['is_married'] as bool?,
        );
      }
    } catch (e) {
      // 프로필이 없을 수 있음 (신규 가입 직후) 또는 네트워크 오류
      dev.log('프로필 로드 실패: $e', name: 'AuthProvider');
    }
  }

  Future<void> setProfile(UserProfile profile) async {
    final user = currentUser;
    if (user == null) return;

    state = profile;
    await _supabase.from('user_profiles').upsert({
      'id': user.id,
      'nickname': profile.nickname,
      'no_house_years': profile.noHouseYears,
      'dependents': profile.dependents,
      'account_years': profile.accountYears,
      'deposit_count': profile.depositCount,
      'is_house_holder': profile.isHouseHolder,
      'is_married': profile.isMarried,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateProfile({
    String? nickname,
    int? noHouseYears,
    int? dependents,
    int? accountYears,
    int? depositCount,
    bool? isHouseHolder,
    bool? isMarried,
  }) async {
    if (state == null) return;
    state = state!.copyWith(
      nickname: nickname,
      noHouseYears: noHouseYears,
      dependents: dependents,
      accountYears: accountYears,
      depositCount: depositCount,
      isHouseHolder: isHouseHolder,
      isMarried: isMarried,
    );
    await setProfile(state!);
  }

  Future<void> clearProfile() async {
    state = null;
  }
}

/// 로그인
Future<AuthResponse> login({
  required String email,
  required String password,
}) async {
  return await _supabase.auth.signInWithPassword(
    email: email,
    password: password,
  );
}

/// 회원가입
Future<AuthResponse> signup({
  required String email,
  required String password,
}) async {
  return await _supabase.auth.signUp(
    email: email,
    password: password,
  );
}

/// 로그아웃
Future<void> logout() async {
  await _supabase.auth.signOut();
}
