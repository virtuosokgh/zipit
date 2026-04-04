/// 수도권 지역 코드 매핑 (서울/인천/경기)
class RegionCodes {
  RegionCodes._();

  // ─── 서울 ───
  static const Map<String, String> seoulGu = {
    '강남구': '11680', '강동구': '11740', '강북구': '11305',
    '강서구': '11500', '관악구': '11620', '광진구': '11215',
    '구로구': '11530', '금천구': '11545', '노원구': '11350',
    '도봉구': '11320', '동대문구': '11230', '동작구': '11590',
    '마포구': '11440', '서대문구': '11410', '서초구': '11650',
    '성동구': '11200', '성북구': '11290', '송파구': '11710',
    '양천구': '11470', '영등포구': '11560', '용산구': '11170',
    '은평구': '11380', '종로구': '11110', '중구': '11140',
    '중랑구': '11260',
  };

  static const List<String> seoulAll = [
    '11110', '11140', '11170', '11200', '11215', '11230', '11260',
    '11290', '11305', '11320', '11350', '11380', '11410', '11440',
    '11470', '11500', '11530', '11545', '11560', '11590', '11620',
    '11650', '11680', '11710', '11740',
  ];

  // ─── 인천 ───
  static const Map<String, String> incheonGu = {
    '중구': '28110', '동구': '28140', '미추홀구': '28177',
    '연수구': '28185', '남동구': '28200', '부평구': '28237',
    '계양구': '28245', '서구': '28260', '강화군': '28710',
    '옹진군': '28720',
  };

  static const List<String> incheonAll = [
    '28110', '28140', '28177', '28185', '28200',
    '28237', '28245', '28260', '28710', '28720',
  ];

  // ─── 경기도 ───
  static const Map<String, String> gyeonggiSi = {
    '수원시 장안구': '41111', '수원시 권선구': '41113',
    '수원시 팔달구': '41115', '수원시 영통구': '41117',
    '성남시 수정구': '41131', '성남시 중원구': '41133',
    '성남시 분당구': '41135',
    '의정부시': '41150',
    '안양시 만안구': '41171', '안양시 동안구': '41173',
    '부천시': '41190', '광명시': '41210', '평택시': '41220',
    '동두천시': '41250',
    '안산시 상록구': '41271', '안산시 단원구': '41273',
    '고양시 덕양구': '41281', '고양시 일산동구': '41285',
    '고양시 일산서구': '41287',
    '과천시': '41290', '구리시': '41310', '남양주시': '41360',
    '오산시': '41370', '시흥시': '41390', '군포시': '41410',
    '의왕시': '41430', '하남시': '41450',
    '용인시 처인구': '41461', '용인시 기흥구': '41463',
    '용인시 수지구': '41465',
    '파주시': '41480', '이천시': '41500', '안성시': '41550',
    '김포시': '41570', '화성시': '41590', '광주시': '41610',
    '양주시': '41630', '포천시': '41650', '여주시': '41670',
  };

  static const List<String> gyeonggiAll = [
    '41111', '41113', '41115', '41117',
    '41131', '41133', '41135', '41150',
    '41171', '41173', '41190', '41210', '41220', '41250',
    '41271', '41273', '41281', '41285', '41287',
    '41290', '41310', '41360', '41370', '41390',
    '41410', '41430', '41450',
    '41461', '41463', '41465',
    '41480', '41500', '41550', '41570', '41590',
    '41610', '41630', '41650', '41670',
  ];

