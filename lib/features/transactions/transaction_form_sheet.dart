import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/budget.dart';
import '../../core/models/category.dart';
import '../../core/models/recurring.dart';
import '../../core/providers/onboarding_provider.dart';
import '../../core/providers/shared_prefs_provider.dart';
import '../../core/repositories/budget_repository.dart';
import '../../core/repositories/category_repository.dart';
import '../../core/repositories/recurring_repository.dart';
import '../../core/repositories/transaction_repository.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/transaction_ingest_service.dart';
import '../../core/ui/motion.dart';
import '../../core/utils/format.dart';
import '../../core/utils/repo_error_handler.dart';
import '../../core/utils/validation.dart';
import '../../core/widgets/category_picker_field.dart';
import '../../l10n/app_localizations.dart';

enum TransactionFormMode { create, edit }

class TransactionFormSheet extends ConsumerStatefulWidget {

  const TransactionFormSheet.create({
    super.key,
    this.initialTitle,
    this.initialAmount,
    this.initialCategory,
    this.initialDate,
    this.initialType,
  })  : mode = TransactionFormMode.create,
        id = null;

  const TransactionFormSheet.edit({
    super.key,
    required this.id,
    this.initialTitle,
    this.initialAmount,
    this.initialCategory,
    this.initialDate,
  })  : mode = TransactionFormMode.edit,
        initialType = null;
  final TransactionFormMode mode;
  final String? id;
  final String? initialTitle;
  final double? initialAmount; // absolute value
  final String? initialCategory;
  final DateTime? initialDate;
  final String? initialType;

  @override
  ConsumerState<TransactionFormSheet> createState() => _TransactionFormSheetState();
}

