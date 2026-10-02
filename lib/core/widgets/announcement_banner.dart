import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_version_providers.dart';
import 'announcement_actions.dart';

/// Banner at the top of the app for the highest-priority live announcement
/// placed as a banner. Its type sets the colour and icon; it can carry a
/// button and, unless the admin marked it undismissible, a close button.
/// Once dismissed, the next banner (if any) takes its place.
class AnnouncementBanner extends ConsumerWidget {
  const AnnouncementBanner({required this.child, super.key});

  final Widget child;

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    final announcement = ref.watch(announcementStateProvider).banner;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        if (announcement != null)
          Builder(
            builder: (final context) {
              final style = announcementStyle(colorScheme, announcement.type);
              final title = announcement.title;
              return Material(
                color: Color.alphaBlend(
                  style.accent.withValues(alpha: 0.14),
                  colorScheme.surface,
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(style.icon, size: 20, color: style.accent),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (title != null && title.isNotEmpty)
                                Text(
                                  title,
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              Text(
                                announcement.body,
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              if (announcement.hasCta)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: InkWell(
                                    onTap: () => runAnnouncementCta(ref, announcement),
                                    child: Text(
                                      announcement.ctaLabel!,
                                      style: textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: style.accent,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (announcement.dismissible) ...[
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => ref
                                .read(announcementStateProvider.notifier)
                                .dismiss(announcement),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: colorScheme.onSurface,
                                semanticLabel: 'Dismiss',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        Expanded(child: child),
      ],
    );
  }
}
