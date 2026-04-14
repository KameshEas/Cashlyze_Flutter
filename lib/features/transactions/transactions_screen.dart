import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/repositories/transaction_repository.dart';
import '../../core/services/auth_service.dart';
import '../../core/providers/onboarding_provider.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/providers/shared_prefs_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../core/widgets/dialogs.dart';
import 'transaction_list_item.dart';
import 'transaction_filter_sheet.dart';
import 'transaction_filters.dart';
import 'transaction_form_sheet.dart';
import '../../core/utils/repo_error_handler.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      try {
        if (_scrollController.position.extentAfter < 300) {
          ref.read(transactionFilterProvider.notifier).loadMore();
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ── Filter bottom sheet ─────────────────────────────────────────────────
  void _openFilterSheet(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => const TransactionFilterSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final txsAsync = ref.watch(userTransactionsProvider);
    final prefs = ref.watch(sharedPrefsServiceProvider);
    final currency = ref.watch(currencyProvider);
    final datePattern = prefs.dateFormat;

    final t = AppLocalizations.of(context);
    final filterState = ref.watch(transactionFilterProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t?.transactions ?? 'Transactions')),
      floatingActionButton: Tooltip(
        message: t?.addTransaction ?? 'Add transaction',
        child: FloatingActionButton.extended(
          onPressed: () => _openAddForm(context),
          icon: const Icon(Icons.add),
          label: Text(t?.add ?? 'Add'),
        ),
      ),
      body: Column(
        children: [
          // ── Filter bar ─────────────────────────────────────────────────────────
          // BEFORE: 7 controls crammed in one Row → overflows on <400dp devices.
          // AFTER:  Search field + single filter icon button that opens a sheet.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    label: 'Search transactions',
                    hint: 'Type to filter by title',
                    textField: true,
                    child: TextField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: t?.search ?? 'Search',
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        // Inline clear button
                        suffixIcon: filterState.query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                tooltip: 'Clear search',
                                onPressed: () => ref.read(transactionFilterProvider.notifier).setQueryImmediate(''),
                              )
                            : null,
                      ),
                      onChanged: (v) => ref.read(transactionFilterProvider.notifier).setQueryImmediate(v),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Filter icon with active-filter badge
                Tooltip(
                  message: 'Filter & sort',
                  child: InkWell(
                    onTap: () => _openFilterSheet(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (() {
                          int c = 0;
                          if (filterState.filter != 'All') c++;
                          if (filterState.category != 'All') c++;
                          if (filterState.minAmount != null) c++;
                          if (filterState.maxAmount != null) c++;
                          if (filterState.selectedMonth != null) c++;
                          return c > 0 ? theme.colorScheme.primary : theme.colorScheme.surface;
                        })(),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.1,
                          ),
                        ),
                      ),
                      child: Badge(
                        isLabelVisible: (() {
                          int c = 0;
                          if (filterState.filter != 'All') c++;
                          if (filterState.category != 'All') c++;
                          if (filterState.minAmount != null) c++;
                          if (filterState.maxAmount != null) c++;
                          if (filterState.selectedMonth != null) c++;
                          return c > 0;
                        })(),
                        label: Text(() {
                          int c = 0;
                          if (filterState.filter != 'All') c++;
                          if (filterState.category != 'All') c++;
                          if (filterState.minAmount != null) c++;
                          if (filterState.maxAmount != null) c++;
                          if (filterState.selectedMonth != null) c++;
                          return '$c';
                        }()),
                        child: Icon(
                          Icons.tune,
                          size: 20,
                          color: (() {
                            int c = 0;
                            if (filterState.filter != 'All') c++;
                            if (filterState.category != 'All') c++;
                            if (filterState.minAmount != null) c++;
                            if (filterState.maxAmount != null) c++;
                              return c > 0 ? Colors.white : theme.colorScheme.onSurface;
                          })(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Builder(builder: (ctx) {
              final filterState = ref.watch(transactionFilterProvider);
              if (txsAsync.isLoading) {
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(userTransactionsProvider);
                    await Future.delayed(const Duration(milliseconds: 150));
                  },
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 88),
                    itemBuilder: (listCtx, i) => const SkeletonListTile(),
                    separatorBuilder: (sepCtx, i) => const SizedBox(height: 12),
                    itemCount: 6,
                  ),
                );
              }
              if (txsAsync.hasError) {
                final e = txsAsync.error;
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.error.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Failed to load: $e')),
                        TextButton(
                          onPressed: () => ref.refresh(userTransactionsProvider),
                          child: Text(AppLocalizations.of(context)?.retry ?? 'Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final allFiltered = ref.watch(filteredTransactionsProvider);
              final paged = ref.watch(paginatedTransactionsProvider);
              final hasMore = ref.watch(transactionsHasMoreProvider);

              final reduceMotion = MediaQuery.of(context).disableAnimations;
              final duration = reduceMotion ? Duration.zero : const Duration(milliseconds: 180);

              Widget listChild;
              if (allFiltered.isEmpty) {
                listChild = Center(
                  key: const ValueKey('tx_empty'),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Semantics(
                        label: 'No transactions illustration',
                        child: Icon(Icons.receipt_long, size: 72, color: theme.colorScheme.primary),
                      ),
                      const SizedBox(height: 12),
                      Text(t?.noTransactions ?? 'No transactions', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      FilledButton(onPressed: () => _openAddForm(context), child: Text(t?.addTransaction ?? 'Add transaction')),
                    ],
                  ),
                );
              } else {
                listChild = RefreshIndicator(
                  key: const ValueKey('tx_list'),
                  onRefresh: () async {
                    ref.invalidate(userTransactionsProvider);
                    await Future.delayed(const Duration(milliseconds: 150));
                  },
                  child: ListView.separated(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 88),
                    itemCount: paged.length + (hasMore ? 1 : 0),
                    addAutomaticKeepAlives: true,
                    itemBuilder: (ctx, i) {
                      if (i >= paged.length) {
                        // load more indicator
                        ref.read(transactionFilterProvider.notifier).loadMore();
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
                        );
                      }
                      final e = paged[i];
                      final isIncome = e.amount > 0;
                      return Dismissible(
                        key: ValueKey('tx_${e.id}'),
                        direction: DismissDirection.horizontal,
                        background: Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(children: [const Icon(Icons.edit, color: Colors.green), const SizedBox(width: 8), Text(t?.edit ?? 'Edit')]),
                        ),
                        secondaryBackground: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [Text(t?.delete ?? 'Delete'), const SizedBox(width: 8), const Icon(Icons.delete, color: Colors.red)]),
                        ),
                        confirmDismiss: (dir) async {
                          if (dir == DismissDirection.startToEnd) {
                            await _openEditForm(context, e.id, e.title, e.amount, e.categoryId, e.date);
                            return false;
                          }
                          final messenger = ScaffoldMessenger.of(context);
                          final confirm = await showConfirmDialog(
                            context,
                            title: AppLocalizations.of(context)?.deleteTransactionTitle ?? 'Delete transaction',
                            content: 'Are you sure you want to delete this transaction?',
                            confirmLabel: AppLocalizations.of(context)?.delete ?? 'Delete',
                            cancelLabel: AppLocalizations.of(context)?.cancel ?? 'Cancel',
                          );
                          if (confirm == true) {
                            try {
                              final payload = {'title': e.title, 'amount': e.amount, 'categoryId': e.categoryId, 'date': e.date};
                              final user = ref.read(currentUserProvider);
                              if (user == null) return false;
                              await ref.read(transactionRepositoryProvider).deleteForUser(user.uid, e.id);
                              messenger.clearSnackBars();
                              final snack = SnackBar(
                                content: Text(t?.deleted ?? 'Deleted'),
                                duration: const Duration(seconds: 3),
                                behavior: SnackBarBehavior.floating,
                                action: SnackBarAction(
                                  label: 'Undo',
                                  onPressed: () async {
                                    final user = ref.read(currentUserProvider);
                                    if (user == null) return;
                                    try {
                                      await ref.read(transactionRepositoryProvider).create(
                                            userId: user.uid,
                                            title: payload['title'] as String,
                                            amount: payload['amount'] as double,
                                            categoryId: payload['categoryId'] as String?,
                                            date: payload['date'] as DateTime,
                                            notes: null,
                                          );
                                    } catch (_) {}
                                  },
                                ),
                              );
                              final controller = messenger.showSnackBar(snack);
                              Future.delayed(snack.duration + const Duration(milliseconds: 200), () {
                                try {
                                  controller.close();
                                } catch (_) {}
                              });
                              return true;
                            } catch (err) {
                              messenger.clearSnackBars();
                              showRepoErrorSnackBar(messenger, err);
                              return false;
                            }
                          }
                          return false;
                        },
                        child: TransactionListItem(tx: e, currency: currency, datePattern: datePattern),
                      );
                    },
                    separatorBuilder: (sepCtx, i) => const SizedBox(height: 16),
                  ),
                );
              }
              return AnimatedSwitcher(duration: duration, child: listChild);
            }),
          ),
        ],
      ),
    );
  }

  Future<void> _openAddForm(BuildContext context) async {
    final theme = Theme.of(context);
    final result = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => const TransactionFormSheet.create(),
    );
    // Draft saving is handled inside the form sheet; nothing to do here.
    return;
  }

  Future<void> _openEditForm(
    BuildContext context,
    String id,
    String title,
    double amount,
    String? categoryId,
    DateTime date,
  ) async {
    final theme = Theme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => TransactionFormSheet.edit(
        id: id,
        initialTitle: title,
        initialAmount: amount,
        initialCategory: categoryId,
        initialDate: date,
      ),
    );
  }

  // Budget creation helper moved into TransactionFormSheet to keep modal logic colocated.
}
