import 'package:cashlyze/core/api/api_exception.dart';
import 'package:cashlyze/core/providers/shared_prefs_provider.dart';
import 'package:cashlyze/core/theme/app_theme.dart';
import 'package:cashlyze/features/auth/data/password_reset_remote_data_source.dart';
import 'package:cashlyze/features/auth/forgot_password_screen.dart';
import 'package:cashlyze/features/auth/reset_code_screen.dart';
import 'package:cashlyze/features/auth/reset_new_password_screen.dart';
import 'package:cashlyze/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Scriptable stand-in for the backend: each list is consumed in order, and an
/// [Exception] entry is thrown instead of returned.
class _FakePasswordReset extends Fake implements PasswordResetRemoteDataSource {
  final List<String> requested = [];
  final List<String> verifiedCodes = [];
  final List<String> passwords = [];
  final List<Object> verifyResults = [];
  final List<Object> requestResults = [];
  Object resetResult = 'ok';

  @override
  Future<void> requestCode({required final String email}) async {
    requested.add(email);
    if (requestResults.isNotEmpty) {
      final r = requestResults.removeAt(0);
      if (r is Exception) throw r;
    }
  }

  @override
  Future<String> verifyCode({required final String email, required final String otp}) async {
    verifiedCodes.add(otp);
    final r = verifyResults.isEmpty ? const ValidationException('Invalid or expired code') : verifyResults.removeAt(0);
    if (r is Exception) throw r;
    return r as String;
  }

  @override
  Future<void> resetPassword({required final String resetToken, required final String newPassword}) async {
    passwords.add(newPassword);
    final r = resetResult;
    if (r is Exception) throw r;
  }
}

Future<(_FakePasswordReset, GoRouter)> _pump(
  final WidgetTester tester, {
  required final String initial,
  final Object? extra,
  // The code screen's cooldown ticker keeps scheduling frames, so
  // pumpAndSettle would fast-forward through the whole cooldown.
  final bool settle = true,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final fake = _FakePasswordReset();
  final router = GoRouter(
    initialLocation: initial,
    initialExtra: extra,
    routes: [
      GoRoute(
        path: '/forgot-password',
        builder: (_, final s) => ForgotPasswordScreen(
          initialEmail: s.uri.queryParameters['email'] ?? '',
          notice: s.uri.queryParameters['notice'],
        ),
      ),
      GoRoute(
        path: '/reset-code',
        builder: (_, final s) => ResetCodeScreen(email: s.uri.queryParameters['email'] ?? ''),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (_, final s) => ResetNewPasswordScreen(args: s.extra! as ResetPasswordArgs),
      ),
      GoRoute(
        path: '/login',
        builder: (_, final s) => Scaffold(body: Text('LOGIN ${s.uri.queryParameters['notice'] ?? ''}')),
      ),
    ],
  );
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      passwordResetRemoteDataSourceProvider.overrideWithValue(fake),
    ],
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
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
  return (fake, router);
}

String _location(final GoRouter router) => router.routeInformationProvider.value.uri.toString();

Future<void> _enterCode(final WidgetTester tester, final String code) async {
  await tester.enterText(find.byType(TextField), code);
  await tester.pump();
}

