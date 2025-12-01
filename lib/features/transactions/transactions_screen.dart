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
  DateTime _selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

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
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: DropdownButton<DateTime>(
                    value: _selectedMonth,
                    items: List.generate(12, (i) {
                      final now = DateTime.now();
                      final m = DateTime(now.year, now.month - i, 1);
                      final label =
                          '${m.year}-${m.month.toString().padLeft(2, '0')}';
                      return DropdownMenuItem(value: m, child: Text(label));
                    }),
                    onChanged: (v) =>
                        setState(() => _selectedMonth = v ?? _selectedMonth),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButtonHideUnderline(
                  child: Semantics(
                    label: 'Filter by type',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: DropdownButton<String>(
                        value: _filter,
                        items: [
                          DropdownMenuItem(
                            value: 'All',
                            child: Text(t?.filterAll ?? 'All'),
                          ),
                          DropdownMenuItem(
                            value: 'Income',
                            child: Text(t?.filterIncome ?? 'Income'),
                          ),
                          DropdownMenuItem(
                            value: 'Expense',
                            child: Text(t?.filterExpense ?? 'Expense'),
                          ),
                        ],
                        onChanged: (v) => setState(() => _filter = v ?? 'All'),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButtonHideUnderline(
                  child: Semantics(
                    label: 'Filter by category',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: catsAsync.when(
                        loading: () => DropdownButton<String>(
                          value: _categoryFilter,
                          items: const [
                            DropdownMenuItem(value: 'All', child: Text('All')),
                          ],
                          onChanged: (v) =>
                              setState(() => _categoryFilter = v ?? 'All'),
                        ),
                        error: (e, _) => DropdownButton<String>(
                          value: _categoryFilter,
                          items: const [
                            DropdownMenuItem(value: 'All', child: Text('All')),
                          ],
                          onChanged: (v) =>
                              setState(() => _categoryFilter = v ?? 'All'),
                        ),
                        data: (list) => DropdownButton<String>(
                          value: _categoryFilter,
                          items: [
                            DropdownMenuItem(
                              value: 'All',
                              child: Text(t?.filterAll ?? 'All'),
                            ),
                            DropdownMenuItem(
                              value: 'Uncategorized',
                              child: Text(t?.uncategorized ?? 'Uncategorized'),
                            ),
                            ...list
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c.name,
                                    child: Text(c.name),
                                  ),
                                )
                                .toList(),
                          ],
                          onChanged: (v) =>
                              setState(() => _categoryFilter = v ?? 'All'),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 110,
                  child: Semantics(
                    label: 'Minimum amount filter',
                    hint: 'Set lowest amount to show',
                    textField: true,
                    child: TextField(
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
                      onChanged: (v) => setState(() => _minAmountText = v),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 110,
                  child: Semantics(
                    label: 'Maximum amount filter',
                    hint: 'Set highest amount to show',
                    textField: true,
                    child: TextField(
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
                      onChanged: (v) => setState(() => _maxAmountText = v),
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
                  padding: const EdgeInsets.all(16),
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
                final monthStart = DateTime(
                  _selectedMonth.year,
                  _selectedMonth.month,
                  1,
                );
                final monthEnd = DateTime(
                  _selectedMonth.year,
                  _selectedMonth.month + 1,
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
                  final inMonth =
                      e.date.isAfter(
                        monthStart.subtract(const Duration(seconds: 1)),
                      ) &&
                      e.date.isBefore(monthEnd);
                  return matchesQuery &&
                      matchesType &&
                      matchesCategory &&
                      matchesAmount &&
                      inMonth;
                }).toList();
                if (filtered.isEmpty) {
                  return Center(
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
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(userTransactionsProvider);
                    await Future.delayed(const Duration(milliseconds: 150));
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
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
                              messenger.showSnackBar(
                                SnackBar(
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
                                              amount:
                                                  payload['amount'] as double,
                                              categoryId:
                                                  payload['categoryId']
                                                      as String?,
                                              date: payload['date'] as DateTime,
                                              notes: null,
                                            );
                                      } catch (_) {}
                                    },
                                  ),
                                ),
                              );
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
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            e.categoryId ??
                                                (t?.uncategorized ??
                                                    'Uncategorized'),
                                            style: theme.textTheme.bodySmall,
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

    final result = await showModalBottomSheet<bool>(
      context: context,
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
            catsAsync.when(
              loading: () {},
              error: (_, __) {},
              data: (list) {
                for (final c in list) {
                  categoryItems.add(
                    DropdownMenuItem(value: c.name, child: Text(c.name)),
                  );
                }
              },
            );
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
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
                            initialValue: category,
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
                              '${AppLocalizations.of(ctx)?.dateLabel ?? 'Date:'} ${date.toLocal()}'
                                  .split(' ')
                                  .first,
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
    );
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
    titleController.dispose();
    amountController.dispose();
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

    await showModalBottomSheet<void>(
      context: context,
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
            catsAsync.when(
              loading: () {},
              error: (_, __) {},
              data: (list) {
                for (final c in list) {
                  categoryItems.add(
                    DropdownMenuItem(value: c.name, child: Text(c.name)),
                  );
                }
              },
            );
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
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
                            initialValue: category,
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
                              '${AppLocalizations.of(ctx)?.dateLabel ?? 'Date:'} ${pickedDate.toLocal()}'
                                  .split(' ')
                                  .first,
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
    );
    titleController.dispose();
    amountController.dispose();
  }

  Future<bool?> _openCreateBudgetForCategory(
    BuildContext parentCtx,
    String categoryName,
    Map<String, dynamic> transactionData,
  ) async {
    final theme = Theme.of(parentCtx);
    final allocatedController = TextEditingController();
    final pageMessenger = ScaffoldMessenger.of(parentCtx);

    final result = await showModalBottomSheet<bool>(
      context: parentCtx,
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
            padding: const EdgeInsets.all(16.0),
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
                          final user = ref.read(currentUserProvider);
                          if (user == null) return;
                          final repo = ref.read(budgetRepositoryProvider);
                          final amount =
                              double.tryParse(allocatedController.text) ?? 0;
                          try {
                            // Create budget
                            await repo.create(
                              userId: user.uid,
                              name: categoryName,
                              allocated: amount,
                              period: BudgetPeriod.monthly,
                            );
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
    );
    allocatedController.dispose();
    return result;
  }
}
