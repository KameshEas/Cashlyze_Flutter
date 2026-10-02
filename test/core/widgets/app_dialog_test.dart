import 'package:cashlyze/core/widgets/dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({final bool reduce = false, required final void Function(BuildContext) onOpen}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduce),
        child: Builder(
          builder: (final context) => Scaffold(
            body: TextButton(onPressed: () => onOpen(context), child: const Text('open')),
          ),
        ),
      ),
    );

double _dialogScale(final WidgetTester tester) => tester
    .widgetList<ScaleTransition>(find.ancestor(of: find.byType(AlertDialog), matching: find.byType(ScaleTransition)))
    .first
    .scale
    .value;

void main() {
  testWidgets('dialog scales in from 0.96 and settles at 1', (final tester) async {
    await tester.pumpWidget(_host(onOpen: (final c) => showConfirmDialog(c, title: 'T', content: 'C')));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(_dialogScale(tester), lessThan(1));
    expect(_dialogScale(tester), greaterThanOrEqualTo(0.96));

    await tester.pumpAndSettle();
    expect(_dialogScale(tester), 1);
    expect(find.text('T'), findsOneWidget);
  });

  testWidgets('returns the chosen value and dismisses', (final tester) async {
    bool? result;
    await tester.pumpWidget(_host(onOpen: (final c) async => result = await showConfirmDialog(c, title: 'T', content: 'C')));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('reduced motion shows the dialog without animating', (final tester) async {
    await tester.pumpWidget(_host(reduce: true, onOpen: (final c) => showConfirmDialog(c, title: 'T', content: 'C')));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(_dialogScale(tester), 1);
  });
}
