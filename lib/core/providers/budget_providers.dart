import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/budget_repository.dart';
import '../repositories/transaction_repository.dart';
import '../models/budget.dart';

DateTime _periodStart(BudgetPeriod p) {
  final now = DateTime.now();
  switch (p) {
    case BudgetPeriod.daily:
      return DateTime(now.year, now.month, now.day);
    case BudgetPeriod.weekly:
      final monday = now.subtract(Duration(days: (now.weekday - 1)));
      return DateTime(monday.year, monday.month, monday.day);
    case BudgetPeriod.monthly:
      return DateTime(now.year, now.month, 1);
  }
}

final budgetsUtilizationProvider = Provider<Map<String, double>>((ref) {
  final budgets = ref.watch(userBudgetsProvider).maybeWhen(data: (d) => d, orElse: () => const []);
  final txs = ref.watch(userTransactionsProvider).maybeWhen(data: (d) => d, orElse: () => const []);
  final spentByBudget = <String, double>{};
  for (final b in budgets) {
    final start = _periodStart(b.period);
    final spent = txs
        .where((t) => t.amount < 0 && t.date.isAfter(start))
        .where((t) => b.categoryIds.isEmpty || b.categoryIds.contains(t.categoryId))
        .fold<double>(0, (p, t) => p + t.amount.abs());
    spentByBudget[b.id] = spent;
  }
  return spentByBudget;
});

final budgetAlertsProvider = Provider<List<String>>((ref) {
  final budgets = ref.watch(userBudgetsProvider).maybeWhen(data: (d) => d, orElse: () => const []);
  final spent = ref.watch(budgetsUtilizationProvider);
  final alerts = <String>[];
  for (final b in budgets) {
    final s = spent[b.id] ?? 0;
    final util = b.allocated == 0 ? 0 : s / b.allocated;
    if (util > 0.9) {
      alerts.add('High utilization for ${b.name}: ${(util * 100).toStringAsFixed(0)}%');
    }
  }
  return alerts;
});