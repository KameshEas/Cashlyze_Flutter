import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// Using Riverpod's Notifier API (no extra dependency required)

import '../../core/models/transaction.dart';
import '../../core/repositories/transaction_repository.dart';

class TransactionFilterState {

  TransactionFilterState({
    this.filter = 'All',
    this.category = 'All',
    this.query = '',
    this.debouncedQuery = '',
    this.minAmount,
    this.maxAmount,
    final DateTime? selectedMonth,
    this.fromDate,
    this.toDate,
    this.page = 1,
    this.pageSize = 20,
    final bool? useDateRange,
  }) : selectedMonth = selectedMonth ?? DateTime(DateTime.now().year, DateTime.now().month),
        // By default don't use a date-range; allow user to enable it.
        useDateRange = useDateRange ?? false;
  final String filter; // 'All' | 'Income' | 'Expense'
  final String category; // 'All' or category label
  final String query; // immediate query (for textfield)
  final String debouncedQuery; // actual query used to filter
  final double? minAmount;
  final double? maxAmount;
  final DateTime? fromDate;
  final DateTime? toDate;
  final bool useDateRange;
  final DateTime? selectedMonth;
  final List<String> selectedTags;
  final int page;
  final int pageSize;

  TransactionFilterState({
    this.filter = 'All',
    this.category = 'All',
    this.query = '',
    this.debouncedQuery = '',
    this.minAmount,
    this.maxAmount,
    DateTime? selectedMonth,
    DateTime? fromDate,
    DateTime? toDate,
    this.selectedTags = const [],
    this.page = 1,
    this.pageSize = 20,
    bool? useDateRange,
  }) : selectedMonth = selectedMonth ?? DateTime(DateTime.now().year, DateTime.now().month, 1),
        // By default don't use a date-range; allow user to enable it.
        useDateRange = useDateRange ?? false,
        fromDate = fromDate,
        toDate = toDate;

  TransactionFilterState copyWith({
    String? filter,
    String? category,
    String? query,
    String? debouncedQuery,
    double? minAmount,
    double? maxAmount,
    DateTime? fromDate,
    DateTime? toDate,
    DateTime? selectedMonth,
    final List<String>? selectedTags,
    int? page,
    int? pageSize,
    bool? useDateRange,
  }) {
    return TransactionFilterState(
      filter: filter ?? this.filter,
      category: category ?? this.category,
      query: query ?? this.query,
      debouncedQuery: debouncedQuery ?? this.debouncedQuery,
      minAmount: minAmount ?? this.minAmount,
      maxAmount: maxAmount ?? this.maxAmount,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      selectedMonth: selectedMonth ?? this.selectedMonth,
      selectedTags: selectedTags ?? this.selectedTags,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      useDateRange: useDateRange ?? this.useDateRange,
    );
  }
}

class TransactionFilterNotifier extends Notifier<TransactionFilterState> {
  Timer? _debounceTimer;
  bool _isLoadingMore = false;

  @override
  TransactionFilterState build() {
    ref.onDispose(() {
      _debounceTimer?.cancel();
    });
    return TransactionFilterState();
  }
  void setQueryImmediate(final String q) {
    state = state.copyWith(query: q);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      state = state.copyWith(debouncedQuery: q, page: 1);
    });
  }

  void setFilterType(final String v) {
    state = state.copyWith(filter: v, page: 1);
  }

  void setCategory(final String v) {
    state = state.copyWith(category: v, page: 1);
  }

  void setMinAmount(final double? v) {
    state = state.copyWith(minAmount: v, page: 1);
  }

  void setMaxAmount(final double? v) {
    state = state.copyWith(maxAmount: v, page: 1);
  }

  void setFromDate(final DateTime? v) {
    state = state.copyWith(fromDate: v, page: 1);
  }

  void setToDate(final DateTime? v) {
    state = state.copyWith(toDate: v, page: 1);
  }

  void setUseDateRange(final bool v) {
    state = state.copyWith(useDateRange: v, page: 1);
  }

  void setSelectedMonth(final DateTime? v) {
    state = state.copyWith(selectedMonth: v, page: 1);
  }

  void resetFilters() {
    state = TransactionFilterState();
  }

  void resetPagination() {
    state = state.copyWith(page: 1);
  }

  void loadMore() {
    if (_isLoadingMore) return;
    _isLoadingMore = true;
    state = state.copyWith(page: state.page + 1);
    // Let the provider graph settle before allowing another increment.
    Future.delayed(const Duration(milliseconds: 300), () {
      _isLoadingMore = false;
    });
  }

  void setSelectedTags(final List<String> tags) {
    state = state.copyWith(selectedTags: tags, page: 1);
  }

  void toggleTag(final String tag) {
    final updated = List<String>.from(state.selectedTags);
    if (updated.contains(tag)) {
      updated.remove(tag);
    } else {
      updated.add(tag);
    }
    state = state.copyWith(selectedTags: updated, page: 1);
  }
}

