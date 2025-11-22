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

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(sharedPrefsServiceProvider);
    final currency = ref.watch(currencyProvider);
    final kpis = ref.watch(kpisProvider);
    final txsAsync = ref.watch(recentTransactionsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () {}, tooltip: 'Notifications'),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBalanceCard(context, currency, kpis),
            const SizedBox(height: 24),
            Text('Quick Actions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildQuickActions(context, ref),
            const SizedBox(height: 24),
            Text('Recent Transactions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
        gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary.withValues(alpha: 0.6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Total Balance', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.8))),
        const SizedBox(height: 8),
        Text(formatAmount(kpis.net, currency), style: Theme.of(context).textTheme.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _buildBalanceDetail(context, 'Income', formatAmount(kpis.income, currency), Icons.arrow_downward, Colors.greenAccent),
          _buildBalanceDetail(context, 'Expense', formatAmount(kpis.expense, currency), Icons.arrow_upward, Colors.redAccent),
        ]),
      ]),
    );
  }

  Widget _buildBalanceDetail(BuildContext context, String label, String amount, IconData icon, Color color) {
    return Row(children: [
      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.8))),
        Text(amount, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
      ]),
    ]);
  }

  Widget _buildQuickActions(BuildContext context, WidgetRef ref) {
    final actions = [
      {'icon': Icons.send, 'label': 'Transfer', 'type': 'Expense', 'category': 'Transport'},
      {'icon': Icons.add_card, 'label': 'Top-up', 'type': 'Income', 'category': 'Income'},
      {'icon': Icons.receipt, 'label': 'Bill', 'type': 'Expense', 'category': 'General'},
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
                focusColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                hoverColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.08),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Icon(
                    action['icon'] as IconData,
                    color: Theme.of(context).colorScheme.secondary,
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

  Widget _buildRecentTransactions(BuildContext context, WidgetRef ref, String currency, AsyncValue<List<TransactionModel>> txsAsync) {
    return txsAsync.when(
      loading: () => Column(children: const [SkeletonListTile(), SizedBox(height: 12), SkeletonListTile(), SizedBox(height: 12), SkeletonListTile()]),
      error: (e, _) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.withValues(alpha: 0.3))), child: Row(children: [const Icon(Icons.error_outline, color: Colors.red), const SizedBox(width: 8), Expanded(child: Text('Failed to load: $e'))])),
      data: (items) {
        if (items.isEmpty) {
          return Center(child: Column(children: [Icon(Icons.receipt_long, size: 72, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 8), Text('No recent transactions', style: Theme.of(context).textTheme.titleMedium)]));
        }
        final list = items.take(3).toList();
        return Column(children: [
          for (var i = 0; i < list.length; i++) ...[
            _buildTransactionItem(context, list[i].title, list[i].categoryId ?? 'Uncategorized', formatAmount(list[i].amount, currency), list[i].amount < 0 ? Colors.white : Theme.of(context).colorScheme.secondary),
            if (i < list.length - 1) const SizedBox(height: 12),
          ]
        ]);
      },
    );
  }

  Widget _buildTransactionItem(BuildContext context, String title, String category, String amount, Color amountColor) {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.05))), child: Row(children: [
      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(Icons.shopping_bag_outlined, color: Theme.of(context).colorScheme.primary, size: 20)),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)), Text(category, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey))])),
      Text(amount, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: amountColor, fontWeight: FontWeight.bold)),
    ]));
  }

  Future<void> _openQuickAdd(BuildContext context, WidgetRef ref, {required String type, required String category}) async {
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        final messenger = ScaffoldMessenger.of(context);
        final nav = Navigator.of(context);
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 48, height: 4, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: DropdownButtonFormField<String>(initialValue: localType, items: const [DropdownMenuItem(value: 'Expense', child: Text('Expense')), DropdownMenuItem(value: 'Income', child: Text('Income'))], onChanged: (v) => localType = v ?? 'Expense', decoration: const InputDecoration(labelText: 'Type', filled: true))),
                const SizedBox(width: 12),
                Expanded(child: DropdownButtonFormField<String>(initialValue: localCategory, items: const [DropdownMenuItem(value: 'General', child: Text('General')), DropdownMenuItem(value: 'Food', child: Text('Food')), DropdownMenuItem(value: 'Entertainment', child: Text('Entertainment')), DropdownMenuItem(value: 'Transport', child: Text('Transport')), DropdownMenuItem(value: 'Income', child: Text('Income'))], onChanged: (v) => localCategory = v ?? 'General', decoration: const InputDecoration(labelText: 'Category', filled: true))),
              ]),
              const SizedBox(height: 12),
              TextFormField(controller: titleController, decoration: const InputDecoration(labelText: 'Title', filled: true)),
              const SizedBox(height: 12),
              TextFormField(controller: amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount', filled: true)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () async {final picked = await showDatePicker(context: ctx, firstDate: DateTime(2000), lastDate: DateTime(2100), initialDate: date); if (picked != null) date = picked;}, child: Text('Date: ${date.toLocal()}'.split(' ').first))),
                const SizedBox(width: 12),
                FilledButton(onPressed: () async {
                  final user = ref.read(currentUserProvider);
                  if (user == null) return;
                  final amount = double.tryParse(amountController.text) ?? 0;
                  final ingest = ref.read(transactionIngestServiceProvider);
                  try {
                    await ingest.addManual(userId: user.uid, title: titleController.text, amount: amount, isIncome: localType == 'Income', categoryId: localCategory == 'General' ? null : localCategory, date: date, notes: null);
                    nav.pop(true);
                    messenger.showSnackBar(const SnackBar(content: Text('Transaction saved')));
                  } catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
                  }
                }, child: const Text('Save')),
              ]),
            ]),
          ),
        );
      },
    );
    if (result != true) {
      final hasData = titleController.text.trim().isNotEmpty || amountController.text.trim().isNotEmpty;
      if (hasData) {
        await prefs.saveDraft('home_quick_add', {
          'title': titleController.text.trim(),
          'amount': double.tryParse(amountController.text.trim()),
          'type': localType,
          'category': localCategory,
          'date': date.toIso8601String(),
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draft saved')));
      }
    } else {
      await prefs.clearDraft('home_quick_add');
    }
    titleController.dispose();
    amountController.dispose();
  }
}
