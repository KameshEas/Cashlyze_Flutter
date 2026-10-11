import 'package:cashlyze/core/models/auth_user.dart';
import 'package:cashlyze/core/providers/biometric_lock_providers.dart';
import 'package:cashlyze/core/services/auth_service.dart';
import 'package:cashlyze/core/services/biometric_service.dart';
import 'package:cashlyze/features/settings/biometric_gate.dart';
import 'package:cashlyze/features/settings/biometric_lock_tile.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeLocalAuth extends Fake implements LocalAuthentication {
  List<BiometricType> enrolled = [];
  bool hardware = true;
  bool deviceSupported = true;
  Object? authenticateResult = true; // bool, or an Exception to throw
  int authenticateCalls = 0;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async => enrolled;

  @override
  Future<bool> get canCheckBiometrics async => hardware;

  @override
  Future<bool> isDeviceSupported() async => deviceSupported;

  @override
  Future<bool> authenticate({
    required final String localizedReason,
    final Iterable<Object?> authMessages = const <Object?>[],
    final AuthenticationOptions options = const AuthenticationOptions(),
  }) async {
    authenticateCalls++;
    final r = authenticateResult;
    if (r is Exception) throw r;
    return r! as bool;
  }
}

/// A service whose answers the test scripts directly.
class _FakeService extends Fake implements BiometricService {
  BiometricStatus currentStatus = BiometricStatus.available;
  BiometricAuthResult result = BiometricAuthResult.success;
  int authCalls = 0;
  int enrollmentOpened = 0;

  @override
  Future<BiometricStatus> status() async => currentStatus;

  @override
  Future<BiometricAuthResult> authenticate({final String reason = ''}) async {
    authCalls++;
    return result;
  }

  @override
  Future<bool> openEnrollmentSettings() async {
    enrollmentOpened++;
    return true;
  }
}

