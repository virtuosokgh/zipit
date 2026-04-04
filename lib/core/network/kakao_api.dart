import 'package:dio/dio.dart';
import '../../models/address_result.dart';
import 'api_client.dart';

class KakaoApi {
  final Dio _dio = ApiClient.kakao;

  /// 주소 검색 (키워드 + 주소 동시 검색)
  Future<List<AddressResult>> searchAddress(String query) async {
    if (query.trim().isEmpty) return [];

    // 키워드 검색 (아파트 이름, 동 이름 등)
    final keywordFuture = _dio.get(
      '/v2/local/search/keyword.json',
      queryParameters: {
        'query': '$query 아파트',
        'size': 10,
      },
    );

    // 주소 검색 (b_code 포함)
    final addressFuture = _dio.get(
      '/v2/local/search/address.json',
      queryParameters: {'query': query, 'size': 5},
    );

    final responses = await Future.wait([
      keywordFuture.catchError((_) => Response(requestOptions: RequestOptions(), data: {'documents': []})),
      addressFuture.catchError((_) => Response(requestOptions: RequestOptions(), data: {'documents': []})),
    ]);

    final keywordDocs = (responses[0].data['documents'] as List?) ?? [];
    final addressDocs = (responses[1].data['documents'] as List?) ?? [];

    final results = <AddressResult>[];

    // 키워드 결과 (b_code 없음 → 좌표로 지역코드 조회 필요)
    for (final doc in keywordDocs) {
      results.add(AddressResult.fromKeywordJson(doc));
    }

    // 주소 결과 (b_code 있음)
    for (final doc in addressDocs) {
      results.add(AddressResult.fromAddressJson(doc));
    }

    return results;
  }

  /// 좌표 → 법정동 코드 조회
  Future<String> getRegionCode(double lat, double lng) async {
    final response = await _dio.get(
      '/v2/local/geo/coord2regioncode.json',
      queryParameters: {'x': lng, 'y': lat},
    );
    final documents = response.data['documents'] as List? ?? [];
    // 법정동(B) 타입 우선
    for (final doc in documents) {
      if (doc['region_type'] == 'B') {
        final code = doc['code']?.toString() ?? '';
        return code.length >= 5 ? code.substring(0, 5) : code;
      }
    }
    if (documents.isNotEmpty) {
      final code = documents[0]['code']?.toString() ?? '';
      return code.length >= 5 ? code.substring(0, 5) : code;
    }
    return '';
  }
}
