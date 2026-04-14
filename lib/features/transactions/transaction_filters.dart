import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// Using Riverpod's Notifier API (no extra dependency required)

import '../../core/models/transaction.dart';
import '../../core/repositories/transaction_repository.dart';

class TransactionFilterState {
  final String filter; // 'All' | 'Income' | 'Expense'
  final String category; // 'All' or category label
  final String query; // immediate query (for textfield)
  final String debouncedQuery; // actual query used to filter
  final double? minAmount;
  final double? maxAmount;
  final DateTime? selectedMonth;
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
    this.page = 1,
    this.pageSize = 20,
  }) : selectedMonth = selectedMonth ?? DateTime(DateTime.now().year, DateTime.now().month, 1);

  TransactionFilterState copyWith({
    String? filter,
    String? category,
    String? query,
    String? debouncedQuery,
    double? minAmount,
    double? maxAmount,
    DateTime? selectedMonth,
    int? page,
    int? pageSize,
  }) {
    return TransactionFilterState(
      filter: filter ?? this.filter,
      category: category ?? this.category,
      query: query ?? this.query,
      debouncedQuery: debouncedQuery ?? this.debouncedQuery,
      minAmount: minAmount ?? this.minAmount,
      maxAmount: maxAmount ?? this.maxAmount,
      selectedMonth: selectedMonth ?? this.selectedMonth,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
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
  void setQueryImmediate(String q) {
    state = state.copyWith(query: q);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      state = state.copyWith(debouncedQuery: q, page: 1);
    });
  }

  void setFilterType(String v) {
    state = state.copyWith(filter: v, page: 1);
  }

  void setCategory(String v) {
    state = state.copyWith(category: v, page: 1);
  }

  void setMinAmount(double? v) {
    state = state.copyWith(minAmount: v, page: 1);
  }

  void setMaxAmount(double? v) {
    state = state.copyWith(maxAmount: v, page: 1);
  }

  void setSelectedMonth(DateTime? v) {
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

  
}

final transactionFilterProvider = NotifierProvider<TransactionFilterNotifier, TransactionFilterState>(TransactionFilterNotifier.new);

final filteredTransactionsProvider = Provider<List<TransactionModel>>((ref) {
  final txsAsync = ref.watch(userTransactionsProvider);
  final f = ref.watch(transactionFilterProvider);
  return txsAsync.maybeWhen(
    data: (items) {
      final q = f.debouncedQuery.trim().toLowerCase();
      final monthStart = f.selectedMonth == null ? null : DateTime(f.selectedMonth!.year, f.selectedMonth!.month, 1);
      final monthEnd = f.selectedMonth == null ? null : DateTime(f.selectedMonth!.year, f.selectedMonth!.month + 1, 1);
      final filtered = items.where((e) {
        final matchesQuery = q.isEmpty || e.title.toLowerCase().contains(q);
        final matchesType = f.filter == 'All' || (f.filter == 'Income' && e.amount > 0) || (f.filter == 'Expense' && e.amount < 0);
        final catLabel = e.categoryId ?? 'Uncategorized';
        final matchesCategory = f.category == 'All' || f.category == catLabel;
        final absAmount = e.amount.abs();
        final matchesAmount = (f.minAmount == null || absAmount >= f.minAmount!) && (f.maxAmount == null || absAmount <= f.maxAmount!);
        final inMonth = monthStart == null || (e.date.isAtSameMomentAs(monthStart) || e.date.isAfter(monthStart)) && e.date.isBefore(monthEnd!);
        return matchesQuery && matchesType && matchesCategory && matchesAmount && inMonth;
      }).toList();
      return filtered;
    },
    orElse: () => <TransactionModel>[],
  );
});

final paginatedTransactionsProvider = Provider<List<TransactionModel>>((ref) {
  final filtered = ref.watch(filteredTransactionsProvider);
  final f = ref.watch(transactionFilterProvider);
  final end = (f.page * f.pageSize) < filtered.length ? (f.page * f.pageSize) : filtered.length;
  if (end <= 0) return <TransactionModel>[];
  return filtered.sublist(0, end);
});

final transactionsHasMoreProvider = Provider<bool>((ref) {
  final filtered = ref.watch(filteredTransactionsProvider);
  final f = ref.watch(transactionFilterProvider);
  return filtered.length > f.page * f.pageSize;
});
