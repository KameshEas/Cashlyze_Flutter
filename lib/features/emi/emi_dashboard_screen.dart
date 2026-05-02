import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/repositories/emi_repository.dart';
import '../../core/models/emi.dart';
import '../../core/utils/format.dart';
import '../../core/providers/onboarding_provider.dart';
import '../../core/services/auth_service.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import '../../core/widgets/animated_progress_indicator.dart';
import 'emi_form_screen.dart';

class EMIDashboardScreen extends ConsumerWidget {
  const EMIDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final plansAsync = ref.watch(userEMIPlansProvider);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('EMI Tracker'),
            const SizedBox(height: 2),
            Text(
              'Track & manage your EMIs',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => GoRouter.of(context).go('/emi/new'),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Add Loan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: plansAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load: $e')),
        data: (plans) {
          if (plans.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.payments_outlined, size: 72),
                  const SizedBox(height: 8),
                  Text('No EMIs yet. Add your first loan.', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => GoRouter.of(context).go('/emi/new'),
                    child: const Text('Add Loan'),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: plans.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final p = plans[i];
              return _PlanCard(plan: p);
            },
          );
        },
      ),
    );
  }
}

class _PlanCard extends ConsumerWidget {
  final EMIPlan plan;
  const _PlanCard({required this.plan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleAsync = ref.watch(emiScheduleProvider(plan.id));
    final currency = ref.watch(currencyProvider);
    return scheduleAsync.when(
      loading: () => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04)),
        ),
        child: const SizedBox(
          height: 64,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04)),
        ),
        child: Text('Failed to load schedule: $e'),
      ),
      data: (items) {
        final paidCount = items.where((e) => e.paid).length;
        final total = items.length;
        final progress = total == 0 ? 0.0 : paidCount / total;
        final pending = total - paidCount;
        final nextDue = items.firstWhere(
          (e) => !e.paid,
          orElse: () => items.isNotEmpty
              ? items.last
              : EMIPayment(
                  id: 'x',
                  planId: plan.id,
                  dueDate: plan.startDate,
                  installment: 0,
                  interest: 0,
                  principal: 0,
                  remainingPrincipal: 0,
                  paid: false,
                ),
        );
        final days = nextDue.dueDate.difference(DateTime.now()).inDays;
        double remainingAmount = items.where((x) => !x.paid).fold<double>(0, (p, e) => p + e.installment);

        return Dismissible(
          key: ValueKey('emi_plan_${plan.id}'),
          direction: DismissDirection.horizontal,
          background: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: const [Icon(Icons.check, color: Colors.green), SizedBox(width: 8), Text('Mark as paid')]),
          ),
          secondaryBackground: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerRight,
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: const [Text('Delete'), SizedBox(width: 8), Icon(Icons.delete, color: Colors.red)]),
          ),
          confirmDismiss: (dir) async {
            final messenger = ScaffoldMessenger.of(context);
            final user = ref.read(currentUserProvider);
            if (user == null) return false;
            if (dir == DismissDirection.startToEnd) {
              // Mark next unpaid as paid
              final unpaid = items.where((x) => !x.paid).toList();
              if (unpaid.isEmpty) {
                messenger.showSnackBar(const SnackBar(content: Text('All EMIs already paid')));
                return false;
              }
              final next = unpaid.first;
              try {
                HapticFeedback.lightImpact();
                await ref.read(emiRepositoryProvider).markPaid(user.uid, plan.id, next.id);
                messenger.showSnackBar(SnackBar(content: Text('${formatAmount(next.installment, currency)} paid')));
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
              }
              return false;
            } else {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete EMI plan'),
                  content: const Text('Delete this EMI plan and its schedule? This action cannot be undone.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
                  ],
                ),
              );
              if (confirm != true) return false;
              try {
                await ref.read(emiRepositoryProvider).deletePlan(user.uid, plan.id);
                messenger.showSnackBar(const SnackBar(content: Text('EMI plan deleted')));
                  // Delay invalidation to allow Dismissible animation to complete
                  Future.delayed(const Duration(milliseconds: 300), () {
                    try {
                      ref.invalidate(userEMIPlansProvider);
                    } catch (_) {}
                  });
                return true;
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
                return false;
              }
            }
          },
          child: InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EMIFormScreen(initialPlan: plan))),
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: name + remaining + overflow
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'EMI Plan',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$pending EMIs left • ${plan.tenureMonths} months • ${plan.annualInterestRate.toStringAsFixed(2)}% interest',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${formatAmount(remainingAmount, currency)} remaining',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          PopupMenuButton<int>(
                            onSelected: (v) async {
                              if (v == 1) {
                                Navigator.of(context).push(MaterialPageRoute(builder: (_) => EMIFormScreen(initialPlan: plan)));
                              } else if (v == 2) {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Delete EMI plan'),
                                    content: const Text('Delete this EMI plan and its schedule? This action cannot be undone.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                                      TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
                                    ],
                                  ),
                                );
                                if (confirm != true) return;
                                final user = ref.read(currentUserProvider);
                                if (user == null) return;
                                try {
                                  await ref.read(emiRepositoryProvider).deletePlan(user.uid, plan.id);
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('EMI plan deleted')));
                                    // Invalidate provider to refresh the list
                                    ref.invalidate(userEMIPlansProvider);
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                                }
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 1, child: Text('Edit')),
                              PopupMenuItem(value: 2, child: Text('Delete')),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Progress
                  AnimatedProgressIndicator(
                    progress: progress.clamp(0.0, double.infinity),
                    minHeight: 8,
                    backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
                  ),
                  const SizedBox(height: 8),
                  Text('$paidCount of $total paid', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 12),
                  // Payment row (first unpaid installment)
                  if (items.where((x) => !x.paid).isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Builder(builder: (ctx) {
                      final e = items.firstWhere((x) => !x.paid);
                      final now = DateTime.now();
                      final dueDays = e.dueDate.difference(DateTime(now.year, now.month, now.day)).inDays;
                      // due pill
                      Color pillColor;
                      String pillLabel;
                      if (dueDays < 0) {
                        pillColor = Colors.red;
                        pillLabel = 'Overdue';
                      } else if (dueDays == 0) {
                        pillColor = Colors.orange;
                        pillLabel = 'Due Today';
                      } else if (dueDays == 1) {
                        pillColor = Colors.orange;
                        pillLabel = 'Due Tomorrow';
                      } else {
                        pillColor = Colors.green;
                        pillLabel = 'Due in $dueDays days';
                      }
                      return Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      formatAmount(e.installment, currency),
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: pillColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        pillLabel,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: pillColor),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          FilledButton(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final user = ref.read(currentUserProvider);
                              if (user == null) return;
                              HapticFeedback.mediumImpact();
                              try {
                                await ref.read(emiRepositoryProvider).markPaid(user.uid, plan.id, e.id);
                                messenger.showSnackBar(SnackBar(content: Text('${formatAmount(e.installment, currency)} paid successfully')));
                              } catch (err) {
                                messenger.showSnackBar(SnackBar(content: Text('Failed: $err')));
                              }
                            },
                            style: FilledButton.styleFrom(elevation: 2, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
                            child: Text('Pay ${formatAmount(e.installment, currency)}'),
                          ),
                        ],
                      );
                    }),
                  ] else ...[
                    const SizedBox(height: 8),
                    Text('No upcoming payments', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
