import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/shared_prefs_provider.dart';

// Use sharedPrefsProvider/sharedPrefsServiceProvider from shared_prefs_provider.dart

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

final onboardingCompletedProvider = NotifierProvider<OnboardingNotifier, bool>(
  OnboardingNotifier.new,
);

class CurrencyNotifier extends Notifier<String> {
  @override
  String build() {
    final prefsService = ref.watch(sharedPrefsServiceProvider);
    return prefsService.currency;
  }

  Future<void> set(final String value) async {
    final prefsService = ref.read(sharedPrefsServiceProvider);
    await prefsService.setCurrency(value);
    state = value;
  }
}

final currencyProvider = NotifierProvider<CurrencyNotifier, String>(
  CurrencyNotifier.new,
);
