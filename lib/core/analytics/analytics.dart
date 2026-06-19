import 'package:firebase_analytics/firebase_analytics.dart';

/// Lightweight analytics wrapper for common events used in Phase 0.
class AnalyticsService {
  factory AnalyticsService() => _instance;

  AnalyticsService._private();

  static final AnalyticsService _instance = AnalyticsService._private();
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Log onboarding completion.
  /// See core/analytics/event_spec.md for parameter definitions.
  Future<void> logOnboardingCompleted({
    required final String method,
    required final int steps,
    required final int durationMs,
    required final bool success,
    final String? reason,
    final int? accountCount,
    final bool? hasLinkedAccount,
  }) async {
    final paramsOnboarding = <String, Object>{
      'method': method,
      'steps': steps,
      'duration_ms': durationMs,
      'success': success,
    };
    if (reason != null) paramsOnboarding['reason'] = reason;
    await _analytics.logEvent(
      name: 'onboarding_completed',
      parameters: paramsOnboarding,
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
    required final String importMethod,
    final String? provider,
    required final int count,
    required final int importDurationMs,
    required final bool success,
    final String? errorCode,
    final String? sampleTxnId,
  }) async {
    final paramsImport = <String, Object>{
      'import_method': importMethod,
      'count': count,
      'import_duration_ms': importDurationMs,
      'success': success,
    };
    if (provider != null) paramsImport['provider'] = provider;
    if (errorCode != null) paramsImport['error_code'] = errorCode;
    if (sampleTxnId != null) paramsImport['sample_txn_id'] = sampleTxnId;
    await _analytics.logEvent(
      name: 'transaction_imported',
      parameters: paramsImport,
    );
  }
}

// Example usage:
// final analytics = AnalyticsService();
// analytics.logOnboardingCompleted(method: 'bank_link', steps: 4, durationMs: 120000, success: true, accountCount: 1, hasLinkedAccount: true);
// analytics.logTransactionImported(importMethod: 'bank_link', provider: 'bank_abc', count: 42, importDurationMs: 3500, success: true);
