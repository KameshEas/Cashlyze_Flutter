import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/first_time_feature_provider.dart';
import 'tutorial_system.dart';

/// Tutorial overlay shown on first category creation
/// Highlights category naming, color selection, and icon customization
class CategoryTutorialOverlay extends BaseTutorialOverlay {
  const CategoryTutorialOverlay({
    required super.onComplete,
    super.key,
  });

  @override
  TutorialEvent get tutorialEvent => TutorialEvent.categorySelection;

  @override
  List<TutorialSection> getTutorialSections(final BuildContext context) {
    return [
      TutorialSection(
        icon: Icons.label_rounded,
        title: 'Category Names',
        description: 'Create meaningful names like "Groceries", "Entertainment", "Transport".',
        color: Colors.blue,
      ),
      TutorialSection(
        icon: Icons.palette_rounded,
        title: 'Custom Colors',
        description: 'Assign colors to categories for quick visual identification.',
        color: Colors.pink,
      ),
      TutorialSection(
        icon: Icons.emoji_emotions_rounded,
        title: 'Icon Selection',
        description: 'Choose icons that represent each category visually.',
        color: Colors.amber,
      ),
      TutorialSection(
        icon: Icons.sort_rounded,
        title: 'Organize Transactions',
        description: 'Categorize your transactions to see spending patterns by type.',
        color: Colors.green,
      ),
    ];
  }

  @override
  Future<void> markAsSeen(final WidgetRef ref) async {
    await ref.read(firstTimeCategoryProvider.notifier).markAsSeen();
  }
}
