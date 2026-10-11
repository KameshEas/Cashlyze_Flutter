import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/account.dart';
import '../models/transaction.dart';
import '../repositories/account_repository.dart';
import '../repositories/transaction_repository.dart';
import '../services/auth_service.dart';
import 'insights_account_providers.dart';

enum TimeRange { last7d, last30d, last90d }

class TimeRangeNotifier extends Notifier<TimeRange> {
  @override
  TimeRange build() => TimeRange.last30d;
  void setRange(final TimeRange r) => state = r;
}

final selectedTimeRangeProvider =
    NotifierProvider<TimeRangeNotifier, TimeRange>(TimeRangeNotifier.new);

final recentTransactionsProvider = StreamProvider<List<TransactionModel>>((
  final ref,
) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(<TransactionModel>[]);
  final repo = ref.watch(transactionRepositoryProvider);
  final stream = repo.streamForUser(user.uid);
  // Firestore streams go quiet when nothing changes; treat that as normal
  // idle time rather than an error. Real stream errors (permissions,
  // network) are left to propagate so the UI can surface them and retry.
  return stream.timeout(
    const Duration(seconds: 15),
    onTimeout: (final sink) {},
  );
});

class TransactionsCacheNotifier extends Notifier<List<TransactionModel>> {
  @override
  List<TransactionModel> build() {
    state = <TransactionModel>[];
    ref.listen<AsyncValue<List<TransactionModel>>>(recentTransactionsProvider, (
      final prev,
      final next,
    ) {
      next.when(
        data: (final d) {
          state = d;
        },
        loading: () {
          // keep last known state during loading
        },
        error: (_, _) {
          // keep last known state on error
        },
      );
    });
    return state;
  }
}

final transactionsCacheProvider =
    NotifierProvider<TransactionsCacheNotifier, List<TransactionModel>>(
      TransactionsCacheNotifier.new,
    );

/// Start of the period the Insights time-range selector stands for.
DateTime insightsRangeCutoff(final TimeRange range, [final DateTime? now]) {
  final n = now ?? DateTime.now();
  return switch (range) {
    TimeRange.last7d => n.subtract(const Duration(days: 7)),
    TimeRange.last30d => n.subtract(const Duration(days: 30)),
    TimeRange.last90d => n.subtract(const Duration(days: 90)),
  };
}

final filteredTransactionsProvider = Provider<List<TransactionModel>>((final ref) {
  final txsAsync = ref.watch(recentTransactionsProvider);
  // For Insights we want the filtered list to reflect the selected time
  // range exactly. Falling back to the full transactions cache while the
  // stream is loading can surface stale/all-time values in KPIs — avoid
  // that by treating loading/error as an empty list here.
  final txs = txsAsync.maybeWhen(
    data: (final d) => d,
    orElse: () => <TransactionModel>[],
  );
  final range = ref.watch(selectedTimeRangeProvider);
  final selectedCats = ref.watch(selectedCategoriesProvider);
  final scope = ref.watch(effectiveInsightsAccountProvider);
  final defaultAccountId = ref.watch(defaultAccountProvider)?.id;
  final cutoff = insightsRangeCutoff(range);
  return txs
      .where((final t) => t.date.isAfter(cutoff))
      .where((final t) => txInAccountScope(t, scope, defaultAccountId))
      .where(
        (final t) =>
            selectedCats.isEmpty ||
            selectedCats.contains(t.categoryId ?? 'Other'),
      )
      .toList();
});

final monthlyTrendProvider = Provider<List<double>>((final ref) {
  final txsAsync = ref.watch(recentTransactionsProvider);
  final txs = txsAsync.maybeWhen(
    data: (final d) => d,
    orElse: () => ref.watch(transactionsCacheProvider),
  );
  final scope = ref.watch(effectiveInsightsAccountProvider);
  final defaultAccountId = ref.watch(defaultAccountProvider)?.id;
  final now = DateTime.now();
  final months = List.generate(
    6,
    (final i) => DateTime(now.year, now.month - (5 - i)),
  );
  final values = List<double>.filled(6, 0);
  for (final t in txs.where((final t) => txInAccountScope(t, scope, defaultAccountId))) {
    for (var i = 0; i < months.length; i++) {
      final m = months[i];
      final next = DateTime(m.year, m.month + 1);
      if (t.date.isAfter(m) && t.date.isBefore(next)) {
        values[i] += t.amount.abs();
      }
    }
  }
  return values;
});

final categoryBreakdownProvider = Provider<Map<String, double>>((final ref) {
  final txs = ref.watch(filteredTransactionsProvider);
  final map = <String, double>{};
  for (final t in txs.where((final t) => t.amount < 0)) {
    final cat = t.categoryId ?? 'Other';
    map[cat] = (map[cat] ?? 0) + t.amount.abs();
  }
  return map;
});

class SelectedCategoriesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};
  void toggle(final String cat) {
    final s = Set<String>.from(state);
    if (s.contains(cat)) {
      s.remove(cat);
    } else {
      s.add(cat);
    }
    state = s;
  }

  void clear() => state = <String>{};
}

final selectedCategoriesProvider =
    NotifierProvider<SelectedCategoriesNotifier, Set<String>>(
      SelectedCategoriesNotifier.new,
    );

/// Spend per account for the selected period, for comparing accounts.
///
/// Deliberately ignores the Insights account selection (it *is* the comparison)
/// but follows the time range. Transactions with no account are counted on the
/// default account.
final accountSpendRowsProvider = Provider<List<AccountSpendRow>>((final ref) {
  final txs = ref.watch(recentTransactionsProvider).maybeWhen(
        data: (final d) => d,
        orElse: () => <TransactionModel>[],
      );
  final accounts = ref.watch(userAccountsProvider).value ?? const <AccountModel>[];
  final defaultAccount = ref.watch(defaultAccountProvider);
  final cutoff = insightsRangeCutoff(ref.watch(selectedTimeRangeProvider));

  final spend = <String, double>{};
  final count = <String, int>{};
  for (final t in txs) {
    if (t.amount >= 0 || !t.date.isAfter(cutoff)) continue;
    // null -> the default account (its real row if the server made one).
    final key = t.accountId ?? defaultAccount?.id ?? kInsightsAccountDefault;
    spend[key] = (spend[key] ?? 0) + t.amount.abs();
    count[key] = (count[key] ?? 0) + 1;
  }

  final rows = <AccountSpendRow>[];
  for (final entry in spend.entries) {
    final account = accounts.where((final a) => a.id == entry.key).firstOrNull;
    final isDefault = entry.key == kInsightsAccountDefault || entry.key == defaultAccount?.id;
    rows.add(AccountSpendRow(
      scope: isDefault ? kInsightsAccountDefault : entry.key,
      name: isDefault ? 'Default account' : (account?.shortLabel ?? 'Unknown account'),
      subtitle: isDefault ? null : account?.subtitle,
      kind: account?.kind ?? AccountKind.bank,
      spend: entry.value,
      count: count[entry.key] ?? 0,
    ));
  }
  rows.sort((final a, final b) => b.spend.compareTo(a.spend));
  return rows;
});