  /// 법정동코드 → 구/시 이름 (전체)
  static const Map<String, String> codeToName = {
    // 서울
    '11110': '종로구', '11140': '중구', '11170': '용산구',
    '11200': '성동구', '11215': '광진구', '11230': '동대문구',
    '11260': '중랑구', '11290': '성북구', '11305': '강북구',
    '11320': '도봉구', '11350': '노원구', '11380': '은평구',
    '11410': '서대문구', '11440': '마포구', '11470': '양천구',
    '11500': '강서구', '11530': '구로구', '11545': '금천구',
    '11560': '영등포구', '11590': '동작구', '11620': '관악구',
    '11650': '서초구', '11680': '강남구', '11710': '송파구',
    '11740': '강동구',
    // 인천
    '28110': '중구', '28140': '동구', '28177': '미추홀구',
    '28185': '연수구', '28200': '남동구', '28237': '부평구',
    '28245': '계양구', '28260': '서구', '28710': '강화군',
    '28720': '옹진군',
    // 경기도
    '41111': '수원시 장안구', '41113': '수원시 권선구',
    '41115': '수원시 팔달구', '41117': '수원시 영통구',
    '41131': '성남시 수정구', '41133': '성남시 중원구',
    '41135': '성남시 분당구', '41150': '의정부시',
    '41171': '안양시 만안구', '41173': '안양시 동안구',
    '41190': '부천시', '41210': '광명시', '41220': '평택시',
    '41250': '동두천시',
    '41271': '안산시 상록구', '41273': '안산시 단원구',
    '41281': '고양시 덕양구', '41285': '고양시 일산동구',
    '41287': '고양시 일산서구',
    '41290': '과천시', '41310': '구리시', '41360': '남양주시',
    '41370': '오산시', '41390': '시흥시', '41410': '군포시',
    '41430': '의왕시', '41450': '하남시',
    '41461': '용인시 처인구', '41463': '용인시 기흥구',
    '41465': '용인시 수지구',
    '41480': '파주시', '41500': '이천시', '41550': '안성시',
    '41570': '김포시', '41590': '화성시', '41610': '광주시',
    '41630': '양주시', '41650': '포천시', '41670': '여주시',
  };

  /// 법정동코드 → 시/도 이름
  static String getCity(String code) {
    if (code.startsWith('11')) return '서울';
    if (code.startsWith('28')) return '인천';
    if (code.startsWith('41')) return '경기';
    return '';
  }

  /// 법정동코드 → "서울 강남구" 형태 풀네임
  static String getFullName(String code) {
    final city = getCity(code);
    final name = codeToName[code] ?? '';
    if (city.isEmpty || name.isEmpty) return '';
    return '$city $name';
  }

  /// 구 이름으로 코드 반환 (서울 우선, 인천, 경기 순)
  static String getCodeForGu(String guName) {
    return seoulGu[guName] ?? incheonGu[guName] ?? gyeonggiSi[guName] ?? '';
  }

  /// 지역 이름 → 코드 리스트
  /// "서울 전체" → 서울 전체 코드, "강남구" → 단일 코드
  static List<String> getCodesForRegion(String region) {
    if (region == '서울 전체') return seoulAll;
    if (region == '인천 전체') return incheonAll;
    if (region == '경기 전체') return gyeonggiAll;

    final code = seoulGu[region] ?? incheonGu[region] ?? gyeonggiSi[region];
    if (code != null) return [code];
    return [];
  }

  /// 여러 지역 이름 → 통합 코드 리스트
  static List<String> getCodesForRegions(List<String> regions) {
    final codes = <String>{};
    for (final r in regions) {
      codes.addAll(getCodesForRegion(r));
    }
    return codes.toList();
  }

  /// 지역 표시 라벨
  static String regionsLabel(List<String> regions) {
    if (regions.isEmpty) return '미설정';
    if (regions.length <= 2) return regions.join(', ');
    return '${regions.first} 외 ${regions.length - 1}곳';
  }

  /// 청약 지역 매칭 키 목록 (subscrptAreaCodeNm 매칭용)
  static Set<String> getSubscriptionMatchKeys(List<String> regions) {
    final keys = <String>{};
    for (final r in regions) {
      if (r.contains('서울') || seoulGu.containsKey(r)) {
        keys.add('서울');
      } else if (r.contains('인천') || incheonGu.containsKey(r)) {
        keys.add('인천');
      } else if (r.contains('경기') || gyeonggiSi.containsKey(r)) {
        keys.add('경기');
      } else if (r.length >= 2) {
        keys.add(r.substring(0, 2));
      }
    }
    return keys;
  }

  // ─── 카테고리별 이름 목록 ───
  static List<String> get seoulGuNames => seoulGu.keys.toList();
  static List<String> get incheonGuNames => incheonGu.keys.toList();
  static List<String> get gyeonggiSiNames => gyeonggiSi.keys.toList();

  /// 전체 구/시 이름 목록
  static List<String> get guNames => [
    ...seoulGuNames,
    ...incheonGuNames,
    ...gyeonggiSiNames,
  ];
}
