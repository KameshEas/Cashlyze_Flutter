import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tutorial event that can be triggered throughout the app
enum TutorialEvent {
  dashboardView('dashboard_view', 'Dashboard Overview'),
  budgetCreation('budget_creation', 'Budget Management'),
  transactionEntry('transaction_entry', 'Transaction Entry'),
  categorySelection('category_selection', 'Category Selection'),
  emiTracking('emi_tracking', 'EMI Tracking'),
  settingsAccess('settings_access', 'App Settings'),
  quickMenu('quick_menu', 'Quick Menu');

  const TutorialEvent(this.id, this.title);

  final String id;
  final String title;
}

/// Base class for all tutorial overlays
abstract class BaseTutorialOverlay extends ConsumerWidget {

  const BaseTutorialOverlay({
    required this.onComplete,
    super.key,
  });
  final VoidCallback onComplete;

  /// Get the tutorial event for tracking
  TutorialEvent get tutorialEvent;

  /// Get the tutorial sections to display
  List<TutorialSection> getTutorialSections(final BuildContext context);

  /// Mark tutorial as seen (override if needed)
  Future<void> markAsSeen(final WidgetRef ref) async {
    // Override in subclasses
  }

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    final sections = getTutorialSections(context);

    return Stack(
      children: [
        // Dim background
        Positioned.fill(
          child: GestureDetector(
            onTap: () async {
              await markAsSeen(ref);
              if (context.mounted) onComplete();
            },
            child: Container(
              color: Colors.black.withValues(alpha: 0.6),
            ),
          ),
        ),
        // Tutorial card
        Positioned(
          bottom: 60,
          left: 24,
          right: 24,
          child: _buildTutorialCard(context, sections, ref),
        ),
      ],
    );
  }

  Widget _buildTutorialCard(
    final BuildContext context,
    final List<TutorialSection> sections,
    final WidgetRef ref,
  ) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tutorialEvent.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    markAsSeen(ref);
                    onComplete();
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.close,
                      size: 20,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Content sections
          ...sections.map((final TutorialSection section) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: section.color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      section.icon,
                      color: section.color,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.title,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          section.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 16),

          // Footer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '💡 Tap anywhere to dismiss',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tutorial section data
class TutorialSection {

  TutorialSection({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
  final String title;
  final String description;
  final IconData icon;
  final Color color;
}

/// Tutorial manager to coordinate when tutorials show
class TutorialManager {
  static void showTutorialIfNeeded(
    final BuildContext context,
    final WidgetRef ref,
    final TutorialEvent event,
    final Widget Function(VoidCallback) tutorialBuilder,
  ) {
    // Check if tutorial has been seen before
    WidgetsBinding.instance.addPostFrameCallback((final _) {
      showDialog(
        context: context,
        builder: (final _) => tutorialBuilder(() {
          Navigator.of(context).pop();
        }),
      );
    });
  }
}
