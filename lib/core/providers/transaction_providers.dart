import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../repositories/transaction_repository.dart';
import '../models/transaction.dart';
import '../services/auth_service.dart';

enum TimeRange { last7d, last30d, last90d }

class TimeRangeNotifier extends Notifier<TimeRange> {
  @override
  TimeRange build() => TimeRange.last30d;
  void setRange(TimeRange r) => state = r;
}

final selectedTimeRangeProvider =
    NotifierProvider<TimeRangeNotifier, TimeRange>(TimeRangeNotifier.new);

final recentTransactionsProvider = StreamProvider<List<TransactionModel>>((
  ref,
) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(<TransactionModel>[]);
  final repo = ref.watch(transactionRepositoryProvider);
  final stream = Stream<List<TransactionModel>>.multi((controller) async {
    try {
      final initial = await repo.getAllForUser(user.uid);
      controller.add(initial);
    } catch (_) {}
    await for (final items in repo.streamForUser(user.uid)) {
      controller.add(items);
    }
  });
  return stream.timeout(const Duration(seconds: 5)).handleError((_, __) {});
});

class TransactionsCacheNotifier extends Notifier<List<TransactionModel>> {
  @override
  List<TransactionModel> build() {
    state = <TransactionModel>[];
    ref.listen<AsyncValue<List<TransactionModel>>>(recentTransactionsProvider, (
      prev,
      next,
    ) {
      next.when(
        data: (d) {
          state = d;
        },
        loading: () {
          // keep last known state during loading
        },
        error: (_, __) {
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

final filteredTransactionsProvider = Provider<List<TransactionModel>>((ref) {
  final txsAsync = ref.watch(recentTransactionsProvider);
  final txs = txsAsync.maybeWhen(
    data: (d) => d,
    orElse: () => ref.watch(transactionsCacheProvider),
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
      .where((t) => t.date.isAfter(cutoff))
      .where(
        (t) =>
            selectedCats.isEmpty ||
            selectedCats.contains(t.categoryId ?? 'Other'),
      )
      .toList();
});

final monthlyTrendProvider = Provider<List<double>>((ref) {
  final txsAsync = ref.watch(recentTransactionsProvider);
  final txs = txsAsync.maybeWhen(
    data: (d) => d,
    orElse: () => ref.watch(transactionsCacheProvider),
  );
  final now = DateTime.now();
  final months = List.generate(
    6,
    (i) => DateTime(now.year, now.month - (5 - i), 1),
  );
  final values = List<double>.filled(6, 0);
  for (final t in txs) {
    for (var i = 0; i < months.length; i++) {
      final m = months[i];
      final next = DateTime(m.year, m.month + 1, 1);
      if (t.date.isAfter(m) && t.date.isBefore(next)) {
        values[i] += t.amount.abs();
      }
    }
  }
  return values;
});

final categoryBreakdownProvider = Provider<Map<String, double>>((ref) {
  final txs = ref.watch(filteredTransactionsProvider);
  final map = <String, double>{};
  for (final t in txs.where((t) => t.amount < 0)) {
    final cat = t.categoryId ?? 'Other';
    map[cat] = (map[cat] ?? 0) + t.amount.abs();
  }
  return map;
});

class SelectedCategoriesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};
  void toggle(String cat) {
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
