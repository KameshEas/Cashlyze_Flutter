import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/biometric_service.dart';

/// Caches biometric availability to avoid repeated IO checks
/// Computed once at app startup, not on every Settings open
final biometricAvailableProvider = FutureProvider<bool>((ref) async {
  return ref.watch(biometricServiceProvider).isAvailable();
});
