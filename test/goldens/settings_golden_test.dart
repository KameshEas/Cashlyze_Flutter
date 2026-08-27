import 'package:cashlyze/core/providers/shared_prefs_provider.dart';
import 'package:cashlyze/core/theme/app_theme.dart';
import 'package:cashlyze/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    // Allow google_fonts to fetch fonts during tests since the app theme
    // requires Plus Jakarta Sans and Inter fonts from Google Fonts.
    try {
      GoogleFonts.config.allowRuntimeFetching = true;
    } catch (_) {}
  });

  testWidgets('Settings screen dark theme golden', (final WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const SettingsScreen())],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: MaterialApp.router(
          theme: AppTheme.darkTheme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byType(SettingsScreen),
      matchesGoldenFile('goldens/settings_dark.png'),
    );
  }, skip: true);

  testWidgets('Settings screen light theme golden', (
    final WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const SettingsScreen())],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byType(SettingsScreen),
      matchesGoldenFile('goldens/settings_light.png'),
    );
  }, skip: true);

  testWidgets(
    'Settings screen 200% text scale golden',
    (final WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const SettingsScreen())],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: MaterialApp.router(
            theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byType(SettingsScreen),
      matchesGoldenFile('goldens/settings_dark_200pct.png'),
    );
  }, skip: true);
}
