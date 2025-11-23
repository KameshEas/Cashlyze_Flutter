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

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  String _filter = 'All';
  String _query = '';
  DateTime _selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final txsAsync = ref.watch(userTransactionsProvider);
    final prefs = ref.watch(sharedPrefsServiceProvider);
    final currency = ref.watch(currencyProvider);
    final datePattern = prefs.dateFormat;

    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      floatingActionButton: Tooltip(
        message: 'Add transaction',
        child: FloatingActionButton.extended(
          onPressed: () => _openAddForm(context),
          icon: const Icon(Icons.add),
          label: const Text('Add'),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Search',
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (v) => setState(() => _query = v),
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
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Previous month',
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () {
                          setState(() {
                            _selectedMonth = DateTime(
                              _selectedMonth.year,
                              _selectedMonth.month - 1,
                              1,
                            );
                          });
                        },
                      ),
                      Text(
                        '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}',
                        style: theme.textTheme.bodyMedium,
                      ),
                      IconButton(
                        tooltip: 'Next month',
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () {
                          setState(() {
                            _selectedMonth = DateTime(
                              _selectedMonth.year,
                              _selectedMonth.month + 1,
                              1,
                            );
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButtonHideUnderline(
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
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All')),
                        DropdownMenuItem(
                          value: 'Income',
                          child: Text('Income'),
                        ),
                        DropdownMenuItem(
                          value: 'Expense',
                          child: Text('Expense'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _filter = v ?? 'All'),
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
                        child: const Text('Retry'),
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
                  final matchesFilter =
                      _filter == 'All' ||
                      (_filter == 'Income' && e.amount > 0) ||
                      (_filter == 'Expense' && e.amount < 0);
                  final inMonth =
                      e.date.isAfter(
                        monthStart.subtract(const Duration(seconds: 1)),
                      ) &&
                      e.date.isBefore(monthEnd);
                  return matchesQuery && matchesFilter && inMonth;
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
                          'No transactions',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: () => _openAddForm(context),
                          child: const Text('Add transaction'),
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
                            children: const [
                              Icon(Icons.edit, color: Colors.green),
                              SizedBox(width: 8),
                              Text('Edit'),
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
                            children: const [
                              Text('Delete'),
                              SizedBox(width: 8),
                              Icon(Icons.delete, color: Colors.red),
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
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (dCtx) => AlertDialog(
                              title: const Text('Delete transaction'),
                              content: const Text(
                                'Are you sure you want to delete this transaction?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(dCtx).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.of(dCtx).pop(true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
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
                              messenger.showSnackBar(
                                SnackBar(
                                  content: const Text('Deleted'),
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
                              messenger.showSnackBar(
                                SnackBar(content: Text('Failed: $err')),
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
                                alpha: 0.05,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isIncome ? Icons.arrow_downward : Icons.arrow_upward,
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
                                    Row(children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: theme.colorScheme.onSurface.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                                        child: Text(e.categoryId ?? 'Uncategorized', style: theme.textTheme.bodySmall),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(formatDate(e.date, datePattern), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
                                    ]),
                                  ],
                                ),
                              ),
                              Text(
                                formatAmount(e.amount, currency),
                                style: theme.textTheme.bodyLarge?.copyWith(color: isIncome ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
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
                        items: const [
                          DropdownMenuItem(
                            value: 'Expense',
                            child: Text('Expense'),
                          ),
                          DropdownMenuItem(
                            value: 'Income',
                            child: Text('Income'),
                          ),
                        ],
                        onChanged: (v) => type = v ?? 'Expense',
                        decoration: const InputDecoration(
                          labelText: 'Type',
                          filled: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: category,
                        items: const [
                          DropdownMenuItem(
                            value: 'General',
                            child: Text('General'),
                          ),
                          DropdownMenuItem(value: 'Food', child: Text('Food')),
                          DropdownMenuItem(
                            value: 'Entertainment',
                            child: Text('Entertainment'),
                          ),
                          DropdownMenuItem(
                            value: 'Transport',
                            child: Text('Transport'),
                          ),
                        ],
                        onChanged: (v) => category = v ?? 'General',
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          filled: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    filled: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amountController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
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
                          if (picked != null) date = picked;
                        },
                        child: Text('Date: ${date.toLocal()}'.split(' ').first),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: () async {
                        final user = ref.read(currentUserProvider);
                        if (user == null) return;
                        final amount =
                            double.tryParse(amountController.text) ?? 0;
                        final ingest = ref.read(
                          transactionIngestServiceProvider,
                        );
                        final messenger = ScaffoldMessenger.of(context);
                        final nav = Navigator.of(context);
                        try {
                          await ingest.addManual(
                            userId: user.uid,
                            title: titleController.text,
                            amount: amount,
                            isIncome: type == 'Income',
                            categoryId: category == 'General' ? null : category,
                            date: date,
                            notes: null,
                          );
                          if (!mounted) return;
                          nav.pop(true);
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Transaction saved')),
                          );
                        } catch (e) {
                          if (e is BudgetMissingException) {
                            // Show budget creation dialog
                            final shouldCreateBudget = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Budget Not Found'),
                                content: Text(
                                  'No budget exists for "${e.categoryName}" category. Would you like to create a budget for this category?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(true),
                                    child: const Text('Create Budget'),
                                  ),
                                ],
                              ),
                            );

                            if (shouldCreateBudget == true && mounted) {
                              // Open budget creation dialog
                              await _openCreateBudgetForCategory(
                                context,
                                e.categoryName,
                                e.transactionData,
                              );
                            }
                          } else {
                            if (!mounted) return;
                            messenger.showSnackBar(
                              SnackBar(content: Text('Failed: $e')),
                            );
                          }
                        }
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Draft saved')));
        }
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
        final messenger = ScaffoldMessenger.of(context);
        final nav = Navigator.of(context);
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
                        items: const [
                          DropdownMenuItem(
                            value: 'Expense',
                            child: Text('Expense'),
                          ),
                          DropdownMenuItem(
                            value: 'Income',
                            child: Text('Income'),
                          ),
                        ],
                        onChanged: (v) => type = v ?? 'Expense',
                        decoration: const InputDecoration(
                          labelText: 'Type',
                          filled: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: category,
                        items: const [
                          DropdownMenuItem(
                            value: 'General',
                            child: Text('General'),
                          ),
                          DropdownMenuItem(value: 'Food', child: Text('Food')),
                          DropdownMenuItem(
                            value: 'Entertainment',
                            child: Text('Entertainment'),
                          ),
                          DropdownMenuItem(
                            value: 'Transport',
                            child: Text('Transport'),
                          ),
                          DropdownMenuItem(
                            value: 'Income',
                            child: Text('Income'),
                          ),
                        ],
                        onChanged: (v) => category = v ?? 'General',
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          filled: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    filled: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
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
                          if (d != null) pickedDate = d;
                        },
                        child: Text(
                          'Date: ${pickedDate.toLocal()}'.split(' ').first,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: () async {
                        final amt = double.tryParse(amountController.text) ?? 0;
                        try {
                          final user = ref.read(currentUserProvider);
                          if (user == null) return;
                          await ref
                              .read(transactionRepositoryProvider)
                              .update(user.uid, id, {
                                'title': titleController.text.trim(),
                                'amount': type == 'Income'
                                    ? amt.abs()
                                    : -amt.abs(),
                                'categoryId': category == 'General'
                                    ? null
                                    : category,
                                'date_ms': pickedDate.millisecondsSinceEpoch,
                              });
                          if (!mounted) return;
                          nav.pop();
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Transaction updated'),
                            ),
                          );
                        } catch (e) {
                          if (e is BudgetMissingException) {
                            // Show budget creation dialog for edit
                            final shouldCreateBudget = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Budget Not Found'),
                                content: Text(
                                  'No budget exists for "${e.categoryName}" category. Would you like to create a budget for this category?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(true),
                                    child: const Text('Create Budget'),
                                  ),
                                ],
                              ),
                            );

                            if (shouldCreateBudget == true && mounted) {
                              // Create a simplified transaction data for edit case
                              final currentUser = ref.read(currentUserProvider);
                              if (currentUser == null) return;
                              final editTransactionData = {
                                'userId': currentUser.uid,
                                'title': titleController.text.trim(),
                                'amount': type == 'Income'
                                    ? amt.abs()
                                    : -amt.abs(),
                                'categoryId': category == 'General'
                                    ? null
                                    : category,
                                'date': pickedDate,
                                'notes': null,
                                'isIncome': type == 'Income',
                              };
                              await _openCreateBudgetForCategory(
                                context,
                                e.categoryName,
                                editTransactionData,
                              );
                            }
                          } else {
                            if (!mounted) return;
                            messenger.showSnackBar(
                              SnackBar(content: Text('Failed: $e')),
                            );
                          }
                        }
                      },
                      child: const Text('Save changes'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    titleController.dispose();
    amountController.dispose();
  }

  Future<void> _openCreateBudgetForCategory(
    BuildContext context,
    String categoryName,
    Map<String, dynamic> transactionData,
  ) async {
    final theme = Theme.of(context);
    final allocatedController = TextEditingController();
    final pageMessenger = ScaffoldMessenger.of(context);

    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final nav = Navigator.of(context);
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
                  decoration: const InputDecoration(
                    labelText: 'Monthly Budget Amount',
                    filled: true,
                    prefixText: '₹ ',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => nav.pop(false),
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

                            if (mounted) {
                              Navigator.of(
                                context,
                              ).pop(true); // Close the add transaction dialog
                              pageMessenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Transaction saved successfully!',
                                  ),
                                ),
                              );
                            }
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
  }
}
