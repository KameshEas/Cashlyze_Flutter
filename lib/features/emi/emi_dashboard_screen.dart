import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/emi.dart';
import '../../core/providers/onboarding_provider.dart';
import '../../core/repositories/emi_repository.dart';
import '../../core/services/auth_service.dart';
import '../../core/ui/motion.dart';
import '../../core/utils/format.dart';
import '../../core/utils/repo_error_handler.dart';
import '../../core/widgets/animated_progress_indicator.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/skeleton.dart';
import 'emi_form_screen.dart';

class EMIDashboardScreen extends ConsumerWidget {
  const EMIDashboardScreen({super.key});

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    final theme = Theme.of(context);
    final plansAsync = ref.watch(userEMIPlansProvider);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('EMI Tracker'),
            const SizedBox(height: 2),
            Text('Track & manage your EMIs', style: theme.textTheme.bodySmall),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/emi/new'),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'Add Loan',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(userEMIPlansProvider);
          await ref.read(userEMIPlansProvider.future);
        },
        child: plansAsync.when(
          loading: () => ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: 4,
            separatorBuilder: (final _, final _) => const SizedBox(height: 12),
            itemBuilder: (final ctx, final i) => const SkeletonListTile(),
          ),
          error: (final e, final _) => Center(
            child: AppEmptyState(
              title: 'Failed to load EMI plans',
              subtitle: repoErrorMessage(e),
              icon: Icons.error_outline_rounded,
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(userEMIPlansProvider),
            ),
          ),
          data: (final plans) {
            if (plans.isEmpty) {
              return Center(
                child: AppEmptyState(
                  title: 'No EMIs yet',
                  subtitle: 'Add your first loan to start tracking payments.',
                  icon: Icons.payments_outlined,
                  actionLabel: 'Add Loan',
                  onAction: () => context.push('/emi/new'),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: plans.length,
              separatorBuilder: (final _, final _) =>
                  const SizedBox(height: 12),
              itemBuilder: (final ctx, final i) {
                final p = plans[i];
                return MotionFadeIn(
                  delay: MotionStagger.delayFor(i),
                  child: _PlanCard(plan: p),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _PlanCard extends ConsumerWidget {
  const _PlanCard({required this.plan});
  final EMIPlan plan;

  /// Confirms and deletes this plan, showing a clean error message on
  /// failure. Returns whether the delete succeeded. Shared by both the
  /// swipe-to-delete and popup-menu delete paths below.
  Future<bool> _confirmAndDeletePlan(
    final BuildContext context,
    final WidgetRef ref,
    final ScaffoldMessengerState messenger,
    final String userId,
  ) async {
    final confirm = await showConfirmDialog(
      context,
      title: 'Delete EMI plan',
      content:
          'Delete this EMI plan and its schedule? This action cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (confirm != true) return false;
    try {
      await ref.read(emiRepositoryProvider).deletePlan(userId, plan.id);
      messenger.showSnackBar(
        const SnackBar(content: Text('EMI plan deleted')),
      );
      return true;
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(repoErrorMessage(e))));
      return false;
    }
  }

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    final scheduleAsync = ref.watch(emiScheduleProvider(plan.id));
    final currency = ref.watch(currencyProvider);
    return scheduleAsync.when(
      loading: () => const SkeletonListTile(),
      error: (final e, final _) => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.04),
          ),
        ),
        child: Text(repoErrorMessage(e)),
      ),
      data: (final items) {
        final paidCount = items.where((final e) => e.paid).length;
        final total = items.length;
        final progress = total == 0 ? 0.0 : paidCount / total;
        final pending = total - paidCount;
        final remainingAmount = items
            .where((final x) => !x.paid)
            .fold<double>(0, (final p, final e) => p + e.installment);

        return Dismissible(
          key: ValueKey('emi_plan_${plan.id}'),
          background: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.check, color: Colors.green),
                SizedBox(width: 8),
                Text('Mark as paid'),
              ],
            ),
          ),
          secondaryBackground: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerRight,
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.12),
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
            final messenger = ScaffoldMessenger.of(context);
            final user = ref.read(currentUserProvider);
            if (user == null) return false;
            if (dir == DismissDirection.startToEnd) {
              // Mark next unpaid as paid
              final unpaid = items.where((final x) => !x.paid).toList();
              if (unpaid.isEmpty) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('All EMIs already paid')),
                );
                return false;
              }
              final next = unpaid.first;
              try {
                await HapticFeedback.lightImpact();
                await ref
                    .read(emiRepositoryProvider)
                    .markPaid(user.uid, plan.id, next.id);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Marked as paid')),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text(repoErrorMessage(e))),
                );
              }
              return false;
            } else {
              final deleted = await _confirmAndDeletePlan(context, ref, messenger, user.uid);
              if (deleted) {
                // Delay invalidation to allow Dismissible animation to complete
                Future.delayed(const Duration(milliseconds: 300), () {
                  try {
                    ref.invalidate(userEMIPlansProvider);
                  } catch (_) {}
                });
              }
              return deleted;
            }
          },
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EMIFormScreen(initialPlan: plan),
              ),
            ),
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.04),
                ),
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
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          PopupMenuButton<int>(
                            tooltip: 'More options',
                            onSelected: (final v) async {
                              final messenger = ScaffoldMessenger.of(context);
                              if (v == 1) {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        EMIFormScreen(initialPlan: plan),
                                  ),
                                );
                              } else if (v == 2) {
                                final user = ref.read(currentUserProvider);
                                if (user == null) return;
                                final deleted = await _confirmAndDeletePlan(
                                  context,
                                  ref,
                                  messenger,
                                  user.uid,
                                );
                                if (deleted) {
                                  ref.invalidate(userEMIPlansProvider);
                                }
                              }
                            },
                            itemBuilder: (final _) => const [
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
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.06),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$paidCount of $total paid',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  // Payment row (first unpaid installment)
                  if (items.where((final x) => !x.paid).isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Builder(
                      builder: (final ctx) {
                        final e = items.firstWhere((final x) => !x.paid);
                        final now = DateTime.now();
                        final dueDays = e.dueDate
                            .difference(DateTime(now.year, now.month, now.day))
                            .inDays;
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        formatAmount(e.installment, currency),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: pillColor.withValues(
                                            alpha: 0.12,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          pillLabel,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(color: pillColor),
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
                                await HapticFeedback.mediumImpact();
                                try {
                                  await ref
                                      .read(emiRepositoryProvider)
                                      .markPaid(user.uid, plan.id, e.id);
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('Marked as paid'),
                                    ),
                                  );
                                } catch (err) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(repoErrorMessage(err)),
                                    ),
                                  );
                                }
                              },
                              style: FilledButton.styleFrom(
                                elevation: 2,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
                                ),
                              ),
                              child: const Text('Mark Paid'),
                            ),
                          ],
                        );
                      },
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    Text(
                      'No upcoming payments',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
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
