import 'package:flutter/material.dart';
import '../../../core/ui/constants.dart';

/// A group of related SettingCards with a section header and optional description
class SettingCardGroup extends StatelessWidget {

  const SettingCardGroup({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.cards,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> cards;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.xlAll,
        border: Border.all(color: theme.colorScheme.outline),
        boxShadow: theme.brightness == Brightness.dark
            ? null
            : const [
                BoxShadow(color: Color(0x0F16201B), blurRadius: 18, offset: Offset(0, 6)),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and title
          Row(
            children: [
              Icon(icon, size: 24, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // Cards with dividers
          const SizedBox(height: 12),
          Column(
            children: List.generate(
              cards.length,
              (final index) {
                final isLast = index == cards.length - 1;
                return Column(
                  children: [
                    cards[index],
                    if (!isLast) ...[
                      const SizedBox(height: 1),
                      Divider(
                        height: 1,
                        indent: 56,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(height: 1),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
