import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

final firebaseAnalyticsProvider = Provider<FirebaseAnalytics>((ref) {
  return FirebaseAnalytics.instance;
});

final firebaseCrashlyticsProvider = Provider<FirebaseCrashlytics>((ref) {
  return FirebaseCrashlytics.instance;
});

class AnalyticsService {
  final FirebaseAnalytics _analytics;

  AnalyticsService(this._analytics);

  Future<void> logScreenView(String screenName) {
    return _analytics.logScreenView(screenName: screenName);
  }

  Future<void> logEvent(String name, {Map<String, Object?>? params}) {
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
}

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService(ref.watch(firebaseAnalyticsProvider));
});
