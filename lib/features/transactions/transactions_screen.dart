import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/transaction.dart';
import '../../core/providers/onboarding_provider.dart';
import '../../core/providers/shared_prefs_provider.dart';
import '../../core/repositories/transaction_repository.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/repo_error_handler.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/skeleton.dart';
import '../../l10n/app_localizations.dart';
import 'transaction_filter_sheet.dart';
import 'transaction_filters.dart';
import 'transaction_form_sheet.dart';
import 'transaction_list_item.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  late final ScrollController _scrollController;
  final Set<String> _selectedIds = {};
  bool _selectionMode = false;

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
  void _openFilterSheet(final BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (final sheetCtx) => const TransactionFilterSheet(),
    );
  }

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final txsAsync = ref.watch(userTransactionsProvider);
    final prefs = ref.watch(sharedPrefsServiceProvider);
    final currency = ref.watch(currencyProvider);
    final allFiltered = ref.watch(filteredTransactionsProvider);
    final datePattern = prefs.dateFormat;

    final t = AppLocalizations.of(context);
    final filterState = ref.watch(transactionFilterProvider);
    return Scaffold(
      appBar: _selectionMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _selectionMode = false;
                  _selectedIds.clear();
                }),
              ),
              title: Text('${_selectedIds.length}'),
              actions: [
                IconButton(
                  tooltip: 'Select all',
                  icon: const Icon(Icons.select_all),
                  onPressed: () => setState(() {
                    if (_selectedIds.length == allFiltered.length) {
                      _selectedIds.clear();
                    } else {
                      _selectedIds.addAll(allFiltered.map((final e) => e.id));
                    }
                  }),
                ),
                IconButton(
                  tooltip: 'Delete selected',
                  icon: const Icon(Icons.delete_forever),
                  onPressed: () => _deleteSelected(context),
                ),
              ],
            )
          : AppBar(title: Text(t?.transactions ?? 'Transactions')),
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
                      onChanged: (final v) => ref.read(transactionFilterProvider.notifier).setQueryImmediate(v),
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
                    child: Consumer(
                      builder: (final ctx, final consumerRef, final _) {
                        final activeCount = consumerRef.watch(activeFilterCountProvider);
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: activeCount > 0
                                ? theme.colorScheme.primary
                                : theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.1,
                              ),
                            ),
                          ),
                          child: Badge(
                            isLabelVisible: activeCount > 0,
                            label: Text('$activeCount'),
                            child: Icon(
                              Icons.tune,
                              size: 20,
                              color: activeCount > 0
                                  ? Colors.white
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Builder(builder: (final ctx) {
              if (txsAsync.isLoading) {
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(userTransactionsProvider);
                    await Future.delayed(const Duration(milliseconds: 150));
                  },
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 88),
                    itemBuilder: (final listCtx, final i) => const SkeletonListTile(),
                    separatorBuilder: (final sepCtx, final i) => const SizedBox(height: 12),
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
                      color: theme.colorScheme.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.error.withValues(alpha: 0.3),
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
                  child: AppEmptyState(
                    title: t?.noTransactions ?? 'No transactions',
                    subtitle: t?.noTransactions == null
                        ? 'You have no transactions yet. Tap Add to create one.'
                        : '${t?.noTransactions}',
                    icon: Icons.receipt_long,
                    actionLabel: t?.addTransaction ?? 'Add transaction',
                    onAction: () => _openAddForm(context),
                  ),
                );
              } else {
                // Group transactions by date for better UX
                final grouped = groupTransactionsByDate(paged);
                final groupOrder = ['Today', 'Yesterday', 'This Week', 'This Month', 'Last Month', 'Older'];
                final activeGroups = groupOrder.where(grouped.containsKey).toList();
                
                // Build flat list with headers: [Header, Item, Item, Header, Item, ...]
                final listItems = <Widget>[];
                for (final groupKey in activeGroups) {
                  final transactions = grouped[groupKey] ?? [];
                  
                  // Add group header
                  listItems.add(
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Row(
                        children: [
                          Text(
                            groupKey,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              height: 1,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                  
                  // Add transactions for this group
                  for (final tx in transactions) {
                    listItems.add(
                      Dismissible(
                        key: ValueKey('tx_${tx.id}'),
                        direction: _selectionMode ? DismissDirection.none : DismissDirection.horizontal,
                        background: Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(children: [const Icon(Icons.edit, color: Colors.green), const SizedBox(width: 8), Text(t?.edit ?? 'Edit')]),
                        ),
                        secondaryBackground: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [Text(t?.delete ?? 'Delete'), const SizedBox(width: 8), const Icon(Icons.delete, color: Colors.red)]),
                        ),
                        confirmDismiss: (final dir) async {
                          if (dir == DismissDirection.startToEnd) {
                            await _openEditForm(context, tx.id, tx.title, tx.amount, tx.categoryId, tx.date);
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
                              final payload = {'title': tx.title, 'amount': tx.amount, 'categoryId': tx.categoryId, 'date': tx.date};
                              final user = ref.read(currentUserProvider);
                              if (user == null) return false;
                              await ref.read(transactionRepositoryProvider).deleteForUser(user.uid, tx.id);
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
                        child: TransactionListItem(
                          tx: tx,
                          currency: currency,
                          datePattern: datePattern,
                          selectionMode: _selectionMode,
                          selected: _selectedIds.contains(tx.id),
                          onSelectedChanged: (final v) => setState(() {
                            if (v) {
                              _selectedIds.add(tx.id);
                              _selectionMode = true;
                            } else {
                              _selectedIds.remove(tx.id);
                              if (_selectedIds.isEmpty) _selectionMode = false;
                            }
                          }),
                          onLongPress: () => setState(() {
                            _selectionMode = true;
                            _selectedIds.add(tx.id);
                          }),
                          onTap: () {
                            if (_selectionMode) {
                              setState(() {
                                if (_selectedIds.contains(tx.id)) {
                                  _selectedIds.remove(tx.id);
                                  if (_selectedIds.isEmpty) _selectionMode = false;
                                } else {
                                  _selectedIds.add(tx.id);
                                }
                              });
                            } else {
                              _openEditForm(context, tx.id, tx.title, tx.amount, tx.categoryId, tx.date);
                            }
                          },
                        ),
                      ),
                    );
                  }
                }
                
                // Add load more indicator if needed
                if (hasMore) {
                  listItems.add(
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  );
                }
                
                listChild = RefreshIndicator(
                  key: const ValueKey('tx_list'),
                  onRefresh: () async {
                    ref.invalidate(userTransactionsProvider);
                    await Future.delayed(const Duration(milliseconds: 150));
                  },
                  child: ListView.separated(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 88),
                    itemCount: listItems.length,
                    separatorBuilder: (final ctx, final i) => const SizedBox(height: 12),
                    itemBuilder: (final ctx, final i) => listItems[i],
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

  Future<void> _openAddForm(final BuildContext context) async {
    final theme = Theme.of(context);
    final result = await showModalBottomSheet<bool?>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (final ctx) => const TransactionFormSheet.create(),
    );
    // If the sheet indicated a successful save, refresh and show feedback.
    if (result == true) {
      ref.read(transactionFilterProvider.notifier).resetFilters();
      if (!context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)?.transactionSaved ?? 'Transaction saved')));
    }
    return;
  }

  Future<void> _openEditForm(
    final BuildContext context,
    final String id,
    final String title,
    final double amount,
    final String? categoryId,
    final DateTime date,
  ) async {
    final theme = Theme.of(context);
    final result = await showModalBottomSheet<bool?>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (final ctx) => TransactionFormSheet.edit(
        id: id,
        initialTitle: title,
        initialAmount: amount,
        initialCategory: categoryId,
        initialDate: date,
      ),
    );
    if (result == true) {
      ref.read(transactionFilterProvider.notifier).resetFilters();
      if (!context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)?.transactionUpdated ?? 'Transaction updated')));
    }
  }

  Future<void> _deleteSelected(final BuildContext context) async {
    if (_selectedIds.isEmpty) return;
    final t = AppLocalizations.of(context);
    final confirm = await showConfirmDialog(
      context,
      title: t?.deleteTransactionTitle ?? 'Delete transactions',
      content: 'Are you sure you want to delete ${_selectedIds.length} transactions?',
      confirmLabel: t?.delete ?? 'Delete',
      cancelLabel: t?.cancel ?? 'Cancel',
    );
    if (confirm != true) return;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    // Capture payloads for undo
    final all = ref.read(filteredTransactionsProvider);
    final payloads = <String, TransactionModel>{};
    for (final id in _selectedIds) {
      final found = all.where((final x) => x.id == id).toList();
      if (found.isNotEmpty) payloads[id] = found.first;
    }

    try {
      for (final id in _selectedIds.toList()) {
        await ref.read(transactionRepositoryProvider).deleteForUser(user.uid, id);
      }
      messenger.clearSnackBars();
      final snack = SnackBar(
        content: Text('${_selectedIds.length} deleted'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            for (final tx in payloads.values) {
              try {
                await ref.read(transactionRepositoryProvider).create(
                      userId: user.uid,
                      title: tx.title,
                      amount: tx.amount,
                      categoryId: tx.categoryId,
                      date: tx.date,
                      notes: tx.notes,
                    );
              } catch (_) {}
            }
          },
        ),
      );
      messenger.showSnackBar(snack);
      setState(() {
        _selectedIds.clear();
        _selectionMode = false;
      });
    } catch (err) {
      showRepoErrorSnackBar(messenger, err);
    }
  }

  // Budget creation helper moved into TransactionFormSheet to keep modal logic colocated.
}
