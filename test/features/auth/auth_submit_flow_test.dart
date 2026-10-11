import 'package:cashlyze/core/api/api_exception.dart';
import 'package:cashlyze/core/providers/otp_pending_provider.dart';
import 'package:cashlyze/core/providers/shared_prefs_provider.dart';
import 'package:cashlyze/core/services/analytics_service.dart';
import 'package:cashlyze/core/services/auth_service.dart';
import 'package:cashlyze/core/theme/app_theme.dart';
import 'package:cashlyze/features/auth/auth_screen.dart';
import 'package:cashlyze/features/auth/data/otp_remote_data_source.dart';
import 'package:cashlyze/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuth extends Fake implements AuthService {
  Object? signInError;
  int signIns = 0;

  @override
  Future<void> signInWithEmailAndPassword({
    required final String email,
    required final String password,
  }) async {
    signIns++;
    if (signInError != null) throw signInError!;
  }
}

class _FakeOtp extends Fake implements OtpRemoteDataSource {
  Object? sendError;
  final List<String> sentTo = [];

  @override
  Future<void> sendOtp({required final String email}) async {
    sentTo.add(email);
    if (sendError != null) throw sendError!;
  }
}

class _FakeAnalytics extends Fake implements AnalyticsService {
  @override
  Future<void> logEvent(final String name, {final Map<String, Object?>? params}) async {}
}

class _Harness {
  _Harness(this.auth, this.otp, this.router, this.container);

  final _FakeAuth auth;
  final _FakeOtp otp;
  final GoRouter router;
  final ProviderContainer container;

  String get location => router.routeInformationProvider.value.uri.toString();
}

Future<_Harness> _pump(final WidgetTester tester, {required final bool login}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final auth = _FakeAuth();
  final otp = _FakeOtp();
  final router = GoRouter(
    initialLocation: login ? '/login' : '/signup',
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const AuthScreen()),
      GoRoute(path: '/signup', builder: (_, _) => const AuthScreen(initialIsLogin: false)),
      GoRoute(path: '/otp', builder: (_, final s) => Scaffold(body: Text('OTP ${s.uri.queryParameters['email']}'))),
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('HOME'))),
    ],
  );
  final container = ProviderContainer(overrides: [
    sharedPrefsProvider.overrideWithValue(prefs),
    authServiceProvider.overrideWithValue(auth),
    otpRemoteDataSourceProvider.overrideWithValue(otp),
    analyticsServiceProvider.overrideWithValue(_FakeAnalytics()),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      theme: AppTheme.lightTheme,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    ),
  ));
  await tester.pumpAndSettle();
  return _Harness(auth, otp, router, container);
}

Future<void> _fill(final WidgetTester tester, {final String? name, final String? mobile}) async {
  Future<void> type(final String label, final String value) => tester.enterText(
        find.ancestor(of: find.text(label), matching: find.byType(TextField)).first,
        value,
      );
  if (name != null) await type('Name', name);
  if (mobile != null) await type('Mobile', mobile);
  await type('Email', 'user@example.com');
  await type('Password', 'secret123');
}

void main() {
  group('login', () {
    testWidgets('wrong password says so, stays on Sign In, and never offers sign-up', (final tester) async {
      final h = await _pump(tester, login: true);
      h.auth.signInError = const UnauthorizedException('Invalid credentials');
      await _fill(tester);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('Incorrect email or password'), findsOneWidget);
      expect(find.textContaining('No account found'), findsNothing);
      expect(find.text('Name'), findsNothing); // still the sign-in form, not sign-up
      expect(h.otp.sentTo, isEmpty); // no hidden "is this email registered" probing
      expect(h.location, '/login');
    });

    testWidgets('other login errors still surface their own message', (final tester) async {
      final h = await _pump(tester, login: true);
      h.auth.signInError = const TooManyRequestsException('Too many login attempts. Please try again later.');
      await _fill(tester);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text('Too many login attempts. Please try again later.'), findsOneWidget);
    });

    testWidgets('successful login goes home', (final tester) async {
      final h = await _pump(tester, login: true);
      await _fill(tester);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(h.auth.signIns, 1);
      expect(h.location, '/');
    });
  });

  group('sign up', () {
    testWidgets('an existing email is reported on Create Account, before any verification step', (final tester) async {
      final h = await _pump(tester, login: false);
      h.otp.sendError = const ConflictException('Email already registered');
      await _fill(tester, name: 'Test User', mobile: '9876543210');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.text('This email is already registered. Please sign in instead.'), findsOneWidget);
      expect(h.location, '/signup'); // did NOT move on to the OTP screen
      expect(h.container.read(otpPendingProvider), isFalse); // nothing left pending
      expect(find.text('Name'), findsNothing); // switched to the sign-in form
    });

    testWidgets('a new email sends the code right away and opens the code-entry step', (final tester) async {
      final h = await _pump(tester, login: false);
      await _fill(tester, name: 'Test User', mobile: '9876543210');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(h.otp.sentTo, ['user@example.com']);
      expect(h.location, startsWith('/otp?email='));
      final pending = h.container.read(otpPendingProvider.notifier);
      expect(h.container.read(otpPendingProvider), isTrue);
      expect(pending.otpAlreadySent, isTrue); // OTP screen skips its own "Send code" step
      expect(pending.pendingEmail, 'user@example.com');
    });

    testWidgets('a rate-limited send stays on the form with the server message', (final tester) async {
      final h = await _pump(tester, login: false);
      h.otp.sendError = const TooManyRequestsException('Rate limit exceeded');
      await _fill(tester, name: 'Test User', mobile: '9876543210');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.text('Rate limit exceeded'), findsOneWidget);
      expect(h.location, '/signup');
      expect(h.container.read(otpPendingProvider), isFalse);
    });
  });
}
