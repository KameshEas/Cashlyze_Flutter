import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/repositories/transaction_repository.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/categorization_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import '../../core/services/transaction_ingest_service.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> with SingleTickerProviderStateMixin {
  String _filter = 'All';
  String _query = '';
  late final AnimationController _shimmerController;
  late final Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _shimmer = CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Widget _skeletonItem(BuildContext context) {
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
          AnimatedBuilder(
            animation: _shimmer,
            builder: (ctx, _) {
              return Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1 + 0.1 * _shimmer.value),
                  shape: BoxShape.circle,
                ),
              );
            },
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedBuilder(
                  animation: _shimmer,
                  builder: (ctx, _) => Container(
                    height: 14,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1 + 0.1 * _shimmer.value),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedBuilder(
                  animation: _shimmer,
                  builder: (ctx, _) => Container(
                    height: 12,
                    width: 160,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08 + 0.1 * _shimmer.value),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final txsAsync = ref.watch(userTransactionsProvider);

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
                Tooltip(
                  message: 'Import options',
                  child: PopupMenuButton<String>(
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
              loading: () => ListView.separated(
                padding: const EdgeInsets.all(16),
                itemBuilder: (ctx, i) => _skeletonItem(context),
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemCount: 6,
              ),
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
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long, size: 72, color: theme.colorScheme.primary),
                        const SizedBox(height: 12),
                        Text('No transactions', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: () => _openAddForm(context),
                          child: const Text('Add transaction'),
                        ),
                      ],
                    ),
                  );
                }
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
                          const SizedBox(width: 8),
                          Tooltip(
                            message: 'Edit',
                            child: IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _openEditForm(context, e.id, e.title, e.amount, e.categoryId, e.date),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Tooltip(
                            message: 'Delete',
                            child: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (dCtx) => AlertDialog(
                                    title: const Text('Delete transaction'),
                                    content: const Text('Are you sure you want to delete this transaction?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.of(dCtx).pop(false), child: const Text('Cancel')),
                                      FilledButton(onPressed: () => Navigator.of(dCtx).pop(true), child: const Text('Delete')),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  try {
                                    await ref.read(transactionRepositoryProvider).delete(e.id);
                                    messenger.showSnackBar(const SnackBar(content: Text('Deleted')));
                                  } catch (err) {
                                    messenger.showSnackBar(SnackBar(content: Text('Failed: $err')));
                                  }
                                }
                              },
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
                        final ingest = ref.read(transactionIngestServiceProvider);
                        final messenger = ScaffoldMessenger.of(ctx);
                        final nav = Navigator.of(ctx);
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

  Future<void> _openEditForm(BuildContext context, String id, String title, double amount, String? categoryId, DateTime date) async {
    final theme = Theme.of(context);
    final titleController = TextEditingController(text: title);
    final amountController = TextEditingController(text: amount.abs().toStringAsFixed(2));
    String type = amount >= 0 ? 'Income' : 'Expense';
    String category = categoryId ?? 'General';
    DateTime pickedDate = date;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        final messenger = ScaffoldMessenger.of(ctx);
        final nav = Navigator.of(ctx);
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
                          DropdownMenuItem(value: 'Income', child: Text('Income')),
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
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount', filled: true),
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
                        child: Text('Date: ${pickedDate.toLocal()}'.split(' ').first),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: () async {
                        final amt = double.tryParse(amountController.text) ?? 0;
                        try {
                          await ref.read(transactionRepositoryProvider).update(id, {
                            'title': titleController.text.trim(),
                            'amount': type == 'Income' ? amt.abs() : -amt.abs(),
                            'categoryId': category == 'General' ? null : category,
                            'date': pickedDate,
                          });
                          nav.pop();
                          messenger.showSnackBar(const SnackBar(content: Text('Transaction updated')));
                        } catch (e) {
                          messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
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
      if (rows.isEmpty || rows.first.length < 3) {
        messenger.showSnackBar(const SnackBar(content: Text('Invalid CSV format')));
        return;
      }
      final header = rows.first.map((e) => e.toString().toLowerCase().trim()).toList();
      final hTitle = header.indexOf('title');
      final hAmount = header.indexOf('amount');
      final hDate = header.indexOf('date');
      final hCategory = header.indexOf('category');
      if (hTitle == -1 || hAmount == -1 || hDate == -1) {
        messenger.showSnackBar(const SnackBar(content: Text('CSV must contain title, amount, date columns')));
        return;
      }
      final repo = ref.read(transactionRepositoryProvider);
      final categorizer = ref.read(categorizationServiceProvider);
      int imported = 0;
      int errors = 0;
      for (final row in rows.skip(1)) {
        if (row.length < 3) continue;
        final title = row[hTitle].toString();
        final amount = double.tryParse(row[hAmount].toString());
        final date = DateTime.tryParse(row[hDate].toString());
        final category = (hCategory != -1 && row.length > hCategory && row[hCategory] != null && row[hCategory].toString().isNotEmpty)
            ? row[hCategory].toString()
            : (categorizer.suggestCategory(title));
        if (title.trim().isEmpty || amount == null || date == null) {
          errors++;
          continue;
        }
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
        } catch (_) {
          errors++;
        }
      }
      messenger.showSnackBar(SnackBar(content: Text('Imported $imported, errors $errors')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }

  Future<void> _importBankDemo(BuildContext context) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final ingest = ref.read(transactionIngestServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final count = await ingest.importBankDemo(user.uid);
      messenger.showSnackBar(SnackBar(content: Text('Imported $count demo bank transactions')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Bank import failed: $e')));
    }
  }
}