import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/goals_providers.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Savings Goals'),
        elevation: 0,
      ),
      body: goalsAsync.when(
        data: (final goals) {
          if (goals.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.savings_outlined,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No savings goals yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateGoalSheet(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Goal'),
                  ),
                ],
              ),
            );
          }

          final activeGoals = goals.where((final g) => g.isActive).toList();
          final completedGoals = goals.where((final g) => !g.isActive).toList();

          return SingleChildScrollView(
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
                        style: const TextStyle(
                          fontSize: 16,
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
                ...activeGoals.map((final goal) {
                  return GoalListItem(
                    goal: goal,
                    onTap: () => _showEditGoalSheet(context, goal),
                    onDelete: () => _deleteGoal(
                      context,
                      goal.id,
                      ref,
                    ),
                  );
                }),
                if (completedGoals.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Text(
                      'Completed Goals (${completedGoals.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ...completedGoals.map((final goal) {
                    return GoalListItem(
                      goal: goal,
                      onTap: () => _showEditGoalSheet(context, goal),
                      onDelete: () => _deleteGoal(
                        context,
                        goal.id,
                        ref,
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 16),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (final err, final stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $err'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(goalsListProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteGoal(
    final BuildContext context,
    final String goalId,
    final WidgetRef ref,
  ) async {
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Goal?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(goalsServiceProvider).deleteGoal(goalId);
        ref.invalidate(goalsListProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Goal deleted')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }
}
