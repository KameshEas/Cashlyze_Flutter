import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/first_time_feature_provider.dart';
import '../../../core/ui/constants.dart';

/// Tutorial overlay shown on first EMI creation
/// Highlights principal amount, interest rate, tenure, and calculation
class EMITutorialOverlay extends ConsumerWidget {
  final VoidCallback onComplete;

  const EMITutorialOverlay({
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
              await ref.read(firstTimeEMIProvider.notifier).markAsSeen();
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
                        'Calculate EMI Payments',
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
                  icon: Icons.trending_up_rounded,
                  title: 'Principal Amount',
                  description: 'Enter the total loan amount you want to calculate EMI for.',
                  color: Colors.blue,
                ),
                const SizedBox(height: AppSpacing.s16),

                _buildTutorialSection(
                  context,
                  icon: Icons.percent_rounded,
                  title: 'Interest Rate',
                  description: 'Input the annual interest rate provided by your lender.',
                  color: Colors.orange,
                ),
                const SizedBox(height: AppSpacing.s16),

                _buildTutorialSection(
                  context,
                  icon: Icons.schedule_rounded,
                  title: 'Tenure (Months)',
                  description: 'Set the loan duration in months to calculate monthly EMI.',
                  color: Colors.green,
                ),
                const SizedBox(height: AppSpacing.s16),

                _buildTutorialSection(
                  context,
                  icon: Icons.calculate_rounded,
                  title: 'Auto-Calculation',
                  description: 'EMI is calculated instantly. Plan your budget accordingly.',
                  color: Colors.purple,
                ),

                const SizedBox(height: AppSpacing.s20),

                // Action button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      await ref.read(firstTimeEMIProvider.notifier).markAsSeen();
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
