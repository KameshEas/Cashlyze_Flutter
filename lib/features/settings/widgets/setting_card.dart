import 'package:flutter/material.dart';

import '../../../core/ui/constants.dart';
import '../../../core/ui/motion.dart';

/// A single setting card with icon, title, description, optional status badge, and interactive element
class SettingCard extends StatefulWidget {

  const SettingCard({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.statusBadge,
    this.trailing,
    this.onTap,
    this.iconColor,
  });
  final IconData icon;
  final String title;
  final String? description;
  final Widget? statusBadge;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;

  @override
  State<SettingCard> createState() => _SettingCardState();
}

class _SettingCardState extends State<SettingCard> {
  bool _isHovered = false;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = widget.iconColor ?? theme.colorScheme.primary;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: PressableScale(
        onTap: widget.onTap,
        pressedScale: widget.onTap != null ? 0.97 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            // Rows sit flat inside their group card (no card-in-card border).
            color: _isHovered
                ? theme.colorScheme.surfaceContainerHighest
                : Colors.transparent,
            borderRadius: AppRadius.lgAll,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Row(
              children: [
                // Left: Icon in colored background
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.14),
                    borderRadius: AppRadius.lgAll,
                  ),
                  child: Icon(widget.icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),

                // Center: Title, Description, Status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (widget.description != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.description!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (widget.statusBadge != null) ...[
                        const SizedBox(height: 6),
                        widget.statusBadge!,
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Right: Interactive element or chevron
                if (widget.trailing != null)
                  widget.trailing!
                else if (widget.onTap != null)
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
