import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

/// 아파트명 + 위치로 도로명 주소 조회
/// key: "$aptName $location" → value: 도로명 주소 문자열
final aptAddressProvider = FutureProvider.family<String, String>((ref, query) async {
  try {
    final dio = ApiClient.kakao;
    final response = await dio.get(
      '/v2/local/search/keyword.json',
      queryParameters: {
        'query': query,
        'size': 1,
      },
    );
    final docs = (response.data['documents'] as List?) ?? [];
    if (docs.isEmpty) return '';

    final doc = docs.first;
    // 도로명 주소 우선, 없으면 지번 주소
    final roadAddress = doc['road_address_name']?.toString() ?? '';
    final address = doc['address_name']?.toString() ?? '';
    return roadAddress.isNotEmpty ? roadAddress : address;
  } catch (_) {
    return '';
  }
});
