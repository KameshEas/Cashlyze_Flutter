import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/repositories/transaction_repository.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/categorization_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  String _filter = 'All';
  String _query = '';
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final txsAsync = ref.watch(userTransactionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
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
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'csv') {
                      _importCsv(context);
                    } else if (value == 'bank_demo') {
                      _importBankDemo(context);
                    }
                  },
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(value: 'csv', child: Text('Import CSV')),
                    PopupMenuItem(value: 'bank_demo', child: Text('Import from bank (demo)')),
                  ],
                  icon: const Icon(Icons.upload_file),
                ),
                const SizedBox(width: 8),
                DropdownButtonHideUnderline(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: DropdownButton<String>(
                      value: _filter,
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All')),
                        DropdownMenuItem(value: 'Income', child: Text('Income')),
                        DropdownMenuItem(value: 'Expense', child: Text('Expense')),
                      ],
                      onChanged: (v) => setState(() => _filter = v ?? 'All'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: txsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Failed to load: $e')),
              data: (items) {
                final filtered = items.where((e) {
                  final matchesQuery = _query.isEmpty ||
                      e.title.toLowerCase().contains(_query.toLowerCase());
                  final matchesFilter = _filter == 'All' ||
                      (_filter == 'Income' && e.amount > 0) ||
                      (_filter == 'Expense' && e.amount < 0);
                  return matchesQuery && matchesFilter;
                }).toList();
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (ctx, i) {
                    final e = filtered[i];
                    final isIncome = e.amount > 0;
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
                              color: isIncome
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.red.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                              color: isIncome ? Colors.greenAccent : Colors.redAccent,
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
                                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  '${e.categoryId ?? 'Uncategorized'} • ${e.date.toLocal()}'.split('.').first,
                                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${isIncome ? '+' : ''}${e.amount.toStringAsFixed(2)}',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: isIncome ? Colors.greenAccent : Colors.redAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemCount: filtered.length,
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

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
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
                          DropdownMenuItem(value: 'Expense', child: Text('Expense')),
                          DropdownMenuItem(value: 'Income', child: Text('Income')),
                        ],
                        onChanged: (v) => type = v ?? 'Expense',
                        decoration: const InputDecoration(labelText: 'Type', filled: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: category,
                        items: const [
                          DropdownMenuItem(value: 'General', child: Text('General')),
                          DropdownMenuItem(value: 'Food', child: Text('Food')),
                          DropdownMenuItem(value: 'Entertainment', child: Text('Entertainment')),
                          DropdownMenuItem(value: 'Transport', child: Text('Transport')),
                        ],
                        onChanged: (v) => category = v ?? 'General',
                        decoration: const InputDecoration(labelText: 'Category', filled: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title', filled: true),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amountController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount', filled: true),
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
                        final amount = double.tryParse(amountController.text) ?? 0;
                        final sugg = ref.read(categorizationServiceProvider).suggestCategory(titleController.text);
                        final repo = ref.read(transactionRepositoryProvider);
                        final messenger = ScaffoldMessenger.of(ctx);
                        final nav = Navigator.of(ctx);
                        try {
                          await repo.create(
                            userId: user.uid,
                            title: titleController.text,
                            amount: type == 'Income' ? amount.abs() : -amount.abs(),
                            categoryId: sugg,
                            date: date,
                            notes: null,
                          );
                          nav.pop();
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
    titleController.dispose();
    amountController.dispose();
  }

  Future<void> _importCsv(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return;
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        messenger.showSnackBar(const SnackBar(content: Text('Failed to read CSV')));
        return;
      }
      final content = String.fromCharCodes(bytes);
      final rows = const CsvToListConverter(eol: '\n').convert(content);
      // Expecting columns: title, amount, date(YYYY-MM-DD), category(optional)
      final repo = ref.read(transactionRepositoryProvider);
      final categorizer = ref.read(categorizationServiceProvider);
      int imported = 0;
      for (final row in rows.skip(1)) {
        if (row.length < 3) continue;
        final title = row[0].toString();
        final amount = double.tryParse(row[1].toString()) ?? 0;
        final date = DateTime.tryParse(row[2].toString()) ?? DateTime.now();
        final category = row.length > 3 && row[3] != null && row[3].toString().isNotEmpty
            ? row[3].toString()
            : (categorizer.suggestCategory(title));
        try {
          await repo.create(
            userId: user.uid,
            title: title,
            amount: amount,
            categoryId: category,
            date: date,
            notes: 'CSV import',
          );
          imported++;
        } catch (_) {}
      }
      messenger.showSnackBar(SnackBar(content: Text('Imported $imported transactions')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }

  Future<void> _importBankDemo(BuildContext context) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final repo = ref.read(transactionRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await repo.create(userId: user.uid, title: 'Bank POS Grocery', amount: -52.35, categoryId: 'Food', date: DateTime.now(), notes: 'Demo import');
      await repo.create(userId: user.uid, title: 'Bank ACH Salary', amount: 1200.00, categoryId: 'Income', date: DateTime.now().subtract(const Duration(days: 2)), notes: 'Demo import');
      messenger.showSnackBar(const SnackBar(content: Text('Imported demo bank transactions')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Bank import failed: $e')));
    }
  }
}