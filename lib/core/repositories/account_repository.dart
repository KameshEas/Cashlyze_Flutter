import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/accounts/data/account_remote_data_source.dart';
import '../models/account.dart';
import '../services/auth_service.dart';

/// The signed-in user's accounts (cards, UPI, cash, bank). Mutations update the
/// list in place, so pickers and the Accounts screen stay in sync without a
/// refetch.
class AccountsNotifier extends AsyncNotifier<List<AccountModel>> {
  AccountRemoteDataSource get _ds => ref.read(accountRemoteDataSourceProvider);

  @override
  Future<List<AccountModel>> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const <AccountModel>[];
    return ref.watch(accountRemoteDataSourceProvider).getAll();
  }

  Future<AccountModel> add({
    required final String name,
    required final String typeId,
    final String? institution,
    final String? last4,
    final String? upiId,
    final String? currencyCode,
  }) async {
    final created = await _ds.create(
      name: name,
      typeId: typeId,
      institution: institution,
      last4: last4,
      upiId: upiId,
      currencyCode: currencyCode,
    );
    state = AsyncData([...?state.value, created]);
    return created;
  }

  Future<AccountModel> edit(
    final String id, {
    required final String name,
    final String? institution,
    final String? last4,
    final String? upiId,
  }) async {
    final updated = await _ds.update(
      id,
      name: name,
      institution: institution,
      last4: last4,
      upiId: upiId,
    );
    state = AsyncData([
      for (final a in state.value ?? const <AccountModel>[]) a.id == id ? updated : a,
    ]);
    return updated;
  }

  /// Throws (a `ValidationException` with the server's reason) when the account
  /// still has transactions.
  Future<void> remove(final String id) async {
    await _ds.delete(id);
    state = AsyncData([
      for (final a in state.value ?? const <AccountModel>[])
        if (a.id != id) a,
    ]);
  }
}

final userAccountsProvider =
    AsyncNotifierProvider<AccountsNotifier, List<AccountModel>>(AccountsNotifier.new);

/// Account types the server offers (Credit Card, Debit Card, UPI, Cash, ...).
final accountTypesProvider = FutureProvider<List<AccountType>>((final ref) {
  return ref.watch(accountRemoteDataSourceProvider).getTypes();
});

/// This calendar month's spend / income per account id.
final accountMonthSpendProvider = FutureProvider<Map<String, AccountSpend>>((final ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const <String, AccountSpend>{};
  final now = DateTime.now();
  final rows = await ref.watch(accountRemoteDataSourceProvider).spendSummary(
        start: DateTime(now.year, now.month),
        end: DateTime(now.year, now.month + 1, 0),
      );
  return {for (final r in rows) r.accountId: r};
});