final transactionFilterProvider = NotifierProvider<TransactionFilterNotifier, TransactionFilterState>(TransactionFilterNotifier.new);

final filteredTransactionsProvider = Provider<List<TransactionModel>>((final ref) {
  final txsAsync = ref.watch(userTransactionsProvider);
  final f = ref.watch(transactionFilterProvider);
  return txsAsync.maybeWhen(
    data: (final items) {
      final q = f.debouncedQuery.trim().toLowerCase();
      final monthStart = f.selectedMonth == null ? null : DateTime(f.selectedMonth!.year, f.selectedMonth!.month);
      final monthEnd = f.selectedMonth == null ? null : DateTime(f.selectedMonth!.year, f.selectedMonth!.month + 1);
      final from = f.fromDate;
      final to = f.toDate;
      final filtered = items.where((final e) {
        final matchesQuery = q.isEmpty || e.title.toLowerCase().contains(q);
        final matchesType = f.filter == 'All' || (f.filter == 'Income' && e.amount > 0) || (f.filter == 'Expense' && e.amount < 0);
        final catLabel = e.categoryId ?? 'General';
        final matchesCategory = f.category == 'All' || f.category == catLabel;
        final absAmount = e.amount.abs();
        final matchesAmount = (f.minAmount == null || absAmount >= f.minAmount!) && (f.maxAmount == null || absAmount <= f.maxAmount!);
        final matchesTags = f.selectedTags.isEmpty || (e.tags != null && e.tags!.any(f.selectedTags.contains));
        bool inRange;
        if (f.useDateRange) {
          // If user enabled date-range but didn't provide endpoints, constrain to last ~6 months by default
          final effectiveFrom = from ?? DateTime.now().subtract(const Duration(days: 180));
          final effectiveTo = to ?? DateTime.now();
          final okFrom = !e.date.isBefore(effectiveFrom);
          final okTo = !e.date.isAfter(effectiveTo);
          inRange = okFrom && okTo;
        } else {
          inRange = monthStart == null || (e.date.isAtSameMomentAs(monthStart) || e.date.isAfter(monthStart)) && e.date.isBefore(monthEnd!);
        }
        return matchesQuery && matchesType && matchesCategory && matchesAmount && matchesTags && inRange;
      }).toList();
      // Ensure newest transactions appear first before pagination.
      filtered.sort((final a, final b) => b.date.compareTo(a.date));
      return filtered;
    },
    orElse: () => <TransactionModel>[],
  );
});

final paginatedTransactionsProvider = Provider<List<TransactionModel>>((final ref) {
  final filtered = ref.watch(filteredTransactionsProvider);
  final f = ref.watch(transactionFilterProvider);
  final end = (f.page * f.pageSize) < filtered.length ? (f.page * f.pageSize) : filtered.length;
  if (end <= 0) return <TransactionModel>[];
  return filtered.sublist(0, end);
});

final transactionsHasMoreProvider = Provider<bool>((final ref) {
  final filtered = ref.watch(filteredTransactionsProvider);
  final f = ref.watch(transactionFilterProvider);
  return filtered.length > f.page * f.pageSize;
});

/// Computes the active filter count (extracted for performance)
/// Prevents quadruple computation in UI layer
final activeFilterCountProvider = Provider<int>((final ref) {
  final state = ref.watch(transactionFilterProvider);
  int count = 0;
  if (state.filter != 'All') count++;
  if (state.category != 'All') count++;
  if (state.minAmount != null) count++;
  if (state.maxAmount != null) count++;
  if (state.selectedMonth != null && state.selectedMonth != DateTime(DateTime.now().year, DateTime.now().month, 1)) count++;
  if (state.selectedTags.isNotEmpty) count++;
  return count;
});

/// Groups transactions by relative date (Today, Yesterday, This Week, etc.)
Map<String, List<TransactionModel>> groupTransactionsByDate(final List<TransactionModel> transactions) {
  final grouped = <String, List<TransactionModel>>{};
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final weekStart = today.subtract(Duration(days: today.weekday - 1));

  for (final tx in transactions) {
    final txDate = DateTime(tx.date.year, tx.date.month, tx.date.day);
    late String group;

    if (txDate == today) {
      group = 'Today';
    } else if (txDate == yesterday) {
      group = 'Yesterday';
    } else if (txDate.isAfter(weekStart) && txDate.isBefore(today)) {
      group = 'This Week';
    } else if (txDate.year == today.year && txDate.month == today.month) {
      group = 'This Month';
    } else if (txDate.year == today.year && txDate.month == today.month - 1) {
      group = 'Last Month';
    } else {
      group = 'Older';
    }

    grouped.putIfAbsent(group, () => []).add(tx);
  }

  return grouped;
}
