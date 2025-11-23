import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/repositories/emi_repository.dart';
import '../../core/models/emi.dart';
import '../../core/utils/format.dart';
import '../../core/providers/onboarding_provider.dart';
import '../../core/services/auth_service.dart';
import 'package:go_router/go_router.dart';

class EMIDashboardScreen extends ConsumerWidget {
  const EMIDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(userEMIPlansProvider);
    final currency = ref.watch(currencyProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('EMI Tracker'), actions: [IconButton(onPressed: () => GoRouter.of(context).go('/emi/new'), icon: const Icon(Icons.add), tooltip: 'New EMI')]),
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
                  const Text('No EMI plans'),
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
      child: scheduleAsync.when(
        loading: () => const SizedBox(height: 64, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Text('Failed to load schedule: $e'),
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
          final nextLabel = days >= 0 ? 'in $days days' : 'overdue by ${days.abs()} days';
          final estCompletion = items.isNotEmpty ? items.last.dueDate : plan.startDate;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.calendar_today, size: 18),
              const SizedBox(width: 8),
              Text('Next: ${nextDue.dueDate.toLocal()}'.split(' ').first, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(width: 8),
              Text(nextLabel, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.orange)),
            ]),
            const SizedBox(height: 8),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
            const SizedBox(height: 8),
            Row(children: [
              Text('Remaining: $pending EMIs', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('Loan: ${formatAmount(plan.loanAmount, currency)}', style: Theme.of(context).textTheme.bodySmall),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              Text('Tenure: ${plan.tenureMonths} months', style: Theme.of(context).textTheme.bodySmall),
              const Spacer(),
              Text('Rate: ${plan.annualInterestRate.toStringAsFixed(2)}%', style: Theme.of(context).textTheme.bodySmall),
            ]),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(progress >= 1 ? Colors.green : Theme.of(context).colorScheme.secondary),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Text('$paidCount/$total EMIs completed')),
              const SizedBox(width: 8),
              Text('Est. completion: ${estCompletion.toLocal()}'.split(' ').first, style: Theme.of(context).textTheme.bodySmall),
            ]),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.where((e) => !e.paid).isEmpty ? 0 : 1,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (ctx, i) {
                final e = items.firstWhere((x) => !x.paid, orElse: () => items.first);
                final now = DateTime.now();
                final isOverdue = !e.paid && e.dueDate.isBefore(DateTime(now.year, now.month, now.day));
                final isDueToday = !e.paid && e.dueDate.toLocal().difference(DateTime(now.year, now.month, now.day)).inDays == 0;
                final statusColor = e.paid
                    ? Colors.green
                    : isOverdue
                        ? Colors.red
                        : isDueToday
                            ? Colors.orange
                            : Theme.of(context).colorScheme.secondary;
                final statusLabel = e.paid
                    ? 'Paid'
                    : isOverdue
                        ? 'Overdue'
                        : isDueToday
                            ? 'Due'
                            : 'Upcoming';
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(children: [
                          const Icon(Icons.calendar_today, size: 18),
                          const SizedBox(width: 8),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Installment Amount', style: Theme.of(context).textTheme.bodySmall),
                            Text(
                              formatAmount(e.installment, currency),
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text('Due: ${e.dueDate.toLocal()}'.split(' ').first, style: Theme.of(context).textTheme.bodySmall),
                          ]),
                        ]),
                      ),
                      Flexible(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                                ),
                                child: Row(children: [
                                  Icon(
                                    e.paid ? Icons.check : (isOverdue ? Icons.error_outline : Icons.schedule),
                                    color: statusColor,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(statusLabel, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: statusColor)),
                                ]),
                              ),
                              if (!e.paid)
                                FilledButton(
                                  onPressed: () async {
                                    final user = ref.read(currentUserProvider);
                                    if (user == null) return;
                                    await ref.read(emiRepositoryProvider).markPaid(user.uid, plan.id, e.id);
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('EMI marked as paid')));
                                  },
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: const Text('Pay'),
                                ),
                              if (e.paid) const Icon(Icons.check_circle, color: Colors.green),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ]);
        },
      ),
    );
  }
}