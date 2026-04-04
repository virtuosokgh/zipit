/// 카카오 주소 검색 결과
class AddressResult {
  final String addressName;     // 전체 주소
  final String regionCode;      // 법정동 코드 (5자리)
  final String dong;            // 동 이름
  final String? buildingName;   // 건물명
  final double latitude;
  final double longitude;
  final bool needsRegionCode;   // 좌표로 지역코드 조회 필요 여부

  AddressResult({
    required this.addressName,
    required this.regionCode,
    required this.dong,
    this.buildingName,
    required this.latitude,
    required this.longitude,
    this.needsRegionCode = false,
  });

  /// 키워드 검색 결과 파싱 (b_code 없음)
  factory AddressResult.fromKeywordJson(Map<String, dynamic> json) {
    return AddressResult(
      addressName: json['address_name'] ?? '',
      regionCode: '',
      dong: '',
      buildingName: json['place_name'],
      latitude: double.tryParse(json['y']?.toString() ?? '') ?? 0,
      longitude: double.tryParse(json['x']?.toString() ?? '') ?? 0,
      needsRegionCode: true,
    );
  }

  /// 주소 검색 결과 파싱 (b_code 있음)
  factory AddressResult.fromAddressJson(Map<String, dynamic> json) {
    final address = json['address'] ?? json['road_address'] ?? {};
    final bCode = (address['b_code'] ?? '').toString();
    final regionCode = bCode.length >= 5 ? bCode.substring(0, 5) : bCode;

    return AddressResult(
      addressName: json['address_name'] ?? '',
      regionCode: regionCode,
      dong: address['region_3depth_name'] ?? '',
      buildingName: null,
      latitude: double.tryParse(json['y']?.toString() ?? '') ?? 0,
      longitude: double.tryParse(json['x']?.toString() ?? '') ?? 0,
      needsRegionCode: regionCode.isEmpty,
    );
  }

  /// regionCode가 채워진 복사본 반환
  AddressResult withRegionCode(String code) {
    return AddressResult(
      addressName: addressName,
      regionCode: code,
      dong: dong,
      buildingName: buildingName,
      latitude: latitude,
      longitude: longitude,
      needsRegionCode: false,
    );
  }
}
