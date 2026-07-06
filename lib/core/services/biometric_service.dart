import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final _localAuth = LocalAuthentication();

  static Future<bool> isDeviceSupported() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isDeviceCapable() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticate() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Authenticate to access Cashlyze',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  static Future<void> cancel() async {
    try {
      await _localAuth.stopAuthentication();
    } catch (_) {}
  }
}
