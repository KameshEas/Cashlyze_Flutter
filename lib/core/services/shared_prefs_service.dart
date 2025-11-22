import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsService {
  static const String _onboardingKey = 'onboarding_completed';
  static const String _alertsEnabledKey = 'alerts_enabled';
  static const String _currencyKey = 'currency';
  static const String _dateFormatKey = 'date_format';
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

  String get currency => _prefs.getString(_currencyKey) ?? 'USD';
  Future<void> setCurrency(String value) async {
    await _prefs.setString(_currencyKey, value);
  }

  String get dateFormat => _prefs.getString(_dateFormatKey) ?? 'yyyy-MM-dd';
  Future<void> setDateFormat(String value) async {
    await _prefs.setString(_dateFormatKey, value);
  }
}
