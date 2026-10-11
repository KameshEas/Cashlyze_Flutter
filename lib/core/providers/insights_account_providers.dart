import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/account.dart';
import '../models/transaction.dart';
import '../repositories/account_repository.dart';

/// Insights scope values besides a concrete account id.
const String kInsightsAccountDefault = 'default';
const String kInsightsAccountAll = 'all';

/// Name the server gives the account it creates for transactions that arrive
/// without one (older app versions, imports).
const String _kDefaultAccountName = 'default account';

/// Which account's data Insights shows. Starts on the **default account**
/// (what a user gets when they haven't chosen anything); [kInsightsAccountAll]
/// widens to every account, and an account id narrows to that card/UPI/cash.
class InsightsAccountNotifier extends Notifier<String> {
  @override
  String build() => kInsightsAccountDefault;

  void select(final String scope) => state = scope;
}

final insightsAccountProvider =
    NotifierProvider<InsightsAccountNotifier, String>(InsightsAccountNotifier.new);

/// The user's server-created "Default Account", if there is one.
final defaultAccountProvider = Provider<AccountModel?>((final ref) {
  final accounts = ref.watch(userAccountsProvider).value ?? const <AccountModel>[];
  return accounts
      .where((final a) => a.name.trim().toLowerCase() == _kDefaultAccountName)
      .firstOrNull;
});

/// The selection, corrected if it points at an account that no longer exists
/// (deleted elsewhere) so Insights falls back to the default instead of going
/// blank.
final effectiveInsightsAccountProvider = Provider<String>((final ref) {
  final selected = ref.watch(insightsAccountProvider);
  if (selected == kInsightsAccountDefault || selected == kInsightsAccountAll) return selected;
  final accounts = ref.watch(userAccountsProvider);
  // While accounts are still loading, keep the user's choice.
  if (!accounts.hasValue) return selected;
  return accounts.value!.any((final a) => a.id == selected) ? selected : kInsightsAccountDefault;
});

/// Whether [t] belongs to the chosen Insights scope. A transaction with no
/// account counts as being on the default account.
bool txInAccountScope(final TransactionModel t, final String scope, final String? defaultAccountId) {
  if (scope == kInsightsAccountAll) return true;
  if (scope == kInsightsAccountDefault) {
    return t.accountId == null || t.accountId == defaultAccountId;
  }
  return t.accountId == scope;
}

/// Short human label for a scope, e.g. "Default account", "HDFC Regalia •• 4821".
String insightsScopeLabel(final String scope, final List<AccountModel> accounts) {
  if (scope == kInsightsAccountDefault) return 'Default account';
  if (scope == kInsightsAccountAll) return 'All accounts';
  return accounts.where((final a) => a.id == scope).firstOrNull?.shortLabel ?? 'Account';
}

/// One account's spend for the selected period, for the "Spend by account" card.
class AccountSpendRow {
  const AccountSpendRow({
    required this.scope,
    required this.name,
    required this.kind,
    required this.spend,
    required this.count,
    this.subtitle,
  });

  /// What to select to drill in: [kInsightsAccountDefault] or an account id.
  final String scope;
  final String name;
  final String? subtitle;
  final AccountKind kind;
  final double spend;
  final int count;
}