void main() {
  const email = 'user@example.com';

  group('ForgotPasswordScreen', () {
    testWidgets('rejects an invalid email without calling the server', (final tester) async {
      final (fake, _) = await _pump(tester, initial: '/forgot-password');
      await tester.enterText(find.byType(TextFormField), 'not-an-email');
      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter a valid email'), findsOneWidget);
      expect(fake.requested, isEmpty);
    });

    testWidgets('sends the code (lower-cased) and continues to the code screen', (final tester) async {
      final (fake, router) = await _pump(tester, initial: '/forgot-password');
      await tester.enterText(find.byType(TextFormField), '  User@Example.com ');
      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();
      expect(fake.requested, [email]);
      expect(_location(router), startsWith('/reset-code?email='));
    });

    testWidgets('429 shows a rate-limit message and stays put', (final tester) async {
      final (fake, router) = await _pump(tester, initial: '/forgot-password');
      fake.requestResults.add(const TooManyRequestsException());
      await tester.enterText(find.byType(TextFormField), email);
      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Too many attempts'), findsOneWidget);
      expect(_location(router), '/forgot-password');
    });

    testWidgets('prefills the email and shows the notice', (final tester) async {
      await _pump(tester, initial: '/forgot-password?email=$email&notice=Session%20expired');
      expect(find.text(email), findsOneWidget);
      expect(find.text('Session expired'), findsOneWidget);
    });
  });

  group('ResetCodeScreen', () {
    testWidgets('a correct code moves to the new-password step', (final tester) async {
      final (fake, router) = await _pump(tester, initial: '/reset-code?email=$email');
      fake.verifyResults.add('reset-token');
      await _enterCode(tester, '123456'); // completing 6 digits auto-submits
      await tester.pumpAndSettle();
      expect(fake.verifiedCodes, ['123456']);
      expect(_location(router), '/reset-password');
      expect(find.text('Choose a new password'), findsOneWidget);
    });

    testWidgets('400 shows an error and clears the field', (final tester) async {
      final (fake, _) = await _pump(tester, initial: '/reset-code?email=$email');
      await _enterCode(tester, '111111');
      await tester.pumpAndSettle();
      expect(find.text('That code is incorrect or has expired.'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
      expect(fake.verifiedCodes, ['111111']);
    });

    testWidgets('warns about remaining attempts, then locks after 5 wrong codes', (final tester) async {
      final (fake, _) = await _pump(tester, initial: '/reset-code?email=$email');
      for (var i = 1; i <= 5; i++) {
        await _enterCode(tester, '11111$i');
        await tester.pumpAndSettle();
        if (i == 3) expect(find.text('That code is incorrect. Attempts left: 2.'), findsOneWidget);
        if (i == 4) expect(find.text('That code is incorrect. Attempts left: 1.'), findsOneWidget);
      }
      expect(find.text('Too many wrong attempts. Request a new code to continue.'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      expect(fake.verifiedCodes.length, 5);
    });

    testWidgets('429 on verify shows the rate-limit message and keeps the screen', (final tester) async {
      final (fake, router) = await _pump(tester, initial: '/reset-code?email=$email');
      fake.verifyResults.add(const TooManyRequestsException());
      await _enterCode(tester, '123456');
      await tester.pumpAndSettle();
      expect(find.textContaining('Too many attempts'), findsOneWidget);
      expect(_location(router), startsWith('/reset-code'));
    });

    testWidgets('resend is disabled during the 60s cooldown, then re-enables and resets attempts',
        (final tester) async {
      final (fake, _) = await _pump(tester, initial: '/reset-code?email=$email', settle: false);
      expect(find.text('Resend in 60s'), findsOneWidget);
      await tester.tap(find.text('Resend in 60s'), warnIfMissed: false);
      await tester.pump();
      expect(fake.requested, isEmpty);

      await tester.pump(const Duration(seconds: 30));
      expect(find.text('Resend in 30s'), findsOneWidget);

      await tester.pump(const Duration(seconds: 30));
      expect(find.text('Resend code'), findsOneWidget);

      await tester.tap(find.text('Resend code'));
      await tester.pump();
      await tester.pump();
      expect(fake.requested, [email]);
      expect(find.text('A new code is on its way.'), findsOneWidget);
      expect(find.text('Resend in 60s'), findsOneWidget); // cooldown restarted
    });

    testWidgets('429 on resend shows the message and restarts the cooldown', (final tester) async {
      final (fake, _) = await _pump(tester, initial: '/reset-code?email=$email', settle: false);
      await tester.pump(const Duration(seconds: 60));
      fake.requestResults.add(const TooManyRequestsException());
      await tester.tap(find.text('Resend code'));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Too many attempts'), findsOneWidget);
      expect(find.text('Resend in 60s'), findsOneWidget);
    });

    testWidgets('a short code is rejected locally (paste of fewer than 6 digits + Verify)', (final tester) async {
      final (fake, _) = await _pump(tester, initial: '/reset-code?email=$email');
      await _enterCode(tester, '123');
      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();
      expect(find.text('Enter all 6 digits of the code'), findsOneWidget);
      expect(fake.verifiedCodes, isEmpty);
    });
  });

  group('ResetNewPasswordScreen', () {
    const args = ResetPasswordArgs(email: email, resetToken: 'reset-token');

    Future<_FakePasswordReset> openScreen(final WidgetTester tester) async {
      final (fake, _) = await _pump(tester, initial: '/reset-password', extra: args);
      return fake;
    }

    Future<void> fill(final WidgetTester tester, final String password, final String confirm) async {
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), password);
      await tester.enterText(fields.at(1), confirm);
      await tester.tap(find.text('Reset password'));
      await tester.pumpAndSettle();
    }

    test('client policy mirrors the server', () {
      expect(isAcceptableResetPassword('NewPassw0rd'), isTrue);
      expect(isAcceptableResetPassword('short1A'), isFalse);
      expect(isAcceptableResetPassword('alllowercase1'), isFalse);
      expect(isAcceptableResetPassword('ALLUPPERCASE1'), isFalse);
      expect(isAcceptableResetPassword('NoDigitsHere'), isFalse);
    });

    testWidgets('weak password is blocked locally', (final tester) async {
      final fake = await openScreen(tester);
      await fill(tester, 'weak', 'weak');
      expect(find.textContaining('Use 8+ characters'), findsOneWidget);
      expect(fake.passwords, isEmpty);
    });

    testWidgets('mismatched confirmation is blocked locally', (final tester) async {
      final fake = await openScreen(tester);
      await fill(tester, 'NewPassw0rd', 'NewPassw0rd!');
      expect(find.text("Passwords don't match"), findsOneWidget);
      expect(fake.passwords, isEmpty);
    });

    testWidgets('success goes to login with a notice', (final tester) async {
      final (fake, router) = await _pump(tester, initial: '/reset-password', extra: args);
      await fill(tester, 'NewPassw0rd', 'NewPassw0rd');
      expect(fake.passwords, ['NewPassw0rd']);
      expect(_location(router), startsWith('/login?notice='));
      expect(find.textContaining('Password reset. Please log in'), findsOneWidget);
    });

    testWidgets('400 from an expired session sends the user back to request a new code', (final tester) async {
      final (fake, router) = await _pump(tester, initial: '/reset-password', extra: args);
      fake.resetResult = const ValidationException('This reset session is invalid or has expired');
      await fill(tester, 'NewPassw0rd', 'NewPassw0rd');
      expect(_location(router), startsWith('/forgot-password?email='));
      expect(find.textContaining('reset session expired'), findsOneWidget);
    });

    testWidgets('400 with a password-policy message stays on the screen', (final tester) async {
      final (fake, router) = await _pump(tester, initial: '/reset-password', extra: args);
      fake.resetResult = const ValidationException('New password must contain at least one digit');
      await fill(tester, 'NewPassw0rd', 'NewPassw0rd');
      expect(_location(router), '/reset-password');
      expect(find.text('New password must contain at least one digit'), findsOneWidget);
    });

    testWidgets('429 shows the rate-limit message and stays', (final tester) async {
      final (fake, router) = await _pump(tester, initial: '/reset-password', extra: args);
      fake.resetResult = const TooManyRequestsException();
      await fill(tester, 'NewPassw0rd', 'NewPassw0rd');
      expect(_location(router), '/reset-password');
      expect(find.textContaining('Too many attempts'), findsOneWidget);
    });
  });
}
