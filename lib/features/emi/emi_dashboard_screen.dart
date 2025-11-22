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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
      child: scheduleAsync.when(
        loading: () => const SizedBox(height: 64, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Text('Failed to load schedule: $e'),
        data: (items) {
          final paidCount = items.where((e) => e.paid).length;
          final total = items.length;
          final progress = total == 0 ? 0.0 : paidCount / total;
          final nextDue = items.firstWhere((e) => !e.paid, orElse: () => items.isNotEmpty ? items.last : EMIPayment(id: 'x', planId: plan.id, dueDate: plan.startDate, installment: 0, interest: 0, principal: 0, remainingPrincipal: 0, paid: false));
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Loan: ${formatAmount(plan.loanAmount, currency)}'),
              Text('Rate: ${plan.annualInterestRate.toStringAsFixed(2)}%'),
              Text('Tenure: ${plan.tenureMonths}m'),
            ]),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress.clamp(0.0, 1.0), minHeight: 8, backgroundColor: Colors.white.withValues(alpha: 0.1), valueColor: AlwaysStoppedAnimation<Color>(progress >= 1 ? Colors.greenAccent : Colors.blueAccent)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Completed: ${(progress * 100).toStringAsFixed(0)}%'),
              Text('Next due: ${nextDue.dueDate.toLocal()}'.split(' ').first),
            ]),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final e = items[i];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Due: ${e.dueDate.toLocal()}'.split(' ').first), Text('Installment: ${formatAmount(e.installment, currency)}')]),
                    e.paid
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : FilledButton(onPressed: () async {final user = ref.read(currentUserProvider); if (user == null) return; await ref.read(emiRepositoryProvider).markPaid(user.uid, plan.id, e.id);}, child: const Text('Mark paid')),
                  ]),
                );
              },
            ),
          ]);
        },
      ),
    );
  }
}