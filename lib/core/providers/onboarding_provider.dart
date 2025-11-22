import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/shared_prefs_service.dart';

final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

final sharedPrefsServiceProvider = Provider<SharedPrefsService>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return SharedPrefsService(prefs);
});

class OnboardingNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefsService = ref.watch(sharedPrefsServiceProvider);
    return prefsService.isOnboardingCompleted;
  }

  void complete() {
    state = true;
  }
}

final onboardingCompletedProvider = NotifierProvider<OnboardingNotifier, bool>(OnboardingNotifier.new);

class CurrencyNotifier extends Notifier<String> {
  @override
  String build() {
    final prefsService = ref.watch(sharedPrefsServiceProvider);
    return prefsService.currency;
  }

  Future<void> set(String value) async {
    final prefsService = ref.read(sharedPrefsServiceProvider);
    await prefsService.setCurrency(value);
    state = value;
  }
}

final currencyProvider = NotifierProvider<CurrencyNotifier, String>(CurrencyNotifier.new);
