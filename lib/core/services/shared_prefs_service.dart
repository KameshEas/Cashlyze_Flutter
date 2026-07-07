import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsService {

  SharedPrefsService(this._prefs);
  static const String _onboardingKey = 'onboarding_completed';
  static const String _alertsEnabledKey = 'alerts_enabled';
  static const String _alertThresholdKey = 'alert_threshold';
  static const String _alertFrequencyKey = 'alert_frequency';
  static const String _currencyKey = 'currency';
  static const String _dateFormatKey = 'date_format';
  static const String _showDevKey = 'show_development_section';
  static const String _languageKey = 'app_language_code';
  static const String _analyticsConsentKey = 'analytics_consent_given';
  static const String _crashlyticsConsentKey = 'crashlytics_consent_given';
  static const String _celebratedGoalsKey = 'celebrated_goal_ids';
  final SharedPreferences _prefs;

  bool get isOnboardingCompleted => _prefs.getBool(_onboardingKey) ?? false;

  Future<void> completeOnboarding() async {
    await _prefs.setBool(_onboardingKey, true);
  }

  bool get alertsEnabled => _prefs.getBool(_alertsEnabledKey) ?? true;
  Future<void> setAlertsEnabled(final bool value) async {
    await _prefs.setBool(_alertsEnabledKey, value);
  }

  double get alertThreshold => _prefs.getDouble(_alertThresholdKey) ?? 0.9;
  Future<void> setAlertThreshold(final double value) async {
    await _prefs.setDouble(_alertThresholdKey, value);
  }

  String get alertFrequency =>
      _prefs.getString(_alertFrequencyKey) ?? 'monthly';
  Future<void> setAlertFrequency(final String value) async {
    await _prefs.setString(_alertFrequencyKey, value);
  }

  String get currency => _prefs.getString(_currencyKey) ?? 'INR';
  Future<void> setCurrency(final String value) async {
    await _prefs.setString(_currencyKey, value);
  }

  String get dateFormat => _prefs.getString(_dateFormatKey) ?? 'yyyy-MM-dd';
  Future<void> setDateFormat(final String value) async {
    await _prefs.setString(_dateFormatKey, value);
  }

  bool get showDevelopmentSection => _prefs.getBool(_showDevKey) ?? false;
  Future<void> setShowDevelopmentSection(final bool value) async {
    await _prefs.setBool(_showDevKey, value);
  }

  String get languageCode => _prefs.getString(_languageKey) ?? 'ENG';
  Future<void> setLanguageCode(final String value) async {
    await _prefs.setString(_languageKey, value);
  }

  Map<String, dynamic>? getDraft(final String key) {
    final raw = _prefs.getString('draft_$key');
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveDraft(final String key, final Map<String, dynamic> data) async {
    await _prefs.setString('draft_$key', jsonEncode(data));
  }

  Future<void> clearDraft(final String key) async {
    await _prefs.remove('draft_$key');
  }

  // Analytics & Crashlytics consent
  bool get analyticsConsentGiven => _prefs.getBool(_analyticsConsentKey) ?? false;
  Future<void> setAnalyticsConsentGiven(final bool value) async {
    await _prefs.setBool(_analyticsConsentKey, value);
  }

  bool get crashlyticsConsentGiven => _prefs.getBool(_crashlyticsConsentKey) ?? false;
  Future<void> setCrashlyticsConsentGiven(final bool value) async {
    await _prefs.setBool(_crashlyticsConsentKey, value);
  }

  // Tracks which savings goals have already shown the completion celebration,
  // so it only plays once per goal rather than on every screen revisit.
  bool hasCelebratedGoal(final String goalId) =>
      (_prefs.getStringList(_celebratedGoalsKey) ?? const []).contains(goalId);

  Future<void> markGoalCelebrated(final String goalId) async {
    final current = _prefs.getStringList(_celebratedGoalsKey) ?? const [];
    if (current.contains(goalId)) return;
    await _prefs.setStringList(_celebratedGoalsKey, [...current, goalId]);
  }
}
