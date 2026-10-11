import 'package:cashlyze/core/api/api_exception.dart';
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
import 'package:cashlyze/core/services/transaction_ingest_service.dart';
import 'package:cashlyze/core/theme/app_theme.dart';
import 'package:cashlyze/features/accounts/accounts_screen.dart';
import 'package:cashlyze/features/accounts/data/account_remote_data_source.dart';
import 'package:cashlyze/features/transactions/transaction_filters.dart';
import 'package:cashlyze/features/transactions/transaction_form_sheet.dart';
import 'package:cashlyze/features/transactions/transaction_list_item.dart';
import 'package:cashlyze/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _user = AuthUser(userId: 'u1', email: 'a@b.com');

const _card = AccountModel(
  id: 'card1',
  name: 'HDFC Regalia',
  typeId: 'at_3',
  typeName: 'Credit Card',
  institution: 'HDFC',
  last4: '4821',
);
const _upi = AccountModel(id: 'upi1', name: 'PhonePe', typeId: 'at_8', typeName: 'UPI', upiId: 'me@okhdfc');

const _types = [
  AccountType(id: 'at_3', name: 'Credit Card'),
  AccountType(id: 'at_7', name: 'Debit Card'),
  AccountType(id: 'at_8', name: 'UPI'),
  AccountType(id: 'at_9', name: 'Cash'),
];

class _FakeAccountDs extends Fake implements AccountRemoteDataSource {
  _FakeAccountDs(this.accounts, {this.spend = const []});

  final List<AccountModel> accounts;
  final List<AccountSpend> spend;
  Object? deleteError;
  final List<Map<String, Object?>> created = [];

  @override
  Future<List<AccountModel>> getAll() async => [...accounts];

  @override
  Future<List<AccountType>> getTypes() async => _types;

  @override
  Future<List<AccountSpend>> spendSummary({final DateTime? start, final DateTime? end}) async => spend;

  @override
  Future<AccountModel> create({
    required final String name,
    required final String typeId,
    final String? institution,
    final String? last4,
    final String? upiId,
    final String? currencyCode,
  }) async {
    created.add({'name': name, 'typeId': typeId, 'institution': institution, 'last4': last4, 'upiId': upiId});
    final type = _types.firstWhere((final t) => t.id == typeId);
    final a = AccountModel(
      id: 'new${created.length}',
      name: name,
      typeId: typeId,
      typeName: type.name,
      institution: institution,
      last4: last4,
      upiId: upiId,
    );
    accounts.add(a);
    return a;
  }

  @override
  Future<void> delete(final String id) async {
    if (deleteError != null) throw deleteError!;
    accounts.removeWhere((final a) => a.id == id);
  }
}

class _FakeIngest extends Fake implements TransactionIngestService {
  final List<Map<String, Object?>> calls = [];

  @override
  Future<void> addManual({
    required final String userId,
    required final String title,
    required final double amount,
    required final bool isIncome,
    final String? categoryId,
    final String? categoryName,
    required final DateTime date,
    final String? notes,
    final List<String>? tags,
    final String? accountId,
  }) async {
    calls.add({'title': title, 'amount': amount, 'accountId': accountId});
  }
}

class _Harness {
  _Harness(this.container, this.ds, this.ingest, this.prefs);

  final ProviderContainer container;
  final _FakeAccountDs ds;
  final _FakeIngest ingest;
  final SharedPreferences prefs;
}

Future<_Harness> _pump(
  final WidgetTester tester, {
  required final Widget home,
  final List<AccountModel> accounts = const [],
  final List<AccountSpend> spend = const [],
  final Map<String, Object> prefValues = const {},
}) async {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(prefValues);
  final prefs = await SharedPreferences.getInstance();
  final ds = _FakeAccountDs([...accounts], spend: spend);
  final ingest = _FakeIngest();
  final container = ProviderContainer(overrides: [
    sharedPrefsProvider.overrideWithValue(prefs),
    currentUserProvider.overrideWithValue(_user),
    accountRemoteDataSourceProvider.overrideWithValue(ds),
    userCategoriesProvider.overrideWith((final ref) => Stream.value(<CategoryModel>[])),
    userBudgetsProvider.overrideWith((final ref) => Stream.value(<BudgetModel>[])),
    transactionIngestServiceProvider.overrideWithValue(ingest),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    ),
  ));
  await tester.pumpAndSettle();
  return _Harness(container, ds, ingest, prefs);
}

/// Opens the transaction form the way the app does: as a modal bottom sheet.
Widget _formLauncher() => Builder(
      builder: (final context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => showModalBottomSheet<bool>(
              context: context,
              isScrollControlled: true,
              builder: (final _) => const TransactionFormSheet.create(),
            ),
            child: const Text('OPEN FORM'),
          ),
        ),
      ),
    );

