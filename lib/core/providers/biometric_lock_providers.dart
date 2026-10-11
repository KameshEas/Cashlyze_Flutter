import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final biometricLockEnabledProvider =
    FutureProvider<bool>((final ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('biometric_lock_enabled') ?? false;
});

class BiometricLockNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('biometric_lock_enabled') ?? false;
  }

  /// Turns the lock on. Callers must have already confirmed biometrics are
  /// enrolled and that the user authenticated (see BiometricLockTile).
  Future<void> enable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_lock_enabled', true);
    state = const AsyncValue.data(true);
  }

  Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_lock_enabled', false);
    state = const AsyncValue.data(false);
  }
}

final biometricLockProvider =
    AsyncNotifierProvider<BiometricLockNotifier, bool>(
      BiometricLockNotifier.new,
    );
