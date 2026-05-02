import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/transaction_repository.dart';
import '../../core/repositories/budget_repository.dart';
import '../../core/repositories/recurring_repository.dart';
import '../../core/services/transaction_ingest_service.dart';
import '../../core/repositories/category_repository.dart';
import '../../core/services/auth_service.dart';
import '../../core/models/budget.dart';
import '../../core/providers/onboarding_provider.dart';
import '../../core/models/recurring.dart';
import '../../core/providers/shared_prefs_provider.dart';
import '../../core/utils/format.dart';
import '../../core/utils/validation.dart';
import '../../core/widgets/category_picker_field.dart';
import '../../l10n/app_localizations.dart';
import '../../core/utils/repo_error_handler.dart';

enum TransactionFormMode { create, edit }

class TransactionFormSheet extends ConsumerStatefulWidget {
  final TransactionFormMode mode;
  final String? id;
  final String? initialTitle;
  final double? initialAmount; // absolute value
  final String? initialCategory;
  final DateTime? initialDate;

  const TransactionFormSheet.create({
    super.key,
    this.initialTitle,
    this.initialAmount,
    this.initialCategory,
    this.initialDate,
  })  : mode = TransactionFormMode.create,
        id = null;

  const TransactionFormSheet.edit({
    super.key,
    required this.id,
    this.initialTitle,
    this.initialAmount,
    this.initialCategory,
    this.initialDate,
  })  : mode = TransactionFormMode.edit;

  @override
  ConsumerState<TransactionFormSheet> createState() => _TransactionFormSheetState();
}

