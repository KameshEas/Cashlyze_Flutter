import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/transaction_providers.dart';
import '../models/transaction.dart';

class Kpis {
  final num income;
  final num expense;
  final num net;
  final num savingsRate;
  const Kpis(this.income, this.expense, this.net, this.savingsRate);
}

final kpisProvider = Provider<Kpis>((ref) {
  final txs = ref
      .watch(recentTransactionsProvider)
      .maybeWhen(data: (d) => d, orElse: () => const []);
  final income = txs
      .where((t) => t.amount > 0)
      .fold<double>(0, (p, t) => p + t.amount);
  final expense = txs
      .where((t) => t.amount < 0)
      .fold<double>(0, (p, t) => p + t.amount.abs());
  final double net = income - expense;
  final double savingsRate = income == 0
      ? 0.0
      : (((income - expense) <= 0) ? 0.0 : (income - expense)) / income;
  return Kpis(
    income.toDouble(),
    expense.toDouble(),
    net.toDouble(),
    savingsRate.toDouble(),
  );
});

final anomaliesProvider = Provider<List<TransactionModel>>((ref) {
  final txs = ref
      .watch(recentTransactionsProvider)
      .maybeWhen(data: (d) => d, orElse: () => const []);
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
