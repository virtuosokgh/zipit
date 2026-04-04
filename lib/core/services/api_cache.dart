import '../../models/apartment_trade.dart';
import '../../models/apartment_rent.dart';

/// TTL 기반 API 응답 캐시
/// - 30분 후 자동 만료
/// - 최대 200개 항목 제한 (LRU 방식)
class ApiCache {
  // 싱글턴
  static final ApiCache _instance = ApiCache._internal();
  factory ApiCache() => _instance;
  ApiCache._internal();

  static const Duration _ttl = Duration(minutes: 30);
  static const int _maxEntries = 200;

  final _tradeCache = <String, _CacheEntry<List<ApartmentTrade>>>{};
  final _rentCache = <String, _CacheEntry<List<ApartmentRent>>>{};

  /// 매매 거래 캐시 키: '{regionCode}_{yearMonth}'
  String tradeKey(String regionCode, String ym) => '${regionCode}_$ym';

  /// 전월세 캐시 키
  String rentKey(String regionCode, String ym) => '${regionCode}_${ym}_rent';

  // ─── 매매 ───

  List<ApartmentTrade>? getTrades(String key) {
    final entry = _tradeCache[key];
    if (entry == null) return null;
    if (entry.isExpired) {
      _tradeCache.remove(key);
      return null;
    }
    entry.lastAccess = DateTime.now();
    return entry.data;
  }

  void putTrades(String key, List<ApartmentTrade> data) {
    _evictIfNeeded(_tradeCache);
    _tradeCache[key] = _CacheEntry(data);
  }

  bool hasTrades(String key) {
    final entry = _tradeCache[key];
    if (entry == null) return false;
    if (entry.isExpired) {
      _tradeCache.remove(key);
      return false;
    }
    return true;
  }

  // ─── 전월세 ───

  List<ApartmentRent>? getRents(String key) {
    final entry = _rentCache[key];
    if (entry == null) return null;
    if (entry.isExpired) {
      _rentCache.remove(key);
      return null;
    }
    entry.lastAccess = DateTime.now();
    return entry.data;
  }

  void putRents(String key, List<ApartmentRent> data) {
    _evictIfNeeded(_rentCache);
    _rentCache[key] = _CacheEntry(data);
  }

  bool hasRents(String key) {
    final entry = _rentCache[key];
    if (entry == null) return false;
    if (entry.isExpired) {
      _rentCache.remove(key);
      return false;
    }
    return true;
  }

  // ─── 관리 ───

  /// 전체 캐시 클리어 (pull-to-refresh 시)
  void clearAll() {
    _tradeCache.clear();
    _rentCache.clear();
  }

  /// 만료된 항목만 제거
  void evictExpired() {
    _tradeCache.removeWhere((_, v) => v.isExpired);
    _rentCache.removeWhere((_, v) => v.isExpired);
  }

  /// LRU 방식으로 가장 오래 접근된 항목 제거
  /// 만료된 항목 먼저 제거, 그래도 부족하면 오래된 20% 제거
  void _evictIfNeeded<T>(Map<String, _CacheEntry<T>> cache) {
    if (cache.length < _maxEntries) return;

    // 먼저 만료된 항목 제거 (정렬 없이 빠름)
    cache.removeWhere((_, v) => v.isExpired);
    if (cache.length < _maxEntries) return;

    // 그래도 부족하면 가장 오래된 접근 시간순으로 20% 제거
    final entries = cache.entries.toList()
      ..sort((a, b) => a.value.lastAccess.compareTo(b.value.lastAccess));
    final removeCount = (cache.length * 0.2).ceil();
    for (var i = 0; i < removeCount && i < entries.length; i++) {
      cache.remove(entries[i].key);
    }
  }
}

class _CacheEntry<T> {
  final T data;
  final DateTime createdAt;
  DateTime lastAccess;

  _CacheEntry(this.data)
      : createdAt = DateTime.now(),
        lastAccess = DateTime.now();

  bool get isExpired =>
      DateTime.now().difference(createdAt) > ApiCache._ttl;
}
