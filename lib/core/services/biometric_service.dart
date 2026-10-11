import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

/// What the device can do right now for biometric authentication.
enum BiometricStatus {
  /// A fingerprint / face is enrolled and ready to use.
  available,

  /// The device has biometric hardware but nothing is enrolled (or no screen
  /// lock is set), so the user has to set one up in system settings first.
  notEnrolled,

  /// No biometric hardware, or the platform can't be queried.
  unsupported,
}

/// Outcome of one authentication attempt.
enum BiometricAuthResult {
  success,

  /// The user cancelled or the fingerprint/face didn't match.
  failed,

  /// Nothing is enrolled; the user needs to set up biometrics.
  notEnrolled,

  /// Too many wrong attempts; the OS has temporarily locked biometrics.
  lockedOut,

  /// Biometrics can't be used (no hardware, plugin error, ...).
  unavailable,
}

/// Wraps `local_auth` so callers get a reason when authentication can't
/// happen, instead of every error collapsing into `false` (which is how a
/// device with no fingerprint set up looked like a toggle that did nothing).
class BiometricService {
  BiometricService({
    final LocalAuthentication? localAuth,
    final MethodChannel? setupChannel,
  })  : _auth = localAuth ?? LocalAuthentication(),
        _setupChannel = setupChannel ?? const MethodChannel(_setupChannelName);

  static const String _setupChannelName =
      'com.aspiredesignovation.cashlyze/biometric_setup';

  final LocalAuthentication _auth;
  final MethodChannel _setupChannel;

  /// Reads the current state fresh each call (the user can enroll or remove a
  /// fingerprint at any time).
  Future<BiometricStatus> status() async {
    try {
      final enrolled = await _auth.getAvailableBiometrics();
      if (enrolled.isNotEmpty) return BiometricStatus.available;

      // Nothing enrolled. Android reports hardware presence separately from
      // enrollment. iOS reports `canCheckBiometrics` false when nothing is
      // enrolled, so there a passcode-capable device is treated as one that
      // can enroll Face ID / Touch ID.
      final hasHardware = await _auth.canCheckBiometrics;
      final iosCanEnroll =
          defaultTargetPlatform == TargetPlatform.iOS && await _auth.isDeviceSupported();
      return (hasHardware || iosCanEnroll)
          ? BiometricStatus.notEnrolled
          : BiometricStatus.unsupported;
    } catch (_) {
      return BiometricStatus.unsupported;
    }
  }

  Future<BiometricAuthResult> authenticate({
    final String reason = 'Authenticate to access Cashlyze',
  }) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: true),
      );
      return ok ? BiometricAuthResult.success : BiometricAuthResult.failed;
    } on PlatformException catch (e) {
      return switch (e.code) {
        'NotEnrolled' || 'PasscodeNotSet' => BiometricAuthResult.notEnrolled,
        'LockedOut' || 'PermanentlyLockedOut' => BiometricAuthResult.lockedOut,
        _ => BiometricAuthResult.unavailable,
      };
    } catch (_) {
      return BiometricAuthResult.unavailable;
    }
  }

  /// Opens the system screen for adding a fingerprint / face. Only Android
  /// can be sent there directly; on iOS there is no public way to open it, so
  /// this returns false and the caller shows instructions instead.
  Future<bool> openEnrollmentSettings() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await _setupChannel.invokeMethod<bool>('openEnrollment') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> cancel() async {
    try {
      await _auth.stopAuthentication();
    } catch (_) {}
  }
}

final biometricServiceProvider = Provider<BiometricService>((final ref) => BiometricService());