Future<void> _openFormAndFill(final WidgetTester tester) async {
  await tester.tap(find.text('OPEN FORM'));
  await tester.pumpAndSettle();
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), '250'); // amount
  await tester.enterText(fields.at(1), 'Dinner'); // title
}

Future<void> _tapSave(final WidgetTester tester) async {
  final save = find.text('Save');
  await tester.ensureVisible(save);
  await tester.tap(save);
  await tester.pumpAndSettle();
}

void main() {
  group('transaction form: account is required', () {
    testWidgets('saving without an account shows "Choose an account" and does not save', (final tester) async {
      final h = await _pump(tester, home: _formLauncher(), accounts: [_card, _upi]);
      await _openFormAndFill(tester);
      await _tapSave(tester);

      expect(find.text('Choose an account'), findsWidgets);
      expect(h.ingest.calls, isEmpty);
    });

    testWidgets('starts with the last-used account and saves with it', (final tester) async {
      final h = await _pump(
        tester,
        home: _formLauncher(),
        accounts: [_card, _upi],
        prefValues: {'last_used_account_id': 'card1'},
      );
      await _openFormAndFill(tester);
      expect(find.text('HDFC Regalia •• 4821'), findsOneWidget);

      await _tapSave(tester);
      expect(h.ingest.calls.single['accountId'], 'card1');
      expect(h.prefs.getString('last_used_account_id'), 'card1');
    });

    testWidgets('a remembered account that has since been deleted is not silently used', (final tester) async {
      final h = await _pump(
        tester,
        home: _formLauncher(),
        accounts: [_upi],
        prefValues: {'last_used_account_id': 'card1'}, // card1 no longer exists
      );
      await _openFormAndFill(tester);
      await _tapSave(tester);

      expect(find.text('Choose an account'), findsWidgets);
      expect(h.ingest.calls, isEmpty);
    });

    testWidgets('picking an account from the list saves with that account and remembers it', (final tester) async {
      final h = await _pump(tester, home: _formLauncher(), accounts: [_card, _upi]);
      await _openFormAndFill(tester);

      await tester.tap(find.text('Choose an account'));
      await tester.pumpAndSettle();
      expect(find.text('HDFC · •• 4821'), findsOneWidget); // subtitle in the sheet
      await tester.tap(find.text('PhonePe'));
      await tester.pumpAndSettle();

      await _tapSave(tester);
      expect(h.ingest.calls.single['accountId'], 'upi1');
      expect(h.prefs.getString('last_used_account_id'), 'upi1');
    });

    testWidgets('first-time user with no accounts is led to add one, which is then selected', (final tester) async {
      final h = await _pump(tester, home: _formLauncher());
      await _openFormAndFill(tester);

      await tester.tap(find.text('Add your first card or account'));
      await tester.pumpAndSettle();
      expect(find.text('Add account'), findsWidgets); // the add-account sheet

      // Defaults to the first type (Credit Card); give it a name and save.
      await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'My Card');
      await tester.tap(find.widgetWithText(FilledButton, 'Add account'));
      await tester.pumpAndSettle();

      expect(h.ds.created.single['name'], 'My Card');
      expect(find.text('My Card'), findsOneWidget); // now selected in the form

      await _tapSave(tester);
      expect(h.ingest.calls.single['accountId'], 'new1');
    });
  });

  group('transaction list', () {
    final tx = TransactionModel(
      id: 't1',
      userId: 'u1',
      title: 'Dinner',
      amount: -250,
      date: DateTime(2026, 1, 5),
      accountId: 'card1',
    );

    Widget row(final TransactionModel t) => Scaffold(
          body: TransactionListItem(tx: t, currency: '₹', datePattern: 'dd MMM'),
        );

    testWidgets('shows which card the spend was on', (final tester) async {
      await _pump(tester, home: row(tx), accounts: [_card]);
      expect(find.text('General · HDFC Regalia •• 4821 · 05 Jan'), findsOneWidget);
    });

    testWidgets('older untagged transactions show no account', (final tester) async {
      await _pump(tester, home: row(tx.copyWith(clearAccountId: true)), accounts: [_card]);
      expect(find.text('General · 05 Jan'), findsOneWidget);
    });

    testWidgets('an account id we do not know about shows nothing rather than an id', (final tester) async {
      await _pump(tester, home: row(tx.copyWith(accountId: 'gone')), accounts: [_card]);
      expect(find.text('General · 05 Jan'), findsOneWidget);
    });
  });

  group('account filter', () {
    TransactionModel t(final String id, final String? account) => TransactionModel(
          id: id,
          userId: 'u1',
          title: id,
          amount: -10,
          date: DateTime.now(),
          accountId: account,
        );

    ProviderContainer container() {
      final c = ProviderContainer(overrides: [
        userTransactionsProvider.overrideWith(
          (final ref) => Stream.value([t('a', 'card1'), t('b', 'upi1'), t('c', null), t('d', 'card1')]),
        ),
      ]);
      addTearDown(c.dispose);
      // Keep both providers subscribed: Riverpod 3 pauses ones nobody listens to.
      c.listen(userTransactionsProvider, (_, _) {});
      c.listen(filteredTransactionsProvider, (_, _) {});
      return c;
    }

    test('filters the list to one account and counts as an active filter', () async {
      final c = container();
      await c.read(userTransactionsProvider.future);

      expect(c.read(filteredTransactionsProvider).length, 4);
      expect(c.read(activeFilterCountProvider), 0);

      c.read(transactionFilterProvider.notifier).setAccount('card1');
      expect(c.read(filteredTransactionsProvider).map((final e) => e.id).toSet(), {'a', 'd'});
      expect(c.read(activeFilterCountProvider), 1);

      c.read(transactionFilterProvider.notifier).setAccount('All');
      expect(c.read(filteredTransactionsProvider).length, 4);
    });

    test('Clear (resetFilters) drops the account filter', () async {
      final c = container();
      await c.read(userTransactionsProvider.future);
      c.read(transactionFilterProvider.notifier).setAccount('upi1');
      c.read(transactionFilterProvider.notifier).resetFilters();
      expect(c.read(transactionFilterProvider).account, 'All');
    });
  });

  group('Accounts screen', () {
    testWidgets('lists accounts with their details and this month\'s spend', (final tester) async {
      await _pump(
        tester,
        home: const AccountsScreen(),
        accounts: [_card, _upi],
        spend: const [AccountSpend(accountId: 'card1', spend: 1250, income: 0, txnCount: 4)],
      );
      expect(find.text('HDFC Regalia'), findsOneWidget);
      expect(find.text('Credit Card · HDFC · •• 4821'), findsOneWidget);
      expect(find.text('UPI · me@okhdfc'), findsOneWidget);
      expect(find.textContaining('1,250'), findsOneWidget); // card spend
      expect(find.textContaining('spent this month'), findsNWidgets(2));
    });

    testWidgets('empty state invites the first account', (final tester) async {
      await _pump(tester, home: const AccountsScreen());
      expect(find.text('No cards or accounts yet'), findsOneWidget);
      expect(find.text('Add account'), findsOneWidget);
    });

    testWidgets('adding a debit card with last 4 digits sends the details', (final tester) async {
      final h = await _pump(tester, home: const AccountsScreen(), accounts: [_card]);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, 'Debit Card'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'SBI Debit');
      await tester.enterText(find.widgetWithText(TextFormField, 'Bank / issuer (optional)'), 'SBI');
      await tester.enterText(find.widgetWithText(TextFormField, 'Last 4 digits (optional)'), '9012');
      await tester.tap(find.widgetWithText(FilledButton, 'Add account'));
      await tester.pumpAndSettle();

      expect(h.ds.created.single, {
        'name': 'SBI Debit',
        'typeId': 'at_7',
        'institution': 'SBI',
        'last4': '9012',
        'upiId': null,
      });
      expect(find.text('SBI Debit'), findsOneWidget); // appears in the list
    });

    testWidgets('form validates last 4 digits and UPI id before calling the server', (final tester) async {
      final h = await _pump(tester, home: const AccountsScreen(), accounts: [_card]);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'X');
      await tester.enterText(find.widgetWithText(TextFormField, 'Last 4 digits (optional)'), '12');
      await tester.tap(find.widgetWithText(FilledButton, 'Add account'));
      await tester.pumpAndSettle();
      expect(find.text('Enter exactly 4 digits'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'UPI'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'UPI ID (optional)'), 'not-a-vpa');
      await tester.tap(find.widgetWithText(FilledButton, 'Add account'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a UPI ID like name@bank'), findsOneWidget);
      expect(h.ds.created, isEmpty);
    });

    testWidgets('deleting an account that still has transactions shows the server reason', (final tester) async {
      final h = await _pump(tester, home: const AccountsScreen(), accounts: [_card]);
      h.ds.deleteError = const ValidationException('Cannot delete account with 12 transaction(s)');

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete').last);
      await tester.pumpAndSettle();

      expect(find.text('Cannot delete account with 12 transaction(s)'), findsOneWidget);
      expect(find.text('HDFC Regalia'), findsOneWidget); // still there
    });
  });
}
