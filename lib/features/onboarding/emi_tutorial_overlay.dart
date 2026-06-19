import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/first_time_feature_provider.dart';
import 'tutorial_system.dart';

/// Tutorial overlay shown on first EMI creation
/// Highlights principal amount, interest rate, tenure, and calculation
class EMITutorialOverlay extends BaseTutorialOverlay {
  const EMITutorialOverlay({
    required super.onComplete,
    super.key,
  });

  @override
  TutorialEvent get tutorialEvent => TutorialEvent.emiTracking;

  @override
  List<TutorialSection> getTutorialSections(final BuildContext context) {
    return [
      TutorialSection(
        icon: Icons.trending_up_rounded,
        title: 'Principal Amount',
        description: 'Enter the total loan amount you want to calculate EMI for.',
        color: Colors.blue,
      ),
      TutorialSection(
        icon: Icons.percent_rounded,
        title: 'Interest Rate',
        description: 'Input the annual interest rate provided by your lender.',
        color: Colors.orange,
      ),
      TutorialSection(
        icon: Icons.schedule_rounded,
        title: 'Tenure (Months)',
        description: 'Set the loan duration in months to calculate monthly EMI.',
        color: Colors.green,
      ),
      TutorialSection(
        icon: Icons.calculate_rounded,
        title: 'Auto-Calculation',
        description: 'EMI is calculated instantly. Plan your budget accordingly.',
        color: Colors.purple,
      ),
    ];
  }

  @override
  Future<void> markAsSeen(final WidgetRef ref) async {
    await ref.read(firstTimeEMIProvider.notifier).markAsSeen();
  }
}
