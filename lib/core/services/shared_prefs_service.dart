import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SharedPrefsService {
  static const String _onboardingKey = 'onboarding_completed';
  static const String _alertsEnabledKey = 'alerts_enabled';
  static const String _alertThresholdKey = 'alert_threshold';
  static const String _alertFrequencyKey = 'alert_frequency';
  static const String _currencyKey = 'currency';
  static const String _dateFormatKey = 'date_format';
  static const String _biometricKey = 'biometric_enabled';
  static const String _showDevKey = 'show_development_section';
  static const String _languageKey = 'app_language_code';
  static const String _analyticsConsentKey = 'analytics_consent_given';
  static const String _crashlyticsConsentKey = 'crashlytics_consent_given';
  final SharedPreferences _prefs;

  SharedPrefsService(this._prefs);

  bool get isOnboardingCompleted => _prefs.getBool(_onboardingKey) ?? false;

  Future<void> completeOnboarding() async {
    await _prefs.setBool(_onboardingKey, true);
  }

  bool get alertsEnabled => _prefs.getBool(_alertsEnabledKey) ?? true;
  Future<void> setAlertsEnabled(bool value) async {
    await _prefs.setBool(_alertsEnabledKey, value);
  }

  double get alertThreshold => _prefs.getDouble(_alertThresholdKey) ?? 0.9;
  Future<void> setAlertThreshold(double value) async {
    await _prefs.setDouble(_alertThresholdKey, value);
  }

  String get alertFrequency =>
      _prefs.getString(_alertFrequencyKey) ?? 'monthly';
  Future<void> setAlertFrequency(String value) async {
    await _prefs.setString(_alertFrequencyKey, value);
  }

  String get currency => _prefs.getString(_currencyKey) ?? 'INR';
  Future<void> setCurrency(String value) async {
    await _prefs.setString(_currencyKey, value);
  }

  String get dateFormat => _prefs.getString(_dateFormatKey) ?? 'yyyy-MM-dd';
  Future<void> setDateFormat(String value) async {
    await _prefs.setString(_dateFormatKey, value);
  }

  bool get biometricEnabled => _prefs.getBool(_biometricKey) ?? false;
  Future<void> setBiometricEnabled(bool value) async {
    await _prefs.setBool(_biometricKey, value);
  }

  bool get showDevelopmentSection => _prefs.getBool(_showDevKey) ?? false;
  Future<void> setShowDevelopmentSection(bool value) async {
    await _prefs.setBool(_showDevKey, value);
  }

  String get languageCode => _prefs.getString(_languageKey) ?? 'ENG';
  Future<void> setLanguageCode(String value) async {
    await _prefs.setString(_languageKey, value);
  }

  Map<String, dynamic>? getDraft(String key) {
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

  Future<void> saveDraft(String key, Map<String, dynamic> data) async {
    await _prefs.setString('draft_$key', jsonEncode(data));
  }

  Future<void> clearDraft(String key) async {
    await _prefs.remove('draft_$key');
  }

  // Analytics & Crashlytics consent
  bool get analyticsConsentGiven => _prefs.getBool(_analyticsConsentKey) ?? false;
  Future<void> setAnalyticsConsentGiven(bool value) async {
    await _prefs.setBool(_analyticsConsentKey, value);
  }

  bool get crashlyticsConsentGiven => _prefs.getBool(_crashlyticsConsentKey) ?? false;
  Future<void> setCrashlyticsConsentGiven(bool value) async {
    await _prefs.setBool(_crashlyticsConsentKey, value);
  }
}