class _TransactionFormSheetState extends ConsumerState<TransactionFormSheet> {
  late final TextEditingController titleController;
  late final TextEditingController amountController;
  late final TextEditingController tagsController;
  String type = 'Expense';
  String category = 'General';
  DateTime date = DateTime.now();
  List<String> tags = [];
  bool repeatEnabled = false;
  String repeatFreq = 'Monthly';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.initialTitle ?? '');
    amountController = TextEditingController(
      text: widget.initialAmount == null
          ? ''
          : widget.initialAmount!.abs().toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), ''),
    );
    tagsController = TextEditingController();
    if (widget.initialType != null) type = widget.initialType!;
    if (widget.initialAmount != null && widget.initialAmount! >= 0) type = 'Income';
    if (widget.initialCategory != null) {
      // Normalize initial category: if an id was provided, map to display name.
      // Do async lookup after init so we don't make initState async.
      final raw = widget.initialCategory!.trim();
      if (raw.isNotEmpty) {
        Future.microtask(() async {
          var cats = ref.read(userCategoriesProvider).maybeWhen(data: (final d) => d, orElse: () => const <CategoryModel>[]);
          if (cats.isEmpty) {
            try {
              final user = ref.read(currentUserProvider);
              if (user != null) {
                cats = await ref.read(categoryRepositoryProvider).getAllForUser(user.uid);
              }
            } catch (_) {}
          }
          final byId = cats.where((final c) => c.id == raw).toList();
          if (byId.isNotEmpty) {
            if (mounted) setState(() => category = byId.first.name);
          } else {
            if (mounted) setState(() => category = widget.initialCategory!);
          }
        });
      }
    }
    if (widget.initialDate != null) date = widget.initialDate!;
  }

  @override
  void dispose() {
    titleController.dispose();
    amountController.dispose();
    tagsController.dispose();
    super.dispose();
  }

  Future<String?> _resolveCategoryId({
    required final String userId,
    required final String? selectedCategory,
  }) async {
    if (selectedCategory == null || selectedCategory.trim().isEmpty) return null;
    final raw = selectedCategory.trim();
    if (raw.toLowerCase() == 'general') return null;

    var categories = ref
        .read(userCategoriesProvider)
        .maybeWhen(data: (final d) => d, orElse: () => const <CategoryModel>[]);

    if (categories.isEmpty) {
      categories = await ref.read(categoryRepositoryProvider).getAllForUser(userId);
    }

    for (final c in categories) {
      if (c.id == raw) return c.id;
    }
    for (final c in categories) {
      if (c.name.toLowerCase() == raw.toLowerCase()) return c.id;
    }

    // If the user picked a label that is not yet in categories, create it so
    // transaction payloads can always send a stable category_id. Invalidate
    // the cache immediately rather than relying solely on the websocket
    // broadcast - if the socket is down/reconnecting, a stale cache would
    // otherwise cause every subsequent submission of the same new category
    // name to create yet another duplicate.
    final created = await ref.read(categoryRepositoryProvider).create(
      userId: userId,
      name: raw,
    );
    ref.invalidate(userCategoriesProvider);
    return created.id;
  }

  Future<bool?> _openCreateBudgetForCategory(final BuildContext parentCtx, final String categoryName, final Map<String, dynamic> transactionData) async {
    final theme = Theme.of(parentCtx);
    final allocatedController = TextEditingController();
    final pageMessenger = ScaffoldMessenger.of(parentCtx);

    final result = await showModalBottomSheet<bool>(
      context: parentCtx,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (final ctx) {
        final nav = Navigator.of(ctx);
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 48, height: 4, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 12),
                Text('Create Budget for "$categoryName"', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Set a monthly budget amount for this category', style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                const SizedBox(height: 12),
                TextFormField(controller: allocatedController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Monthly Budget Amount', filled: true, prefixText: '${ref.read(currencyProvider)} ')),
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
                      final catsListForCreate = ref.read(userCategoriesProvider).maybeWhen(data: (final d) => d, orElse: () => const <CategoryModel>[]);
                      final nameToIdForCreate = <String, String>{};
                      for (final c in catsListForCreate) {
                        final nm = c.name.trim();
                        if (nm.isEmpty) continue;
                        nameToIdForCreate[nm.toLowerCase()] = c.id;
                      }
                      final rawKey = categoryName.trim();
                      String storageKey = rawKey;
                      if (nameToIdForCreate.containsKey(rawKey.toLowerCase())) {
                        storageKey = nameToIdForCreate[rawKey.toLowerCase()]!;
                      } else if (catsListForCreate.any((final c) => c.id == rawKey)) {
                        storageKey = rawKey;
                      }
                      await repo.create(userId: user.uid, name: categoryName, allocated: amount, period: BudgetPeriod.monthly, categoryIds: [storageKey]);
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
                        categoryName: transactionData['categoryName'] as String?,
                        date: transactionData['date'] as DateTime,
                        tags: (transactionData['tags'] as List<String>?)?.isNotEmpty ?? false ? transactionData['tags'] as List<String>? : null,
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
  Widget build(final BuildContext context) {
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
        child: MotionFadeIn(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 48, height: 4, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(
                initialValue: type,
                items: [
                  DropdownMenuItem(value: 'Expense', child: Text(t?.expense ?? 'Expense')),
                  DropdownMenuItem(value: 'Income', child: Text(t?.income ?? 'Income')),
                ],
                onChanged: (final v) => setState(() => type = v ?? 'Expense'),
                decoration: InputDecoration(labelText: t?.typeLabel ?? 'Type', filled: true),
              )),
              const SizedBox(width: 12),
              Expanded(
                child: CategoryPickerField(
                  value: category,
                  onChanged: (final v) => setState(() => category = v),
                  label: t?.categoryLabel ?? 'Category',
                  budgetsOnly: true,
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
              FilledButton(onPressed: _isSubmitting ? null : () async {
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
                final localCategoryName = category; // always keep display label (e.g., 'General')
                setState(() => _isSubmitting = true);
                try {
                  final user = ref.read(currentUserProvider);
                  if (user == null) return;
                  final localCategoryId = await _resolveCategoryId(
                    userId: user.uid,
                    selectedCategory: localCategoryName,
                  );

                  if (widget.mode == TransactionFormMode.create) {
                    if (!isIncome && localCategoryName.toLowerCase() != 'general') {
                      final budgets = await ref.read(budgetRepositoryProvider).streamForUser(user.uid).first;
                      final hasBudget = budgets.any((final b) => b.name.toLowerCase() == localCategoryName.toLowerCase());
                      if (!hasBudget) {
                        final transactionData = {
                          'userId': user.uid,
                          'title': titleController.text.trim(),
                          'amount': amt,
                          'isIncome': isIncome,
                          'categoryId': localCategoryId,
                          'categoryName': localCategoryName,
                          'date': date,
                          'tags': tags.isNotEmpty ? tags : null,
                        };
                        if (!context.mounted) return;
                        final res = await _openCreateBudgetForCategory(context, localCategoryName, transactionData);
                        if (!context.mounted) return;
                        if (res == true) {
                          FocusScope.of(context).unfocus();
                          Navigator.of(context).pop(true);
                        }
                        return;
                      }
                    }

                    final ingest = ref.read(transactionIngestServiceProvider);
                    await ingest.addManual(userId: user.uid, title: titleController.text, amount: amt, isIncome: isIncome, categoryId: localCategoryId, categoryName: localCategoryName, date: date, tags: tags.isNotEmpty ? tags : null);
                    if (repeatEnabled) {
                      final freq = repeatFreq == 'Weekly' ? RecurringFrequency.weekly : RecurringFrequency.monthly;
                      await ref.read(recurringRepositoryProvider).createRule(userId: user.uid, title: titleController.text, amount: amt, isIncome: isIncome, categoryId: localCategoryId, startDate: date, frequency: freq);
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
                      'categoryId': localCategoryId,
                      // Send the selected display value so backend can clear or match
                      // the category even when user picks 'General'.
                      'categoryName': category,
                      'date_ms': date.millisecondsSinceEpoch,
                    });
                    if (!mounted) return;
                    nav.pop(true);
                  }
                } catch (e) {
                  if (!mounted) return;
                  debugPrint('Transaction save failed: $e');
                  showRepoErrorSnackBar(messenger, e);
                } finally {
                  if (mounted) setState(() => _isSubmitting = false);
                }
              }, child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(t?.save ?? 'Save')),
            ]),
            const SizedBox(height: 12),
            Text('Tags', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ...tags.map((final tag) => InputChip(
                  label: Text(tag),
                  onDeleted: () => setState(() => tags.remove(tag)),
                )),
                ActionChip(
                  label: const Text('Add Tag'),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (final ctx) => AlertDialog(
                        title: Text(t?.titleLabel ?? 'Add Tag'),
                        content: TextField(
                          controller: tagsController,
                          decoration: const InputDecoration(
                            labelText: 'Tag name',
                            filled: true,
                          ),
                          onSubmitted: (final value) {
                            final trimmed = value.trim();
                            if (trimmed.isNotEmpty && !tags.contains(trimmed)) {
                              setState(() {
                                tags.add(trimmed);
                                tagsController.clear();
                              });
                            }
                            Navigator.of(ctx).pop();
                          },
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              final trimmed = tagsController.text.trim();
                              if (trimmed.isNotEmpty && !tags.contains(trimmed)) {
                                setState(() {
                                  tags.add(trimmed);
                                  tagsController.clear();
                                });
                              }
                              Navigator.of(ctx).pop();
                            },
                            child: const Text('Add'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            CheckboxListTile(value: repeatEnabled, onChanged: (final v) => setState(() => repeatEnabled = v ?? false), title: Text(t?.repeatLabel ?? 'Repeat'), contentPadding: EdgeInsets.zero),
            if (repeatEnabled) const SizedBox(height: 8),
            if (repeatEnabled)
              DropdownButtonFormField<String>(
                initialValue: repeatFreq,
                items: [
                  DropdownMenuItem(value: 'Monthly', child: Text(t?.monthlyLabel ?? 'Monthly')),
                  DropdownMenuItem(value: 'Weekly', child: Text(t?.weeklyLabel ?? 'Weekly')),
                ],
                onChanged: (final v) => setState(() => repeatFreq = v ?? 'Monthly'),
                decoration: InputDecoration(labelText: t?.frequencyLabel ?? 'Frequency', filled: true),
              ),
          ],
        )),
      ),
    );
  }
}
