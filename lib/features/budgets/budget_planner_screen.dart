import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/budget.dart';
import '../../core/models/category.dart';
import '../../core/models/transaction.dart';
import '../../core/providers/budget_providers.dart';
import '../../core/providers/first_time_feature_provider.dart';
import '../../core/providers/onboarding_provider.dart';
import '../../core/providers/shared_prefs_provider.dart';
import '../../core/repositories/budget_repository.dart';
import '../../core/repositories/category_repository.dart';
import '../../core/repositories/transaction_repository.dart';
import '../../core/services/auth_service.dart';
import '../../core/ui/constants.dart';
import '../../core/utils/format.dart';
import '../../core/utils/validation.dart';
import '../../core/widgets/animated_progress_indicator.dart';
import '../../core/widgets/animated_progress_text.dart';
import '../../core/widgets/skeleton.dart';
import '../onboarding/budget_tutorial_overlay.dart';
import 'budget_card.dart';

class BudgetPlannerScreen extends ConsumerStatefulWidget {
  const BudgetPlannerScreen({super.key});

  @override
  ConsumerState<BudgetPlannerScreen> createState() =>
      _BudgetPlannerScreenState();
}

class _BudgetPlannerScreenState extends ConsumerState<BudgetPlannerScreen> {
  bool _showBudgetTutorial = false;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final prefs = ref.watch(sharedPrefsServiceProvider);
    final currency = ref.watch(currencyProvider);
    final budgetsAsync = ref.watch(userBudgetsProvider);
    final budgets = budgetsAsync.maybeWhen(
      data: (final d) => d,
      orElse: () => const <BudgetModel>[],
    );
    final spentMap = ref.watch(budgetsUtilizationProvider);
    // Exclude the synthetic/read-only 'General' budget from totals so its
    // infinite allocation doesn't break utilization math.
    final visibleBudgets = budgets.where((final b) => b.id != '__general_budget').toList();
    final totalAllocated = visibleBudgets.fold<double>(0.0, (final p, final e) => p + e.allocated);
    final totalSpent = visibleBudgets.fold<double>(
      0.0,
      (final p, final e) => p + (spentMap[e.id] ?? 0.0),
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
                        onSelected: (final selected) {
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
                separatorBuilder: (final sepCtx, final i) => const SizedBox(height: 12),
                itemBuilder: (final ctx, final i) {
                  return const SkeletonListTile();
                },
              ),
              error: (final e, final _) =>
                  Center(child: Text('Failed to load budgets: $e')),
              data: (final list) {
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
                  onReorder: (final oldIndex, newIndex) {
                    final newOrderedList = [...orderedBudgets];
                    if (oldIndex < newIndex) {
                      newIndex -= 1;
                    }
                    final item = newOrderedList.removeAt(oldIndex);
                    newOrderedList.insert(newIndex, item);

                    // Extract IDs for persistence (including General budget)
                    final orderToSave = newOrderedList.map((final b) => b.id).toList();

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
    final BuildContext context,
    final BudgetModel budget,
    final String currency,
    final int index,
  ) {
    
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
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
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
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Delete'),
            SizedBox(width: 8),
            Icon(Icons.delete, color: Colors.red),
          ],
        ),
      ),
      confirmDismiss: (final dir) async {
        if (dir == DismissDirection.startToEnd) {
          await _openAdjustBudget(context, budget.id, budget.allocated, budget.name);
          return false;
        }
        // For delete (right swipe), show confirmation dialog
        if (!context.mounted) return false;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (final ctx) => AlertDialog(
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
        if (!context.mounted) return false;

        if (!confirmed) return false;
        
        // For delete (right swipe), perform soft delete with optional remap
        try {
          final user = ref.read(currentUserProvider);
          if (user == null) return false;

          // Gather current transactions and categories to compute impact
          final txs = ref.read(userTransactionsProvider).maybeWhen(data: (final d) => d, orElse: () => const <TransactionModel>[]);
          final cats = ref.read(userCategoriesProvider).maybeWhen(data: (final d) => d, orElse: () => const <CategoryModel>[]);

          final idToName = <String, String>{};
          final nameToId = <String, String>{};
          for (final c in cats) {
            final nm = c.name.trim();
            if (nm.isEmpty) continue;
            idToName[c.id] = nm;
            nameToId[nm.toLowerCase()] = c.id;
          }

          // Build normalized keys claimed by this budget
          final budgetKeys = <String>{};
          if (budget.categoryIds.isEmpty) {
            final vTrim = budget.name.trim();
            if (vTrim.isNotEmpty) {
              budgetKeys.add(vTrim);
              budgetKeys.add(vTrim.toLowerCase());
              final mappedName = idToName[vTrim];
              if (mappedName != null) budgetKeys.add(mappedName.toLowerCase());
              final mappedId = nameToId[vTrim.toLowerCase()];
              if (mappedId != null) budgetKeys.add(mappedId);
            }
          } else {
            for (final v in budget.categoryIds) {
              final vTrim = v.trim();
              if (vTrim.isEmpty) continue;
              budgetKeys.add(vTrim);
              budgetKeys.add(vTrim.toLowerCase());
              final mappedName = idToName[vTrim];
              if (mappedName != null) budgetKeys.add(mappedName.toLowerCase());
              final mappedId = nameToId[vTrim.toLowerCase()];
              if (mappedId != null) budgetKeys.add(mappedId);
            }
          }

          // Find impacted transactions and collect their identifiers
          final impactedTxs = <TransactionModel>[];
          final impactedIdentifiers = <String>{};
          for (final t in txs) {
            final raw = (t.categoryId ?? t.categoryName ?? 'General').trim();
            if (raw.isEmpty) continue;
            final candidates = <String>{raw, raw.toLowerCase()};
            final asName = idToName[raw];
            if (asName != null) candidates.add(asName.toLowerCase());
            final asId = nameToId[raw.toLowerCase()];
            if (asId != null) candidates.add(asId);
            var matches = false;
            for (final c in candidates) {
              if (budgetKeys.contains(c)) {
                matches = true;
                break;
              }
            }
            if (matches) {
              impactedTxs.add(t);
              impactedIdentifiers.add(raw);
            }
          }

          final repo = ref.read(budgetRepositoryProvider);

          if (impactedTxs.isNotEmpty) {
            final candidates = ref
              .read(filteredBudgetsProvider)
              .where((final b) => b.id != budget.id && (b.name.trim().toLowerCase() != 'general'))
              .toList();
            final selectedTarget = await showDialog<String?>(
              context: context,
              builder: (final ctx) {
                String? sel = candidates.isNotEmpty ? candidates.first.id : '__general_budget';
                return StatefulBuilder(builder: (final ctx, final setState) {
                  return AlertDialog(
                    title: Text('Remap ${impactedTxs.length} transaction(s)'),
                    content: SizedBox(
                      width: double.maxFinite,
                      child: RadioGroup<String>(
                        groupValue: sel,
                        onChanged: (final v) => setState(() => sel = v),
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            const RadioListTile<String>(
                              value: '__general_budget',
                              title: Text('General'),
                            ),
                            for (final t in candidates)
                              RadioListTile<String>(
                                value: t.id,
                                title: Text(t.name),
                              ),
                          ],
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(ctx, sel), child: const Text('Confirm')),
                    ],
                  );
                });
              },
              );
              if (!mounted) return false;
              if (selectedTarget == null) return false;

            // If user chose a persisted budget to merge into, update it
            List<String>? previousTargetCats;
            if (selectedTarget != '__general_budget') {
              final targetB = candidates.firstWhere((final b) => b.id == selectedTarget);
              previousTargetCats = List<String>.from(targetB.categoryIds);
              final union = <String>{...previousTargetCats, ...budget.categoryIds, ...impactedIdentifiers};
              try {
                await repo.update(targetB.id, {'userId': user.uid, 'categoryIds': union.toList()});
              } catch (err) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to remap: $err')));
                return false;
              }
            }

            // Proceed to delete the original budget
            await repo.delete(user.uid, budget.id);

            // Record deletion + remap for undo
            ref.read(lastDeletedBudgetProvider.notifier).setDeleted(DeletedBudgetRecord(
              budget: budget,
              timestamp: DateTime.now(),
              remappedTargetId: selectedTarget != '__general_budget' ? selectedTarget : null,
              targetPreviousCategoryIds: previousTargetCats,
            ));

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
                        final rec = ref.read(lastDeletedBudgetProvider);
                        // Recreate the deleted budget
                        await repo.create(
                          userId: user.uid,
                          name: budget.name,
                          allocated: budget.allocated,
                          period: budget.period,
                          categoryIds: budget.categoryIds,
                        );
                        // If we merged into a target, revert its categories
                        if (rec?.remappedTargetId != null && rec?.targetPreviousCategoryIds != null) {
                          try {
                            await repo.update(rec!.remappedTargetId!, {'userId': user.uid, 'categoryIds': rec.targetPreviousCategoryIds});
                          } catch (_) {}
                        }
                        ref.read(lastDeletedBudgetProvider.notifier).clear();
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Budget restored')));
                      } catch (err) {
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to restore: $err')));
                      }
                    },
                  ),
                ),
              );
            }

            return true;
          }

          final List<CategoryModel> categoriesToDelete = [];
          if (budget.categoryIds.isEmpty) {
            final matchName = budget.name.trim().toLowerCase();
            final otherBudgets = ref.read(filteredBudgetsProvider).where((final b) => b.id != budget.id).toList();
            for (final c in cats) {
              final cname = c.name.trim();
              if (cname.isEmpty) continue;
              if (cname.toLowerCase() != matchName) continue;

              // Skip if other budgets reference this category (by id or name)
              final usedByOtherBudget = otherBudgets.any((final b) {
                if (b.categoryIds.isEmpty) {
                  return b.name.trim().toLowerCase() == cname.toLowerCase();
                }
                return b.categoryIds.any((final v) {
                  final vt = v.trim();
                  if (vt.isEmpty) return false;
                  if (vt == c.id) return true;
                  if (vt.toLowerCase() == cname.toLowerCase()) return true;
                  return false;
                });
              });
              if (usedByOtherBudget) continue;

              // Skip if any transaction references this category (by id or name)
              final usedByTx = txs.any((final t) {
                final raw = (t.categoryId ?? t.categoryName ?? '').trim();
                if (raw.isEmpty) return false;
                if (raw == c.id) return true;
                if (raw.toLowerCase() == cname.toLowerCase()) return true;
                return false;
              });
              if (usedByTx) continue;

              categoriesToDelete.add(c);
            }
          }

          // Record deleted budget + categories for undo
          ref.read(lastDeletedBudgetProvider.notifier).setDeleted(DeletedBudgetRecord(
            budget: budget,
            timestamp: DateTime.now(),
            deletedCategories: categoriesToDelete.isNotEmpty ? categoriesToDelete : null,
          ));

          await repo.delete(user.uid, budget.id);

          // Delete category records (best-effort)
          if (categoriesToDelete.isNotEmpty) {
            for (final c in categoriesToDelete) {
              try {
                await ref.read(categoryRepositoryProvider).delete(user.uid, c.id);
              } catch (_) {}
            }
            // Ensure any cached category lists are refreshed
            try {
              ref.invalidate(userCategoriesProvider);
            } catch (_) {}
          }

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
                      final rec = ref.read(lastDeletedBudgetProvider);
                      // Recreate any deleted categories first (best-effort)
                      if (rec?.deletedCategories != null) {
                        for (final dc in rec!.deletedCategories!) {
                          try {
                            await ref.read(categoryRepositoryProvider).create(userId: user.uid, name: dc.name, icon: dc.icon, color: dc.color);
                          } catch (_) {}
                        }
                      }

                      await repo.create(
                        userId: user.uid,
                        name: budget.name,
                        allocated: budget.allocated,
                        period: budget.period,
                        categoryIds: budget.categoryIds,
                      );
                      // Force providers to refresh after restoring
                      try {
                        ref.invalidate(userCategoriesProvider);
                      } catch (_) {}
                      try {
                        ref.invalidate(userBudgetsProvider);
                      } catch (_) {}
                      ref.read(lastDeletedBudgetProvider.notifier).clear();
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Budget restored')));
                    } catch (err) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to restore: $err')));
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

  // _buildBudgetListItem removed — not referenced. Use _buildBudgetItem instead.





  

  Future<void> _openCreateBudget(final BuildContext context) async {
    final theme = Theme.of(context);
    final nameController = TextEditingController();
    final allocatedController = TextEditingController();
    
    BudgetPeriod selectedPeriod = BudgetPeriod.monthly;

    final prefs = ref.read(sharedPrefsServiceProvider);
    final draft = prefs.getDraft('budget_create');
    if (draft != null) {
      nameController.text = (draft['name'] as String?) ?? '';
      final amt = draft['allocated'];
      if (amt != null) allocatedController.text = amt.toString();
      // categories are not part of budget creation UI anymore
      final periodStr = draft['period'] as String?;
      if (periodStr != null) {
        try {
          selectedPeriod = BudgetPeriod.values.firstWhere(
            (final p) => p.toString() == 'BudgetPeriod.$periodStr',
          );
        } catch (_) {
          selectedPeriod = BudgetPeriod.monthly;
        }
      }
    }
    final result = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (final ctx) {
        final nav = Navigator.of(ctx);

            return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: StatefulBuilder(builder: (final ctx, final setSheetState) => Consumer(builder: (final cctx, final wref, final _) {
              // Budget creation modal: no category selection UI

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
                    onSelectionChanged: (final Set<BudgetPeriod> newSelection) {
                      setSheetState(() {
                        selectedPeriod = newSelection.first;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
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

                            final messenger = ScaffoldMessenger.of(ctx);
                            try {
                              await repo.create(
                                userId: user.uid,
                                name: name,
                                allocated: amount,
                                period: selectedPeriod,
                              );
                              nav.pop(true);
                              messenger.showSnackBar(
                                const SnackBar(content: Text('Budget created')),
                              );
                            } catch (e) {
                              debugPrint('Budget creation failed: $e');
                              messenger.showSnackBar(
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
    );
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
          'period': selectedPeriod.name,
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draft saved')));
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
    final BuildContext context,
    final String id,
    final double allocated,
    final String currentName,
  ) async {
    final theme = Theme.of(context);
    final nameController = TextEditingController(text: currentName);
    final amountController = TextEditingController(
      text: allocated.toStringAsFixed(2),
    );
    final noteController = TextEditingController();
    final prefs = ref.read(sharedPrefsServiceProvider);
    final adjustDraft = prefs.getDraft('budget_adjust');
    
    if (adjustDraft != null) {
      final amt = adjustDraft['newAllocated'];
      if (amt != null) amountController.text = amt.toString();
      nameController.text = (adjustDraft['name'] as String?) ?? nameController.text;
      noteController.text = (adjustDraft['note'] as String?) ?? '';
    }
    final result = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (final ctx) {
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
                            ScaffoldMessenger.of(ctx).showSnackBar(
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
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Enter a valid name')),
                            );
                            return;
                          }
                          final messenger = ScaffoldMessenger.of(ctx);
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
                            messenger.showSnackBar(
                              SnackBar(
                                content: const Text('Budget adjusted'),
                                duration: const Duration(seconds: 3),
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
                                      messenger.showSnackBar(
                                        const SnackBar(content: Text('Adjustment undone')),
                                      );
                                    } catch (err) {
                                      messenger.showSnackBar(
                                        SnackBar(content: Text('Failed to undo: $err')),
                                      );
                                    }
                                  },
                                ),
                              ),
                            );
                          } catch (e) {
                            messenger.showSnackBar(
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
    );
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
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draft saved')));
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
  const _SectionHeader({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(final BuildContext context) {
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
  const _BaseCard({
    required this.child,
  });
  final Widget child;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
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
  const _EmptyState({required this.message, required this.icon});
  final String message;
  final IconData icon;

  @override
  Widget build(final BuildContext context) {
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
  const _BudgetsHeroCard({
    required this.totalAllocated,
    required this.totalSpent,
    required this.utilization,
    required this.currency,
    required this.isLoading,
  });
  final double totalAllocated;
  final double totalSpent;
  final double utilization;
  final String currency;
  final bool isLoading;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;

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
