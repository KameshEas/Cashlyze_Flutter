import 'package:cashlyze/core/providers/shared_prefs_provider.dart';
import 'package:cashlyze/routes/widgets/app_shell_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildApp() {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (final context, final state, final navigationShell) =>
            AppShellScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/', builder: (final context, final state) => const Text('Home Page')),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/other', builder: (final context, final state) => const Text('Other Page')),
            ],
          ),
        ],
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  setUp(() {
    // Prevent AppBottomNavBar's first-launch quick-menu coachmark dialog
    // from popping up and interfering with these back-button tests.
    SharedPreferences.setMockInitialValues({'first_time_quick_menu_tutorial_seen': true});
  });

  Future<ProviderScope> buildScope() async {
    final prefs = await SharedPreferences.getInstance();
    return ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: _buildApp(),
    );
  }

  testWidgets('back on Home tab shows a log-out confirmation instead of exiting', (
    final WidgetTester tester,
  ) async {
    await tester.pumpWidget(await buildScope());
    await tester.pumpAndSettle();

    expect(find.text('Home Page'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Are you sure you want to log out?'), findsOneWidget);

    // Cancelling must not navigate away or crash.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Home Page'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('back on a non-Home tab returns to Home instead of showing the dialog', (
    final WidgetTester tester,
  ) async {
    await tester.pumpWidget(await buildScope());
    await tester.pumpAndSettle();

    GoRouter.of(tester.element(find.text('Home Page'))).go('/other');
    await tester.pumpAndSettle();
    expect(find.text('Other Page'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Home Page'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
