import 'dart:convert';

class UserProfile {
  final String email;
  final String nickname;

  // 청약 정보 (Optional)
  final int? noHouseYears;    // 무주택 기간
  final int? dependents;      // 부양가족 수
  final int? accountYears;    // 청약통장 가입 기간
  final int? depositCount;    // 납입 횟수
  final bool? isHouseHolder;  // 세대주 여부
  final bool? isMarried;      // 혼인 여부

  const UserProfile({
    required this.email,
    required this.nickname,
    this.noHouseYears,
    this.dependents,
    this.accountYears,
    this.depositCount,
    this.isHouseHolder,
    this.isMarried,
  });

  UserProfile copyWith({
    String? email,
    String? nickname,
    int? noHouseYears,
    int? dependents,
    int? accountYears,
    int? depositCount,
    bool? isHouseHolder,
    bool? isMarried,
  }) {
    return UserProfile(
      email: email ?? this.email,
      nickname: nickname ?? this.nickname,
      noHouseYears: noHouseYears ?? this.noHouseYears,
      dependents: dependents ?? this.dependents,
      accountYears: accountYears ?? this.accountYears,
      depositCount: depositCount ?? this.depositCount,
      isHouseHolder: isHouseHolder ?? this.isHouseHolder,
      isMarried: isMarried ?? this.isMarried,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'nickname': nickname,
      'noHouseYears': noHouseYears,
      'dependents': dependents,
      'accountYears': accountYears,
      'depositCount': depositCount,
      'isHouseHolder': isHouseHolder,
      'isMarried': isMarried,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      email: json['email'] as String,
      nickname: json['nickname'] as String,
      noHouseYears: json['noHouseYears'] as int?,
      dependents: json['dependents'] as int?,
      accountYears: json['accountYears'] as int?,
      depositCount: json['depositCount'] as int?,
      isHouseHolder: json['isHouseHolder'] as bool?,
      isMarried: json['isMarried'] as bool?,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory UserProfile.fromJsonString(String jsonString) {
    return UserProfile.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }
}
