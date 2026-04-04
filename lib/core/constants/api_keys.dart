/// API Keys - 배포 시 환경변수로 교체 필요
class ApiKeys {
  ApiKeys._();

  // Kakao
  static const String kakaoRestApiKey = '511ad9b00a88d260d3a91ecc5f2b7416';
  static const String kakaoNativeAppKey = '4449d37df4f4139e24d89356624596e0';

  // 공공데이터포털 - 국토교통부 실거래가 (인증키 동일)
  static const String dataGoKrKey = '0DLJ6yf5JtB+civbpv0WW3MqNT3agDfOu8qHWIE3cS3ti9yWLqpXfo8/sUmumDAfiIkFgkk7JB7tQYX7+x3AMw==';

  // 매매 실거래가
  static const String aptTradeEndpoint = 'https://apis.data.go.kr/1613000/RTMSDataSvcAptTrade';
  // 매매 실거래가 상세
  static const String aptTradeDetailEndpoint = 'https://apis.data.go.kr/1613000/RTMSDataSvcAptTradeDev';
  // 전월세 실거래가
  static const String aptRentEndpoint = 'https://apis.data.go.kr/1613000/RTMSDataSvcAptRent';

  // 한국부동산원 청약홈 분양정보
  static const String subscriptionEndpoint = 'https://apis.data.go.kr/1613000/SubscriptInfoService';
}
