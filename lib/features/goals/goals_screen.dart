import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/goals_model.dart';
import '../../core/providers/goals_providers.dart';
import '../../core/ui/motion.dart';
import '../../core/utils/repo_error_handler.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/skeleton.dart';
import 'create_edit_goal_sheet.dart';
import 'goal_list_item.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  void _showCreateGoalSheet(final BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (final context) => const CreateEditGoalSheet(),
    );
  }

  void _showEditGoalSheet(final BuildContext context, final dynamic goal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (final context) => CreateEditGoalSheet(goal: goal),
    );
  }

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    final goalsAsync = ref.watch(goalsListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Savings Goals'),
        elevation: 0,
      ),
      body: goalsAsync.when(
        data: (final goals) {
          if (goals.isEmpty) {
            return Center(
              child: AppEmptyState(
                title: 'No savings goals yet',
                subtitle: 'Create a goal to start tracking your progress.',
                icon: Icons.savings_outlined,
                actionLabel: 'Create Goal',
                onAction: () => _showCreateGoalSheet(context),
              ),
            );
          }

          final activeGoals = goals.where((final g) => g.isActive).toList();
          final completedGoals = goals.where((final g) => !g.isActive).toList();

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(goalsListProvider);
              await Future.delayed(const Duration(milliseconds: 150));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Active Goals (${activeGoals.length})',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _showCreateGoalSheet(context),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  MotionStagger(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: activeGoals.map((final goal) {
                      return GoalListItem(
                        goal: goal,
                        onTap: () => _showEditGoalSheet(context, goal),
                        onDelete: () => _deleteGoal(context, goal, ref),
                      );
                    }).toList(),
                  ),
                  if (completedGoals.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                      child: Text(
                        'Completed Goals (${completedGoals.length})',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    MotionStagger(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      initialDelay: MotionStagger.delayFor(activeGoals.length),
                      children: completedGoals.map((final goal) {
                        return GoalListItem(
                          goal: goal,
                          onTap: () => _showEditGoalSheet(context, goal),
                          onDelete: () => _deleteGoal(context, goal, ref),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
        loading: () => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemBuilder: (final context, final i) => const SkeletonListTile(),
          separatorBuilder: (final context, final i) => const SizedBox(height: 12),
          itemCount: 6,
        ),
        error: (final err, final stack) => Center(
          child: AppEmptyState(
            title: 'Failed to load savings goals',
            subtitle: repoErrorMessage(err),
            icon: Icons.error_outline_rounded,
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(goalsListProvider),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteGoal(
    final BuildContext context,
    final GoalsModel goal,
    final WidgetRef ref,
  ) async {
    if (!context.mounted) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Goal?',
      content: 'This action cannot be undone.',
      confirmLabel: 'Delete',
    );

    if (confirmed == true && context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      await HapticFeedback.mediumImpact();
      try {
        await ref.read(goalsServiceProvider).deleteGoal(goal.id);
        ref.invalidate(goalsListProvider);
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Goal deleted'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                try {
                  await ref.read(goalsServiceProvider).createGoal(goal);
                  ref.invalidate(goalsListProvider);
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Goal restored')),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(repoErrorMessage(e))),
                  );
                }
              },
            ),
          ),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text(repoErrorMessage(e))),
        );
      }
    }
  }
}
