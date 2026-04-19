import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/first_time_feature_provider.dart';
import '../../../core/ui/constants.dart';

/// Tutorial overlay shown on first transaction creation
/// Highlights category selection, amount entry, and transaction types
class TransactionTutorialOverlay extends ConsumerWidget {
  final VoidCallback onComplete;

  const TransactionTutorialOverlay({
    required this.onComplete,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        // Dim background
        Positioned.fill(
          child: GestureDetector(
            onTap: () async {
              await ref.read(firstTimeTransactionProvider.notifier).markAsSeen();
              if (context.mounted) onComplete();
            },
            child: Container(
              color: Colors.black.withValues(alpha: 0.6),
            ),
          ),
        ),
        // Tutorial card with information
        Positioned(
          bottom: 60,
          left: 24,
          right: 24,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(AppSpacing.s20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Text(
                        'Record Transactions',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s16),

                // Content sections
                _buildTutorialSection(
                  context,
                  icon: Icons.category_rounded,
                  title: 'Select Category',
                  description: 'Choose a category that matches your spending for better tracking.',
                  color: Colors.blue,
                ),
                const SizedBox(height: AppSpacing.s16),

                _buildTutorialSection(
                  context,
                  icon: Icons.local_atm_rounded,
                  title: 'Enter Amount',
                  description: 'Input the transaction amount accurately for proper budget tracking.',
                  color: Colors.green,
                ),
                const SizedBox(height: AppSpacing.s16),

                _buildTutorialSection(
                  context,
                  icon: Icons.account_balance_rounded,
                  title: 'Transaction Types',
                  description: 'Income increases budget, expense decreases it. Choose wisely.',
                  color: Colors.orange,
                ),
                const SizedBox(height: AppSpacing.s16),

                _buildTutorialSection(
                  context,
                  icon: Icons.calendar_today_rounded,
                  title: 'Set Date & Time',
                  description: 'Record the exact date and time for accurate financial history.',
                  color: Colors.purple,
                ),

                const SizedBox(height: AppSpacing.s20),

                // Action button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      await ref.read(firstTimeTransactionProvider.notifier).markAsSeen();
                      if (context.mounted) onComplete();
                    },
                    child: const Text('Got It!'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTutorialSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(
            icon,
            color: color,
            size: 18,
          ),
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
