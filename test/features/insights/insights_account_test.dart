import 'package:cashlyze/core/models/account.dart';
import 'package:cashlyze/core/models/auth_user.dart';
import 'package:cashlyze/core/models/category.dart';
import 'package:cashlyze/core/models/transaction.dart';
import 'package:cashlyze/core/providers/budget_analytics_providers.dart';
import 'package:cashlyze/core/providers/insights_account_providers.dart';
import 'package:cashlyze/core/providers/shared_prefs_provider.dart';
import 'package:cashlyze/core/providers/transaction_providers.dart';
import 'package:cashlyze/core/repositories/category_repository.dart';
import 'package:cashlyze/core/services/auth_service.dart';
import 'package:cashlyze/core/theme/app_theme.dart';
import 'package:cashlyze/features/accounts/data/account_remote_data_source.dart';
import 'package:cashlyze/features/insights/insights_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _defaultAcc = AccountModel(id: 'defacc', name: 'Default Account', typeId: 'at_1', typeName: 'Checking');
const _card = AccountModel(
  id: 'card1',
  name: 'HDFC Regalia',
  typeId: 'at_3',
  typeName: 'Credit Card',
  institution: 'HDFC',
  last4: '4821',
);
const _upi = AccountModel(id: 'upi1', name: 'PhonePe', typeId: 'at_8', typeName: 'UPI');

class _FakeAccountDs extends Fake implements AccountRemoteDataSource {
  _FakeAccountDs(this.accounts);
  final List<AccountModel> accounts;

  @override
  Future<List<AccountModel>> getAll() async => accounts;
}

DateTime _daysAgo(final int d) => DateTime.now().subtract(Duration(days: d));

TransactionModel _tx(final String id, final double amount, final String? account, {final int daysAgo = 2}) =>
    TransactionModel(id: id, userId: 'u1', title: id, amount: amount, date: _daysAgo(daysAgo), accountId: account);

final _transactions = [
  _tx('no-account', -1000, null), // chosen nothing -> default account
  _tx('on-default', -500, 'defacc'), // the server-made Default Account
  _tx('on-card', -300, 'card1'),
  _tx('on-upi', -100, 'upi1'),
  _tx('salary', 2000, 'card1'), // income on the card
  _tx('too-old', -9999, null, daysAgo: 200), // outside every range
];

Future<ProviderContainer> _pump(
  final WidgetTester tester, {
  final Size size = const Size(412, 900),
  final double textScale = 1.0,
  final List<AccountModel> accounts = const [_defaultAcc, _card, _upi],
  final List<TransactionModel>? txs,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    sharedPrefsProvider.overrideWithValue(prefs),
    currentUserProvider.overrideWithValue(const AuthUser(userId: 'u1', email: 'a@b.com')),
    accountRemoteDataSourceProvider.overrideWithValue(_FakeAccountDs([...accounts])),
    recentTransactionsProvider.overrideWith((final ref) => Stream.value(txs ?? _transactions)),
    userCategoriesProvider.overrideWith((final ref) => Stream.value(<CategoryModel>[])),
    serverCategoryBreakdownProvider.overrideWith((final ref) async => <String, double>{'Food': 1900}),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (final context, final child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: const InsightsScreen(),
    ),
  ));
  await tester.pumpAndSettle();
  return container;
}

