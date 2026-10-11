import 'package:cashlyze/core/models/account.dart';
import 'package:cashlyze/core/models/auth_user.dart';
import 'package:cashlyze/core/models/budget.dart';
import 'package:cashlyze/core/models/category.dart';
import 'package:cashlyze/core/models/transaction.dart';
import 'package:cashlyze/core/providers/shared_prefs_provider.dart';
import 'package:cashlyze/core/repositories/budget_repository.dart';
import 'package:cashlyze/core/repositories/category_repository.dart';
import 'package:cashlyze/core/repositories/transaction_repository.dart';
import 'package:cashlyze/core/services/auth_service.dart';
import 'package:cashlyze/core/theme/app_theme.dart';
import 'package:cashlyze/core/widgets/scrollable_column.dart';
import 'package:cashlyze/features/accounts/account_form_sheet.dart';
import 'package:cashlyze/features/accounts/data/account_remote_data_source.dart';
import 'package:cashlyze/features/transactions/transaction_filter_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAccountDs extends Fake implements AccountRemoteDataSource {
  _FakeAccountDs(this.accounts);
  final List<AccountModel> accounts;

  @override
  Future<List<AccountModel>> getAll() async => accounts;

  @override
  Future<List<AccountType>> getTypes() async => const [
        AccountType(id: 'at_3', name: 'Credit Card'),
        AccountType(id: 'at_7', name: 'Debit Card'),
        AccountType(id: 'at_8', name: 'UPI'),
        AccountType(id: 'at_9', name: 'Cash'),
        AccountType(id: 'at_1', name: 'Checking'),
        AccountType(id: 'at_5', name: 'Investment'),
        AccountType(id: 'at_6', name: 'Loan'),
        AccountType(id: 'at_2', name: 'Savings'),
        AccountType(id: 'at_4', name: 'Wallet'),
      ];
}

/// A phone-sized screen, larger text and the keyboard up: the combination that
/// makes a non-scrolling sheet overflow.
Future<void> _pumpSheetHost(
  final WidgetTester tester, {
  required final Widget sheet,
  required final List<AccountModel> accounts,
  final Size size = const Size(360, 640),
  final double textScale = 1.3,
  final double keyboard = 0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      currentUserProvider.overrideWithValue(const AuthUser(userId: 'u', email: 'a@b.com')),
      accountRemoteDataSourceProvider.overrideWithValue(_FakeAccountDs(accounts)),
      userCategoriesProvider.overrideWith((final ref) => Stream.value(<CategoryModel>[])),
      userBudgetsProvider.overrideWith((final ref) => Stream.value(<BudgetModel>[])),
      userTransactionsProvider.overrideWith((final ref) => Stream.value(<TransactionModel>[])),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (final context, final child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Builder(
        builder: (final context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (final _) => sheet,
              ),
              child: const Text('OPEN'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('OPEN'));
  await tester.pumpAndSettle();
}

List<AccountModel> _many(final int n) => [
      for (var i = 0; i < n; i++)
        AccountModel(
          id: 'a$i',
          name: ['HSBC Platinum', 'Axis Neo', 'RBL', 'Yes Bank', 'Default Account', 'PhonePe', 'Cash wallet', 'SBI Debit'][i % 8],
          typeId: 'at_3',
          typeName: 'Credit Card',
          last4: '${1000 + i}',
        ),
    ];

void main() {
  group('sheets scroll instead of overflowing', () {
    for (final keyboard in [0.0, 280.0]) {
      testWidgets('filter sheet with many accounts, big text, keyboard=$keyboard', (final tester) async {
        await _pumpSheetHost(
          tester,
          sheet: const TransactionFilterSheet(),
          accounts: _many(8),
          keyboard: keyboard,
        );
        // Overflow is reported as an exception ("A RenderFlex overflowed ...").
        expect(tester.takeException(), isNull);

        // The primary action at the bottom must still be reachable.
        await tester.scrollUntilVisible(find.text('Apply'), 200, scrollable: find.byType(Scrollable).first);
        expect(find.text('Apply'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('add-account sheet on a small phone with the keyboard up', (final tester) async {
      await _pumpSheetHost(tester, sheet: const AccountFormSheet(), accounts: const [], keyboard: 300);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Add account').last, 200, scrollable: find.byType(Scrollable).first);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ScrollableColumn shrink-wraps when everything fits and scrolls when it does not', (final tester) async {
      tester.view.physicalSize = const Size(300, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      Widget host(final int count) => MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: ScrollableColumn(children: [for (var i = 0; i < count; i++) SizedBox(height: 50, child: Text('row $i'))]),
              ),
            ),
          );

      await tester.pumpWidget(host(2));
      expect(tester.getSize(find.byType(ScrollableColumn)).height, 100); // fits: exactly its content

      await tester.pumpWidget(host(30)); // 1500px of content in a 400px screen
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(ScrollableColumn)).height, 400); // capped, and scrollable
    });
  });

  group('chip labels are readable in every state', () {
    for (final dark in [false, true]) {
      testWidgets('${dark ? 'dark' : 'light'} theme', (final tester) async {
        final theme = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
        await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Wrap(children: [
              FilterChip(label: const Text('fu'), onSelected: (_) {}),
              FilterChip(label: const Text('fs'), selected: true, onSelected: (_) {}),
              ChoiceChip(label: const Text('cu'), selected: false, onSelected: (_) {}),
              ChoiceChip(label: const Text('cs'), selected: true, onSelected: (_) {}),
              const Chip(label: Text('plain')),
            ]),
          ),
        ));

        Color? labelColor(final String t) => DefaultTextStyle.of(tester.element(find.text(t))).style.color;
        final onSurface = theme.colorScheme.onSurface;

        // Unselected labels use the normal text colour (they sit on a pale/dark
        // chip), which is what was white-on-pale and unreadable before.
        for (final t in ['fu', 'cu', 'plain']) {
          expect(labelColor(t), onSurface, reason: '$t should use onSurface');
        }
        // Selected chips are filled with the primary colour, so the label flips to white.
        for (final t in ['fs', 'cs']) {
          expect(labelColor(t), Colors.white, reason: '$t should be white on the filled chip');
        }
      });
    }
  });
}
