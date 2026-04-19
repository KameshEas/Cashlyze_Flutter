import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/realtime_db_service.dart';
import '../models/app_version.dart';

class AppVersionRepository {
  final RealtimeDbService _db;
  
  // Simple cache with TTL
  Map<String, CachedVersion>? _cache;
  static const Duration _cacheTTL = Duration(minutes: 5);

  AppVersionRepository(this._db);

  /// Get version config for a platform (android or ios)
  /// Returns null if data not found or on error
  Future<AppVersionModel?> getVersionByPlatform(String platform) async {
    try {
      debugPrint('DEBUG Repository: Getting version for platform: $platform');
      
      // Check cache first
      if (_isCacheValid()) {
        final cached = _cache!['app_versions/$platform'];
        if (cached != null && cached.isValid()) {
          debugPrint('DEBUG Repository: Returning cached version: ${cached.version}');
          return cached.version;
        }
      }

      // Fetch from RTDB
      final snapshot = await _db.get('app_versions/$platform');
      debugPrint('DEBUG Repository: RTDB snapshot exists: ${snapshot.exists}, value: ${snapshot.value}');
      
      if (snapshot.exists && snapshot.value != null) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        debugPrint('DEBUG Repository: Parsed data: $data');
        final model = AppVersionModel.fromRTDB(data);
        debugPrint('DEBUG Repository: Created model: $model');
        
        // Cache the result
        _cache ??= {};
        _cache!['app_versions/$platform'] = CachedVersion(model, DateTime.now());
        
        return model;
      }
      
      // Fallback: Return test data in debug mode if Firebase data not found
      if (!kReleaseMode) {
        debugPrint('DEBUG Repository: No Firebase data found, returning test data for platform: $platform');
        final testModel = AppVersionModel(
          minimumVersion: '1.0.3',
          currentVersion: '1.0.5',
          releaseNotes: 'Test update required. Please update the app to the latest version.',
          rolloutPercentage: 100,
          storeUrl: 'https://play.google.com/store/apps/details?id=com.aspiredesignovation.cashlyze',
        );
        debugPrint('DEBUG Repository: Returning test model: $testModel');
        return testModel;
      }
      
      debugPrint('DEBUG Repository: No version data found for platform: $platform');
      return null;
    } catch (e) {
      // On error, return null (fail-safe)
      debugPrint('DEBUG Repository: Error fetching version: $e');
      return null;
    }
  }

  /// Get all version configs
  Future<Map<String, AppVersionModel?>> getAllVersions() async {
    try {
      final snapshot = await _db.get('app_versions');
      
      if (!snapshot.exists || snapshot.value == null) {
        return {};
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final result = <String, AppVersionModel?>{};

      data.forEach((platform, versionData) {
        try {
          if (versionData is Map) {
            final model = AppVersionModel.fromRTDB(
              Map<String, dynamic>.from(versionData as Map),
            );
            result[platform] = model;
          }
        } catch (e) {
          // Skip invalid entries
        }
      });

      return result;
    } catch (e) {
      return {};
    }
  }

  /// Check if cache is still valid
  bool _isCacheValid() {
    if (_cache == null) return false;
    
    for (final entry in _cache!.values) {
      if (!entry.isValid()) {
        _cache = null;
        return false;
      }
    }
    
    return true;
  }

  /// Clear cache manually
  void clearCache() {
    _cache = null;
  }
}

/// Helper class for caching version data with TTL
class CachedVersion {
  final AppVersionModel version;
  final DateTime cachedAt;

  CachedVersion(this.version, this.cachedAt);

  bool isValid() {
    final age = DateTime.now().difference(cachedAt);
    return age < AppVersionRepository._cacheTTL;
  }
}

final appVersionRepositoryProvider = Provider<AppVersionRepository>((ref) {
  return AppVersionRepository(ref.watch(realtimeDbServiceProvider));
});
