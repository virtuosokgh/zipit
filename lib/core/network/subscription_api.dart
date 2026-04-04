import 'package:dio/dio.dart';
import '../../features/subscription/providers/subscription_provider.dart';
import 'api_client.dart';

class SubscriptionApi {
  final Dio _dio = ApiClient.odcloud;

  /// 아파트 분양 공고 목록 조회 (odcloud JSON API)
  Future<List<SubscriptionInfo>> getSubscriptions() async {
    try {
      final response = await _dio.get(
        '/ApplyhomeInfoDetailSvc/v1/getAPTLttotPblancDetail',
        queryParameters: {
          'page': 1,
          'perPage': 100,
        },
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw Exception('잘못된 응답 형식');
      }

      final List<dynamic> items = data['data'] ?? [];
      return items
          .map((item) => SubscriptionInfo.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('청약 정보를 불러오지 못했습니다: $e');
    }
  }

  /// 평형별 정보 조회
  Future<List<SubscriptionUnitType>> getUnitTypes(String houseManageNo) async {
    try {
      final response = await _dio.get(
        '/ApplyhomeInfoDetailSvc/v1/getAPTLttotPblancMdl',
        queryParameters: {
          'cond[HOUSE_MANAGE_NO::EQ]': houseManageNo,
          'perPage': 20,
        },
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw Exception('잘못된 응답 형식');
      }

      final List<dynamic> items = data['data'] ?? [];
      return items
          .map((item) => SubscriptionUnitType.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('평형별 정보를 불러오지 못했습니다: $e');
    }
  }
}
