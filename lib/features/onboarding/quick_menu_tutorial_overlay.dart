import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/first_time_feature_provider.dart';
import 'tutorial_system.dart';

/// Tutorial overlay shown the first time a user sees the new center nav
/// button, pointing out the destinations tucked behind it.
class QuickMenuTutorialOverlay extends BaseTutorialOverlay {
  const QuickMenuTutorialOverlay({
    required super.onComplete,
    super.key,
  });

  @override
  TutorialEvent get tutorialEvent => TutorialEvent.quickMenu;

  @override
  List<TutorialSection> getTutorialSections(final BuildContext context) {
    return [
      TutorialSection(
        icon: Icons.apps_rounded,
        title: 'New Quick Menu',
        description: 'Tap the center button to reach Goals, Categories, EMI, Search, Scan and Help Center.',
        color: Colors.blue,
      ),
      TutorialSection(
        icon: Icons.camera_alt_outlined,
        title: 'Scan Receipts',
        description: 'Snap a photo of a receipt and add it as a transaction in seconds.',
        color: Colors.purple,
      ),
    ];
  }

  @override
  Future<void> markAsSeen(final WidgetRef ref) async {
    await ref.read(firstTimeQuickMenuProvider.notifier).markAsSeen();
  }
}
