import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction.dart';
import '../repositories/transaction_repository.dart';
import '../services/auth_service.dart';

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
  return stream.timeout(const Duration(seconds: 15)).handleError((_, _) {});
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
  final now = DateTime.now();
  DateTime cutoff;
  if (range == TimeRange.last7d) {
    cutoff = now.subtract(const Duration(days: 7));
  } else if (range == TimeRange.last30d) {
    cutoff = now.subtract(const Duration(days: 30));
  } else {
    cutoff = now.subtract(const Duration(days: 90));
  }
  return txs
      .where((final t) => t.date.isAfter(cutoff))
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
  final now = DateTime.now();
  final months = List.generate(
    6,
    (final i) => DateTime(now.year, now.month - (5 - i)),
  );
  final values = List<double>.filled(6, 0);
  for (final t in txs) {
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
