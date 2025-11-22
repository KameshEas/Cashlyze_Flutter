import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/repositories/budget_repository.dart';
import '../../core/services/auth_service.dart';
import '../../core/providers/budget_providers.dart';
import '../../core/models/budget.dart';

class BudgetPlannerScreen extends ConsumerStatefulWidget {
  const BudgetPlannerScreen({super.key});

  @override
  ConsumerState<BudgetPlannerScreen> createState() => _BudgetPlannerScreenState();
}

class _BudgetPlannerScreenState extends ConsumerState<BudgetPlannerScreen> {

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final budgetsAsync = ref.watch(userBudgetsProvider);
    final budgets = budgetsAsync.maybeWhen(data: (d) => d, orElse: () => const []);
    final spentMap = ref.watch(budgetsUtilizationProvider);
    final totalAllocated = budgets.fold<double>(0, (p, e) => p + e.allocated);
    final totalSpent = budgets.fold<double>(0, (p, e) => p + (spentMap[e.id] ?? 0));
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
            if (utilization > 0.9)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_outlined, color: Colors.orange),
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
                  const SizedBox(height: 8),
                  Text(
                    'Allocated: ${totalAllocated.toStringAsFixed(2)}\nSpent: ${totalSpent.toStringAsFixed(2)}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
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
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Failed to load budgets: $e')),
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_balance_wallet, size: 72, color: theme.colorScheme.primary),
                        const SizedBox(height: 12),
                        Text('No budgets', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        FilledButton(onPressed: () => _openCreateBudget(context), child: const Text('Create budget')),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) {
                  final e = list[i];
                  final spent = spentMap[e.id] ?? 0;
                  final progress = e.allocated == 0 ? 0 : spent / e.allocated;
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(e.name, style: theme.textTheme.titleMedium),
                            Text(
                              '${spent.toStringAsFixed(2)} / ${e.allocated.toStringAsFixed(2)}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Tooltip(
                              message: 'Delete budget',
                              child: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  final messenger = ScaffoldMessenger.of(context);
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (dCtx) => AlertDialog(
                                      title: const Text('Delete budget'),
                                      content: const Text('Are you sure you want to delete this budget?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.of(dCtx).pop(false), child: const Text('Cancel')),
                                        FilledButton(onPressed: () => Navigator.of(dCtx).pop(true), child: const Text('Delete')),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    try {
                                      await ref.read(budgetRepositoryProvider).delete(e.id);
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
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0).toDouble(),
                          minHeight: 8,
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progress > 1 ? Colors.redAccent : Colors.greenAccent,
                          ),
                        ),
                      ],
                    ),
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

  Future<void> _openCreateBudget(BuildContext context) async {
    final theme = Theme.of(context);
    final nameController = TextEditingController();
    final allocatedController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Allocated',
                    filled: true,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          final user = ref.read(currentUserProvider);
                          if (user == null) return;
                          final repo = ref.read(budgetRepositoryProvider);
                          final name = nameController.text.trim();
                          final amount = double.tryParse(allocatedController.text) ?? 0;
                          final messenger = ScaffoldMessenger.of(ctx);
                          final nav = Navigator.of(ctx);
                          try {
                            await repo.create(userId: user.uid, name: name, allocated: amount, period: BudgetPeriod.monthly);
                            nav.pop();
                            messenger.showSnackBar(const SnackBar(content: Text('Budget created')));
                          } catch (e) {
                            messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
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
    nameController.dispose();
    allocatedController.dispose();
  }
}
