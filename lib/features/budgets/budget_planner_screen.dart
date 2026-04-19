import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/repositories/budget_repository.dart';
import '../../core/services/auth_service.dart';
import '../../core/providers/shared_prefs_provider.dart';
import '../../core/providers/budget_providers.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/utils/format.dart';
import '../../core/providers/onboarding_provider.dart';
import '../../core/models/budget.dart';
import 'budget_card.dart';
import 'package:flutter/services.dart';
import '../../core/utils/validation.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/repositories/category_repository.dart';
import '../../core/ui/constants.dart';
import '../../core/widgets/animated_progress_indicator.dart';
import '../../core/widgets/animated_progress_text.dart';
import '../onboarding/budget_tutorial_overlay.dart';
import '../../core/providers/first_time_feature_provider.dart';

class BudgetPlannerScreen extends ConsumerStatefulWidget {
  const BudgetPlannerScreen({super.key});

  @override
  ConsumerState<BudgetPlannerScreen> createState() =>
      _BudgetPlannerScreenState();
}

class _BudgetPlannerScreenState extends ConsumerState<BudgetPlannerScreen> {
  bool _showBudgetTutorial = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prefs = ref.watch(sharedPrefsServiceProvider);
    final currency = ref.watch(currencyProvider);
    final budgetsAsync = ref.watch(userBudgetsProvider);
    final budgets = budgetsAsync.maybeWhen(
      data: (d) => d,
      orElse: () => const [],
    );
    final spentMap = ref.watch(budgetsUtilizationProvider);
    // Exclude the synthetic/read-only 'General' budget from totals so its
    // infinite allocation doesn't break utilization math.
    final visibleBudgets = budgets.where((b) => b.id != '__general_budget').toList();
    final totalAllocated = visibleBudgets.fold<double>(0.0, (p, e) => p + e.allocated);
    final totalSpent = visibleBudgets.fold<double>(
      0.0,
      (p, e) => p + (spentMap[e.id] ?? 0.0),
    );
    final double utilization = totalAllocated == 0.0 ? 0.0 : totalSpent / totalAllocated;

