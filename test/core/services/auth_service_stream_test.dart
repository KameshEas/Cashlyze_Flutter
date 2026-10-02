import 'dart:async';

import 'package:cashlyze/core/models/auth_user.dart';
import 'package:cashlyze/core/services/auth_service.dart';
import 'package:cashlyze/core/services/secure_storage_service.dart';
import 'package:cashlyze/features/auth/data/auth_remote_data_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeStorage extends Fake implements SecureStorageService {
  _FakeStorage(this.token);
  final String? token;

  @override
  Future<String?> getAuthToken() async => token;
}

/// Secure storage whose read throws (e.g. Keystore key missing after a backup
/// restore).
class _ThrowingStorage extends Fake implements SecureStorageService {
  @override
  Future<String?> getAuthToken() async => throw Exception('keystore unavailable');
}

/// Secure storage whose read never completes (e.g. a stalled Keystore call).
class _HangingStorage extends Fake implements SecureStorageService {
  @override
  Future<String?> getAuthToken() => Completer<String?>().future;
}

class _FakeRemote extends Fake implements AuthRemoteDataSource {}

/// Regression: on a cold start while signed in, AuthService emits the cached
/// user as soon as it is built. A listener that attaches a moment later (the
/// router's StreamProvider) used to miss that single event and stayed in the
/// "loading" state - the app hung on its loading screen for ~30s.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a subscriber that attaches AFTER the initial emission still gets the signed-in user', () async {
    SharedPreferences.setMockInitialValues({'auth_user_id': 'u1', 'auth_user_email': 'a@b.com'});
    final service = AuthService(authDataSource: _FakeRemote(), secureStorage: _FakeStorage('token'));

    // Let the constructor's async init finish emitting before anyone listens.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final first = await service.authStateChanges.first.timeout(const Duration(seconds: 2));
    expect(first, isA<AuthUser>());
    expect(first?.email, 'a@b.com');
    service.dispose();
  });

  test('signed out: late subscriber gets null (not a never-resolving stream)', () async {
    SharedPreferences.setMockInitialValues({});
    final service = AuthService(authDataSource: _FakeRemote(), secureStorage: _FakeStorage(null));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final first = await service.authStateChanges.first.timeout(const Duration(seconds: 2));
    expect(first, isNull);
    service.dispose();
  });

  test('an early subscriber still receives the initial value and later updates', () async {
    SharedPreferences.setMockInitialValues({'auth_user_id': 'u1', 'auth_user_email': 'a@b.com'});
    final service = AuthService(authDataSource: _FakeRemote(), secureStorage: _FakeStorage('token'));
    final seen = <AuthUser?>[];
    final sub = service.authStateChanges.listen(seen.add);

    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(seen.length, 1);
    expect(seen.single?.userId, 'u1');

    await sub.cancel();
    service.dispose();
  });

  test('storage that throws falls back to signed-out instead of hanging', () async {
    SharedPreferences.setMockInitialValues({'auth_user_id': 'u1', 'auth_user_email': 'a@b.com'});
    final service = AuthService(authDataSource: _FakeRemote(), secureStorage: _ThrowingStorage());
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final first = await service.authStateChanges.first.timeout(const Duration(seconds: 2));
    expect(first, isNull);
    service.dispose();
  });

  test('storage that never answers resolves to signed-out after the startup timeout', () async {
    SharedPreferences.setMockInitialValues({'auth_user_id': 'u1', 'auth_user_email': 'a@b.com'});
    final service = AuthService(
      authDataSource: _FakeRemote(),
      secureStorage: _HangingStorage(),
      startupReadTimeout: const Duration(milliseconds: 150),
    );
    final seen = <AuthUser?>[];
    final sub = service.authStateChanges.listen(seen.add);

    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(seen, isEmpty, reason: 'still waiting on storage');

    await Future<void>.delayed(const Duration(milliseconds: 250)); // past the bound
    expect(seen, [null]);

    await sub.cancel();
    service.dispose();
  });
}
