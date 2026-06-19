import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Service for caching API responses to enable offline functionality
class OfflineCacheService {

  OfflineCacheService(this._prefs);
  static const String _cachePrefix = 'offline_cache_';
  static const String _cacheTimestampSuffix = '_timestamp';
  static const Duration _defaultCacheDuration = Duration(hours: 24);

  final SharedPreferences _prefs;

  // ── Public Methods ────────────────────────────────────────────────────────────

  /// Cache a response with a key
  Future<void> cacheResponse(
    final String key,
    final dynamic data, {
    final Duration cacheDuration = _defaultCacheDuration,
  }) async {
    try {
      final cacheKey = _getCacheKey(key);
      final timestampKey = _getCacheTimestampKey(key);

      // Serialize data to JSON
      final jsonString = jsonEncode(data);

      // Store data and timestamp
      await Future.wait([
        _prefs.setString(cacheKey, jsonString),
        _prefs.setInt(timestampKey, DateTime.now().millisecondsSinceEpoch),
      ]);
    } catch (_) {
      // Silently fail on cache write
    }
  }

  /// Retrieve cached response
  Future<dynamic> getCachedResponse(
    final String key, {
    final Duration cacheDuration = _defaultCacheDuration,
  }) async {
    try {
      final cacheKey = _getCacheKey(key);
      final timestampKey = _getCacheTimestampKey(key);

      final cachedJson = _prefs.getString(cacheKey);
      final timestamp = _prefs.getInt(timestampKey);

      if (cachedJson == null || timestamp == null) {
        return null;
      }

      // Check if cache has expired
      final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (cacheAge > cacheDuration.inMilliseconds) {
        await clearCache(key);
        return null;
      }

      return jsonDecode(cachedJson);
    } catch (_) {
      // Silently fail on cache read
      return null;
    }
  }

  /// Check if a cached response exists and is valid
  Future<bool> hasCachedResponse(
    final String key, {
    final Duration cacheDuration = _defaultCacheDuration,
  }) async {
    try {
      final timestampKey = _getCacheTimestampKey(key);
      final timestamp = _prefs.getInt(timestampKey);

      if (timestamp == null) {
        return false;
      }

      final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
      return cacheAge <= cacheDuration.inMilliseconds;
    } catch (_) {
      return false;
    }
  }

  /// Clear cache for a specific key
  Future<void> clearCache(final String key) async {
    try {
      final cacheKey = _getCacheKey(key);
      final timestampKey = _getCacheTimestampKey(key);

      await Future.wait([
        _prefs.remove(cacheKey),
        _prefs.remove(timestampKey),
      ]);
    } catch (_) {
      // Silently fail on cache clear
    }
  }

  /// Clear all cached responses
  Future<void> clearAllCache() async {
    try {
      final keys = _prefs.getKeys();
      final cacheKeys = keys.where((final k) => k.startsWith(_cachePrefix)).toList();

      for (final key in cacheKeys) {
        await _prefs.remove(key);
      }
    } catch (_) {
      // Silently fail on bulk clear
    }
  }

  /// Get cache key with prefix
  String _getCacheKey(final String key) => '$_cachePrefix$key';

  /// Get cache timestamp key
  String _getCacheTimestampKey(final String key) =>
      '$_cachePrefix$key$_cacheTimestampSuffix';

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final keys = _prefs.getKeys();
      final cacheKeys = keys.where((final k) => k.startsWith(_cachePrefix)).toList();
      final dataKeys = cacheKeys
          .where((final k) => !k.endsWith(_cacheTimestampSuffix))
          .toList();

      int totalSize = 0;
      for (final key in dataKeys) {
        final data = _prefs.getString(key);
        if (data != null) {
          totalSize += data.length;
        }
      }

      return {
        'cached_keys': dataKeys.length,
        'total_size_bytes': totalSize,
        'cache_keys': dataKeys,
      };
    } catch (_) {
      return {'error': 'Failed to get cache stats'};
    }
  }
}