    // Watch ordered and filtered budgets
    final orderedBudgets = ref.watch(orderedBudgetsProvider);
    final selectedPeriodFilter = ref.watch(periodFilterProvider);
    final showTutorial = _showBudgetTutorial && ref.watch(firstTimeBudgetProvider);

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: const Text('Budgets')),
          floatingActionButton: Tooltip(
            message: 'Create budget',
            child: FloatingActionButton.extended(
              onPressed: () => _openCreateBudget(context),
              icon: const Icon(Icons.add),
              label: const Text('Create'),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (prefs.alertsEnabled && utilization > 0.9)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_outlined,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Budget utilization is high (${(utilization * 100).toStringAsFixed(0)}%). Consider adjusting allocations.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            _BudgetsHeroCard(
              totalAllocated: totalAllocated,
              totalSpent: totalSpent,
              utilization: utilization,
              currency: currency,
              isLoading: budgetsAsync.isLoading,
            ),
            const SizedBox(height: 24),
            const _SectionHeader(
              title: 'Category Budgets',
              icon: Icons.donut_large_rounded,
            ),
            const SizedBox(height: 12),
            // Period filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final period in ['All', 'Daily', 'Weekly', 'Monthly'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(period),
                        selected: selectedPeriodFilter == period,
                        onSelected: (selected) {
                          if (selected) {
                            ref.read(periodFilterProvider.notifier).setFilter(period);
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            budgetsAsync.when(
              loading: () => ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 4,
                separatorBuilder: (sepCtx, i) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) {
                  return const SkeletonListTile();
                },
              ),
              error: (e, _) =>
                  Center(child: Text('Failed to load budgets: $e')),
              data: (list) {
                if (orderedBudgets.isEmpty) {
                  return Column(
                    children: [
                      const SizedBox(height: AppSpacing.s8),
                      const _EmptyState(
                        message: 'No budgets',
                        icon: Icons.account_balance_wallet,
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      Center(
                        child: FilledButton(
                          onPressed: () => _openCreateBudget(context),
                          child: const Text('Create budget'),
                        ),
                      ),
                    ],
                  );
                }
                return ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  onReorder: (oldIndex, newIndex) {
                    final newOrderedList = [...orderedBudgets];
                    if (oldIndex < newIndex) {
                      newIndex -= 1;
                    }
                    final item = newOrderedList.removeAt(oldIndex);
                    newOrderedList.insert(newIndex, item);

                    // Extract IDs for persistence (including General budget)
                    final orderToSave = newOrderedList.map((b) => b.id).toList();

                    ref.read(budgetOrderProvider.notifier).updateOrder(orderToSave);
                  },
                  children: [
                    for (int i = 0; i < orderedBudgets.length; i++)
                      Padding(
                        key: ValueKey('budget_padding_${orderedBudgets[i].id}'),
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildBudgetItem(
                          context,
                          orderedBudgets[i],
                          currency,
                          i,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
        ),
      ),
    ),
        // Tutorial overlay
        if (showTutorial)
          BudgetTutorialOverlay(
            onComplete: () {
              setState(() => _showBudgetTutorial = false);
            },
          ),
      ],
    );
  }

  Widget _buildBudgetItem(
    BuildContext context,
    BudgetModel budget,
    String currency,
    int index,
  ) {
    final theme = Theme.of(context);
    final isSynthetic = budget.id == '__general_budget';

    final budgetCard = BudgetCard(
      key: ValueKey('budget_${budget.id}'),
      budget: budget,
      currency: currency,
      isSynthetic: isSynthetic,
      onAdjust: () => _openAdjustBudget(
        context,
        budget.id,
        budget.allocated,
        budget.name,
      ),
    );

    // General budget can be reordered (via long-press) but not swiped
    if (isSynthetic) {
      return budgetCard;
    }

    return Dismissible(
      key: ValueKey('budget_dismissible_${budget.id}'),
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
            Text('Adjust'),
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
          await _openAdjustBudget(context, budget.id, budget.allocated, budget.name);
          return false;
        }
        // For delete (right swipe), show confirmation dialog
        if (!context.mounted) return false;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Budget?'),
            content: Text('Are you sure you want to delete "${budget.name}"? You can undo this within 8 seconds.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ?? false;
        
        if (!confirmed) return false;
        
        // For delete (right swipe), perform soft delete with undo
        try {
          final user = ref.read(currentUserProvider);
          if (user == null) return false;

          // Store the deleted budget for recovery
          ref.read(lastDeletedBudgetProvider.notifier).setDeleted(DeletedBudgetRecord(
            budget: budget,
            timestamp: DateTime.now(),
          ));

          // Perform the deletion
          await ref.read(budgetRepositoryProvider).delete(user.uid, budget.id);

          // Show undo SnackBar
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Budget deleted'),
                duration: const Duration(seconds: 8),
                action: SnackBarAction(
                  label: 'Undo',
                  onPressed: () async {
                    try {
                      // Restore the budget
                      final restored = await ref.read(budgetRepositoryProvider).create(
                        userId: user.uid,
                        name: budget.name,
                        allocated: budget.allocated,
                        period: budget.period,
                        categoryIds: budget.categoryIds,
                      );
                      // Clear the deletion record
                      ref.read(lastDeletedBudgetProvider.notifier).clear();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Budget restored')),
                        );
                      }
                    } catch (err) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to restore: $err')),
                        );
                      }
                    }
                  },
                ),
              ),
            );
          }
          return true;
        } catch (err) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed: $err')),
            );
          }
          return false;
        }
      },
      child: budgetCard,
    );
  }

  Widget _buildBudgetListItem(BuildContext context, BudgetModel e, String currency) {
    final isSynthetic = e.id == '__general_budget';
    final budgetCard = BudgetCard(
      budget: e,
      currency: currency,
      isSynthetic: isSynthetic,
      onAdjust: () => _openAdjustBudget(
        context,
        e.id,
        e.allocated,
        e.name,
      ),
    );

    if (isSynthetic) {
      return budgetCard;
    }

    return Dismissible(
      key: ValueKey('budget_${e.id}'),
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
            Text('Adjust'),
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
          await _openAdjustBudget(context, e.id, e.allocated, e.name);
          return false;
        }
        final messenger = ScaffoldMessenger.of(context);
        final confirm = await showConfirmDialog(
          context,
          title: 'Delete budget',
          content:
              'Are you sure you want to delete this budget?',
          confirmLabel: 'Delete',
          cancelLabel: 'Cancel',
        );
        if (confirm == true) {
          try {
            final user = ref.read(currentUserProvider);
            if (user == null) return false;
            await ref
                .read(budgetRepositoryProvider)
                .delete(user.uid, e.id);
            messenger.showSnackBar(
              const SnackBar(content: Text('Deleted')),
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
      child: budgetCard,
    );
  }





  

  Future<void> _openCreateBudget(BuildContext context) async {
    final theme = Theme.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final nameController = TextEditingController();
    final allocatedController = TextEditingController();
    final pageMessenger = ScaffoldMessenger.of(context);
    List<String> selectedCategoryIds = <String>[];
    BudgetPeriod selectedPeriod = BudgetPeriod.monthly;

    final prefs = ref.read(sharedPrefsServiceProvider);
    final draft = prefs.getDraft('budget_create');
    if (draft != null) {
      nameController.text = (draft['name'] as String?) ?? '';
      final amt = draft['allocated'];
      if (amt != null) allocatedController.text = amt.toString();
      final cats = draft['categoryIds'];
      if (cats is List) {
        selectedCategoryIds = cats.cast<String>();
      }
      final periodStr = draft['period'] as String?;
      if (periodStr != null) {
        try {
          selectedPeriod = BudgetPeriod.values.firstWhere(
            (p) => p.toString() == 'BudgetPeriod.$periodStr',
          );
        } catch (_) {
          selectedPeriod = BudgetPeriod.monthly;
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
        final nav = Navigator.of(ctx);
        final categories = ref
            .watch(userCategoriesProvider)
            .maybeWhen(data: (d) => d, orElse: () => const []);
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: StatefulBuilder(builder: (ctx, setSheetState) => Consumer(builder: (cctx, wref, _) {
              final categories = wref.watch(userCategoriesProvider).maybeWhen(data: (d) => d, orElse: () => const []);
              return Column(
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
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: allocatedController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}'),
                      ),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Allocated',
                      helperText: 'e.g., 500.00',
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Budget Period',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<BudgetPeriod>(
                    segments: const [
                      ButtonSegment(
                        value: BudgetPeriod.daily,
                        label: Text('Daily'),
                      ),
                      ButtonSegment(
                        value: BudgetPeriod.weekly,
                        label: Text('Weekly'),
                      ),
                      ButtonSegment(
                        value: BudgetPeriod.monthly,
                        label: Text('Monthly'),
                      ),
                    ],
                    selected: <BudgetPeriod>{selectedPeriod},
                    onSelectionChanged: (Set<BudgetPeriod> newSelection) {
                      setSheetState(() {
                        selectedPeriod = newSelection.first;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  if (categories.isNotEmpty) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Categories (optional)',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in categories)
                          FilterChip(
                            label: Text(c.name),
                            // Store & compare by name — transactions also store
                            // categoryId as the category name string, not the
                            // RTDB key, so this must match.
                            selected: selectedCategoryIds.contains(c.name),
                            onSelected: (sel) {
                              setSheetState(() {
                                if (sel) {
                                  selectedCategoryIds = [
                                    ...selectedCategoryIds,
                                    c.name,
                                  ];
                                } else {
                                  selectedCategoryIds = selectedCategoryIds
                                      .where((n) => n != c.name)
                                      .toList();
                                }
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            final user = ref.read(currentUserProvider);
                            if (user == null) {
                              // In normal app flow this shouldn't happen because
                              // the Budgets page requires an authenticated user.
                              // If it does, just no-op instead of showing a
                              // confusing snackbar.
                              return;
                            }

                            final repo = ref.read(budgetRepositoryProvider);
                            final name = nameController.text.trim();
                            if (name.isEmpty) {
                              // Use the sheet's own ScaffoldMessenger so the
                              // snackbar appears INSIDE/ABOVE the modal, not
                              // hidden behind it on the page underneath.
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('Enter a name')),
                              );
                              return;
                            }

                            final amountText = allocatedController.text.trim();
                            if (!validateAmount(amountText)) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text('Enter a valid amount'),
                                ),
                              );
                              return;
                            }

                            final amount = double.tryParse(amountText) ?? 0;
                            if (amount <= 0) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Amount must be greater than zero',
                                  ),
                                ),
                              );
                              return;
                            }

                            try {
                              // Normalize selected category identifiers to canonical
                              // category IDs where possible before persisting the
                              // budget. The UI keeps `selectedCategoryIds` as
                              // readable names for UX; here we convert names -> ids
                              // using the user's categories so stored budgets are
                              // consistent.
                              final catsList = ref.read(userCategoriesProvider).maybeWhen(data: (d) => d, orElse: () => const []);
                              final nameToId = <String, String>{};
                              for (final c in catsList) {
                                final nm = (c.name ?? '').trim();
                                if (nm.isEmpty) continue;
                                nameToId[nm.toLowerCase()] = c.id;
                              }
                              final finalCategoryIds = selectedCategoryIds.map((s) {
                                final sTrim = (s ?? '').trim();
                                if (sTrim.isEmpty) return sTrim;
                                final mapped = nameToId[sTrim.toLowerCase()];
                                if (mapped != null) return mapped;
                                // If value already looks like an id that exists,
                                // keep it as-is.
                                if (catsList.any((c) => c.id == sTrim)) return sTrim;
                                // Otherwise persist the original string (legacy).
                                return sTrim;
                              }).where((s) => s.isNotEmpty).toList();

                              final created = await repo.create(
                                userId: user.uid,
                                name: name,
                                allocated: amount,
                                period: selectedPeriod,
                                categoryIds: finalCategoryIds,
                              );
                              nav.pop(true);
                              pageMessenger.showSnackBar(
                                const SnackBar(content: Text('Budget created')),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text('Failed: $e')),
                              );
                            }
                          },
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            })),
          ),
        );
      },
    ));
    if (result == true) {
      // Show tutorial on first budget creation
      if (mounted) {
        setState(() => _showBudgetTutorial = true);
      }
    } else if (result != true) {
      final hasData =
          nameController.text.trim().isNotEmpty ||
          allocatedController.text.trim().isNotEmpty;
      if (hasData) {
        await prefs.saveDraft('budget_create', {
          'name': nameController.text.trim(),
          'allocated': double.tryParse(allocatedController.text.trim()),
          'categoryIds': selectedCategoryIds,
          'period': selectedPeriod.name,
        });
        if (mounted) {
          messenger.showSnackBar(const SnackBar(content: Text('Draft saved')));
        }
      }
    } else {
      await prefs.clearDraft('budget_create');
    }
    // Do not dispose the controllers here; they are short-lived and tied to
    // the bottom sheet lifecycle. Disposing them synchronously after the
    // sheet closes can race with framework rebuilds and trigger
    // "controller used after dispose" assertions.
  }

  Future<void> _openAdjustBudget(
    BuildContext context,
    String id,
    double allocated,
    String currentName,
  ) async {
    final theme = Theme.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final nameController = TextEditingController(text: currentName);
    final amountController = TextEditingController(
      text: allocated.toStringAsFixed(2),
    );
    final noteController = TextEditingController();
    final prefs = ref.read(sharedPrefsServiceProvider);
    final adjustDraft = prefs.getDraft('budget_adjust');
    final pageMessenger = ScaffoldMessenger.of(context);
    if (adjustDraft != null) {
      final amt = adjustDraft['newAllocated'];
      if (amt != null) amountController.text = amt.toString();
      nameController.text = (adjustDraft['name'] as String?) ?? nameController.text;
      noteController.text = (adjustDraft['note'] as String?) ?? '';
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
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Budget name',
                    helperText: 'Edit the budget name',
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
                  decoration: const InputDecoration(
                    labelText: 'New allocation',
                    helperText: 'e.g., 500.00',
                    filled: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    filled: true,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          if (!validateAmount(amountController.text.trim())) {
                            pageMessenger.showSnackBar(
                              const SnackBar(
                                content: Text('Enter a valid amount'),
                              ),
                            );
                            return;
                          }
                          final newAlloc =
                              double.tryParse(amountController.text) ??
                              allocated;
                          final newName = nameController.text.trim();
                          if (newName.isEmpty) {
                            pageMessenger.showSnackBar(
                              const SnackBar(content: Text('Enter a valid name')),
                            );
                            return;
                          }
                          try {
                            final user = ref.read(currentUserProvider);
                            if (user == null) return;
                            
                            // Store the old allocation for undo
                            ref.read(lastBudgetAdjustmentProvider.notifier).setAdjustment(
                              BudgetAdjustmentRecord(
                                budgetId: id,
                                oldAllocated: allocated,
                                newAllocated: newAlloc,
                                timestamp: DateTime.now(),
                              ),
                            );

                            // Update name if changed
                            if (newName != currentName) {
                              await ref
                                  .read(budgetRepositoryProvider)
                                  .update(id, {'userId': user.uid, 'name': newName});
                            }
                            await ref
                                .read(budgetRepositoryProvider)
                                .addAdjustment(
                                  userId: user.uid,
                                  id: id,
                                  newAllocated: newAlloc,
                                  note: noteController.text.trim().isEmpty
                                      ? null
                                      : noteController.text.trim(),
                                  oldAllocated: allocated,
                                );
                            nav.pop(true);
                            
                            // Show undo SnackBar
                            pageMessenger.showSnackBar(
                              SnackBar(
                                content: const Text('Budget adjusted'),
                                duration: const Duration(seconds: 5),
                                action: SnackBarAction(
                                  label: 'Undo',
                                  onPressed: () async {
                                    try {
                                      await ref
                                          .read(budgetRepositoryProvider)
                                          .undoAdjustment(
                                            userId: user.uid,
                                            id: id,
                                            previousAllocated: allocated,
                                          );
                                      // Clear the adjustment record
                                      ref.read(lastBudgetAdjustmentProvider.notifier).clear();
                                      pageMessenger.showSnackBar(
                                        const SnackBar(content: Text('Adjustment undone')),
                                      );
                                    } catch (err) {
                                      pageMessenger.showSnackBar(
                                        SnackBar(content: Text('Failed to undo: $err')),
                                      );
                                    }
                                  },
                                ),
                              ),
                            );
                          } catch (e) {
                            pageMessenger.showSnackBar(
                              SnackBar(content: Text('Failed: $e')),
                            );
                          }
                        },
                        child: const Text('Save'),
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
    if (result != true) {
      final hasData =
          amountController.text.trim().isNotEmpty ||
          noteController.text.trim().isNotEmpty ||
          nameController.text.trim().isNotEmpty;
      if (hasData) {
        await prefs.saveDraft('budget_adjust', {
          'newAllocated': double.tryParse(amountController.text.trim()),
          'note': noteController.text.trim().isEmpty
              ? null
              : noteController.text.trim(),
          'name': nameController.text.trim().isEmpty
              ? null
              : nameController.text.trim(),
        });
        if (mounted) {
          messenger.showSnackBar(const SnackBar(content: Text('Draft saved')));
        }
      }
    } else {
      await prefs.clearDraft('budget_adjust');
    }
    // Do not dispose these controllers synchronously; like the create budget
    // sheet, they are short-lived and tied to the bottom sheet lifecycle,
    // and disposing them here can race with framework rebuilds.
  }
}

