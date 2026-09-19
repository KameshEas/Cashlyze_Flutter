import 'package:cashlyze/core/config/env_config.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the getter should give when `.env` has nothing: normally null, or the
/// `--dart-define` value if this test run was started with one.
final String? _whenEnvHasNothing = const String.fromEnvironment('ONESIGNAL_APP_ID').isEmpty
    ? null
    : const String.fromEnvironment('ONESIGNAL_APP_ID');

void main() {
  tearDown(dotenv.clean);

  group('EnvConfig.oneSignalAppId', () {
    // Must run before any test loads .env: dotenv's "initialized" flag is
    // process-wide and can't be reset, and `dotenv.env` throws until it is set.
    test('is null, not an error, when .env could not be loaded at all', () {
      expect(dotenv.isInitialized, isFalse);
      expect(EnvConfig.oneSignalAppId, _whenEnvHasNothing);
    });

    test('uses ONESIGNAL_APP_ID from .env when it is set', () {
      dotenv.testLoad(fileInput: 'ONESIGNAL_APP_ID=test-app-id');
      expect(EnvConfig.oneSignalAppId, 'test-app-id');
    });

    test('falls back to --dart-define=ONESIGNAL_APP_ID when .env has none', () {
      dotenv.testLoad(fileInput: 'FIREBASE_PROJECT_ID=x');
      expect(EnvConfig.oneSignalAppId, const String.fromEnvironment('ONESIGNAL_APP_ID'));
    }, skip: const bool.hasEnvironment('ONESIGNAL_APP_ID')
        ? false
        : 'run with --dart-define=ONESIGNAL_APP_ID=some-id');

    test('.env wins over --dart-define', () {
      dotenv.testLoad(fileInput: 'ONESIGNAL_APP_ID=from-env');
      expect(EnvConfig.oneSignalAppId, 'from-env');
    });

    test('trims the value from .env', () {
      dotenv.testLoad(fileInput: 'ONESIGNAL_APP_ID=  padded-id  ');
      expect(EnvConfig.oneSignalAppId, 'padded-id');
    });

    test('is null when .env has no such key (no default is baked in)', () {
      // The situation of a CI build whose secrets don't include the key.
      dotenv.testLoad(fileInput: 'FIREBASE_PROJECT_ID=x');
      expect(EnvConfig.oneSignalAppId, _whenEnvHasNothing);
    });

    test('is null when the value is blank', () {
      dotenv.testLoad(fileInput: 'ONESIGNAL_APP_ID=');
      expect(EnvConfig.oneSignalAppId, _whenEnvHasNothing);
      dotenv.testLoad(fileInput: 'ONESIGNAL_APP_ID=   ');
      expect(EnvConfig.oneSignalAppId, _whenEnvHasNothing);
    });
  });
}