void main() {
  group('BiometricService.status', () {
    test('enrolled -> available', () async {
      final auth = _FakeLocalAuth()..enrolled = [BiometricType.fingerprint];
      expect(await BiometricService(localAuth: auth).status(), BiometricStatus.available);
    });

    test('hardware but nothing enrolled -> notEnrolled (so we can send the user to set it up)', () async {
      final auth = _FakeLocalAuth()..hardware = true;
      expect(await BiometricService(localAuth: auth).status(), BiometricStatus.notEnrolled);
    });

    test('no hardware -> unsupported', () async {
      final auth = _FakeLocalAuth()
        ..hardware = false
        ..deviceSupported = false;
      expect(await BiometricService(localAuth: auth).status(), BiometricStatus.unsupported);
    });
  });

  group('BiometricService.authenticate', () {
    BiometricService svc(final Object? result) =>
        BiometricService(localAuth: _FakeLocalAuth()..authenticateResult = result);

    test('maps success and plain failure', () async {
      expect(await svc(true).authenticate(), BiometricAuthResult.success);
      expect(await svc(false).authenticate(), BiometricAuthResult.failed);
    });

    test('maps platform error codes to reasons instead of a silent false', () async {
      expect(await svc(PlatformException(code: 'NotEnrolled')).authenticate(), BiometricAuthResult.notEnrolled);
      expect(await svc(PlatformException(code: 'PasscodeNotSet')).authenticate(), BiometricAuthResult.notEnrolled);
      expect(await svc(PlatformException(code: 'LockedOut')).authenticate(), BiometricAuthResult.lockedOut);
      expect(await svc(PlatformException(code: 'PermanentlyLockedOut')).authenticate(), BiometricAuthResult.lockedOut);
      // The pre-fix failure on Android (activity wasn't a FragmentActivity):
      expect(await svc(PlatformException(code: 'no_fragment_activity')).authenticate(), BiometricAuthResult.unavailable);
    });
  });

  group('BiometricService.openEnrollmentSettings', () {
    const channel = MethodChannel('com.aspiredesignovation.cashlyze/biometric_setup');

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });

    test('Android asks the native side to open the enrollment screen', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (final c) async {
        calls.add(c.method);
        return true;
      });
      expect(await BiometricService(localAuth: _FakeLocalAuth()).openEnrollmentSettings(), isTrue);
      expect(calls, ['openEnrollment']);
    });

    test('iOS cannot be sent there, so it reports false for the caller to explain', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(await BiometricService(localAuth: _FakeLocalAuth()).openEnrollmentSettings(), isFalse);
    });
  });

  group('BiometricLockTile', () {
    Future<ProviderContainer> pumpTile(final WidgetTester tester, final _FakeService service,
        {final bool enabled = false}) async {
      SharedPreferences.setMockInitialValues({'biometric_lock_enabled': enabled});
      // HapticFeedback awaits a platform call; give it a handler so it completes.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (final _) async => null);
      addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      final container = ProviderContainer(overrides: [biometricServiceProvider.overrideWithValue(service)]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: BiometricLockTile())),
      ));
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('no fingerprint set up: toggling explains it and offers to open settings (no silent no-op)',
        (final tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final service = _FakeService()..currentStatus = BiometricStatus.notEnrolled;
      final container = await pumpTile(tester, service);

      expect(find.text('Set up a fingerprint or face unlock to turn this on'), findsOneWidget);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(find.text('Set up biometrics'), findsOneWidget);
      expect(service.authCalls, 0); // never even tried to authenticate
      expect(container.read(biometricLockProvider).value, isFalse); // and did not enable

      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();
      expect(service.enrollmentOpened, 1);
      debugDefaultTargetPlatformOverride = null; // must be reset before the test ends
    });

    testWidgets('enrolled and recognised: lock turns on', (final tester) async {
      final service = _FakeService();
      final container = await pumpTile(tester, service);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(service.authCalls, 1);
      expect(container.read(biometricLockProvider).value, isTrue);
      expect(find.text('Biometric lock enabled'), findsOneWidget);
    });

    testWidgets('cancelled or not recognised: stays off without nagging', (final tester) async {
      final service = _FakeService()..result = BiometricAuthResult.failed;
      final container = await pumpTile(tester, service);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(container.read(biometricLockProvider).value, isFalse);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('fingerprints removed between status check and prompt: falls back to the setup dialog',
        (final tester) async {
      final service = _FakeService()..result = BiometricAuthResult.notEnrolled;
      final container = await pumpTile(tester, service);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.text('Set up biometrics'), findsOneWidget);
      expect(container.read(biometricLockProvider).value, isFalse);
    });

    testWidgets('unsupported device: row is disabled with a clear reason', (final tester) async {
      final service = _FakeService()..currentStatus = BiometricStatus.unsupported;
      await pumpTile(tester, service);
      expect(find.text('Not supported on this device'), findsOneWidget);
      expect(find.byType(Switch), findsNothing);
    });
  });

  group('BiometricGate', () {
    const user = AuthUser(userId: 'u1', email: 'a@b.com');

    Future<({ProviderContainer container, _FakeService service})> pumpGate(
      final WidgetTester tester, {
      required final bool lockEnabled,
      final AuthUser? signedIn = user,
      final BiometricAuthResult result = BiometricAuthResult.success,
      final Duration relockAfter = const Duration(seconds: 30),
      final Stream<AuthUser?>? authStream,
    }) async {
      SharedPreferences.setMockInitialValues({'biometric_lock_enabled': lockEnabled});
      final service = _FakeService()..result = result;
      final container = ProviderContainer(overrides: [
        biometricServiceProvider.overrideWithValue(service),
        authStateChangesProvider.overrideWith((final ref) => authStream ?? Stream.value(signedIn)),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: BiometricGate(relockAfter: relockAfter, child: const Scaffold(body: Text('APP CONTENT'))),
        ),
      ));
      await tester.pumpAndSettle();
      return (container: container, service: service);
    }

    Future<void> background(final WidgetTester tester) async {
      for (final s in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      await tester.pump(const Duration(milliseconds: 5));
      for (final s in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      await tester.pumpAndSettle();
    }

    testWidgets('lock off: the app just shows', (final tester) async {
      final r = await pumpGate(tester, lockEnabled: false);
      expect(find.text('APP CONTENT'), findsOneWidget);
      expect(r.service.authCalls, 0);
    });

    testWidgets('lock on + restored session: prompts on launch, then reveals the app', (final tester) async {
      final r = await pumpGate(tester, lockEnabled: true);
      expect(r.service.authCalls, 1);
      expect(find.text('Authenticate to unlock'), findsNothing); // unlocked after success
      expect(find.text('APP CONTENT'), findsOneWidget);
    });

    testWidgets('lock on + failed auth: app stays hidden behind the lock screen', (final tester) async {
      final r = await pumpGate(tester, lockEnabled: true, result: BiometricAuthResult.failed);
      expect(r.service.authCalls, 1);
      expect(find.text('Authenticate to unlock'), findsOneWidget);
      expect(find.text('APP CONTENT'), findsNothing); // Offstage: not painted/visible
    });

    testWidgets('nothing enrolled any more: shows setup + a way out, never traps the user', (final tester) async {
      await pumpGate(tester, lockEnabled: true, result: BiometricAuthResult.notEnrolled);
      expect(find.text('Set up biometrics'), findsOneWidget);
      expect(find.text('Turn off Biometric Lock'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);

      await tester.tap(find.text('Turn off Biometric Lock'));
      await tester.pumpAndSettle();
      expect(find.text('APP CONTENT'), findsOneWidget);
    });

    testWidgets('signed out: no lock even if the setting is on', (final tester) async {
      final r = await pumpGate(tester, lockEnabled: true, signedIn: null);
      expect(r.service.authCalls, 0);
      expect(find.text('APP CONTENT'), findsOneWidget);
    });

    testWidgets('re-locks after the app has been in the background long enough', (final tester) async {
      final r = await pumpGate(tester, lockEnabled: true, relockAfter: Duration.zero);
      expect(r.service.authCalls, 1);
      await background(tester);
      expect(r.service.authCalls, 2);
    });

    testWidgets('a quick app switch does not re-lock', (final tester) async {
      final r = await pumpGate(tester, lockEnabled: true, relockAfter: const Duration(hours: 1));
      expect(r.service.authCalls, 1);
      await background(tester);
      expect(r.service.authCalls, 1);
      expect(find.text('APP CONTENT'), findsOneWidget);
    });
  });
}