// Shared small UI primitives (visual parity with Insights)

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 17, color: theme.colorScheme.primary),
        const SizedBox(width: AppSpacing.s8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _BaseCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  const _BaseCard({
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.07),
        ),
        boxShadow: AppShadow.card,
      ),
      child: child,
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  const _EmptyState({required this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _BaseCard(
      child: SizedBox(
        height: 100,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.s12),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetsHeroCard extends StatelessWidget {
  final double totalAllocated;
  final double totalSpent;
  final double utilization;
  final String currency;
  final bool isLoading;
  const _BudgetsHeroCard({
    required this.totalAllocated,
    required this.totalSpent,
    required this.utilization,
    required this.currency,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    final over = utilization > 1.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.16),
            color.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: color.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Budget',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Allocated', style: theme.textTheme.labelSmall),
                    const SizedBox(height: AppSpacing.s4),
                    Text(formatAmount(totalAllocated, currency), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Spent', style: theme.textTheme.labelSmall),
                    const SizedBox(height: AppSpacing.s4),
                    Text(formatAmount(totalSpent, currency), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          Row(
            children: [
              Expanded(
                child: AnimatedProgressIndicator(
                  progress: utilization.clamp(0.0, double.infinity),
                  minHeight: 8,
                  backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              AnimatedProgressText(
                progress: utilization.clamp(0.0, 1.0),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


