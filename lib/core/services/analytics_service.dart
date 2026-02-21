import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'shared_prefs_service.dart';
import '../providers/shared_prefs_provider.dart';

final firebaseAnalyticsProvider = Provider<FirebaseAnalytics>((ref) {
  return FirebaseAnalytics.instance;
});

final firebaseCrashlyticsProvider = Provider<FirebaseCrashlytics>((ref) {
  return FirebaseCrashlytics.instance;
});

class AnalyticsService {
  final FirebaseAnalytics _analytics;
  final SharedPrefsService? _prefs;

  AnalyticsService(this._analytics, [this._prefs]);

  bool get _hasAnalyticsConsent => _prefs?.analyticsConsentGiven ?? false;
  bool get _hasCrashlyticsConsent => _prefs?.crashlyticsConsentGiven ?? false;

  /// Initialize Crashlytics with consent check
  Future<void> initializeCrashlytics() async {
    if (_hasCrashlyticsConsent) {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
    } else {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
    }
  }

  Future<void> logScreenView(String screenName) async {
    if (!_hasAnalyticsConsent) return;
    return _analytics.logScreenView(screenName: screenName);
  }

  Future<void> logEvent(String name, {Map<String, Object?>? params}) async {
    if (!_hasAnalyticsConsent) return;
    
    Map<String, Object> sanitized = {};
    if (params != null) {
      params.forEach((k, v) {
        if (v is bool) {
          sanitized[k] = v ? 1 : 0;
        } else if (v is num || v is String) {
          sanitized[k] = v as Object;
        } else if (v is DateTime) {
          sanitized[k] = v.millisecondsSinceEpoch;
        } else {
          sanitized[k] = v.toString();
        }
      });
    }
    return _analytics.logEvent(name: name, parameters: sanitized);
  }

  /// Update analytics consent - call when user changes consent setting
  Future<void> updateAnalyticsConsent(bool enabled) async {
    await _analytics.setAnalyticsCollectionEnabled(enabled);
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(enabled);
  }
}

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  final prefsService = ref.watch(sharedPrefsServiceProvider);
  return AnalyticsService(ref.watch(firebaseAnalyticsProvider), prefsService);
});
