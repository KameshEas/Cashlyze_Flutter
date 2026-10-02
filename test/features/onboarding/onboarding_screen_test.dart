import 'package:cashlyze/core/providers/shared_prefs_provider.dart';
import 'package:cashlyze/core/services/analytics_service.dart';
import 'package:cashlyze/core/theme/app_theme.dart';
import 'package:cashlyze/features/onboarding/onboarding_screen.dart';
import 'package:cashlyze/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAnalytics extends Fake implements AnalyticsService {
  final List<(String, Map<String, Object?>?)> events = [];

  @override
  Future<void> logEvent(final String name, {final Map<String, Object?>? params}) async =>
      events.add((name, params));
}

Future<_FakeAnalytics> _pump(
  final WidgetTester tester, {
  required final Size size,
  final double textScale = 1.0,
  final bool dark = false,
  final Locale locale = const Locale('en'),
  final bool disableAnimations = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final analytics = _FakeAnalytics();
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, _) => const OnboardingScreen()),
    GoRoute(path: '/login', builder: (_, _) => const Scaffold(body: Text('LOGIN'))),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      analyticsServiceProvider.overrideWithValue(analytics),
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
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
        ),
        child: child!,
      ),
      routerConfig: router,
    ),
  ));
  await tester.pumpAndSettle();
  return analytics;
}

void main() {
  const sizes = <String, Size>{
    'small 320x568': Size(320, 568),
    'standard 360x640': Size(360, 640),
    'common 390x844': Size(390, 844),
    'large 430x932': Size(430, 932),
    'tall 412x915': Size(412, 915),
    'short landscape 740x360': Size(740, 360),
  };

  group('layout (no overflow)', () {
    for (final e in sizes.entries) {
      for (final scale in [1.0, 2.0]) {
        for (final dark in [false, true]) {
          testWidgets('${e.key} x$scale ${dark ? 'dark' : 'light'}', (final tester) async {
            await _pump(tester, size: e.value, textScale: scale, dark: dark);
            expect(tester.takeException(), isNull);
            for (var i = 0; i < 2; i++) {
              await tester.tap(find.byType(FilledButton));
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            }
          });
        }
      }
    }
    for (final loc in ['hi', 'ta']) {
      testWidgets('locale $loc at 360x640 x1.3', (final tester) async {
        await _pump(tester, size: const Size(360, 640), textScale: 1.3, locale: Locale(loc));
        expect(tester.takeException(), isNull);
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('behaviour', () {
    testWidgets('Next advances, Back returns, Skip hidden on last page', (final tester) async {
      await _pump(tester, size: const Size(390, 844));
      expect(find.text('See where your money goes'), findsOneWidget);
      expect(find.byTooltip('Back'), findsNothing);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Budgets that keep you on track'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('See where your money goes'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('Skip'), findsNothing);
    });

    testWidgets('Get Started logs once, persists, and goes to /login', (final tester) async {
      final analytics = await _pump(tester, size: const Size(390, 844));
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Get Started'));
      await tester.pump(); // second tap lands before navigation completes
      await tester.tap(find.byType(FilledButton), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('LOGIN'), findsOneWidget);
      expect(analytics.events.length, 1);
      expect(analytics.events.single.$1, 'onboarding_completed');
      expect(analytics.events.single.$2?['method'], 'slides');
      expect(analytics.events.single.$2?['steps'], 3);
    });

    testWidgets('Skip logs method=skip with the step reached', (final tester) async {
      final analytics = await _pump(tester, size: const Size(390, 844));
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.text('LOGIN'), findsOneWidget);
      expect(analytics.events.single.$2?['method'], 'skip');
      expect(analytics.events.single.$2?['steps'], 1);
    });

    testWidgets('swipe navigates between pages', (final tester) async {
      await _pump(tester, size: const Size(390, 844));
      await tester.fling(find.byType(PageView), const Offset(-250, 0), 2000);
      await tester.pumpAndSettle();
      expect(find.text('Budgets that keep you on track'), findsOneWidget);
    });
  });

  group('accessibility', () {
    testWidgets('exposes step progress and illustration description', (final tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, size: const Size(390, 844));
      expect(find.bySemanticsLabel('Step 1 of 3'), findsOneWidget);
      expect(find.bySemanticsLabel('Illustration: a list of categorised transactions'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Step 2 of 3'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('tap targets are at least 48dp', (final tester) async {
      await _pump(tester, size: const Size(360, 640));
      expect(tester.getSize(find.byType(FilledButton)).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(find.widgetWithText(TextButton, 'Skip')).height, greaterThanOrEqualTo(48));
    });

    testWidgets('reduced motion renders without errors', (final tester) async {
      await _pump(tester, size: const Size(390, 844), disableAnimations: true);
      expect(tester.takeException(), isNull);
    });
  });
}
