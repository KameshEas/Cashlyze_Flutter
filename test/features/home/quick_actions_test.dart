import 'package:cashlyze/features/home/widgets/quick_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _scheme = ColorScheme.light(
  primary: Color(0xFF115A68),
  primaryContainer: Color(0xFFD7ECEF),
);

Future<void> _pump(
  final WidgetTester tester, {
  final Size size = const Size(360, 800),
  final double textScale = 1,
  final bool reduce = false,
}) async {
  tester.view
    ..physicalSize = size * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(
          body: Padding(padding: EdgeInsets.all(16), child: QuickActions()),
        ),
      ),
      GoRoute(path: '/scan', builder: (_, _) => const Scaffold(body: Text('SCAN PAGE'))),
      GoRoute(path: '/emi/new', builder: (_, _) => const Scaffold(body: Text('EMI PAGE'))),
      GoRoute(path: '/budgets', builder: (_, _) => const Scaffold(body: Text('BUDGETS PAGE'))),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(
        theme: ThemeData(colorScheme: _scheme),
        routerConfig: router,
        builder: (final context, final child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: reduce,
          ),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Color _buttonColor(final WidgetTester tester, final IconData icon) {
  final container = tester.widget<Container>(
    find.ancestor(of: find.byIcon(icon), matching: find.byType(Container)).first,
  );
  return (container.decoration! as BoxDecoration).color!;
}

void main() {
  testWidgets('shows the five actions with short one-line labels', (final tester) async {
    await _pump(tester);
    for (final label in ['Expense', 'Top-up', 'EMI', 'Budget', 'Scan']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('daily money actions are solid, occasional ones are tonal', (final tester) async {
    await _pump(tester);
    expect(_buttonColor(tester, Icons.north_east_rounded), _scheme.primary);
    expect(_buttonColor(tester, Icons.south_west_rounded), _scheme.primary);
    expect(_buttonColor(tester, Icons.payments_outlined), _scheme.primaryContainer);
    expect(_buttonColor(tester, Icons.donut_small_rounded), _scheme.primaryContainer);
    expect(_buttonColor(tester, Icons.document_scanner_outlined), _scheme.primaryContainer);
  });

  testWidgets('no action is colour-coded beyond the two tiers', (final tester) async {
    await _pump(tester);
    final colors = {
      for (final i in [
        Icons.north_east_rounded,
        Icons.south_west_rounded,
        Icons.payments_outlined,
        Icons.donut_small_rounded,
        Icons.document_scanner_outlined,
      ])
        _buttonColor(tester, i),
    };
    expect(colors, {_scheme.primary, _scheme.primaryContainer});
  });

  testWidgets('every button is the same size and sits on one baseline', (final tester) async {
    await _pump(tester);
    final rects = [
      for (final i in [
        Icons.north_east_rounded,
        Icons.south_west_rounded,
        Icons.payments_outlined,
        Icons.donut_small_rounded,
        Icons.document_scanner_outlined,
      ])
        tester.getRect(find.ancestor(of: find.byIcon(i), matching: find.byType(Container)).first),
    ];
    for (final r in rects) {
      expect(r.width, closeTo(56, 0.01));
      expect(r.height, closeTo(56, 0.01));
      expect(r.top, closeTo(rects.first.top, 0.01));
    }
  });

  testWidgets('tapping a route action navigates there', (final tester) async {
    await _pump(tester);
    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();
    expect(find.text('SCAN PAGE'), findsOneWidget);
  });

  testWidgets('EMI opens the new-plan form; Budget opens the budgets tab route', (final tester) async {
    await _pump(tester);
    await tester.tap(find.text('EMI'));
    await tester.pumpAndSettle();
    expect(find.text('EMI PAGE'), findsOneWidget);
  });

  testWidgets('the tap target is larger than the visible button', (final tester) async {
    await _pump(tester);
    final target = tester.getSize(find.ancestor(of: find.text('Scan'), matching: find.byType(GestureDetector)).first);
    expect(target.height, greaterThanOrEqualTo(72));
    expect(target.width, greaterThanOrEqualTo(48));
  });

  testWidgets('screen readers hear the full action, not the short label', (final tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    expect(find.bySemanticsLabel('Add expense'), findsOneWidget);
    expect(find.bySemanticsLabel('Add income'), findsOneWidget);
    expect(find.bySemanticsLabel('Add EMI'), findsOneWidget);
    expect(find.bySemanticsLabel('Open budgets'), findsOneWidget);
    expect(find.bySemanticsLabel('Scan a receipt'), findsOneWidget);
    handle.dispose();
  });

  for (final (size, scale) in [
    (const Size(320, 640), 1.0),
    (const Size(320, 640), 2.0),
    (const Size(412, 915), 1.3),
  ]) {
    testWidgets('no overflow, labels fit at ${size.width.toInt()}dp, ${scale}x text', (final tester) async {
      await _pump(tester, size: size, textScale: scale);
      expect(tester.takeException(), isNull);
      // Labels scale down to fit their column rather than wrapping/truncating.
      for (final l in ['Expense', 'Top-up', 'EMI', 'Budget', 'Scan']) {
        final label = tester.getRect(find.text(l));
        final column = tester.getRect(find.ancestor(of: find.text(l), matching: find.byType(GestureDetector)).first);
        expect(label.width, lessThanOrEqualTo(column.width + 0.01), reason: '$l fits its column');
        expect(label.height, lessThan(40), reason: '$l stays on one line');
      }
    });
  }

  testWidgets('buttons shrink on a narrow phone but stay tappable', (final tester) async {
    await _pump(tester, size: const Size(320, 640));
    final w = tester.getSize(find.ancestor(of: find.byIcon(Icons.north_east_rounded), matching: find.byType(Container)).first).width;
    expect(w, lessThan(56));
    expect(w, greaterThanOrEqualTo(44));
  });

  testWidgets('works under reduced motion', (final tester) async {
    await _pump(tester, reduce: true);
    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();
    expect(find.text('SCAN PAGE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
