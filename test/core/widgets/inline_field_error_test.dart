import 'package:cashlyze/core/widgets/inline_field_error.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(final String? message, {final bool reduce = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduce),
        child: Scaffold(
          body: Column(children: [InlineFieldError(message: message), const Text('below')]),
        ),
      ),
    );

void main() {
  testWidgets('reserves no space without a message', (final tester) async {
    await tester.pumpWidget(_host(null));
    expect(tester.getSize(find.byType(InlineFieldError)).height, 0);
  });

  testWidgets('grows in with the message, and the field below moves down smoothly', (final tester) async {
    await tester.pumpWidget(_host(null));
    final y0 = tester.getTopLeft(find.text('below')).dy;

    await tester.pumpWidget(_host('Enter a valid amount'));
    await tester.pump(const Duration(milliseconds: 60));
    final yMid = tester.getTopLeft(find.text('below')).dy;
    await tester.pumpAndSettle();
    final yEnd = tester.getTopLeft(find.text('below')).dy;

    expect(find.text('Enter a valid amount'), findsOneWidget);
    expect(yMid, greaterThan(y0));
    expect(yMid, lessThan(yEnd));
  });

  testWidgets('is not colour-only: shows an icon and announces itself', (final tester) async {
    await tester.pumpWidget(_host('Enter a title'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    final semantics = tester.getSemantics(find.text('Enter a title'));
    expect(semantics.label, contains('Enter a title'));
  });

  testWidgets('clears when the message goes away', (final tester) async {
    await tester.pumpWidget(_host('Enter a title'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_host(null));
    await tester.pumpAndSettle();
    expect(find.text('Enter a title'), findsNothing);
    expect(tester.getSize(find.byType(InlineFieldError)).height, 0);
  });

  testWidgets('reduced motion swaps instantly', (final tester) async {
    await tester.pumpWidget(_host(null, reduce: true));
    final y0 = tester.getTopLeft(find.text('below')).dy;
    await tester.pumpWidget(_host('Enter a title', reduce: true));
    await tester.pump();
    expect(find.text('Enter a title'), findsOneWidget);
    expect(tester.getTopLeft(find.text('below')).dy, greaterThan(y0));
  });
}
