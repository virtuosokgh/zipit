/// 앱 전역 상수 (하드코딩 방지)
class AppConstants {
  AppConstants._();

  // ─── 면적 변환 ───
  /// ㎡ → 평 변환 계수
  static const double sqmToPyeong = 3.3058;

  /// 공급면적 추정 계수 (전용면적 × 이 값)
  static const double supplyAreaRatio = 1.3;

  // ─── API 조회 기간 ───
  /// 실거래 조회 기간 (월 수) - TOP 리스트용
  static const int tradeMonthsLong = 6;

  /// 실거래 조회 기간 (월 수) - 시세 리스트용 (빠른 응답)
  static const int tradeMonthsShort = 3;

  /// 실거래 조회 기간 (월 수) - 상세화면용 (충분한 이력)
  static const int tradeMonthsDetail = 12;

  /// 최근 거래 판단 기준 (일)
  static const int recentTradeDays = 90;

  // ─── 페이지네이션 ───
  /// 리스트 페이지 크기
  static const int pageSize = 10;

  /// 무한 스크롤 트리거 거리 (px)
  static const double scrollLoadThreshold = 200;

  // ─── AI 추정 알고리즘 ───
  /// 추세율 최대값 (±%)
  static const double trendRateCap = 15.0;

  /// 최소 거래 건수 (신뢰도) - 1건이라도 있으면 표시
  static const int minTradesForListing = 1;

  /// 면적 허용 오차 (㎡) - 같은 평형 판단 기준
  static const double areaTolerance = 5.0;

  // ─── 기본값 ───
  /// 기본 지역코드 (강남구) - 지역 미선택 시
  static const String defaultRegionCode = '11680';

  /// 기본 조회 지역 코드 (지역 미선택 시)
  static const List<String> defaultMarketRegionCodes = [
    '11650', // 서초구
    '11680', // 강남구
    '11710', // 송파구
    '11740', // 강동구
    '11170', // 용산구
  ];

  // ─── 날짜 범위 ───
  /// 계약 등록 최소 연도
  static const int contractDateMinYear = 2020;

  /// 계약 등록 최대 연도
  static const int contractDateMaxYear = 2035;

  // ─── 청약 자격 요건 ───
  /// 투기과열지구 통장 가입 기간 (월)
  static const int accountMonthsSpeculation = 24;

  /// 수도권 통장 가입 기간 (월)
  static const int accountMonthsMetro = 12;

  /// 기타 지역 통장 가입 기간 (월)
  static const int accountMonthsOther = 6;

  /// 수도권 납입 횟수
  static const int depositCountMetro = 24;

  /// 기타 지역 납입 횟수
  static const int depositCountOther = 12;

  // ─── 리스트 표시 한도 ───
  /// 홈 화면 계약 표시 수
  static const int homeContractLimit = 2;

  /// 홈 화면 청약 표시 수
  static const int homeSubscriptionLimit = 3;

  /// 홈 화면 최신 실거래 표시 수
  static const int homeLatestTradeLimit = 5;

  /// 위젯 표시 항목 수
  static const int widgetItemLimit = 5;

  /// 검색 최소 글자 수
  static const int searchMinLength = 2;

  // ─── Duration (ms) ───
  /// 페이지 전환 애니메이션
  static const int animPageMs = 300;

  /// 카드/타일 애니메이션
  static const int animCardMs = 200;

  /// 필터 바 애니메이션
  static const int animFilterMs = 250;

  /// 검색 디바운스
  static const int debounceMs = 400;

  /// Pull-to-refresh 딜레이
  static const int refreshDelayMs = 500;

  // ─── 금융 상수 ───
  /// 주택담보대출 연이자율 (4.5%)
  static const double mortgageInterestRate = 0.045;

  /// 이자율 표시 문자열
  static const String mortgageInterestLabel = '연 4.5%';

  // ─── 청약 점수 ───
  /// 청약 가점 만점
  static const int maxSubscriptionScore = 84;

  // ─── 예산 ───
  /// 예산 슬라이더 최소값 (만원)
  static const double budgetSliderMin = 0;

  /// 예산 슬라이더 최대값 (만원)
  static const double budgetSliderMax = 200000;

  /// 예산 슬라이더 분할 수
  static const int budgetSliderDivisions = 40;

  // ─── 차트 ───
  /// 차트 Y축 상한 배율
  static const double chartYAxisMaxMultiplier = 1.1;

  /// 차트 Y축 추정가 상한 배율
  static const double chartYAxisEstimateMultiplier = 1.05;

  // ─── 건축년도 추정 ───
  /// 최초 거래일 기준 건축년도 차감 (년)
  static const int buildYearEstimateOffset = 2;

  /// 거래 이력 기반 추정 최소 건수
  static const int buildYearEstimateMinTrades = 3;

  /// 기본 건물 연식 (년) - 거래 이력 부족 시
  static const int defaultBuildingAge = 20;

  // ─── 금융 비율 ───
  /// 전세보증보험 한도 비율 (시세 대비)
  static const double jeonseInsuranceLimitRatio = 0.8;

  /// 월세 보증금 환산 계수 (1000만원당 월 5만원)
  static const double monthlyRentConversionFactor = 200;

  /// 가격 시그널 임계값 (±5%)
  static const double priceSignalThreshold = 0.05;

  /// 대출 담보 비율 (시세 80%)
  static const double loanCollateralRatio = 0.8;

  /// 방 수당 대출 차감액 (만원)
  static const int loanRoomPenalty = 5000;

  // ─── 배치 처리 ───
  /// API 호출 배치 크기
  static const int apiBatchSize = 5;

  // ─── URL ───
  /// 개인정보 처리방침 URL
  static const String privacyPolicyUrl = 'https://virtuosokgh.github.io/zipit-privacy/';

  /// 이용약관 URL
  static const String termsUrl = 'https://virtuosokgh.github.io/zipit-privacy/terms.html';
}
