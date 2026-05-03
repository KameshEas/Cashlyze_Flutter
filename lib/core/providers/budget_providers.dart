import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../repositories/budget_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/transaction_repository.dart';
import '../models/budget.dart';
import '../models/category.dart';
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

  // Build maps for category id <-> name to normalize matching. Use
  // a multi-valued map for names because duplicates may exist; keep
  // each name's set of ids so we can match transactions to any id.
  final idToName = <String, String>{};
  final nameToIds = <String, Set<String>>{};
  for (final c in categories) {
    final nameTrim = (c.name ?? '').trim();
    idToName[c.id] = nameTrim;
    final key = nameTrim.toLowerCase();
    nameToIds.putIfAbsent(key, () => <String>{}).add(c.id);
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
        final mappedIds = nameToIds[vTrim.toLowerCase()];
        if (mappedIds != null) {
          for (final mid in mappedIds) s.add(mid);
        }
      }
    } else {
      for (final v in b.categoryIds) {
        final vTrim = v.trim();
        s.add(vTrim); // as stored in budget (could be id or name)
        s.add(vTrim.toLowerCase());
        // If this value looks like an id we can map to a name too.
        final mappedName = idToName[vTrim];
        if (mappedName != null) s.add(mappedName.toLowerCase());
        // If value is a name, map to id(s) too.
        final mappedIds = nameToIds[vTrim.toLowerCase()];
        if (mappedIds != null) {
          for (final mid in mappedIds) s.add(mid);
        }
      }
    }

    // Also always include the budget's own name as a matching key. This
    // helps transient cases where server/client disagree about which
    // category ids are claimed by the budget (e.g., during a rename).
    final nameKey = (b.name ?? '').trim();
    if (nameKey.isNotEmpty) {
      s.add(nameKey);
      s.add(nameKey.toLowerCase());
      final mappedIdsForName = nameToIds[nameKey.toLowerCase()];
      if (mappedIdsForName != null) {
        for (final mid in mappedIdsForName) s.add(mid);
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

  // Precompute period starts
  final periodStartById = {for (final b in sortedBudgets) b.id: _periodStart(b.period)};

  for (final t in txs) {
    if (t.amount >= 0) continue;
    // Build candidate keys from both the category id and the category
    // name reported on the transaction. Include both forms even when
    // an id is present so we tolerate rename/order races.
    final idCandidate = (t.categoryId ?? '').trim();
    final nameCandidate = (t.categoryName ?? '').trim();
    final candidates = <String>{};

    if (idCandidate.isNotEmpty) {
      candidates.add(idCandidate);
      candidates.add(idCandidate.toLowerCase());
      final idAsName = idToName[idCandidate];
      if (idAsName != null) {
        candidates.add(idAsName);
        candidates.add(idAsName.toLowerCase());
      }
    }

    if (nameCandidate.isNotEmpty) {
      candidates.add(nameCandidate);
      candidates.add(nameCandidate.toLowerCase());
      final nameAsIds = nameToIds[nameCandidate.toLowerCase()];
      if (nameAsIds != null) {
        for (final mid in nameAsIds) candidates.add(mid);
      }
    }

    if (candidates.isEmpty) {
      candidates.add('General');
      candidates.add('general');
    }

    // Always print instrumentation so developers can see matching
    // candidates in all build modes when debugging this issue.
    print('[BudgetsUtil] tx ${t.id} id=${t.categoryId} name=${t.categoryName} candidates=${candidates.join(', ')}');

    // Find the primary budget for the first candidate that has one
    String? ownerId;
    String? matchedCandidate;
    for (final c in candidates) {
      if (primaryForKey.containsKey(c)) {
        ownerId = primaryForKey[c];
        matchedCandidate = c;
        break;
      }
    }

    print('[BudgetsUtil] tx ${t.id} matched=$matchedCandidate owner=$ownerId');
    if (ownerId == null) continue;

    final start = periodStartById[ownerId]!;
    if (t.date.isBefore(start)) continue;

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

// Period filter provider - tracks which period filter is active (All, Daily, Weekly, Monthly)
class PeriodFilterNotifier extends Notifier<String> {
  @override
  String build() => 'All';

  void setFilter(String filter) {
    state = filter;
  }
}

final periodFilterProvider = NotifierProvider<PeriodFilterNotifier, String>(
  PeriodFilterNotifier.new,
);

// Filtered budgets by period
final filteredBudgetsProvider = Provider<List<BudgetModel>>((ref) {
  final budgets = ref.watch(userBudgetsProvider).maybeWhen(data: (d) => d, orElse: () => <BudgetModel>[]);
  final selectedFilter = ref.watch(periodFilterProvider);

  if (selectedFilter == 'All') {
    return budgets;
  }

  final filtered = budgets.where((b) {
    if (b.id == '__general_budget') return true; // Always show General budget
    final periodName = b.period.name.toLowerCase();
    return periodName == selectedFilter.toLowerCase();
  }).toList();
  return filtered.cast<BudgetModel>();
});

// Track last budget adjustment for undo
class BudgetAdjustmentRecord {
  final String budgetId;
  final double oldAllocated;
  final double newAllocated;
  final DateTime timestamp;

  BudgetAdjustmentRecord({
    required this.budgetId,
    required this.oldAllocated,
    required this.newAllocated,
    required this.timestamp,
  });
}

// Last adjustment notifier
class LastAdjustmentNotifier extends Notifier<BudgetAdjustmentRecord?> {
  @override
  BudgetAdjustmentRecord? build() => null;

  void setAdjustment(BudgetAdjustmentRecord? record) {
    state = record;
  }

  void clear() {
    state = null;
  }
}

final lastBudgetAdjustmentProvider = NotifierProvider<LastAdjustmentNotifier, BudgetAdjustmentRecord?>(
  LastAdjustmentNotifier.new,
);

// Track last deleted budget for recovery
class DeletedBudgetRecord {
  final BudgetModel budget;
  final DateTime timestamp;

  // If the deleted budget was remapped to another budget, store the
  // target budget id and the previous categoryIds of the target so an
  // undo operation can restore the previous state.
  final String? remappedTargetId;
  final List<String>? targetPreviousCategoryIds;

  // If the delete operation removed any Category records as part of
  // the budget deletion, keep them here so an undo can recreate them.
  final List<CategoryModel>? deletedCategories;

  DeletedBudgetRecord({
    required this.budget,
    required this.timestamp,
    this.remappedTargetId,
    this.targetPreviousCategoryIds,
    this.deletedCategories,
  });
}

// Last delete notifier
class LastDeleteNotifier extends Notifier<DeletedBudgetRecord?> {
  @override
  DeletedBudgetRecord? build() => null;

  void setDeleted(DeletedBudgetRecord? record) {
    state = record;
  }

  void clear() {
    state = null;
  }
}

final lastDeletedBudgetProvider = NotifierProvider<LastDeleteNotifier, DeletedBudgetRecord?>(
  LastDeleteNotifier.new,
);

// Budget order notifier
class BudgetOrderNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    _loadOrder();
    return [];
  }

  Future<void> _loadOrder() async {
    try {
      final prefs = ref.read(sharedPrefsProvider);
      final saved = prefs.getString('budget_order') ?? '[]';
      // Simple JSON parsing for list of strings
      final parsed = (saved.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '').split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList());
      state = parsed.cast<String>();
    } catch (_) {
      state = [];
    }
  }

  Future<void> updateOrder(List<String> newOrder) async {
    state = newOrder;
    try {
      final prefs = ref.read(sharedPrefsProvider);
      final json = newOrder.map((id) => '"$id"').toList();
      await prefs.setString('budget_order', '[${json.join(',')}]');
    } catch (_) {
      // Ignore errors
    }
  }
}

final budgetOrderProvider = NotifierProvider<BudgetOrderNotifier, List<String>>(
  BudgetOrderNotifier.new,
);

// Ordered budgets combining custom order and filtering (all budgets can be reordered)
final orderedBudgetsProvider = Provider<List<BudgetModel>>((ref) {
  final filteredBudgets = ref.watch(filteredBudgetsProvider);
  final customOrder = ref.watch(budgetOrderProvider);

  final budgets = filteredBudgets.toList().cast<BudgetModel>();

  // Sort budgets by custom order (including General budget)
  if (customOrder.isNotEmpty) {
    budgets.sort((a, b) {
      final aIndex = customOrder.indexOf(a.id);
      final bIndex = customOrder.indexOf(b.id);
      // Items in custom order come first, sorted by their position
      if (aIndex != -1 && bIndex != -1) return aIndex.compareTo(bIndex);
      // Items in custom order come before items not in custom order
      if (aIndex != -1) return -1;
      if (bIndex != -1) return 1;
      // Items not in custom order maintain original order
      return 0;
    });
  }

  return budgets;
});

