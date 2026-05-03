import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/first_time_feature_provider.dart';
import '../../../core/ui/constants.dart';

/// Tooltip position enumeration
enum TooltipPosition {
  top,
  bottom,
  left,
  right,
  center,
}

/// A reusable, contextual tooltip overlay that appears near a target widget
/// Supports multiple positions and auto-dismissal after duration
/// Tracks dismissed tooltips in SharedPreferences
class ContextualTooltip extends ConsumerWidget {
  /// Unique identifier for this tooltip (used for tracking dismissals)
  final String tooltipId;

  /// The title shown in the tooltip
  final String title;

  /// The description/content of the tooltip
  final String description;

  /// Icon to display in the tooltip header
  final IconData icon;

  /// Color theme for the tooltip
  final Color accentColor;

  /// Position where tooltip should appear relative to target
  final TooltipPosition position;

  /// Target widget that the tooltip points to
  /// If null, tooltip appears in center
  final Widget? targetWidget;

  /// Optional callback when user dismisses the tooltip
  final VoidCallback? onDismiss;

  /// Duration before auto-dismissing tooltip (null = manual dismiss only)
  final Duration? autoDismissAfter;

  /// Whether to show a close button
  final bool showCloseButton;

  /// Whether to show a "Got It" button instead of close
  final bool showGotItButton;

  const ContextualTooltip({
    required this.tooltipId,
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
    this.position = TooltipPosition.bottom,
    this.targetWidget,
    this.onDismiss,
    this.autoDismissAfter,
    this.showCloseButton = true,
    this.showGotItButton = false,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dismissedTooltips = ref.watch(dismissedTooltipsProvider);
    final isDismissed = dismissedTooltips.contains(tooltipId);

    if (isDismissed) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        // Semi-transparent background (tap to dismiss)
        Positioned.fill(
          child: GestureDetector(
            onTap: () => _handleDismiss(context, ref),
            child: Container(
              color: Colors.transparent,
            ),
          ),
        ),
        // Tooltip card
        Positioned(
          left: 16,
          right: 16,
          top: position == TooltipPosition.top ? 60 : null,
          bottom: position == TooltipPosition.bottom ? 60 : null,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with icon and title
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(
                        icon,
                        color: accentColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (showCloseButton && !showGotItButton)
                      GestureDetector(
                        onTap: () => _handleDismiss(context, ref),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s12),

                // Description text
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                ),

                // Action button if specified
                if (showGotItButton) ...[
                  const SizedBox(height: AppSpacing.s16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => _handleDismiss(context, ref),
                      style: FilledButton.styleFrom(
                        backgroundColor: accentColor,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Got It'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Auto-dismiss timer
        if (autoDismissAfter != null)
          _AutoDismissTimer(
            duration: autoDismissAfter!,
            onExpire: () => _handleDismiss(context, ref),
          ),
      ],
    );
  }

  Future<void> _handleDismiss(BuildContext context, WidgetRef ref) async {
    await ref.read(dismissedTooltipsProvider.notifier).dismiss(tooltipId);
    onDismiss?.call();
  }
}

/// Timer widget that auto-dismisses after specified duration
class _AutoDismissTimer extends StatefulWidget {
  final Duration duration;
  final VoidCallback onExpire;

  const _AutoDismissTimer({
    required this.duration,
    required this.onExpire,
  });

  @override
  State<_AutoDismissTimer> createState() => _AutoDismissTimerState();
}

class _AutoDismissTimerState extends State<_AutoDismissTimer> {
  late Future<void> _future;

  @override
  void initState() {
    super.initState();
    _future = Future.delayed(widget.duration, widget.onExpire);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
