import 'package:dio/dio.dart';
import 'package:xml/xml.dart';
import '../constants/api_keys.dart';
import '../../models/apartment_trade.dart';
import '../../models/apartment_rent.dart';
import 'api_client.dart';

class RealEstateApi {
  // 싱글턴
  static final RealEstateApi _instance = RealEstateApi._internal();
  factory RealEstateApi() => _instance;
  RealEstateApi._internal();

  final Dio _dio = ApiClient.dataGoKr;

  /// 아파트 매매 실거래가 조회 (스로틀링 + 에러 안전)
  Future<List<ApartmentTrade>> getAptTrades({
    required String regionCode,
    required String dealYmd,
  }) async {
    return apiThrottler.run(() async {
      try {
        final response = await _dio.get(
          '${ApiKeys.aptTradeEndpoint}/getRTMSDataSvcAptTrade',
          queryParameters: {
            'LAWD_CD': regionCode,
            'DEAL_YMD': dealYmd,
            'numOfRows': '1000',
            'pageNo': '1',
          },
        );
        return _parseTradeXml(response.data);
      } catch (e) {
        return <ApartmentTrade>[];
      }
    });
  }

  /// 아파트 매매 실거래가 상세 조회
  Future<List<ApartmentTrade>> getAptTradeDetails({
    required String regionCode,
    required String dealYmd,
  }) async {
    return apiThrottler.run(() async {
      try {
        final response = await _dio.get(
          '${ApiKeys.aptTradeDetailEndpoint}/getRTMSDataSvcAptTradeDev',
          queryParameters: {
            'LAWD_CD': regionCode,
            'DEAL_YMD': dealYmd,
            'numOfRows': '1000',
            'pageNo': '1',
          },
        );
        return _parseTradeXml(response.data);
      } catch (e) {
        return <ApartmentTrade>[];
      }
    });
  }

  /// 아파트 전월세 실거래가 조회
  Future<List<ApartmentRent>> getAptRents({
    required String regionCode,
    required String dealYmd,
  }) async {
    return apiThrottler.run(() async {
      try {
        final response = await _dio.get(
          '${ApiKeys.aptRentEndpoint}/getRTMSDataSvcAptRent',
          queryParameters: {
            'LAWD_CD': regionCode,
            'DEAL_YMD': dealYmd,
            'numOfRows': '1000',
            'pageNo': '1',
          },
        );
        return _parseRentXml(response.data);
      } catch (e) {
        return <ApartmentRent>[];
      }
    });
  }

  List<ApartmentTrade> _parseTradeXml(dynamic data) {
    try {
      final doc = XmlDocument.parse(data is String ? data : data.toString());
      final items = doc.findAllElements('item');
      return items.map((item) {
        final map = <String, dynamic>{};
        for (final child in item.children.whereType<XmlElement>()) {
          map[child.name.local] = child.innerText;
        }
        return ApartmentTrade.fromXml(map);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  List<ApartmentRent> _parseRentXml(dynamic data) {
    try {
      final doc = XmlDocument.parse(data is String ? data : data.toString());
      final items = doc.findAllElements('item');
      return items.map((item) {
        final map = <String, dynamic>{};
        for (final child in item.children.whereType<XmlElement>()) {
          map[child.name.local] = child.innerText;
        }
        return ApartmentRent.fromXml(map);
      }).toList();
    } catch (e) {
      return [];
    }
  }
}
