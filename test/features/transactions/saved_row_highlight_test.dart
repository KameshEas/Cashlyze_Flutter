import 'package:cashlyze/core/models/category.dart';
import 'package:cashlyze/core/models/transaction.dart';
import 'package:cashlyze/core/repositories/category_repository.dart';
import 'package:cashlyze/features/transactions/transaction_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _tx = TransactionModel(
  id: 't1',
  userId: 'u',
  title: 'Coffee',
  amount: -120,
  date: DateTime(2026, 1, 5),
);

Widget _host({required final bool highlight, final bool reduce = false}) => ProviderScope(
      overrides: [userCategoriesProvider.overrideWith((final ref) => Stream.value(<CategoryModel>[]))],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduce),
          child: Scaffold(
            body: TransactionListItem(tx: _tx, currency: '₹', datePattern: 'dd MMM', highlight: highlight),
          ),
        ),
      ),
    );

Color _rowFill(final WidgetTester tester) => tester
    .widget<Material>(find.descendant(of: find.byType(TransactionListItem), matching: find.byType(Material)).first)
    .color!;

void main() {
  testWidgets('a saved row starts tinted and fades back to the normal surface', (final tester) async {
    await tester.pumpWidget(_host(highlight: false));
    await tester.pump();
    final normal = _rowFill(tester);

    await tester.pumpWidget(_host(highlight: true));
    final tinted = _rowFill(tester);
    expect(tinted, isNot(normal));

    await tester.pump(kSavedHighlightDuration ~/ 2);
    final mid = _rowFill(tester);
    expect(mid, isNot(tinted));
    expect(mid, isNot(normal));

    await tester.pumpAndSettle();
    expect(_rowFill(tester), normal);
  });

  testWidgets('reduced motion skips the tint entirely', (final tester) async {
    await tester.pumpWidget(_host(highlight: false, reduce: true));
    await tester.pump();
    final normal = _rowFill(tester);

    await tester.pumpWidget(_host(highlight: true, reduce: true));
    await tester.pump();
    expect(_rowFill(tester), normal);
  });

  testWidgets('rows that are not highlighted never animate', (final tester) async {
    await tester.pumpWidget(_host(highlight: false));
    await tester.pump();
    final before = _rowFill(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(_rowFill(tester), before);
  });
}
