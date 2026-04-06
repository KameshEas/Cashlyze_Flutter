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
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../../core/utils/validation.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/repositories/category_repository.dart';

class BudgetPlannerScreen extends ConsumerStatefulWidget {
  const BudgetPlannerScreen({super.key});

  @override
  ConsumerState<BudgetPlannerScreen> createState() =>
      _BudgetPlannerScreenState();
}

class _BudgetPlannerScreenState extends ConsumerState<BudgetPlannerScreen> {
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
    final totalAllocated = visibleBudgets.fold<double>(0, (p, e) => p + e.allocated);
    final totalSpent = visibleBudgets.fold<double>(
      0,
      (p, e) => p + (spentMap[e.id] ?? 0),
    );
    final utilization = totalAllocated == 0 ? 0 : totalSpent / totalAllocated;

    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      floatingActionButton: Tooltip(
        message: 'Create budget',
        child: FloatingActionButton.extended(
          onPressed: () => _openCreateBudget(context),
          icon: const Icon(Icons.add),
          label: const Text('Create'),
        ),
      ),
      body: SingleChildScrollView(
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary.withValues(alpha: 0.6),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Monthly Budget',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // FIX: was a single Text with '\n' — no typographic hierarchy.
                  // Now two rows with label + amount, matching the home card pattern.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildBudgetStat(
                        context,
                        label: 'Allocated',
                        value: formatAmount(totalAllocated, currency),
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                      _buildBudgetStat(
                        context,
                        label: 'Spent',
                        value: formatAmount(totalSpent, currency),
                        icon: Icons.trending_up_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: utilization.clamp(0.0, 1.0).toDouble(),
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      utilization > 1 ? Colors.redAccent : Colors.greenAccent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Category Budgets',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
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
                if (list.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.account_balance_wallet,
                          size: 72,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        Text('No budgets', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: () => _openCreateBudget(context),
                          child: const Text('Create budget'),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: list.length,
                  separatorBuilder: (sepCtx, i) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final e = list[i];
                    final spent = spentMap[e.id] ?? 0;
                    final progress = e.allocated == 0 ? 0 : spent / e.allocated;
                    final allocatedLabel = e.allocated.isFinite
                      ? formatAmount(e.allocated, currency)
                      : '∞';

                    final isSynthetic = e.id == '__general_budget';
                    final budgetCard = _BudgetFlipCard(
                      budget: e,
                      spent: spent,
                      currency: currency,
                      isSynthetic: isSynthetic,
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
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }





  /// Stat pill used in the hero budget card (replaces the '\n' text blob).
  Widget _buildBudgetStat(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
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

  Future<void> _openCreateBudget(BuildContext context) async {
    final theme = Theme.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final nameController = TextEditingController();
    final allocatedController = TextEditingController();
    final pageMessenger = ScaffoldMessenger.of(context);
    List<String> selectedCategoryIds = <String>[];

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
            child: StatefulBuilder(builder: (ctx, setSheetState) => Column(
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
                          debugPrint('Budget create: Save pressed');
                          print('Budget create: Save pressed');
                          // Visual feedback removed (no blocking dialog).
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
                            debugPrint('Creating budget (name=$name, allocated=$amount, cats=$selectedCategoryIds');
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
                              period: BudgetPeriod.monthly,
                              categoryIds: finalCategoryIds,
                            );
                            debugPrint('Budget created id=${created.id}');
                            nav.pop(true);
                            pageMessenger.showSnackBar(
                              const SnackBar(content: Text('Budget created')),
                            );
                          } catch (e) {
                            debugPrint('Budget create failed: $e');
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
            )),
          ),
        );
      },
    ));
    if (result != true) {
      final hasData =
          nameController.text.trim().isNotEmpty ||
          allocatedController.text.trim().isNotEmpty;
      if (hasData) {
        await prefs.saveDraft('budget_create', {
          'name': nameController.text.trim(),
          'allocated': double.tryParse(allocatedController.text.trim()),
          'categoryIds': selectedCategoryIds,
        });
        if (mounted)
          messenger.showSnackBar(const SnackBar(content: Text('Draft saved')));
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
                            pageMessenger.showSnackBar(
                              const SnackBar(content: Text('Budget adjusted')),
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
        if (mounted)
          messenger.showSnackBar(const SnackBar(content: Text('Draft saved')));
      }
    } else {
      await prefs.clearDraft('budget_adjust');
    }
    // Do not dispose these controllers synchronously; like the create budget
    // sheet, they are short-lived and tied to the bottom sheet lifecycle,
    // and disposing them here can race with framework rebuilds.
  }
}

/// Flip card widget for budgets. Tapping toggles front/back showing
/// remaining allocation. The synthetic 'General' budget should be
/// rendered read-only (no flip) by passing `isSynthetic: true`.
class _BudgetFlipCard extends StatefulWidget {
  final BudgetModel budget;
  final double spent;
  final String currency;
  final bool isSynthetic;

  const _BudgetFlipCard({
    required this.budget,
    required this.spent,
    required this.currency,
    required this.isSynthetic,
  });

  @override
  State<_BudgetFlipCard> createState() => _BudgetFlipCardState();
}

class _BudgetFlipCardState extends State<_BudgetFlipCard> {
  bool _showBack = false;

  void _toggle() {
    if (widget.isSynthetic) return;
    setState(() => _showBack = !_showBack);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allocated = widget.budget.allocated;
    final spent = widget.spent;
    final progress = allocated.isFinite ? (allocated == 0 ? 0.0 : (spent / allocated)) : 0.0;
    final allocatedLabel = allocated.isFinite ? formatAmount(allocated, widget.currency) : '∞';
    final remaining = allocated.isFinite ? (allocated - spent) : double.infinity;

    return GestureDetector(
      onTap: _toggle,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: _showBack ? math.pi : 0),
        duration: const Duration(milliseconds: 380),
        builder: (ctx, angle, child) {
          final isUnder = angle > (math.pi / 2);
          Widget face;
          if (isUnder) {
            face = Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationY(math.pi),
              child: _buildBack(theme, remaining),
            );
          } else {
            face = _buildFront(theme, allocatedLabel, spent, progress);
          }
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: face,
          );
        },
      ),
    );
  }

  Widget _buildFront(ThemeData theme, String allocatedLabel, double spent, double progress) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.budget.name, style: theme.textTheme.titleMedium),
              Text('${formatAmount(spent, widget.currency)} / $allocatedLabel', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0).toDouble(),
            minHeight: 8,
            backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(
              progress > 1 ? theme.colorScheme.error : theme.colorScheme.secondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBack(ThemeData theme, double remaining) {
    final remLabel = remaining.isFinite ? formatAmount(remaining, widget.currency) : '∞';
    final over = remaining.isFinite ? remaining < 0 : false;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Remaining', style: theme.textTheme.titleSmall),
              Text(remLabel, style: theme.textTheme.titleMedium?.copyWith(color: over ? theme.colorScheme.error : null, fontWeight: FontWeight.bold)),
            ],
          ),
          // Only show the remaining amount on the back of the card.
        ],
      ),
    );
  }
}