Future<void> _choose(final WidgetTester tester, final String chipLabel) async {
  final chip = find.widgetWithText(ChoiceChip, chipLabel);
  await tester.ensureVisible(chip); // the chip row scrolls sideways
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

String _heroCaption(final WidgetTester tester) => tester
    .widgetList<Text>(find.textContaining(' · Last '))
    .map((final t) => t.data!)
    .firstWhere((final s) => s.contains('transaction'));

void main() {
  group('account scope', () {
    testWidgets('starts on the Default account: transactions with no account count towards it', (final tester) async {
      await _pump(tester);

      final chip = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Default account'));
      expect(chip.selected, isTrue);
      // 'no-account' (null) + 'on-default' (the real Default Account) only.
      expect(_heroCaption(tester), 'Default account · Last 30 days · 2 transactions');
      // Spend by account lists the default bucket once, with both transactions.
      expect(find.text('Default account'), findsWidgets);
    });

    testWidgets('All accounts widens to everything in the period (and still ignores old data)', (final tester) async {
      await _pump(tester);
      await _choose(tester, 'All accounts');
      expect(_heroCaption(tester), 'All accounts · Last 30 days · 5 transactions');
    });

    testWidgets('choosing a card narrows to that card', (final tester) async {
      await _pump(tester);
      await _choose(tester, 'HDFC Regalia •• 4821');
      expect(_heroCaption(tester), 'HDFC Regalia •• 4821 · Last 30 days · 2 transactions');
    });

    testWidgets('the server-made "Default Account" is not offered as a second chip', (final tester) async {
      await _pump(tester);
      expect(find.widgetWithText(ChoiceChip, 'Default Account'), findsNothing);
      expect(find.widgetWithText(ChoiceChip, 'PhonePe'), findsOneWidget);
    });

    testWidgets('tapping a row in "Spend by account" drills into that account', (final tester) async {
      final c = await _pump(tester);
      await tester.scrollUntilVisible(find.text('PhonePe').last, 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('PhonePe').last);
      await tester.pumpAndSettle();
      expect(c.read(insightsAccountProvider), 'upi1');
    });

    testWidgets('a selected account that has been deleted falls back to the default', (final tester) async {
      final c = await _pump(tester);
      c.read(insightsAccountProvider.notifier).select('deleted-account');
      await tester.pumpAndSettle();
      expect(c.read(effectiveInsightsAccountProvider), kInsightsAccountDefault);
    });

    testWidgets('with no accounts at all everything is the default account', (final tester) async {
      await _pump(tester, accounts: const [], txs: [_tx('a', -200, null), _tx('b', -300, null)]);
      expect(_heroCaption(tester), 'Default account · Last 30 days · 2 transactions');
    });
  });

  group('spend by account provider', () {
    testWidgets('groups untagged spend under the default account and ranks by amount', (final tester) async {
      final c = await _pump(tester);
      final rows = c.read(accountSpendRowsProvider);
      expect(rows.map((final r) => r.name).toList(), ['Default account', 'HDFC Regalia •• 4821', 'PhonePe']);
      expect(rows.first.spend, 1500); // 1000 (no account) + 500 (Default Account)
      expect(rows.first.count, 2);
      expect(rows[1].spend, 300); // income on the card is not spend
    });
  });

  group('layout', () {
    testWidgets('the four figures are equal tiles with values on one left edge', (final tester) async {
      await _pump(tester);
      Rect rect(final String k) => tester.getRect(find.byKey(ValueKey('stat-$k')));
      final income = rect('income'), expenses = rect('expenses'), savings = rect('savings'), daily = rect('daily');

      // A true 2x2 grid: columns and rows line up, tiles are the same size.
      expect(income.left, savings.left);
      expect(expenses.left, daily.left);
      expect(income.top, expenses.top);
      expect(savings.top, daily.top);
      expect(income.size, expenses.size);
      expect(savings.size, daily.size);
      expect(income.width, closeTo(expenses.width, 0.01));
      // Page gutters: 16 on both sides.
      expect(income.left, 16);
      expect(expenses.right, 412 - 16);

      // The bug: AmountText values used to start at different x than plain ones.
      // Each value must now start exactly at its tile's padding edge.
      for (final k in ['income', 'expenses', 'savings', 'daily']) {
        final tile = find.byKey(ValueKey('stat-$k'));
        final value = tester.getTopLeft(find.descendant(of: tile, matching: find.byType(Text)).last);
        expect(value.dx - rect(k).left, 16 + 1, reason: '$k value should sit on the tile padding edge (border 1 + padding 16)');
      }
    });

    for (final scale in [1.0, 1.4]) {
      testWidgets('no overflow on a small phone at ${scale}x text', (final tester) async {
        await _pump(tester, size: const Size(360, 700), textScale: scale);
        expect(tester.takeException(), isNull);
        // Section titles are drawn upper-case, so match case-insensitively.
        final recurringTitle = find.byWidgetPredicate(
          (final w) => w is Text && (w.data ?? '').toLowerCase() == 'recurring payments',
        );
        await tester.scrollUntilVisible(recurringTitle, 300, scrollable: find.byType(Scrollable).first);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
