import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/transaction_providers.dart';
import '../models/transaction.dart';

class Kpis {
  final num income;
  final num expense;
  final num net;
  final num savingsRate;
  final num avgDailySpend;
  final int txCount;
  final num largestExpense;
  const Kpis(this.income, this.expense, this.net, this.savingsRate, this.avgDailySpend, this.txCount, this.largestExpense);
}

final kpisProvider = Provider<Kpis>((ref) {
  var txs = ref.watch(filteredTransactionsProvider);
  final allTxs = ref.watch(recentTransactionsProvider).maybeWhen(
    data: (d) => d,
    orElse: () => ref.watch(transactionsCacheProvider),
  );
  if (txs.isEmpty && allTxs.isNotEmpty) {
    txs = allTxs;
  }
  final range = ref.watch(selectedTimeRangeProvider);
  int days;
  if (range == TimeRange.last7d) {
    days = 7;
  } else if (range == TimeRange.last30d) {
    days = 30;
  } else {
    days = 90;
  }
  final income = txs.where((t) => t.amount > 0).fold<num>(0, (p, t) => p + t.amount);
  final expense = txs.where((t) => t.amount < 0).fold<num>(0, (p, t) => p + t.amount.abs());
  final num net = income - expense;
  final num savingsRate = income == 0 ? 0 : (((income - expense) <= 0) ? 0 : (income - expense)) / income;
  final int txCount = txs.length;
  final num avgDailySpend = days == 0 ? 0 : (expense / days);
  final num largestExpense = txs.where((t) => t.amount < 0).map((t) => t.amount.abs()).fold<num>(0, (p, a) => a > p ? a : p);
  return Kpis(income, expense, net, savingsRate, avgDailySpend, txCount, largestExpense);
});

final anomaliesProvider = Provider<List<TransactionModel>>((ref) {
  final txs = ref.watch(filteredTransactionsProvider);
  final byCat = <String, List<double>>{};
  for (final t in txs.where((t) => t.amount < 0)) {
    final key = t.categoryId ?? 'Other';
    byCat.putIfAbsent(key, () => []).add(t.amount.abs());
  }
  final outliers = <TransactionModel>[];
  for (final entry in byCat.entries) {
    final values = entry.value;
    if (values.length < 5) continue;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance =
        values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) /
        values.length;
    final std = sqrt(variance);
    outliers.addAll(
      txs
          .where(
            (t) =>
                (t.categoryId ?? 'Other') == entry.key &&
                t.amount.abs() > mean + 2 * std,
          )
          .cast<TransactionModel>(),
    );
  }
  return outliers;
});

final recommendationsProvider = Provider<List<String>>((ref) {
  final breakdown = ref.watch(categoryBreakdownProvider);
  final suggestions = <String>[];
  for (final e in breakdown.entries) {
    if (e.value > 0 && e.value > 300) {
      suggestions.add(
        'Consider increasing budget for ${e.key} or reducing spend (>${e.value.toStringAsFixed(0)})',
      );
    }
  }
  return suggestions;
});
