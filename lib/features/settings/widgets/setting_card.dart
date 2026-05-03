import 'package:flutter/material.dart';

/// A single setting card with icon, title, description, optional status badge, and interactive element
class SettingCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? description;
  final Widget? statusBadge;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;

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

  @override
  State<SettingCard> createState() => _SettingCardState();
}

class _SettingCardState extends State<SettingCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = widget.iconColor ?? theme.colorScheme.primary;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _isHovered
                ? theme.colorScheme.surface.withValues(alpha: 0.8)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(
                alpha: _isHovered ? 0.1 : 0.06,
              ),
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Row(
              children: [
                // Left: Icon in colored background
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(widget.icon, color: iconColor, size: 18),
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
