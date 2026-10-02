import 'package:cashlyze/core/branding/animated_brand_logo.dart';
import 'package:cashlyze/core/providers/otp_pending_provider.dart';
import 'package:cashlyze/core/providers/shared_prefs_provider.dart';
import 'package:cashlyze/core/theme/app_theme.dart';
import 'package:cashlyze/features/auth/auth_screen.dart';
import 'package:cashlyze/features/auth/data/otp_remote_data_source.dart';
import 'package:cashlyze/features/auth/otp_screen.dart';
import 'package:cashlyze/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeOtp extends Fake implements OtpRemoteDataSource {
  int sent = 0;

  @override
  Future<void> sendOtp({required final String email}) async => sent++;
}


Future<_FakeOtp> _pump(
  final WidgetTester tester, {
  required final Widget screen,
  required final Size size,
  final double textScale = 1.0,
  final bool dark = false,
  final Locale locale = const Locale('en'),
  final double keyboard = 0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final otp = _FakeOtp();
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, _) => screen),
    GoRoute(path: '/login', builder: (_, _) => const Scaffold(body: Text('LOGIN'))),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      otpRemoteDataSourceProvider.overrideWithValue(otp),
    ],
    child: MaterialApp.router(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (final context, final child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      routerConfig: router,
    ),
  ));
  await tester.pumpAndSettle();
  return otp;
}

TextField _fieldByLabel(final WidgetTester tester, final String label) => tester.widget<TextField>(
      find.ancestor(of: find.text(label), matching: find.byType(TextField)).first,
    );

void main() {
  const sizes = <String, Size>{
    'small 320x568': Size(320, 568),
    'standard 360x640': Size(360, 640),
    'common 390x844': Size(390, 844),
    'tall 412x915': Size(412, 915),
    'large 430x932': Size(430, 932),
  };

  group('AuthScreen layout', () {
    for (final e in sizes.entries) {
      for (final scale in [1.0, 2.0]) {
        for (final dark in [false, true]) {
          testWidgets('${e.key} x$scale ${dark ? 'dark' : 'light'} sign in + sign up', (final tester) async {
            await _pump(tester, screen: const AuthScreen(), size: e.value, textScale: scale, dark: dark);
            expect(tester.takeException(), isNull);
            await tester.tap(find.text('Sign Up').first);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          });
        }
      }
    }

    testWidgets('keyboard open on a short phone at 200% text', (final tester) async {
      await _pump(
        tester,
        screen: const AuthScreen(initialIsLogin: false),
        size: const Size(360, 640),
        textScale: 2.0,
        keyboard: 300,
      );
      expect(tester.takeException(), isNull);
    });

    for (final loc in ['hi', 'ta']) {
      testWidgets('locale $loc sign up at 360x640 x1.3', (final tester) async {
        await _pump(tester, screen: const AuthScreen(initialIsLogin: false), size: const Size(360, 640), textScale: 1.3, locale: Locale(loc));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('form sheet is anchored to the bottom on a tall screen', (final tester) async {
      await _pump(tester, screen: const AuthScreen(), size: const Size(412, 915));
      final sheet = tester.getRect(find.byType(AutofillGroup));
      // Sheet padding sits below the group; its content must be in the lower half.
      expect(sheet.top, greaterThan(915 / 2));
      expect(sheet.bottom, greaterThan(915 - 60));
    });

    testWidgets('logo stays mounted (no animation replay) when the keyboard opens', (final tester) async {
      await _pump(tester, screen: const AuthScreen(), size: const Size(390, 844));
      final before = tester.state(find.byType(PlayOnceBrandLogo));
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(PlayOnceBrandLogo)), same(before));
    });
  });

  group('AuthScreen behaviour', () {
    testWidgets('tabs and inline link switch mode; name field only on sign up', (final tester) async {
      await _pump(tester, screen: const AuthScreen(), size: const Size(390, 844));
      expect(find.text('Name'), findsNothing);
      await tester.tap(find.text('Sign Up').first);
      await tester.pumpAndSettle();
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('At least 6 characters'), findsOneWidget);
      await tester.tap(find.text('Sign In').last); // inline link
      await tester.pumpAndSettle();
      expect(find.text('Name'), findsNothing);
      expect(find.text('At least 6 characters'), findsNothing);
    });

    testWidgets('autofill hints follow the mode', (final tester) async {
      await _pump(tester, screen: const AuthScreen(), size: const Size(390, 844));
      expect(_fieldByLabel(tester, 'Password').autofillHints, contains(AutofillHints.password));
      expect(_fieldByLabel(tester, 'Email').autofillHints, contains(AutofillHints.username));
      await tester.tap(find.text('Sign Up').first);
      await tester.pumpAndSettle();
      expect(_fieldByLabel(tester, 'Password').autofillHints, contains(AutofillHints.newPassword));
      expect(_fieldByLabel(tester, 'Mobile').autofillHints, contains(AutofillHints.telephoneNumber));
    });

    testWidgets('mobile field accepts only digits and +, capped at 15', (final tester) async {
      await _pump(tester, screen: const AuthScreen(initialIsLogin: false), size: const Size(390, 844));
      final mobile = find.ancestor(of: find.text('Mobile'), matching: find.byType(TextField)).first;
      await tester.enterText(mobile, 'ab+91 98765-43210 12345');
      expect(tester.widget<TextField>(mobile).controller!.text, '+91987654321012');
    });

    testWidgets('validation messages are shown (localised) on empty submit', (final tester) async {
      await _pump(tester, screen: const AuthScreen(), size: const Size(390, 844));
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
    });

    testWidgets('semantics: tabs expose selected state; password toggle has a label', (final tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, screen: const AuthScreen(), size: const Size(390, 844));
      expect(find.bySemanticsLabel('Sign In'), findsWidgets);
      expect(find.byTooltip('Show password'), findsOneWidget);
      handle.dispose();
    });
  });

  group('OtpScreen', () {
    for (final e in sizes.entries) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('${e.key} x$scale both phases', (final tester) async {
          await _pump(tester, screen: const OtpScreen(email: 'a@b.com'), size: e.value, textScale: scale);
          expect(tester.takeException(), isNull);
          await tester.tap(find.byType(FilledButton));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('send code reveals one labelled code field and a sent banner', (final tester) async {
      final handle = tester.ensureSemantics();
      final h = await _pump(tester, screen: const OtpScreen(email: 'a@b.com'), size: const Size(390, 844));
      expect(find.text('Verify your account'), findsOneWidget);
      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();
      expect(h.sent, 1);
      expect(find.text('Enter your code'), findsOneWidget);
      expect(find.textContaining('Code sent to a@b.com'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget); // one real field, not six
      expect(find.bySemanticsLabel('Verification code, 6 digits'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '12ab34');
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '1234');
      handle.dispose();
    });

    testWidgets('use a different email clears pending and returns to login', (final tester) async {
      await _pump(tester, screen: const OtpScreen(email: 'a@b.com'), size: const Size(390, 844));
      final container = ProviderScope.containerOf(tester.element(find.byType(OtpScreen)));
      container.read(otpPendingProvider.notifier).setPending(email: 'a@b.com', password: 'secret1');
      expect(container.read(otpPendingProvider), isTrue);
      await tester.tap(find.text('Use a different email'));
      await tester.pumpAndSettle();
      expect(find.text('LOGIN'), findsOneWidget);
      expect(container.read(otpPendingProvider), isFalse);
      expect(container.read(otpPendingProvider.notifier).pendingPassword, isEmpty);
    });
  });
}
