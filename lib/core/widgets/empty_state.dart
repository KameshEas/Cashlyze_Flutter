import 'package:flutter/material.dart';

import '../illustrations/app_illustration.dart';

/// Empty / failed / no-results state.
///
/// Visual precedence: [illustration] (purpose-built scene) > [icon] (legacy
/// glyph tile) > text only. The illustration is dropped automatically when the
/// available height or text scale can't afford it, so the title and action
/// are never pushed off-screen. [compact] is text-only, for dense screens
/// (e.g. Insights) where one section's empty state shouldn't dominate.
class AppEmptyState extends StatelessWidget {

  const AppEmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.illustration,
    this.compact = false,
    this.actionLabel,
    this.onAction,
  });
  final String title;
  final String? subtitle;
  final IconData? icon;
  final AppIllustrationKind? illustration;
  final bool compact;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (final context, final constraints) {
        final showIllustration = !compact && illustration != null && AppIllustration.fits(context, constraints);
        final showIcon = !compact && !showIllustration && icon != null;
        return Padding(
          padding: compact ? const EdgeInsets.symmetric(vertical: 8) : EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showIllustration) ...[
                AppIllustration(illustration!),
                const SizedBox(height: 16),
              ],
              if (showIcon) ...[
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 44, color: theme.colorScheme.primary),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (subtitle != null) const SizedBox(height: 8),
              if (subtitle != null)
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              if (actionLabel != null && onAction != null) const SizedBox(height: 12),
              if (actionLabel != null && onAction != null)
                FilledButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
            ],
          ),
        );
      },
    );
  }
}
