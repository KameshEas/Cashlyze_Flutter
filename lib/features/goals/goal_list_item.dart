import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/goals_model.dart';
import '../../core/providers/onboarding_provider.dart';
import '../../core/ui/constants.dart';
import '../../core/ui/motion.dart';
import '../../core/utils/format.dart';
import 'goal_progress_ring.dart';

class GoalListItem extends ConsumerWidget {
  const GoalListItem({
    required this.goal,
    required this.onTap,
    required this.onDelete,
    super.key,
  });

  final GoalsModel goal;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    final currency = ref.watch(currencyProvider);
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: PressableScale(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              GoalProgressRing(
                progress: goal.progressPercent ?? goal.calculatedProgress,
                currentAmount: goal.currentAmount,
                targetAmount: goal.targetAmount,
                size: 100,
                color: _parseColor(goal.color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        if (goal.icon != null) ...[
                          Text(
                            goal.icon!,
                            style: const TextStyle(fontSize: 20),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            goal.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (goal.description != null && goal.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          goal.description!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${formatAmount(goal.currentAmount, currency)} / ${formatAmount(goal.targetAmount, currency)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (goal.targetDate != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      goal.isOverdue
                                          ? 'Overdue by ${(DateTime.now().difference(goal.targetDate!).inDays)} days'
                                          : 'In ${goal.daysRemaining} days',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: goal.isOverdue
                                            ? AppColors.error
                                            : AppColors.warning,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (goal.isCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Completed',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Semantics(
                label: 'Goal options for ${goal.name}',
                child: PopupMenuButton<String>(
                  tooltip: 'More options',
                  onSelected: (final value) {
                    if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (final BuildContext context) => [
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18),
                          SizedBox(width: 8),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _parseColor(final String? colorHex) {
    if (colorHex == null || colorHex.isEmpty) {
      return Colors.blue;
    }
    try {
      return Color(int.parse('FF${colorHex.replaceFirst('#', '')}', radix: 16));
    } catch (_) {
      return Colors.blue;
    }
  }
}
