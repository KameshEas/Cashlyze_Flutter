import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/repositories/transaction_repository.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/transaction_ingest_service.dart';
import '../../core/providers/onboarding_provider.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/repositories/budget_repository.dart';
import '../../core/models/budget.dart';
import '../../core/repositories/category_repository.dart';
import '../../core/utils/validation.dart';
import '../../core/providers/shared_prefs_provider.dart';
import 'package:flutter/services.dart';
import '../../core/repositories/recurring_repository.dart';
import '../../core/models/recurring.dart';
import '../../l10n/app_localizations.dart';
import '../../core/widgets/dialogs.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  String _filter = 'All';
  String _categoryFilter = 'All';
  String _query = '';
  String _minAmountText = '';
  String _maxAmountText = '';
  // null means "All time" — no month filter applied.
  // Default is current month so users first see recent spend.
  DateTime? _selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
   );

  int get _activeFilterCount {
    int count = 0;
    if (_filter != 'All') count++;
    if (_categoryFilter != 'All') count++;
    if (_minAmountText.isNotEmpty) count++;
    if (_maxAmountText.isNotEmpty) count++;
    if (_selectedMonth != null) count++;
    return count;
  }

  // ── Filter bottom sheet ─────────────────────────────────────────────────
  void _openFilterSheet(
    BuildContext context,
    dynamic t,
    AsyncValue catsAsync,
  ) {
    // Local copies — applied on "Apply" tap, discarded on dismiss.
    String localFilter = _filter;
    String localCategory = _categoryFilter;
    DateTime? localMonth = _selectedMonth;
    final minController = TextEditingController(text: _minAmountText);
    final maxController = TextEditingController(text: _maxAmountText);
    final theme = Theme.of(context);

    Future.microtask(() => showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                top: 16,
                left: 12,
                right: 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.2,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter Transactions',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Period ────────────────────────────────────────────
                  Text('Period', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      // 1 extra item at index 0 for "All time"
                      itemCount: 13,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        if (i == 0) {
                          return FilterChip(
                            label: const Text('All time'),
                            selected: localMonth == null,
                            onSelected: (_) =>
                                setSheetState(() => localMonth = null),
                          );
                        }
                        final now = DateTime.now();
                        final m = DateTime(now.year, now.month - (i - 1), 1);
                        final label =
                            '${m.year}-${m.month.toString().padLeft(2, '0')}';
                        final isSelected = localMonth != null &&
                            localMonth!.year == m.year &&
                            localMonth!.month == m.month;
                        return FilterChip(
                          label: Text(label),
                          selected: isSelected,
                          onSelected: (_) =>
                              setSheetState(() => localMonth = m),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Type ──────────────────────────────────────────────
                  Text('Type', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'All',
                        label: Text(t?.filterAll ?? 'All'),
                      ),
                      ButtonSegment(
                        value: 'Income',
                        label: Text(t?.filterIncome ?? 'Income'),
                        icon: const Icon(Icons.arrow_downward, size: 14),
                      ),
                      ButtonSegment(
                        value: 'Expense',
                        label: Text(t?.filterExpense ?? 'Expense'),
                        icon: const Icon(Icons.arrow_upward, size: 14),
                      ),
                    ],
                    selected: {localFilter},
                    onSelectionChanged: (v) =>
                        setSheetState(() => localFilter = v.first),
                  ),
                  const SizedBox(height: 20),

                  // ── Category ──────────────────────────────────────────
                  Text('Category', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  catsAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (list) {
                      // Start with explicit options
                      final cats = <String>['All', 'Uncategorized'];
                      final seenLower = <String>{'all', 'uncategorized'};
                      for (final c in list) {
                        final nm = (c.name ?? '').trim();
                        if (nm.isEmpty) continue;
                        final nl = nm.toLowerCase();
                        if (!seenLower.contains(nl)) {
                          cats.add(nm);
                          seenLower.add(nl);
                        }
                      }

                      // Append budget-claimed category names (map ids -> names
                      // or use budget name if no categoryIds present). Avoid
                      // duplicates using lowercase set.
                      final budgets = ref.watch(userBudgetsProvider).maybeWhen(data: (d) => d, orElse: () => const []);
                      final idToName = <String, String>{};
                      for (final c in list) {
                        final nm = (c.name ?? '').trim();
                        if (nm.isNotEmpty) idToName[c.id] = nm;
                      }
                      for (final b in budgets) {
                        final catIds = b.categoryIds ?? <String>[];
                        String key = '';
                        if (catIds.isNotEmpty) {
                          final raw = catIds.first.trim();
                          if (raw.isEmpty) {
                            key = (b.name ?? '').trim();
                          } else if (idToName.containsKey(raw)) key = idToName[raw]!.trim();
                          else key = (b.name ?? raw).trim();
                        } else {
                          key = (b.name ?? '').trim();
                        }
                        if (key.isEmpty) continue;
                        final kl = key.toLowerCase();
                        if (!seenLower.contains(kl)) {
                          cats.add(key);
                          seenLower.add(kl);
                        }
                      }

                      return Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: cats
                            .map(
                              (c) => FilterChip(
                                label: Text(c),
                                selected: localCategory == c,
                                onSelected: (_) =>
                                    setSheetState(() => localCategory = c),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // ── Amount range ──────────────────────────────────────
                  Text('Amount Range', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: minController,
                          decoration: const InputDecoration(
                            labelText: 'Min',
                            filled: true,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: maxController,
                          decoration: const InputDecoration(
                            labelText: 'Max',
                            filled: true,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Actions ───────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            final now = DateTime.now();
                            final currentMonthStart =
                                DateTime(now.year, now.month, 1);
                            setState(() {
                              _filter = 'All';
                              _categoryFilter = 'All';
                              _minAmountText = '';
                              _maxAmountText = '';
                              // Reset to default view: current month only.
                              _selectedMonth = currentMonthStart;
                            });
                            Navigator.of(ctx).pop();
                          },
                          child: const Text('Clear'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            setState(() {
                              _filter = localFilter;
                              _categoryFilter = localCategory;
                              _selectedMonth = localMonth;
                              _minAmountText = minController.text;
                              _maxAmountText = maxController.text;
                            });
                            Navigator.of(ctx).pop();
                          },
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final txsAsync = ref.watch(userTransactionsProvider);
    final catsAsync = ref.watch(userCategoriesProvider);
    final prefs = ref.watch(sharedPrefsServiceProvider);
    final currency = ref.watch(currencyProvider);
    final datePattern = prefs.dateFormat;

    final t = AppLocalizations.of(context);
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
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                tooltip: 'Clear search',
                                onPressed: () => setState(() => _query = ''),
                              )
                            : null,
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Filter icon with active-filter badge
                Tooltip(
                  message: 'Filter & sort',
                  child: InkWell(
                    onTap: () => _openFilterSheet(context, t, catsAsync),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _activeFilterCount > 0
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
                        isLabelVisible: _activeFilterCount > 0,
                        label: Text('$_activeFilterCount'),
                        child: Icon(
                          Icons.tune,
                          size: 20,
                          color: _activeFilterCount > 0
                              ? Colors.white
                              : theme.colorScheme.onSurface,
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
            child: txsAsync.when(
              loading: () => RefreshIndicator(
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
              ),
              error: (e, _) => Padding(
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
                        child: Text(
                          AppLocalizations.of(context)?.retry ?? 'Retry',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              data: (items) {
                // _selectedMonth == null → show all transactions (no date filter)
                final monthStart = _selectedMonth == null
                    ? null
                    : DateTime(_selectedMonth!.year, _selectedMonth!.month, 1);
                final monthEnd = _selectedMonth == null
                    ? null
                    : DateTime(
                        _selectedMonth!.year,
                        _selectedMonth!.month + 1,
                        1,
                      );
                final filtered = items.where((e) {
                  final matchesQuery =
                      _query.isEmpty ||
                      e.title.toLowerCase().contains(_query.toLowerCase());
                  final matchesType =
                      _filter == 'All' ||
                      (_filter == 'Income' && e.amount > 0) ||
                      (_filter == 'Expense' && e.amount < 0);
                  final catLabel = e.categoryId ?? 'Uncategorized';
                  final matchesCategory =
                      _categoryFilter == 'All' || _categoryFilter == catLabel;
                  final minAmt = double.tryParse(_minAmountText);
                  final maxAmt = double.tryParse(_maxAmountText);
                  final absAmount = e.amount.abs();
                  final matchesAmount =
                      (minAmt == null || absAmount >= minAmt) &&
                      (maxAmt == null || absAmount <= maxAmt);
                  final inMonth = monthStart == null ||
                      (e.date.isAfter(
                            monthStart.subtract(const Duration(seconds: 1)),
                          ) &&
                          e.date.isBefore(monthEnd!));
                  return matchesQuery &&
                      matchesType &&
                      matchesCategory &&
                      matchesAmount &&
                      inMonth;
                }).toList();
                final reduceMotion = MediaQuery.of(context).disableAnimations;
                final duration = reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 180);
                Widget listChild;
                if (filtered.isEmpty) {
                  listChild = Center(
                    key: const ValueKey('tx_empty'),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Semantics(
                          label: 'No transactions illustration',
                          child: Icon(
                            Icons.receipt_long,
                            size: 72,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          t?.noTransactions ?? 'No transactions',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: () => _openAddForm(context),
                          child: Text(t?.addTransaction ?? 'Add transaction'),
                        ),
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
                      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 88),
                      itemBuilder: (ctx, i) {
                        final e = filtered[i];
                        final isIncome = e.amount > 0;
                        return Dismissible(
                          key: ValueKey('tx_${e.id}'),
                        direction: DismissDirection.horizontal,
                        background: Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.edit, color: Colors.green),
                              const SizedBox(width: 8),
                              Text(t?.edit ?? 'Edit'),
                            ],
                          ),
                        ),
                        secondaryBackground: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(t?.delete ?? 'Delete'),
                              const SizedBox(width: 8),
                              const Icon(Icons.delete, color: Colors.red),
                            ],
                          ),
                        ),
                        confirmDismiss: (dir) async {
                          if (dir == DismissDirection.startToEnd) {
                            await _openEditForm(
                              context,
                              e.id,
                              e.title,
                              e.amount,
                              e.categoryId,
                              e.date,
                            );
                            return false;
                          }
                          final messenger = ScaffoldMessenger.of(context);
                          final confirm = await showConfirmDialog(
                            context,
                            title:
                                AppLocalizations.of(
                                  context,
                                )?.deleteTransactionTitle ??
                                'Delete transaction',
                            content:
                                'Are you sure you want to delete this transaction?',
                            confirmLabel:
                                AppLocalizations.of(context)?.delete ??
                                'Delete',
                            cancelLabel:
                                AppLocalizations.of(context)?.cancel ??
                                'Cancel',
                          );
                          if (confirm == true) {
                            try {
                              final payload = {
                                'title': e.title,
                                'amount': e.amount,
                                'categoryId': e.categoryId,
                                'date': e.date,
                              };
                              final user = ref.read(currentUserProvider);
                              if (user == null) return false;
                              await ref
                                  .read(transactionRepositoryProvider)
                                  .deleteForUser(user.uid, e.id);
                              messenger.clearSnackBars();
                              final snack = SnackBar(
                                content: Text(t?.deleted ?? 'Deleted'),
                                duration: const Duration(seconds: 3),
                                behavior: SnackBarBehavior.floating,
                                action: SnackBarAction(
                                  label: 'Undo',
                                  onPressed: () async {
                                    final user = ref.read(
                                      currentUserProvider,
                                    );
                                    if (user == null) return;
                                    try {
                                      await ref
                                          .read(transactionRepositoryProvider)
                                          .create(
                                            userId: user.uid,
                                            title: payload['title'] as String,
                                            amount: payload['amount'] as double,
                                            categoryId:
                                                payload['categoryId'] as String?,
                                            date: payload['date'] as DateTime,
                                            notes: null,
                                          );
                                    } catch (_) {}
                                  },
                                ),
                              );
                              final controller = messenger.showSnackBar(snack);
                              // As a defensive fallback ensure the snackbar is closed
                              // shortly after its duration in case platform/overlay
                              // issues prevent it from auto-dismissing.
                              Future.delayed(snack.duration + const Duration(milliseconds: 200), () {
                                try {
                                  controller.close();
                                } catch (_) {}
                              });
                              return true;
                            } catch (err) {
                              messenger.clearSnackBars();
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Failed: $err'),
                                  duration: const Duration(seconds: 4),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return false;
                            }
                          }
                          return false;
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.14,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.06,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isIncome
                                      ? Icons.arrow_downward
                                      : Icons.arrow_upward,
                                  color: isIncome ? Colors.green : Colors.red,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.title,
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.08),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              e.categoryId ??
                                                  (t?.uncategorized ??
                                                      'Uncategorized'),
                                              style: theme.textTheme.bodySmall,
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          formatDate(e.date, datePattern),
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: theme
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.7),
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                formatAmount(e.amount, currency),
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: isIncome ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (sepCtx, i) => const SizedBox(height: 16),
                    itemCount: filtered.length,
                    ),
                  );
                }
                return AnimatedSwitcher(
                  duration: duration,
                  child: listChild,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAddForm(BuildContext context) async {
    final theme = Theme.of(context);
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    String type = 'Expense';
    String category = 'General';
    DateTime date = DateTime.now();
    bool repeatEnabled = false;
    String repeatFreq = 'Monthly';

    final prefs = ref.read(sharedPrefsServiceProvider);
    final draft = prefs.getDraft('transaction_add');
    if (draft != null) {
      titleController.text = (draft['title'] as String?) ?? '';
      final amt = draft['amount'];
      if (amt != null) {
        amountController.text = amt.toString();
      }
      type = (draft['type'] as String?) ?? type;
      category = (draft['category'] as String?) ?? category;
      final ds = draft['date'] as String?;
      if (ds != null) {
        final parsed = DateTime.tryParse(ds);
        if (parsed != null) {
          date = parsed;
        }
      }
    }

    final result = await Future.microtask(() => showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final catsAsync = ref.watch(userCategoriesProvider);
        return StatefulBuilder(
            builder: (ctx, setModalState) {
            final categoryItems = <DropdownMenuItem<String>>[
              const DropdownMenuItem(value: 'General', child: Text('General')),
            ];
            final addedValues = <String>{'general'};
            catsAsync.when(
              loading: () {},
              error: (_, __) {},
              data: (list) {
                for (final c in list) {
                  final name = c.name.trim();
                  if (!addedValues.contains(name.toLowerCase())) {
                    categoryItems.add(
                      DropdownMenuItem(
                        value: name,
                        child: Row(children: [Expanded(child: Text(name, overflow: TextOverflow.ellipsis))]),
                      ),
                    );
                    addedValues.add(name.toLowerCase());
                  }
                }
              },
            );

            // Also include budgets as category options where budgets claim a
            // specific category. Budgets may store either category *ids* or
            // category *names* (legacy). Map identifiers to a friendly
            // category name using the user's categories to ensure dropdown
            // entries are consistent.
            final catsList = catsAsync.maybeWhen(data: (d) => d, orElse: () => const []);
            final idToName = <String, String>{};
            final nameToId = <String, String>{};
            for (final c in catsList) {
              final nm = (c.name ?? '').trim();
              if (nm.isEmpty) continue;
              idToName[c.id] = nm;
              nameToId[nm.toLowerCase()] = c.id;
            }

            final budgets = ref
                .watch(userBudgetsProvider)
                .maybeWhen(data: (d) => d, orElse: () => const []);
            for (final b in budgets) {
              final catIds = b.categoryIds ?? <String>[];
              String key = '';
              if (catIds.isNotEmpty) {
                final raw = catIds.first.trim();
                if (raw.isEmpty) {
                  key = (b.name ?? '').trim();
                } else if (idToName.containsKey(raw)) {
                  key = idToName[raw]!.trim();
                } else {
                  // Maybe the stored value was a category name instead of id.
                  final mappedId = nameToId[raw.toLowerCase()];
                  if (mappedId != null) {
                    key = idToName[mappedId] ?? raw;
                  } else {
                    key = raw;
                  }
                }
              } else {
                key = (b.name ?? '').trim();
              }
              if (key.isEmpty) continue;
              final keyLower = key.toLowerCase();
              if (!addedValues.contains(keyLower)) {
                categoryItems.add(
                  DropdownMenuItem(
                    value: key,
                    child: Row(children: [Expanded(child: Text('${(b.name ?? key)} (Budget)', overflow: TextOverflow.ellipsis))]),
                  ),
                );
                addedValues.add(keyLower);
              }
            }

            // Compute a safe initial category that matches exactly one item.
            // If the stored `category` is an id, map it to the canonical
            // display name so it matches dropdown item values (which are
            // display names).
            String displayCategory = category.trim();
            if (idToName.containsKey(displayCategory)) {
              displayCategory = idToName[displayCategory]!.trim();
            } else {
              final mappedId = nameToId[displayCategory.toLowerCase()];
              if (mappedId != null) displayCategory = idToName[mappedId] ?? displayCategory;
            }
            final matchingCount = categoryItems.where((it) => it.value == displayCategory).length;
            final effectiveInitialCategory = matchingCount == 1
                ? displayCategory
                : (categoryItems.isNotEmpty ? categoryItems.first.value : null);
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: type,
                            items: [
                              DropdownMenuItem(
                                value: 'Expense',
                                child: Text(
                                  AppLocalizations.of(ctx)?.expense ??
                                      'Expense',
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'Income',
                                child: Text(
                                  AppLocalizations.of(ctx)?.income ?? 'Income',
                                ),
                              ),
                            ],
                            onChanged: (v) => type = v ?? 'Expense',
                            decoration: InputDecoration(
                              labelText:
                                  AppLocalizations.of(ctx)?.typeLabel ?? 'Type',
                              filled: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: effectiveInitialCategory,
                              isExpanded: true,
                              items: categoryItems,
                              onChanged: (v) => category = v ?? 'General',
                            decoration: InputDecoration(
                              labelText:
                                  AppLocalizations.of(ctx)?.categoryLabel ??
                                  'Category',
                              filled: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText:
                            AppLocalizations.of(ctx)?.titleLabel ?? 'Title',
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}'),
                        ),
                      ],
                      decoration: InputDecoration(
                        labelText:
                            AppLocalizations.of(ctx)?.amountLabel ?? 'Amount',
                        helperText:
                            AppLocalizations.of(ctx)?.amountHelperEg ??
                            'e.g., 123.45',
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                                initialDate: date,
                              );
                              if (picked != null) {
                                setModalState(() => date = picked);
                              }
                            },
                            child: Text(
                              '${AppLocalizations.of(ctx)?.dateLabel ?? 'Date:'} ${formatDate(date.toLocal(), ref.watch(sharedPrefsServiceProvider).dateFormat)}',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: () async {
                            final user = ref.read(currentUserProvider);
                            if (user == null) return;
                            final messenger = ScaffoldMessenger.of(ctx);
                            final nav = Navigator.of(ctx);
                            if (!validateTitle(titleController.text.trim())) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    AppLocalizations.of(ctx)?.enterTitleError ??
                                        'Enter a title',
                                  ),
                                ),
                              );
                              return;
                            }
                            if (!validateAmount(amountController.text.trim())) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    AppLocalizations.of(
                                          ctx,
                                        )?.enterValidAmountError ??
                                        'Enter a valid amount',
                                  ),
                                ),
                              );
                              return;
                            }
                            if (!validateDate(date)) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    AppLocalizations.of(
                                          ctx,
                                        )?.enterValidDateError ??
                                        'Enter a valid date',
                                  ),
                                ),
                              );
                              return;
                            }
                            final amount =
                                double.tryParse(amountController.text) ?? 0;
                            final isIncome = type == 'Income';
                            final localCategory = category == 'General'
                                ? null
                                : category;

                            try {
                              if (!isIncome && localCategory != null) {
                                final budgets = await ref
                                    .read(budgetRepositoryProvider)
                                    .streamForUser(user.uid)
                                    .first;
                                final hasBudget = budgets.any(
                                  (b) =>
                                      b.name.toLowerCase() ==
                                      localCategory.toLowerCase(),
                                );
                                if (!hasBudget) {
                                  final transactionData = {
                                    'userId': user.uid,
                                    'title': titleController.text,
                                    'amount': amount,
                                    'isIncome': isIncome,
                                    'categoryId': localCategory,
                                    'date': date,
                                    'notes': null,
                                  };
                                  final res =
                                      await _openCreateBudgetForCategory(
                                        ctx,
                                        localCategory,
                                        transactionData,
                                      );
                                  if (!context.mounted || !mounted) return;
                                  if (res == true) {
                                    FocusScope.of(context).unfocus();
                                    Navigator.of(context).pop(true);
                                  }
                                  return;
                                }
                              }

                              final ingest = ref.read(
                                transactionIngestServiceProvider,
                              );
                              await ingest.addManual(
                                userId: user.uid,
                                title: titleController.text,
                                amount: amount,
                                isIncome: isIncome,
                                categoryId: localCategory,
                                date: date,
                                notes: null,
                              );
                              if (repeatEnabled) {
                                final freq = repeatFreq == 'Weekly'
                                    ? RecurringFrequency.weekly
                                    : RecurringFrequency.monthly;
                                await ref
                                    .read(recurringRepositoryProvider)
                                    .createRule(
                                      userId: user.uid,
                                      title: titleController.text,
                                      amount: amount,
                                      isIncome: isIncome,
                                      categoryId: localCategory,
                                      startDate: date,
                                      frequency: freq,
                                    );
                              }
                              if (!mounted) return;
                              nav.pop(true);
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    AppLocalizations.of(
                                          ctx,
                                        )?.transactionSaved ??
                                        'Transaction saved',
                                  ),
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              messenger.showSnackBar(
                                SnackBar(content: Text('Failed: $e')),
                              );
                            }
                          },
                          child: Text(AppLocalizations.of(ctx)?.save ?? 'Save'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: repeatEnabled,
                      onChanged: (v) =>
                          setModalState(() => repeatEnabled = v ?? false),
                      title: Text(
                        AppLocalizations.of(ctx)?.repeatLabel ?? 'Repeat',
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (repeatEnabled) const SizedBox(height: 8),
                    if (repeatEnabled)
                      DropdownButtonFormField<String>(
                        initialValue: repeatFreq,
                        items: [
                          DropdownMenuItem(
                            value: 'Monthly',
                            child: Text(
                              AppLocalizations.of(ctx)?.monthlyLabel ??
                                  'Monthly',
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'Weekly',
                            child: Text(
                              AppLocalizations.of(ctx)?.weeklyLabel ?? 'Weekly',
                            ),
                          ),
                        ],
                        onChanged: (v) =>
                            setModalState(() => repeatFreq = v ?? 'Monthly'),
                        decoration: InputDecoration(
                          labelText:
                              AppLocalizations.of(ctx)?.frequencyLabel ??
                              'Frequency',
                          filled: true,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ));
    if (result != true) {
      final hasData =
          titleController.text.trim().isNotEmpty ||
          amountController.text.trim().isNotEmpty;
      if (hasData) {
        final prefs = ref.read(sharedPrefsServiceProvider);
        await prefs.saveDraft('transaction_add', {
          'title': titleController.text.trim(),
          'amount': double.tryParse(amountController.text.trim()),
          'type': type,
          'category': category,
          'date': date.toIso8601String(),
        });
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.draftSaved ?? 'Draft saved',
            ),
          ),
        );
      }
    } else {
      final prefs = ref.read(sharedPrefsServiceProvider);
      await prefs.clearDraft('transaction_add');
    }
    // Intentionally not disposing the controllers here. Disposing them
    // immediately after the sheet closes can race with framework
    // rebuilds and trigger "used after dispose" assertions. Let the
    // bottom sheet widget lifecycle manage its controllers instead.
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
    final titleController = TextEditingController(text: title);
    final amountController = TextEditingController(
      text: amount.abs().toStringAsFixed(2),
    );
    String type = amount >= 0 ? 'Income' : 'Expense';
    String category = categoryId ?? 'General';
    DateTime pickedDate = date;

    await Future.microtask(() => showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final messenger = ScaffoldMessenger.of(ctx);
        final nav = Navigator.of(ctx);
        final catsAsync = ref.watch(userCategoriesProvider);
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final categoryItems = <DropdownMenuItem<String>>[
              const DropdownMenuItem(value: 'General', child: Text('General')),
            ];
            final addedValues = <String>{'general'};
            catsAsync.when(
              loading: () {},
              error: (_, __) {},
              data: (list) {
                for (final c in list) {
                  final nm = (c.name ?? '').trim();
                  if (nm.isEmpty) continue;
                  if (!addedValues.contains(nm.toLowerCase())) {
                    categoryItems.add(
                      DropdownMenuItem(value: nm, child: Text(nm)),
                    );
                    addedValues.add(nm.toLowerCase());
                  }
                }
              },
            );

            // Include budgets as category options using the same mapping
            // logic as the create form so budget-claimed categories appear.
            final catsListEdit = catsAsync.maybeWhen(data: (d) => d, orElse: () => const []);
            final idToNameEdit = <String, String>{};
            final nameToIdEdit = <String, String>{};
            for (final c in catsListEdit) {
              final nm = (c.name ?? '').trim();
              if (nm.isEmpty) continue;
              idToNameEdit[c.id] = nm;
              nameToIdEdit[nm.toLowerCase()] = c.id;
            }
            final budgetsEdit = ref.watch(userBudgetsProvider).maybeWhen(data: (d) => d, orElse: () => const []);
            for (final b in budgetsEdit) {
              final catIds = b.categoryIds ?? <String>[];
              String key = '';
              if (catIds.isNotEmpty) {
                final raw = catIds.first.trim();
                if (raw.isEmpty) {
                  key = (b.name ?? '').trim();
                } else if (idToNameEdit.containsKey(raw)) key = idToNameEdit[raw]!.trim();
                else {
                  final mappedId = nameToIdEdit[raw.toLowerCase()];
                  if (mappedId != null) {
                    key = idToNameEdit[mappedId] ?? raw;
                  } else {
                    key = (b.name ?? raw).trim();
                  }
                }
              } else {
                key = (b.name ?? '').trim();
              }
              if (key.isEmpty) continue;
              final keyLower = key.toLowerCase();
              if (!addedValues.contains(keyLower)) {
                categoryItems.add(
                  DropdownMenuItem(value: key, child: Text(key)),
                );
                addedValues.add(keyLower);
              }
            }

            // Ensure the initially selected category matches exactly one
            // item by mapping stored ids -> display names when needed.
            String displayCategoryEdit = category.trim();
            if (idToNameEdit.containsKey(displayCategoryEdit)) {
              displayCategoryEdit = idToNameEdit[displayCategoryEdit]!.trim();
            } else {
              final mappedId = nameToIdEdit[displayCategoryEdit.toLowerCase()];
              if (mappedId != null) displayCategoryEdit = idToNameEdit[mappedId] ?? displayCategoryEdit;
            }
            final matchingCountEdit = categoryItems.where((it) => it.value == displayCategoryEdit).length;
            final effectiveInitialCategoryEdit = matchingCountEdit == 1
                ? displayCategoryEdit
                : (categoryItems.isNotEmpty ? categoryItems.first.value : null);
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: type,
                            items: [
                              DropdownMenuItem(
                                value: 'Expense',
                                child: Text(
                                  AppLocalizations.of(ctx)?.expense ??
                                      'Expense',
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'Income',
                                child: Text(
                                  AppLocalizations.of(ctx)?.income ?? 'Income',
                                ),
                              ),
                            ],
                            onChanged: (v) => type = v ?? 'Expense',
                            decoration: InputDecoration(
                              labelText:
                                  AppLocalizations.of(ctx)?.typeLabel ?? 'Type',
                              filled: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: effectiveInitialCategoryEdit,
                            items: categoryItems,
                            onChanged: (v) => category = v ?? 'General',
                            decoration: InputDecoration(
                              labelText:
                                  AppLocalizations.of(ctx)?.categoryLabel ??
                                  'Category',
                              filled: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText:
                            AppLocalizations.of(ctx)?.titleLabel ?? 'Title',
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}'),
                        ),
                      ],
                      decoration: InputDecoration(
                        labelText:
                            AppLocalizations.of(ctx)?.amountLabel ?? 'Amount',
                        helperText:
                            AppLocalizations.of(ctx)?.amountHelperEg ??
                            'e.g., 123.45',
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final d = await showDatePicker(
                                context: ctx,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                                initialDate: pickedDate,
                              );
                              if (d != null) {
                                setModalState(() => pickedDate = d);
                              }
                            },
                            child: Text(
                              '${AppLocalizations.of(ctx)?.dateLabel ?? 'Date:'} ${formatDate(pickedDate.toLocal(), ref.watch(sharedPrefsServiceProvider).dateFormat)}',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: () async {
                            if (!validateTitle(titleController.text.trim())) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    AppLocalizations.of(ctx)?.enterTitleError ??
                                        'Enter a title',
                                  ),
                                ),
                              );
                              return;
                            }
                            if (!validateAmount(amountController.text.trim())) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    AppLocalizations.of(
                                          ctx,
                                        )?.enterValidAmountError ??
                                        'Enter a valid amount',
                                  ),
                                ),
                              );
                              return;
                            }
                            if (!validateDate(pickedDate)) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    AppLocalizations.of(
                                          ctx,
                                        )?.enterValidDateError ??
                                        'Enter a valid date',
                                  ),
                                ),
                              );
                              return;
                            }
                            final amt =
                                double.tryParse(amountController.text) ?? 0;
                            final isIncome = type == 'Income';
                            final localCategory = category == 'General'
                                ? null
                                : category;
                            try {
                              final user = ref.read(currentUserProvider);
                              if (user == null) return;

                              if (!isIncome && localCategory != null) {
                                final budgets = await ref
                                    .read(budgetRepositoryProvider)
                                    .streamForUser(user.uid)
                                    .first;
                                final hasBudget = budgets.any(
                                  (b) =>
                                      b.name.toLowerCase() ==
                                      localCategory.toLowerCase(),
                                );
                                if (!hasBudget) {
                                  final editTransactionData = {
                                    'userId': user.uid,
                                    'title': titleController.text.trim(),
                                    'amount': isIncome ? amt.abs() : -amt.abs(),
                                    'categoryId': localCategory,
                                    'date': pickedDate,
                                    'notes': null,
                                    'isIncome': isIncome,
                                  };
                                  final res =
                                      await _openCreateBudgetForCategory(
                                        ctx,
                                        localCategory,
                                        editTransactionData,
                                      );
                                  if (!context.mounted || !mounted) return;
                                  if (res == true) {
                                    FocusScope.of(context).unfocus();
                                    Navigator.of(context).pop(true);
                                  }
                                  return;
                                }
                              }

                              await ref
                                  .read(transactionRepositoryProvider)
                                  .update(user.uid, id, {
                                    'title': titleController.text.trim(),
                                    'amount': isIncome ? amt.abs() : -amt.abs(),
                                    'categoryId': localCategory,
                                    'date_ms':
                                        pickedDate.millisecondsSinceEpoch,
                                  });
                              if (!mounted) return;
                              nav.pop();
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    AppLocalizations.of(
                                          ctx,
                                        )?.transactionUpdated ??
                                        'Transaction updated',
                                  ),
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              messenger.showSnackBar(
                                SnackBar(content: Text('Failed: $e')),
                              );
                            }
                          },
                          child: Text(
                            AppLocalizations.of(ctx)?.saveChanges ??
                                'Save changes',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ));
    // Intentionally not disposing the controllers here for the same
    // reason as above (avoid 'used after dispose' races).
  }

  Future<bool?> _openCreateBudgetForCategory(
    BuildContext parentCtx,
    String categoryName,
    Map<String, dynamic> transactionData,
  ) async {
    final theme = Theme.of(parentCtx);
    final allocatedController = TextEditingController();
    final pageMessenger = ScaffoldMessenger.of(parentCtx);

    final result = await Future.microtask(() => showModalBottomSheet<bool>(
      context: parentCtx,
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final nav = Navigator.of(ctx);
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Create Budget for "$categoryName"',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Set a monthly budget amount for this category',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: allocatedController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Monthly Budget Amount',
                    filled: true,
                    prefixText: '${ref.read(currencyProvider)} ',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          FocusScope.of(ctx).unfocus();
                          nav.pop(false);
                        },
                        child: const Text('Skip'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          debugPrint('Transaction modal: Save pressed');
                          print('Transaction modal: Save pressed');
                          // Visual feedback removed (no blocking dialog).
                          final user = ref.read(currentUserProvider);
                          if (user == null) return;
                          final repo = ref.read(budgetRepositoryProvider);
                          final amount =
                              double.tryParse(allocatedController.text) ?? 0;
                          try {
                            // Create budget
                            debugPrint('Creating budget for $categoryName (amount=$amount)');
                            // Normalize the category identifier to an ID when
                            // possible so the created budget references the
                            // canonical category id instead of a display name.
                            final catsListForCreate = ref.read(userCategoriesProvider).maybeWhen(data: (d) => d, orElse: () => const []);
                            final nameToIdForCreate = <String, String>{};
                            for (final c in catsListForCreate) {
                              final nm = (c.name ?? '').trim();
                              if (nm.isEmpty) continue;
                              nameToIdForCreate[nm.toLowerCase()] = c.id;
                            }
                            final rawKey = categoryName.trim();
                            String storageKey = rawKey;
                            if (nameToIdForCreate.containsKey(rawKey.toLowerCase())) {
                              storageKey = nameToIdForCreate[rawKey.toLowerCase()]!;
                            } else if (catsListForCreate.any((c) => c.id == rawKey)) {
                              storageKey = rawKey;
                            }
                            final createdBudget = await repo.create(
                              userId: user.uid,
                              name: categoryName,
                              allocated: amount,
                              period: BudgetPeriod.monthly,
                              categoryIds: [storageKey],
                            );
                            debugPrint('Created budget id=${createdBudget.id}');
                            if (!ctx.mounted) return;
                            FocusScope.of(ctx).unfocus();
                            nav.pop(true);
                            pageMessenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Budget for "$categoryName" created successfully!',
                                ),
                              ),
                            );

                            // Now save the original transaction
                            final ingest = ref.read(
                              transactionIngestServiceProvider,
                            );
                            await ingest.addManual(
                              userId: transactionData['userId'] as String,
                              title: transactionData['title'] as String,
                              amount: (transactionData['amount'] as double)
                                  .abs(),
                              isIncome: transactionData['isIncome'] as bool,
                              categoryId:
                                  transactionData['categoryId'] as String?,
                              date: transactionData['date'] as DateTime,
                              notes: transactionData['notes'] as String?,
                            );

                            // Do not pop parent sheet here; caller will close based on returned result
                          } catch (e) {
                            nav.pop(false);
                            pageMessenger.showSnackBar(
                              SnackBar(
                                content: Text('Failed to create budget: $e'),
                              ),
                            );
                          }
                        },
                        child: const Text('Create & Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ));
    // Do not dispose allocatedController here; let the sheet's lifecycle
    // handle it to avoid dispose-after-use races.
    return result;
  }
}
