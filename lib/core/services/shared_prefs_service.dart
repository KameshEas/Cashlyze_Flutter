import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsService {
  static const String _onboardingKey = 'onboarding_completed';
  final SharedPreferences _prefs;

  SharedPrefsService(this._prefs);

  bool get isOnboardingCompleted => _prefs.getBool(_onboardingKey) ?? false;

  Future<void> completeOnboarding() async {
    await _prefs.setBool(_onboardingKey, true);
  }
}
