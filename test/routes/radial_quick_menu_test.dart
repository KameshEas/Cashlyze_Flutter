import 'package:cashlyze/routes/widgets/radial_quick_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Widget _buildApp(final List<String> navigatedTo) {
  return ProviderScope(
    child: MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (final context, final state) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showRadialQuickMenu(context),
                  child: const Text('Open menu'),
                ),
              ),
            ),
          ),
          for (final path in ['/goals', '/categories', '/emi', '/search', '/scan', '/help_center'])
            GoRoute(
              path: path,
              builder: (final context, final state) {
                navigatedTo.add(path);
                return Scaffold(body: Text('Screen for $path'));
              },
            ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('shows all six quick-menu items with no overflow', (
    final WidgetTester tester,
  ) async {
    await tester.pumpWidget(_buildApp([]));
    await tester.tap(find.text('Open menu'));
    await tester.pumpAndSettle();

    for (final label in ['Goals', 'Categories', 'EMI', 'Search', 'Scan', 'Help']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping an item closes the menu and navigates to its route', (
    final WidgetTester tester,
  ) async {
    final navigatedTo = <String>[];
    await tester.pumpWidget(_buildApp(navigatedTo));
    await tester.tap(find.text('Open menu'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Goals'));
    await tester.pumpAndSettle();

    expect(navigatedTo, contains('/goals'));
    expect(find.text('Open menu'), findsNothing);
    expect(find.text('Screen for /goals'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping the scrim dismisses the menu without navigating', (
    final WidgetTester tester,
  ) async {
    final navigatedTo = <String>[];
    await tester.pumpWidget(_buildApp(navigatedTo));
    await tester.tap(find.text('Open menu'));
    await tester.pumpAndSettle();

    // Tap a corner of the screen, away from any fanned-out item.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(navigatedTo, isEmpty);
    expect(find.text('Open menu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens and closes instantly under reduce motion', (
    final WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _buildApp([]),
      ),
    );
    await tester.tap(find.text('Open menu'));
    await tester.pump();

    expect(find.text('Goals'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fits within a narrow 360dp-wide screen with no overflow', (
    final WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildApp([]));
    await tester.tap(find.text('Open menu'));
    await tester.pumpAndSettle();

    for (final label in ['Goals', 'Categories', 'EMI', 'Search', 'Scan', 'Help']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
}
