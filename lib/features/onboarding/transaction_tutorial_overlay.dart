import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/first_time_feature_provider.dart';
import 'tutorial_system.dart';

/// Tutorial overlay shown on first transaction creation
/// Highlights category selection, amount entry, and transaction types
class TransactionTutorialOverlay extends BaseTutorialOverlay {
  const TransactionTutorialOverlay({
    required super.onComplete,
    super.key,
  });

  @override
  TutorialEvent get tutorialEvent => TutorialEvent.transactionEntry;

  @override
  List<TutorialSection> getTutorialSections(final BuildContext context) {
    return [
      TutorialSection(
        icon: Icons.category_rounded,
        title: 'Select Category',
        description: 'Choose a category that matches your spending for better tracking.',
        color: Colors.blue,
      ),
      TutorialSection(
        icon: Icons.local_atm_rounded,
        title: 'Enter Amount',
        description: 'Input the transaction amount accurately for proper budget tracking.',
        color: Colors.green,
      ),
      TutorialSection(
        icon: Icons.account_balance_rounded,
        title: 'Transaction Types',
        description: 'Income increases budget, expense decreases it. Choose wisely.',
        color: Colors.orange,
      ),
      TutorialSection(
        icon: Icons.calendar_today_rounded,
        title: 'Set Date & Time',
        description: 'Record the exact date and time for accurate financial history.',
        color: Colors.purple,
      ),
    ];
  }

  @override
  Future<void> markAsSeen(final WidgetRef ref) async {
    await ref.read(firstTimeTransactionProvider.notifier).markAsSeen();
  }
}
