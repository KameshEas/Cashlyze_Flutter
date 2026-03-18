import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../repositories/budget_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/transaction_repository.dart';
import '../models/budget.dart';
import '../providers/shared_prefs_provider.dart';

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
  final categories = ref.watch(userCategoriesProvider).maybeWhen(data: (d) => d, orElse: () => const []);
  final spentByBudget = <String, double>{};

  // Build maps for category id <-> name to normalize matching.
  final idToName = <String, String>{};
  final nameToId = <String, String>{};
  for (final c in categories) {
    final nameTrim = (c.name ?? '').trim();
    idToName[c.id] = nameTrim;
    nameToId[nameTrim.toLowerCase()] = c.id;
  }

  // Sort budgets oldest → newest so the first budget that claims a
  // category becomes the "primary" owner of that category's spend.
  final sortedBudgets = [...budgets]..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  // For each budget, compute a normalized set of identifiers it claims
  // (both ids and lowercased names) so we can match transactions stored
  // as either name or id.
  final budgetNormalized = <String, Set<String>>{};
  for (final b in sortedBudgets) {
    final s = <String>{};
    if (b.categoryIds.isEmpty) {
      // If budget doesn't explicitly list categoryIds, assume the budget's
      // name itself is the claimed category (e.g., budget named "Food").
      final vTrim = (b.name ?? '').trim();
      if (vTrim.isNotEmpty) {
        s.add(vTrim);
        s.add(vTrim.toLowerCase());
        final mappedName = idToName[vTrim];
        if (mappedName != null) s.add(mappedName.toLowerCase());
        final mappedId = nameToId[vTrim.toLowerCase()];
        if (mappedId != null) s.add(mappedId);
      }
    } else {
      for (final v in b.categoryIds) {
        final vTrim = v.trim();
        s.add(vTrim); // as stored in budget (could be id or name)
        s.add(vTrim.toLowerCase());
        // If this value looks like an id we can map to a name too.
        final mappedName = idToName[vTrim];
        if (mappedName != null) s.add(mappedName.toLowerCase());
        // If value is a name, map to id too.
        final mappedId = nameToId[vTrim.toLowerCase()];
        if (mappedId != null) s.add(mappedId);
      }
    }
    budgetNormalized[b.id] = s;
    spentByBudget[b.id] = 0;
  }

  // Build primary budget map: for each normalized category key choose the
  // first budget (oldest) that contains it.
  final primaryForKey = <String, String>{};
  for (final b in sortedBudgets) {
    final keys = budgetNormalized[b.id] ?? <String>{};
    for (final k in keys) {
      primaryForKey.putIfAbsent(k, () => b.id);
    }
  }

  // Debug logging to help diagnose mismatches between stored category
  // values on transactions and budget category identifiers.
  if (kDebugMode) {
    print('DEBUG budgetsUtilization: categories (id->name) = $idToName');
    print('DEBUG budgetsUtilization: nameToId = $nameToId');
    print('DEBUG budgetsUtilization: budgetNormalized = $budgetNormalized');
    print('DEBUG budgetsUtilization: primaryForKey = $primaryForKey');
  }

  // Precompute period starts
  final periodStartById = {for (final b in sortedBudgets) b.id: _periodStart(b.period)};

  for (final t in txs) {
    if (t.amount >= 0) continue;
    final raw = t.categoryId;
    if (raw == null) continue;

    final rawTrim = raw.trim();
    final candidates = <String>{};
    candidates.add(rawTrim);
    candidates.add(rawTrim.toLowerCase());
    // If raw matches a known id, also add its name lowercased
    final asName = idToName[rawTrim];
    if (asName != null) candidates.add(asName.toLowerCase());
    // If raw looks like a name, try mapping to id
    final asId = nameToId[rawTrim.toLowerCase()];
    if (asId != null) candidates.add(asId);

    // Find the primary budget for the first candidate that has one
    String? ownerId;
    for (final c in candidates) {
      if (primaryForKey.containsKey(c)) {
        ownerId = primaryForKey[c];
        break;
      }
    }
    if (kDebugMode) {
      print('DEBUG budgetsUtilization: txn=${t.id} raw="$raw" candidates=$candidates owner=$ownerId amount=${t.amount}');
    }
    if (ownerId == null) continue;

    final start = periodStartById[ownerId]!;
    if (!t.date.isAfter(start)) continue;

    spentByBudget[ownerId] = (spentByBudget[ownerId] ?? 0) + t.amount.abs();
  }

  return spentByBudget;
});

final budgetAlertsProvider = Provider<List<String>>((ref) {
  final budgets = ref.watch(userBudgetsProvider).maybeWhen(data: (d) => d, orElse: () => const []);
  final spent = ref.watch(budgetsUtilizationProvider);
  final prefs = ref.watch(sharedPrefsServiceProvider);
  final threshold = prefs.alertThreshold;
  final alerts = <String>[];
  for (final b in budgets) {
    final s = spent[b.id] ?? 0;
    final util = b.allocated == 0 ? 0 : s / b.allocated;
    if (util >= threshold) {
      alerts.add('High utilization for ${b.name}: ${(util * 100).toStringAsFixed(0)}% (threshold ${(threshold * 100).toStringAsFixed(0)}%)');
    }
  }
  return alerts;
});
