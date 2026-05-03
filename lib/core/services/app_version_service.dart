import 'dart:io';
import 'dart:math';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart';
import '../models/app_version.dart';
import 'analytics_service.dart';

class AppVersionService {
  final AnalyticsService _analyticsService;

  AppVersionService(this._analyticsService);

  /// Get the current app version from package info
  Future<String> getCurrentAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      // Fallback version
      return '0.0.0';
    }
  }

  /// Get platform name (android or ios)
  String getPlatformName() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  /// Compare semantic versions
  /// Returns true if current < minimum (update required)
  /// Example: isVersionOutdated('1.0.0', '1.0.1') -> true
  bool isVersionOutdated(String currentVersion, String minimumVersion) {
    try {
      final current = _parseVersion(currentVersion);
      final minimum = _parseVersion(minimumVersion);

      // Compare major
      if (current[0] != minimum[0]) {
        return current[0] < minimum[0];
      }
      // Compare minor
      if (current[1] != minimum[1]) {
        return current[1] < minimum[1];
      }
      // Compare patch
      return current[2] < minimum[2];
    } catch (e) {
      // If parsing fails, assume no update is needed
      return false;
    }
  }

  /// Parse semantic version string (e.g., "1.0.0") into list [major, minor, patch]
  List<int> _parseVersion(String version) {
    try {
      // Remove any '+' suffix (e.g., "1.0.0+6" -> "1.0.0")
      final cleanVersion = version.split('+').first;
      final parts = cleanVersion.split('.').map((p) => int.parse(p)).toList();

      // Ensure we have [major, minor, patch]
      while (parts.length < 3) {
        parts.add(0);
      }
      return parts.sublist(0, 3);
    } catch (e) {
      return [0, 0, 0];
    }
  }

  /// Check if current user is eligible for rollout based on percentage
  /// This uses a deterministic hash of deviceId to ensure consistent user assignment
  Future<bool> isEligibleForRollout(int rolloutPercentage) async {
    if (rolloutPercentage >= 100) return true;
    if (rolloutPercentage <= 0) return false;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final bundleId = packageInfo.packageName;

      // Create a deterministic hash from bundle ID
      // This ensures the same user always gets the same rollout decision
      final hash = _hashString(bundleId).abs() % 100;
      return hash < rolloutPercentage;
    } catch (e) {
      // If unable to determine, use random chance
      return Random().nextInt(100) < rolloutPercentage;
    }
  }

  /// Simple string hash for consistency
  int _hashString(String str) {
    int hash = 0;
    for (int i = 0; i < str.length; i++) {
      final char = str.codeUnitAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash; // Convert to 32-bit integer
    }
    return hash;
  }

  /// Check if force update is required
  /// Returns tuple: (forceUpdateRequired, eligibleForRollout)
  Future<bool> shouldForceUpdate(AppVersionModel versionConfig) async {
    try {
      final currentVersion = await getCurrentAppVersion();

      if (isVersionOutdated(currentVersion, versionConfig.minimumVersion)) {
        final eligible = await isEligibleForRollout(versionConfig.rolloutPercentage);
        
        if (eligible) {
          await _analyticsService.logEvent(
            'force_update_required',
            params: {
              'current_version': currentVersion,
              'minimum_version': versionConfig.minimumVersion,
              'platform': getPlatformName(),
              'rollout_percentage': versionConfig.rolloutPercentage,
            },
          );
          return true;
        }
      }
      return false;
    } catch (e) {
      // If there's any error, don't block the app
      return false;
    }
  }

  /// Log when user initiates update (clicks button)
  Future<void> logUpdateInitiated(String minimumVersion) async {
    try {
      final currentVersion = await getCurrentAppVersion();
      await _analyticsService.logEvent(
        'force_update_initiated',
        params: {
          'current_version': currentVersion,
          'minimum_version': minimumVersion,
          'platform': getPlatformName(),
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
    } catch (e) {
      // Silently fail analytics logging
    }
  }

  /// Log when user is redirected to store
  Future<void> logRedirectedToStore(String platform) async {
    try {
      final currentVersion = await getCurrentAppVersion();
      await _analyticsService.logEvent(
        'user_redirected_to_store',
        params: {
          'current_version': currentVersion,
          'platform': platform,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
    } catch (e) {
      // Silently fail analytics logging
    }
  }
}
