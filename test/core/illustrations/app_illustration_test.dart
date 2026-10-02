import 'package:cashlyze/core/api/api_exception.dart';
import 'package:cashlyze/core/illustrations/app_illustration.dart';
import 'package:cashlyze/core/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(final Widget child, {final Brightness brightness = Brightness.light, final double textScale = 1}) =>
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(body: child),
      ),
    );

void main() {
  group('illustrationForError', () {
    test('network and timeout failures read as offline', () {
      expect(illustrationForError(const NetworkException()), AppIllustrationKind.offline);
      expect(illustrationForError(const TimeoutException()), AppIllustrationKind.offline);
    });

    test('everything else is the calm error scene', () {
      expect(illustrationForError(const ServerException()), AppIllustrationKind.error);
      expect(illustrationForError(StateError('x')), AppIllustrationKind.error);
    });
  });

  group('AppEmptyState', () {
    testWidgets('shows the illustration when there is room', (final tester) async {
      tester.view
        ..physicalSize = const Size(800, 1600)
        ..devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(const Center(
        child: AppEmptyState(
          title: 'No budgets',
          icon: Icons.account_balance_wallet,
          illustration: AppIllustrationKind.envelope,
        ),
      )));
      await tester.pumpAndSettle();

      expect(find.byType(AppIllustration), findsOneWidget);
      expect(find.byIcon(Icons.account_balance_wallet), findsNothing);
    });

    testWidgets('falls back to the icon when text is scaled up, keeping title and CTA', (final tester) async {
      await tester.pumpWidget(_host(
        Center(
          child: AppEmptyState(
            title: 'No budgets',
            icon: Icons.account_balance_wallet,
            illustration: AppIllustrationKind.envelope,
            actionLabel: 'Create budget',
            onAction: () {},
          ),
        ),
        textScale: 2,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(AppIllustration), findsNothing);
      expect(find.byIcon(Icons.account_balance_wallet), findsOneWidget);
      expect(find.text('Create budget'), findsOneWidget);
    });

    testWidgets('falls back to the icon on a short viewport', (final tester) async {
      tester.view
        ..physicalSize = const Size(800, 600)
        ..devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(const Center(
        child: AppEmptyState(
          title: 'No budgets',
          icon: Icons.account_balance_wallet,
          illustration: AppIllustrationKind.envelope,
        ),
      )));
      await tester.pumpAndSettle();

      expect(find.byType(AppIllustration), findsNothing);
      expect(find.byIcon(Icons.account_balance_wallet), findsOneWidget);
    });

    testWidgets('compact is text only', (final tester) async {
      await tester.pumpWidget(_host(const AppEmptyState(
        title: 'No data',
        icon: Icons.pie_chart_rounded,
        illustration: AppIllustrationKind.chart,
        compact: true,
      )));
      await tester.pumpAndSettle();

      expect(find.byType(AppIllustration), findsNothing);
      expect(find.byIcon(Icons.pie_chart_rounded), findsNothing);
      expect(find.text('No data'), findsOneWidget);
    });

    testWidgets('legacy icon-only call sites are unchanged', (final tester) async {
      await tester.pumpWidget(_host(const Center(
        child: AppEmptyState(title: 'Start typing', icon: Icons.search_outlined),
      )));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.search_outlined), findsOneWidget);
    });
  });

  testWidgets('contact sheet: every scene, light and dark', (final tester) async {
    tester.view
      ..physicalSize = const Size(1500, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Widget sheet(final Brightness b) => Theme(
          data: ThemeData(brightness: b),
          child: ColoredBox(
            color: b == Brightness.dark ? const Color(0xFF09131A) : const Color(0xFFF2F7F8),
            child: Wrap(
              alignment: WrapAlignment.center,
              runAlignment: WrapAlignment.center,
              spacing: 24,
              runSpacing: 12,
              children: [
                for (final k in AppIllustrationKind.values) AppIllustration(k, width: 200),
              ],
            ),
          ),
        );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RepaintBoundary(
            key: const ValueKey('sheet'),
            child: Column(
              children: [
                Expanded(child: sheet(Brightness.light)),
                Expanded(child: sheet(Brightness.dark)),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(find.byKey(const ValueKey('sheet')), matchesGoldenFile('goldens/illustrations_sheet.png'));
  });
}
