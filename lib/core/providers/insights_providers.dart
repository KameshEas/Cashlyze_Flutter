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
  final txs = ref.watch(filteredTransactionsProvider);
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
  final num savingsRate = income == 0
      ? 0
      : (((income - expense) <= 0) ? 0 : (income - expense)) / income;
  final int txCount = txs.length;
  final num avgDailySpend = days == 0 ? 0 : (expense / days);
  final num largestExpense = txs
      .where((t) => t.amount < 0)
      .map((t) => t.amount.abs())
      .fold<num>(0, (p, a) => a > p ? a : p);
  return Kpis(income, expense, net, savingsRate, avgDailySpend, txCount,
      largestExpense);
});

/// KPIs for the current calendar month (used on Home so the
/// "This Month" card matches the underlying data, independent of the
/// Insights time-range selector).
final currentMonthKpisProvider = Provider<Kpis>((ref) {
  var txs = ref.watch(recentTransactionsProvider).maybeWhen(
    data: (d) => d,
    orElse: () => ref.watch(transactionsCacheProvider),
  );

  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);
  final nextMonthStart = DateTime(now.year, now.month + 1, 1);

  txs = txs
      .where(
        (t) =>
            t.date.isAfter(
              monthStart.subtract(const Duration(seconds: 1)),
            ) &&
            t.date.isBefore(nextMonthStart),
      )
      .toList();

  final int days = now.difference(monthStart).inDays + 1;

  final income = txs
      .where((t) => t.amount > 0)
      .fold<num>(0, (p, t) => p + t.amount);
  final expense = txs
      .where((t) => t.amount < 0)
      .fold<num>(0, (p, t) => p + t.amount.abs());
  final num net = income - expense;
  final num savingsRate = income == 0
      ? 0
      : (((income - expense) <= 0) ? 0 : (income - expense)) / income;
  final int txCount = txs.length;
  final num avgDailySpend = days == 0 ? 0 : (expense / days);
  final num largestExpense = txs
      .where((t) => t.amount < 0)
      .map((t) => t.amount.abs())
      .fold<num>(0, (p, a) => a > p ? a : p);

  return Kpis(
    income,
    expense,
    net,
    savingsRate,
    avgDailySpend,
    txCount,
    largestExpense,
  );
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

// ── Top merchants ────────────────────────────────────────────────────────────

class TopMerchant {
  final String name;
  final double amount;
  const TopMerchant(this.name, this.amount);
}

final topMerchantsProvider = Provider<List<TopMerchant>>((ref) {
  final txs = ref.watch(filteredTransactionsProvider);
  final map = <String, double>{};
  for (final t in txs.where((t) => t.amount < 0)) {
    map[t.title] = (map[t.title] ?? 0) + t.amount.abs();
  }
  final sorted = map.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return sorted.take(5).map((e) => TopMerchant(e.key, e.value)).toList();
});

// ── Recurring payments ───────────────────────────────────────────────────────

class RecurringPayment {
  final String title;
  final double avgAmount;
  final int occurrences;
  final Duration avgInterval;
  const RecurringPayment({
    required this.title,
    required this.avgAmount,
    required this.occurrences,
    required this.avgInterval,
  });
}

final recurringPaymentsProvider = Provider<List<RecurringPayment>>((ref) {
  final txsAsync = ref.watch(recentTransactionsProvider);
  final txs = txsAsync.maybeWhen(
    data: (d) => d,
    orElse: () => <TransactionModel>[],
  );
  final byTitle = <String, List<TransactionModel>>{};
  for (final t in txs.where((t) => t.amount < 0)) {
    byTitle.putIfAbsent(t.title, () => []).add(t);
  }
  final result = <RecurringPayment>[];
  for (final entry in byTitle.entries) {
    final list = entry.value..sort((a, b) => a.date.compareTo(b.date));
    if (list.length < 2) continue;
    final amounts = list.map((t) => t.amount.abs()).toList();
    final avgAmount = amounts.reduce((a, b) => a + b) / amounts.length;
    final intervals = <int>[];
    for (int i = 1; i < list.length; i++) {
      intervals.add(list[i].date.difference(list[i - 1].date).inDays);
    }
    final avgDays =
        intervals.reduce((a, b) => a + b) / intervals.length;
    if (avgDays < 20 || avgDays > 42) continue;
    final variance = amounts
            .map((a) => pow(a - avgAmount, 2))
            .reduce((a, b) => a + b) /
        amounts.length;
    final stdDev = sqrt(variance);
    if (avgAmount > 0 && stdDev / avgAmount > 0.25) continue;
    result.add(RecurringPayment(
      title: entry.key,
      avgAmount: avgAmount,
      occurrences: list.length,
      avgInterval: Duration(days: avgDays.round()),
    ));
  }
  result.sort((a, b) => b.avgAmount.compareTo(a.avgAmount));
  return result;
});

// ── Forecast next month ──────────────────────────────────────────────────────

final forecastExpenseNextMonthProvider = Provider<double?>((ref) {
  final monthly = ref.watch(monthlyTrendProvider);
  if (monthly.length < 2) return null;
  final last =
      monthly.length >= 3 ? monthly.sublist(monthly.length - 3) : monthly;
  return last.reduce((a, b) => a + b) / last.length;
});
