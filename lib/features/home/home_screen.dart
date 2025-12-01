import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/onboarding_provider.dart';
import '../../core/providers/insights_providers.dart';
import '../../core/providers/transaction_providers.dart';
import '../../core/services/transaction_ingest_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/models/transaction.dart';
import '../../core/repositories/emi_repository.dart';
import '../../core/repositories/transaction_repository.dart';
import '../../core/services/realtime_db_service.dart';
import '../../l10n/app_localizations.dart';
import '../../core/providers/recurring_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(recurringProcessorProvider);
    final currency = ref.watch(currencyProvider);
    final kpis = ref.watch(kpisProvider);
    final txsAsync = ref.watch(recentTransactionsProvider);
    final mismatch = ref.watch(databaseUrlMismatchProvider);
    final dbUrl = ref.watch(databaseUrlProvider);
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t?.dashboard ?? 'Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
            tooltip: 'Notifications',
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            tooltip: 'Menu',
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'emi', child: Text('EMI Tracker')),
              PopupMenuItem(value: 'emi_new', child: Text('Add EMI Plan')),
            ],
            onSelected: (value) {
              if (value == 'emi') {
                GoRouter.of(context).go('/emi');
              } else if (value == 'emi_new') {
                GoRouter.of(context).go('/emi/new');
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (mismatch)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'Connected to $dbUrl. Expected asia-southeast1 instance.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            _buildBalanceCard(context, currency, kpis),
            const SizedBox(height: 24),
            Text(
              t?.quickActions ?? 'Quick Actions',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildQuickActions(context, ref),
            const SizedBox(height: 24),
            Text(
              t?.emiTracker ?? 'EMI Tracker',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildUpcomingEmi(context, ref, currency),
            const SizedBox(height: 24),
            Text(
              t?.recentTransactions ?? 'Recent Transactions',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildRecentTransactions(context, ref, currency, txsAsync),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context, String currency, Kpis kpis) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary.withValues(alpha: 0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Balance',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'This Month',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Text(
              formatAmount(kpis.net, currency),
              key: ValueKey(kpis.net),
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBalanceDetail(
                context,
                'Income',
                formatAmount(kpis.income, currency),
                Icons.arrow_downward,
                Theme.of(context).colorScheme.secondary,
              ),
              _buildBalanceDetail(
                context,
                'Expense',
                formatAmount(kpis.expense, currency),
                Icons.arrow_upward,
                Theme.of(context).colorScheme.error,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceDetail(
    BuildContext context,
    String label,
    String amount,
    IconData icon,
    Color color,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final isExpense = label.toLowerCase().contains('expense');
    final bg = isExpense
        ? scheme.error.withValues(alpha: 0.2)
        : color.withValues(alpha: 0.15);
    final border = isExpense
        ? Border.all(color: scheme.error.withValues(alpha: 0.35))
        : null;
    final ic = isExpense ? Icons.trending_up : icon;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        border: border,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ic, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              Text(
                amount,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, WidgetRef ref) {
    final actions = [
      {
        'icon': Icons.send,
        'label': 'Transfer',
        'type': 'Expense',
        'category': 'Transport',
      },
      {
        'icon': Icons.add_card,
        'label': 'Top-up',
        'type': 'Income',
        'category': 'Income',
      },
      {
        'icon': Icons.receipt,
        'label': 'Bill',
        'type': 'Expense',
        'category': 'General',
      },
      {'icon': Icons.more_horiz, 'label': 'More', 'route': '/transactions'},
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: actions.map((action) {
        return Column(
          children: [
            Semantics(
              label: '${action['label']} action',
              button: true,
              child: InkWell(
                onTap: () {
                  if (action.containsKey('route')) {
                    GoRouter.of(context).go(action['route'] as String);
                  } else {
                    _openQuickAdd(
                      context,
                      ref,
                      type: action['type'] as String,
                      category: action['category'] as String,
                    );
                  }
                },
                borderRadius: BorderRadius.circular(16),
                focusColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                hoverColor: Theme.of(
                  context,
                ).colorScheme.secondary.withValues(alpha: 0.08),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: IconTheme(
                    data: const IconThemeData(size: 20),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.secondary.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        action['icon'] as IconData,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              action['label'] as String,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildRecentTransactions(
    BuildContext context,
    WidgetRef ref,
    String currency,
    AsyncValue<List<TransactionModel>> txsAsync,
  ) {
    return txsAsync.when(
      loading: () => Column(
        children: const [
          SkeletonListTile(),
          SizedBox(height: 12),
          SkeletonListTile(),
          SizedBox(height: 12),
          SkeletonListTile(),
        ],
      ),
      error: (e, _) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text('Failed to load: $e')),
          ],
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long,
                  size: 72,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  'No recent transactions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          );
        }
        final list = items.take(3).toList();
        return Column(
          children: [
            for (var i = 0; i < list.length; i++) ...[
              _buildTransactionItem(
                context,
                list[i].title,
                list[i].categoryId ?? 'Uncategorized',
                formatAmount(list[i].amount, currency),
                list[i].amount >= 0,
              ),
              if (i < list.length - 1) const SizedBox(height: 16),
            ],
          ],
        );
      },
    );
  }

  Widget _buildTransactionItem(
    BuildContext context,
    String title,
    String category,
    String amount,
    bool isIncome,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
              Icons.shopping_bag_outlined,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(category, style: theme.textTheme.bodySmall),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: isIncome
                  ? theme.colorScheme.secondary
                  : theme.colorScheme.error,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openQuickAdd(
    BuildContext context,
    WidgetRef ref, {
    required String type,
    required String category,
  }) async {
    final theme = Theme.of(context);
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    String localType = type;
    String localCategory = category;
    DateTime date = DateTime.now();
    // Prefill from draft
    final prefs = ref.read(sharedPrefsServiceProvider);
    final draft = prefs.getDraft('home_quick_add');
    if (draft != null) {
      titleController.text = (draft['title'] as String?) ?? '';
      final amt = draft['amount'];
      if (amt != null) amountController.text = amt.toString();
      localType = (draft['type'] as String?) ?? localType;
      localCategory = (draft['category'] as String?) ?? localCategory;
      final ds = draft['date'] as String?;
      if (ds != null) {
        final parsed = DateTime.tryParse(ds);
        if (parsed != null) date = parsed;
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
                        initialValue: localType,
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
                        onChanged: (v) => localType = v ?? 'Expense',
                        decoration: const InputDecoration(
                          labelText: 'Type',
                          filled: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: localCategory,
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
                        onChanged: (v) => localCategory = v ?? 'General',
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
                        try {
                          await ingest.addManual(
                            userId: user.uid,
                            title: titleController.text,
                            amount: amount,
                            isIncome: localType == 'Income',
                            categoryId: localCategory == 'General'
                                ? null
                                : localCategory,
                            date: date,
                            notes: null,
                          );
                          nav.pop(true);
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Transaction saved')),
                          );
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('Failed: $e')),
                          );
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
        await prefs.saveDraft('home_quick_add', {
          'title': titleController.text.trim(),
          'amount': double.tryParse(amountController.text.trim()),
          'type': localType,
          'category': localCategory,
          'date': date.toIso8601String(),
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Draft saved')));
      }
    } else {
      await prefs.clearDraft('home_quick_add');
    }
    titleController.dispose();
    amountController.dispose();
  }

  Widget _buildUpcomingEmi(
    BuildContext context,
    WidgetRef ref,
    String currency,
  ) {
    final upcomingAsync = ref.watch(emiUpcomingProvider);
    final theme = Theme.of(context);
    return upcomingAsync.when(
      loading: () => const SkeletonListTile(),
      error: (e, _) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text('Failed to load: $e')),
          ],
        ),
      ),
      data: (items) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.08,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.calendar_today, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Upcoming EMI',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  FilledButton.tonal(
                    onPressed: () => GoRouter.of(context).go('/emi'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    child: const Text('View Details'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                height: 1,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
              ),
              const SizedBox(height: 12),
              if (items.isEmpty)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.08,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.credit_card, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No upcoming EMI this month',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    FilledButton.tonal(
                      onPressed: () => GoRouter.of(context).go('/emi/new'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      child: const Text('Set Reminder'),
                    ),
                  ],
                )
              else ...[
                for (var i = 0; i < items.take(3).length; i++) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.05,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.credit_card, size: 18),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Due: ${items[i].dueDate.toLocal()}'
                                      .split(' ')
                                      .first,
                                  style: theme.textTheme.bodyMedium,
                                ),
                                Text(
                                  formatAmount(items[i].installment, currency),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        FilledButton.tonal(
                          onPressed: () async {
                            final user = ref.read(currentUserProvider);
                            if (user == null) return;
                            try {
                              await ref
                                  .read(emiRepositoryProvider)
                                  .markPaid(
                                    user.uid,
                                    items[i].planId,
                                    items[i].id,
                                  );
                              await ref
                                  .read(transactionRepositoryProvider)
                                  .create(
                                    userId: user.uid,
                                    title: 'EMI installment',
                                    amount: -items[i].installment.abs(),
                                    categoryId: 'EMI',
                                    date: items[i].dueDate,
                                    notes: 'EMI payment recorded from Home',
                                  );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'EMI marked paid and transaction added',
                                  ),
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed: $e')),
                              );
                            }
                          },
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          child: const Text('Pay'),
                        ),
                      ],
                    ),
                  ),
                  if (i < items.take(3).length - 1) const SizedBox(height: 12),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}
