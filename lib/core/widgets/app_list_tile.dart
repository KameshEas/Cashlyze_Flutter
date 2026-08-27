import 'package:flutter/material.dart';

import '../ui/constants.dart';
import 'app_card.dart';

/// The "row with an icon badge, title, subtitle pill, and a trailing value"
/// shape repeated across Home's recent-transactions list and similar simple
/// list rows. Built on [AppCard] so container styling (radius, border,
/// optional accent bar, press feedback) stays centralized.
///
/// Not a fit for rows with genuinely bespoke content (multi-line tag wraps,
/// selection checkboxes, per-field conditional logic) - those should keep
/// their own layout but still use [AppCard] for the shared container.
class AppListTile extends StatelessWidget {
  const AppListTile({
    super.key,
    required this.title,
    required this.trailing,
    this.subtitle,
    this.leadingIcon,
    this.leadingIconColor,
    this.accentColor,
    this.trailingColor,
    this.onTap,
    this.onLongPress,
  });

  final String title;
  final String? subtitle;
  final IconData? leadingIcon;
  final Color? leadingIconColor;
  final Color? accentColor;

  /// Usually a formatted amount - kept as a widget-agnostic value: pass a
  /// pre-formatted [Text] via [trailingBuilder] if custom styling is needed
  /// beyond [trailingColor].
  final String trailing;
  final Color? trailingColor;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.s16),
      accentColor: accentColor,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Row(
        children: [
          if (leadingIcon != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.s8 + 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(
                leadingIcon,
                color: leadingIconColor ?? theme.colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.s16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.s4 + 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                      borderRadius: AppRadius.mdAll,
                    ),
                    child: Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          Text(
            trailing,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: trailingColor ?? theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
