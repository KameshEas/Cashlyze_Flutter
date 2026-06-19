import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/shared_prefs_provider.dart';
import 'shared_prefs_service.dart';

final firebaseAnalyticsProvider = Provider<FirebaseAnalytics>((final ref) {
  return FirebaseAnalytics.instance;
});

class AnalyticsService {

  AnalyticsService(this._analytics, [this._prefs]);
  final FirebaseAnalytics _analytics;
  final SharedPrefsService? _prefs;

  bool get _hasAnalyticsConsent => _prefs?.analyticsConsentGiven ?? false;

  Future<void> logScreenView(final String screenName) async {
    if (!_hasAnalyticsConsent) return;
    return _analytics.logScreenView(screenName: screenName);
  }

  Future<void> logEvent(final String name, {final Map<String, Object?>? params}) async {
    if (!_hasAnalyticsConsent) return;
    
    final Map<String, Object> sanitized = {};
    if (params != null) {
      params.forEach((final k, final v) {
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
  Future<void> updateAnalyticsConsent(final bool enabled) async {
    await _analytics.setAnalyticsCollectionEnabled(enabled);
  }
}

final analyticsServiceProvider = Provider<AnalyticsService>((final ref) {
  final prefsService = ref.watch(sharedPrefsServiceProvider);
  return AnalyticsService(ref.watch(firebaseAnalyticsProvider), prefsService);
});
