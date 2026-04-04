import 'dart:async';
import 'package:dio/dio.dart';
import '../constants/api_keys.dart';

class ApiClient {
  ApiClient._();

  /// 공공데이터포털 API 클라이언트 (싱글턴)
  static final Dio _dataGoKr = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 15),
    queryParameters: {'serviceKey': ApiKeys.dataGoKrKey},
  ));
  static Dio get dataGoKr => _dataGoKr;

  /// 공공데이터포털 odcloud API 클라이언트 (싱글턴)
  static final Dio _odcloud = Dio(BaseOptions(
    baseUrl: 'https://api.odcloud.kr/api',
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 15),
    queryParameters: {'serviceKey': ApiKeys.dataGoKrKey},
  ));
  static Dio get odcloud => _odcloud;

  /// 카카오 API 클라이언트 (싱글턴)
  static final Dio _kakao = Dio(BaseOptions(
    baseUrl: 'https://dapi.kakao.com',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Authorization': 'KakaoAK ${ApiKeys.kakaoRestApiKey}'},
  ));
  static Dio get kakao => _kakao;
}

/// API 호출 스로틀러: 동시 요청 수를 제한하여 rate limit 방지
class ApiThrottler {
  final int maxConcurrent;
  int _running = 0;
  final _queue = <Completer<void>>[];

  ApiThrottler({this.maxConcurrent = 5});

  Future<T> run<T>(Future<T> Function() task) async {
    if (_running >= maxConcurrent) {
      final completer = Completer<void>();
      _queue.add(completer);
      await completer.future;
    }
    _running++;
    try {
      return await task();
    } finally {
      _running--;
      if (_queue.isNotEmpty) {
        _queue.removeAt(0).complete();
      }
    }
  }
}

/// 전역 API 스로틀러 (동시 최대 5개 요청 — rate limit 방지)
final apiThrottler = ApiThrottler(maxConcurrent: 5);