class _TransactionFormSheetState extends ConsumerState<TransactionFormSheet> {
  late final TextEditingController titleController;
  late final TextEditingController amountController;
  String type = 'Expense';
  String category = 'General';
  DateTime date = DateTime.now();
  bool repeatEnabled = false;
  String repeatFreq = 'Monthly';

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.initialTitle ?? '');
    amountController = TextEditingController(text: (widget.initialAmount ?? 0).toStringAsFixed(2));
    if (widget.initialAmount != null && widget.initialAmount! >= 0) type = 'Income';
    if (widget.initialCategory != null) category = widget.initialCategory!;
    if (widget.initialDate != null) date = widget.initialDate!;
  }

  @override
  void dispose() {
    titleController.dispose();
    amountController.dispose();
    super.dispose();
  }

  Future<bool?> _openCreateBudgetForCategory(BuildContext parentCtx, String categoryName, Map<String, dynamic> transactionData) async {
    final theme = Theme.of(parentCtx);
    final allocatedController = TextEditingController();
    final pageMessenger = ScaffoldMessenger.of(parentCtx);

    final result = await showModalBottomSheet<bool>(
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
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 48, height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 12),
                Text('Create Budget for "$categoryName"', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Set a monthly budget amount for this category', style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                const SizedBox(height: 12),
                TextFormField(controller: allocatedController, keyboardType: TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Monthly Budget Amount', filled: true, prefixText: '${ref.read(currencyProvider)} ')),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: () { FocusScope.of(ctx).unfocus(); nav.pop(false); }, child: const Text('Skip'))),
                  const SizedBox(width: 12),
                  Expanded(child: FilledButton(onPressed: () async {
                    final user = ref.read(currentUserProvider);
                    if (user == null) return;
                    final repo = ref.read(budgetRepositoryProvider);
                    final amount = double.tryParse(allocatedController.text) ?? 0;
                    try {
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
                      final createdBudget = await repo.create(userId: user.uid, name: categoryName, allocated: amount, period: BudgetPeriod.monthly, categoryIds: [storageKey]);
                      if (!ctx.mounted) return;
                      FocusScope.of(ctx).unfocus();
                      nav.pop(true);
                      pageMessenger.showSnackBar(SnackBar(content: Text('Budget for "$categoryName" created successfully!')));

                      // Save the originally-intended transaction
                      final ingest = ref.read(transactionIngestServiceProvider);
                      await ingest.addManual(
                        userId: transactionData['userId'] as String,
                        title: transactionData['title'] as String,
                        amount: (transactionData['amount'] as double).abs(),
                        isIncome: transactionData['isIncome'] as bool,
                        categoryId: transactionData['categoryId'] as String?,
                        date: transactionData['date'] as DateTime,
                        notes: transactionData['notes'] as String?,
                      );
                    } catch (e) {
                      nav.pop(false);
                      showRepoErrorSnackBar(pageMessenger, e);
                    }
                  }, child: const Text('Create & Save'))),
                ]),
              ],
            ),
          ),
        );
      },
    );

    // Do not dispose allocatedController here; the sheet manages it.
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final prefs = ref.watch(sharedPrefsServiceProvider);
    if (widget.mode == TransactionFormMode.create) {
      // If creating, attempt to hydrate from saved draft
      final draft = prefs.getDraft('transaction_add');
      if (draft != null) {
        titleController.text = (draft['title'] as String?) ?? titleController.text;
        final amt = draft['amount'];
        if (amt != null) amountController.text = amt.toString();
        type = (draft['type'] as String?) ?? type;
        category = (draft['category'] as String?) ?? category;
        final ds = draft['date'] as String?;
        if (ds != null) {
          final parsed = DateTime.tryParse(ds);
          if (parsed != null) date = parsed;
        }
      }

    }

    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 48, height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(
                initialValue: type,
                items: [
                  DropdownMenuItem(value: 'Expense', child: Text(t?.expense ?? 'Expense')),
                  DropdownMenuItem(value: 'Income', child: Text(t?.income ?? 'Income')),
                ],
                onChanged: (v) => setState(() => type = v ?? 'Expense'),
                decoration: InputDecoration(labelText: t?.typeLabel ?? 'Type', filled: true),
              )),
              const SizedBox(width: 12),
              Expanded(
                child: CategoryPickerField(
                  value: category,
                  onChanged: (v) => setState(() => category = v),
                  label: t?.categoryLabel ?? 'Category',
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextFormField(controller: titleController, decoration: InputDecoration(labelText: t?.titleLabel ?? 'Title', filled: true)),
            const SizedBox(height: 12),
            TextFormField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
              decoration: InputDecoration(labelText: t?.amountLabel ?? 'Amount', helperText: t?.amountHelperEg ?? 'e.g., 123.45', filled: true),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () async {
                final picked = await showDatePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime(2100), initialDate: date);
                if (picked != null) setState(() => date = picked);
              }, child: Text('${t?.dateLabel ?? 'Date:'} ${formatDate(date.toLocal(), ref.watch(sharedPrefsServiceProvider).dateFormat)}'))),
              const SizedBox(width: 12),
              FilledButton(onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final nav = Navigator.of(context);
                if (!validateTitle(titleController.text.trim())) {
                  showRepoErrorSnackBar(messenger, Exception(t?.enterTitleError ?? 'Enter a title'));
                  return;
                }
                if (!validateAmount(amountController.text.trim())) {
                  showRepoErrorSnackBar(messenger, Exception(t?.enterValidAmountError ?? 'Enter a valid amount'));
                  return;
                }
                if (!validateDate(date)) {
                  showRepoErrorSnackBar(messenger, Exception(t?.enterValidDateError ?? 'Enter a valid date'));
                  return;
                }
                final amt = double.tryParse(amountController.text) ?? 0;
                final isIncome = type == 'Income';
                final localCategory = category == 'General' ? null : category;
                try {
                  final user = ref.read(currentUserProvider);
                  if (user == null) return;

                  if (widget.mode == TransactionFormMode.create) {
                    if (!isIncome && localCategory != null) {
                      final budgets = await ref.read(budgetRepositoryProvider).streamForUser(user.uid).first;
                      final hasBudget = budgets.any((b) => b.name.toLowerCase() == localCategory.toLowerCase());
                      if (!hasBudget) {
                        final transactionData = {
                          'userId': user.uid,
                          'title': titleController.text.trim(),
                          'amount': amt,
                          'isIncome': isIncome,
                          'categoryId': localCategory,
                          'date': date,
                          'notes': null,
                        };
                        final res = await _openCreateBudgetForCategory(context, localCategory, transactionData);
                        if (!mounted) return;
                        if (res == true) {
                          FocusScope.of(context).unfocus();
                          Navigator.of(context).pop(true);
                        }
                        return;
                      }
                    }

                    final ingest = ref.read(transactionIngestServiceProvider);
                    await ingest.addManual(userId: user.uid, title: titleController.text, amount: amt, isIncome: isIncome, categoryId: localCategory, date: date, notes: null);
                    if (repeatEnabled) {
                      final freq = repeatFreq == 'Weekly' ? RecurringFrequency.weekly : RecurringFrequency.monthly;
                      await ref.read(recurringRepositoryProvider).createRule(userId: user.uid, title: titleController.text, amount: amt, isIncome: isIncome, categoryId: localCategory, startDate: date, frequency: freq);
                    }
                    if (!mounted) return;
                    nav.pop(true);
                  } else {
                    // Edit
                    final user = ref.read(currentUserProvider);
                    if (user == null) return;
                    await ref.read(transactionRepositoryProvider).update(user.uid, widget.id!, {
                      'title': titleController.text.trim(),
                      'amount': isIncome ? amt.abs() : -amt.abs(),
                      'categoryId': localCategory,
                      'date_ms': date.millisecondsSinceEpoch,
                    });
                    if (!mounted) return;
                    nav.pop(true);
                  }
                } catch (e) {
                  if (!mounted) return;
                  debugPrint('Transaction save failed: $e');
                  showRepoErrorSnackBar(messenger, e);
                }
              }, child: Text(t?.save ?? 'Save')),
            ]),
            const SizedBox(height: 12),
            CheckboxListTile(value: repeatEnabled, onChanged: (v) => setState(() => repeatEnabled = v ?? false), title: Text(t?.repeatLabel ?? 'Repeat'), contentPadding: EdgeInsets.zero),
            if (repeatEnabled) const SizedBox(height: 8),
            if (repeatEnabled)
              DropdownButtonFormField<String>(
                initialValue: repeatFreq,
                items: [
                  DropdownMenuItem(value: 'Monthly', child: Text(t?.monthlyLabel ?? 'Monthly')),
                  DropdownMenuItem(value: 'Weekly', child: Text(t?.weeklyLabel ?? 'Weekly')),
                ],
                onChanged: (v) => setState(() => repeatFreq = v ?? 'Monthly'),
                decoration: InputDecoration(labelText: t?.frequencyLabel ?? 'Frequency', filled: true),
              ),
          ],
        ),
      ),
    );
  }
}
