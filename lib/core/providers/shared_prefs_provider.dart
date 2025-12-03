import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/shared_prefs_service.dart';

final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPrefsProvider must be overridden in main.dart');
});

final sharedPrefsServiceProvider = Provider<SharedPrefsService>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return SharedPrefsService(prefs);
});

class LocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() {
    final code = ref.watch(sharedPrefsServiceProvider).languageCode;
    return _toLocale(code);
  }

  Locale _toLocale(String code) {
    switch (code) {
      case 'ENG':
        return const Locale('en');
      case 'HIN':
        return const Locale('hi');
      case 'TAM':
        return const Locale('ta');
      default:
        return const Locale('en');
    }
  }

  Future<void> setCode(String code) async {
    await ref.read(sharedPrefsServiceProvider).setLanguageCode(code);
    state = _toLocale(code);
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale?>(
  LocaleNotifier.new,
);
