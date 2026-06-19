import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/first_time_feature_provider.dart';
import 'tutorial_system.dart';

/// Tutorial overlay shown on first budget creation
/// Highlights period selector, filter chips, and drag-to-reorder gesture
class BudgetTutorialOverlay extends BaseTutorialOverlay {
  const BudgetTutorialOverlay({
    required super.onComplete,
    super.key,
  });

  @override
  TutorialEvent get tutorialEvent => TutorialEvent.budgetCreation;

  @override
  List<TutorialSection> getTutorialSections(final BuildContext context) {
    return [
      TutorialSection(
        icon: Icons.calendar_today_rounded,
        title: 'Choose Budget Period',
        description: 'Select Daily, Weekly, or Monthly based on your needs.',
        color: Colors.blue,
      ),
      TutorialSection(
        icon: Icons.filter_alt_rounded,
        title: 'Filter by Period',
        description: 'Use filter chips to view budgets for a specific period.',
        color: Colors.orange,
      ),
      TutorialSection(
        icon: Icons.touch_app_rounded,
        title: 'Drag to Reorder',
        description: 'Long-press and drag budgets to reorder them for quick access.',
        color: Colors.green,
      ),
      TutorialSection(
        icon: Icons.undo_rounded,
        title: 'Undo Changes',
        description: 'Undo budget adjustments within 5 seconds or deletions within 8 seconds.',
        color: Colors.purple,
      ),
    ];
  }

  @override
  Future<void> markAsSeen(final WidgetRef ref) async {
    await ref.read(firstTimeBudgetProvider.notifier).markAsSeen();
  }
}
