import 'package:firebase_analytics/firebase_analytics.dart';

/// Lightweight analytics wrapper for common events used in Phase 0.
class AnalyticsService {
  AnalyticsService._private();
  static final AnalyticsService _instance = AnalyticsService._private();
  factory AnalyticsService() => _instance;

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Log onboarding completion.
  /// See core/analytics/event_spec.md for parameter definitions.
  Future<void> logOnboardingCompleted({
    required String method,
    required int steps,
    required int durationMs,
    required bool success,
    String? reason,
    int? accountCount,
    bool? hasLinkedAccount,
  }) async {
    await _analytics.logEvent(
      name: 'onboarding_completed',
      parameters: <String, Object?>{
        'method': method,
        'steps': steps,
        'duration_ms': durationMs,
        'success': success,
        if (reason != null) 'reason': reason,
      },
    );

    if (accountCount != null) {
      await _analytics.setUserProperty(name: 'account_count', value: accountCount.toString());
    }
    if (hasLinkedAccount != null) {
      await _analytics.setUserProperty(name: 'has_linked_account', value: hasLinkedAccount ? 'true' : 'false');
    }
  }

  /// Log transaction import events.
  /// `count` should reflect number of transactions persisted in this operation.
  Future<void> logTransactionImported({
    required String importMethod,
    String? provider,
    required int count,
    required int importDurationMs,
    required bool success,
    String? errorCode,
    String? sampleTxnId,
  }) async {
    await _analytics.logEvent(
      name: 'transaction_imported',
      parameters: <String, Object?>{
        'import_method': importMethod,
        if (provider != null) 'provider': provider,
        'count': count,
        'import_duration_ms': importDurationMs,
        'success': success,
        if (errorCode != null) 'error_code': errorCode,
        if (sampleTxnId != null) 'sample_txn_id': sampleTxnId,
      },
    );
  }
}

// Example usage:
// final analytics = AnalyticsService();
// analytics.logOnboardingCompleted(method: 'bank_link', steps: 4, durationMs: 120000, success: true, accountCount: 1, hasLinkedAccount: true);
// analytics.logTransactionImported(importMethod: 'bank_link', provider: 'bank_abc', count: 42, importDurationMs: 3500, success: true);
