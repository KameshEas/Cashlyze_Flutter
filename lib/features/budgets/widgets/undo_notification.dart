import 'package:flutter/material.dart';
import '../../../core/utils/format.dart';

/// Widget for displaying undo/redo notifications for budget changes
class UndoNotification extends StatefulWidget {

  const UndoNotification({
    super.key,
    required this.budgetName,
    required this.oldValue,
    required this.newValue,
    required this.currency,
    required this.onUndo,
    this.displayDuration = const Duration(seconds: 5),
  });
  final String budgetName;
  final double oldValue;
  final double newValue;
  final String currency;
  final VoidCallback onUndo;
  final Duration displayDuration;

  @override
  State<UndoNotification> createState() => _UndoNotificationState();
}

class _UndoNotificationState extends State<UndoNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _scheduleDismissal();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  void _scheduleDismissal() {
    Future.delayed(widget.displayDuration, () {
      if (mounted) {
        _animationController.reverse().then((_) {
          if (mounted) Navigator.of(context).pop();
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleUndo() {
    widget.onUndo();
    _animationController.reverse().then((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final change = widget.newValue - widget.oldValue;
    final isIncrease = change > 0;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isIncrease ? Colors.green : Colors.orange)
                      .withValues(alpha: 0.15),
                ),
                child: Icon(
                  isIncrease ? Icons.trending_up : Icons.trending_down,
                  color: isIncrease ? Colors.green : Colors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${widget.budgetName} budget updated',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          formatAmount(widget.oldValue, widget.currency),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward,
                          size: 12,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatAmount(widget.newValue, widget.currency),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isIncrease ? Colors.green : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _handleUndo,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      'Undo',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Show undo notification in overlay
void showUndoNotification(
  final BuildContext context, {
  required final String budgetName,
  required final double oldValue,
  required final double newValue,
  required final String currency,
  required final VoidCallback onUndo,
  final Duration displayDuration = const Duration(seconds: 5),
}) {
  final overlay = Overlay.of(context);
  late OverlayEntry overlayEntry;

  overlayEntry = OverlayEntry(
    builder: (final BuildContext context) {
      return Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        child: UndoNotification(
          budgetName: budgetName,
          oldValue: oldValue,
          newValue: newValue,
          currency: currency,
          onUndo: () {
            onUndo();
            overlayEntry.remove();
          },
          displayDuration: displayDuration,
        ),
      );
    },
  );

  overlay.insert(overlayEntry);

  // Auto-dismiss after duration
  Future.delayed(displayDuration, () {
    if (overlayEntry.mounted) {
      overlayEntry.remove();
    }
  });
}
