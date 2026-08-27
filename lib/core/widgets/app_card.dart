import 'package:flutter/material.dart';

import '../ui/constants.dart';
import '../ui/motion.dart';

/// The single "surface card" shape used across the app: rounded, tinted
/// border, optional press feedback and elevated shadow. Consolidates the
/// `Container(color: surface, radius: lg, border: subtle-alpha)` pattern
/// that used to be hand-rolled separately in `RecentTransactionItem`,
/// `TransactionListItem`, `BudgetCard`, and settings' `SettingCard` — build
/// on this instead of copy-pasting the decoration again.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
    this.elevated = false,
    this.color,
    this.borderColor,
    this.radius = AppRadius.lgAll,
    this.accentColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;

  /// Uses [AppShadow.elevated] instead of the default flat border-only look
  /// - for surfaces that should visually lift above the page (e.g. a sheet
  /// header, a highlighted card), not the default for ordinary list cards.
  final bool elevated;

  /// Overrides the theme's card surface color (rarely needed - most
  /// call-sites should leave this null and inherit `colorScheme.surface`).
  final Color? color;
  final Color? borderColor;
  final BorderRadius radius;

  /// Draws a 4px left accent bar (e.g. income/expense distinction on a
  /// transaction row). Null draws no accent bar.
  final Color? accentColor;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final resolvedColor = color ?? theme.colorScheme.surface;
    final resolvedBorder = borderColor ?? theme.colorScheme.onSurface.withValues(alpha: 0.06);

    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: resolvedColor,
        borderRadius: radius,
        border: Border.all(color: resolvedBorder),
        boxShadow: elevated ? AppShadow.elevated : null,
      ),
      foregroundDecoration: accentColor == null
          ? null
          : BoxDecoration(
              borderRadius: radius,
              border: Border(left: BorderSide(color: accentColor!, width: 4)),
            ),
      child: child,
    );

    if (onTap == null && onLongPress == null) return card;

    return ClipRRect(
      borderRadius: radius,
      child: PressableScale(
        onTap: onTap,
        onLongPress: onLongPress,
        child: card,
      ),
    );
  }
}
