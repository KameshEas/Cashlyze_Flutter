import 'package:cashlyze/core/models/transaction.dart';
import 'package:cashlyze/core/providers/insights_providers.dart';
import 'package:cashlyze/core/providers/shared_prefs_provider.dart';
import 'package:cashlyze/core/repositories/category_repository.dart';
import 'package:cashlyze/core/theme/app_theme.dart';
import 'package:cashlyze/core/ui/finance_style.dart';
import 'package:cashlyze/core/widgets/grouped_list.dart';
import 'package:cashlyze/core/widgets/transaction_row.dart';
import 'package:cashlyze/features/home/widgets/balance_card.dart';
import 'package:cashlyze/features/transactions/transaction_list_item.dart';
import 'package:cashlyze/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

TransactionModel _tx(final String title, final double amount, {final String category = 'Food & Dining'}) =>
    TransactionModel(
      id: title,
      userId: 'u',
      title: title,
      amount: amount,
      categoryName: category,
      date: DateTime(2026, 10, 2, 16, 12),
    );

Future<void> _pump(
  final WidgetTester tester,
  final Widget child, {
  final Size size = const Size(390, 844),
  final double scale = 1.0,
  final bool dark = false,
  final Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      userCategoriesProvider.overrideWith((final ref) => Stream.value(const [])),
      currentMonthKpisProvider.overrideWithValue(const Kpis(25000, 1470.5, 23529.5, 0.94, 49, 4, 420)),
    ],
    child: MaterialApp(
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
      builder: (final context, final c) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: c!,
      ),
      home: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: child)),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('AmountText', () {
    testWidgets('signs: + for income, true minus for expense, none for zero', (final tester) async {
      await _pump(
        tester,
        const Column(children: [
          AmountText(amount: 5000, currency: 'INR'),
          AmountText(amount: -420, currency: 'INR'),
          AmountText(amount: 0, currency: 'INR'),
        ]),
      );
      expect(find.text('+₹5,000.00'), findsOneWidget);
      expect(find.text('$kMinus₹420.00'), findsOneWidget);
      expect(find.text('₹0.00'), findsOneWidget);
      expect(kMinus.codeUnitAt(0), 0x2212);
    });

    testWidgets('screen readers hear the kind of amount, not just a sign', (final tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        const Column(children: [
          AmountText(amount: 5000, currency: 'INR'),
          AmountText(amount: -420, currency: 'INR'),
        ]),
      );
      expect(find.bySemanticsLabel('Income ₹5,000.00'), findsOneWidget);
      expect(find.bySemanticsLabel('Expense ₹420.00'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('uses tabular figures', (final tester) async {
      await _pump(tester, const AmountText(amount: -1, currency: 'INR'));
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.style?.fontFeatures, contains(const FontFeature.tabularFigures()));
    });

    testWidgets('a huge amount scales down instead of overflowing a narrow slot', (final tester) async {
      await _pump(
        tester,
        const SizedBox(width: 90, child: AmountText(amount: -987654321.55, currency: 'INR')),
        scale: 2.0,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('income is green and expense is a distinct soft coral (not the error red)', (final tester) async {
      await _pump(
        tester,
        const Column(children: [
          AmountText(amount: 10, currency: 'INR'),
          AmountText(amount: -10, currency: 'INR'),
          AmountText(amount: 10, currency: 'INR', showSign: false),
        ]),
      );
      final income = tester.widget<Text>(find.text('+₹10.00'));
      final expense = tester.widget<Text>(find.text('$kMinus₹10.00'));
      final plain = tester.widget<Text>(find.text('₹10.00'));
      expect(income.style?.color, const Color(0xFF1B7A4B));
      expect(expense.style?.color, const Color(0xFFC2453B));
      expect(expense.style?.color, isNot(income.style?.color));
      expect(expense.style?.color, isNot(const Color(0xFFEF4444)));
      // Unsigned figures (averages, forecasts) are plain numbers, never tinted.
      expect(plain.style?.color, isNot(income.style?.color));
      expect(plain.style?.color, isNot(expense.style?.color));
    });
  });

  group('SectionLabel', () {
    testWidgets('uppercases for English only (Hindi/Tamil have no case)', (final tester) async {
      await _pump(tester, const SectionLabel('Recent'));
      expect(find.text('RECENT'), findsOneWidget);
      await _pump(tester, const SectionLabel('हाल के'), locale: const Locale('hi'));
      expect(find.text('हाल के'), findsOneWidget);
    });
  });

  group('GroupedRow / GroupedSection', () {
    test('groupPositionOf maps indexes', () {
      expect(groupPositionOf(0, 1), GroupPosition.only);
      expect(groupPositionOf(0, 3), GroupPosition.first);
      expect(groupPositionOf(1, 3), GroupPosition.middle);
      expect(groupPositionOf(2, 3), GroupPosition.last);
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets('section of rows lays out at x$scale on a 320dp phone', (final tester) async {
        await _pump(
          tester,
          GroupedSection(children: [
            for (final t in ['Zomato', 'Uber', 'Amazon'])
              TransactionRow(tx: _tx(t, -420), currency: 'INR'),
          ]),
          size: const Size(320, 640),
          scale: scale,
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(TransactionRow), findsNWidgets(3));
      });
    }

    testWidgets('rows keep a 56dp minimum height for tap targets', (final tester) async {
      await _pump(
        tester,
        GroupedRow(position: GroupPosition.only, onTap: () {}, child: const Text('x')),
      );
      expect(tester.getSize(find.byType(GroupedRow)).height, greaterThanOrEqualTo(56));
    });
  });

  group('TransactionListItem', () {
    const long = 'Monthly electricity bill payment for the apartment including late fee and surcharge';
    for (final loc in ['en', 'hi', 'ta']) {
      for (final scale in [1.0, 2.0]) {
        for (final dark in [false, true]) {
          testWidgets('$loc x$scale ${dark ? 'dark' : 'light'} long title, 320dp', (final tester) async {
            await _pump(
              tester,
              Column(children: [
                TransactionListItem(
                  tx: _tx(long, -1234567.89),
                  currency: 'INR',
                  datePattern: 'yyyy-MM-dd',
                  position: GroupPosition.first,
                ),
                TransactionListItem(
                  tx: _tx('Salary', 250000, category: 'Income'),
                  currency: 'INR',
                  datePattern: 'yyyy-MM-dd',
                  position: GroupPosition.last,
                  selectionMode: true,
                  selected: true,
                ),
              ]),
              size: const Size(320, 700),
              scale: scale,
              dark: dark,
              locale: Locale(loc),
            );
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });

  group('BalanceCard', () {
    for (final scale in [1.0, 2.0]) {
      testWidgets('lays out at x$scale on a 320dp phone with signed figures', (final tester) async {
        await _pump(tester, const BalanceCard(), size: const Size(320, 700), scale: scale);
        expect(tester.takeException(), isNull);
        expect(find.textContaining('₹23,529.50'), findsWidgets);
        expect(find.text('+₹25,000.00'), findsOneWidget);
        expect(find.text('$kMinus₹1,470.50'), findsOneWidget);
      });
    }
  });
}
