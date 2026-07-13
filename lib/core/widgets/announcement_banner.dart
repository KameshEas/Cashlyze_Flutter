import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_version_providers.dart';

/// Dismissible banner shown at the top of the app when the backend has an
/// active announcement (see AppVersionModel.announcementActive). Dismissal
/// is persisted per message, so it stays dismissed until the admin console
/// changes the message text.
class AnnouncementBanner extends ConsumerWidget {
  const AnnouncementBanner({required this.child, super.key});

  final Widget child;

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    final announcement = ref.watch(announcementStateProvider);

    return Column(
      children: [
        if (announcement.visible && announcement.message != null)
          Material(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.campaign_outlined,
                      size: 20,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        announcement.message!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () =>
                          ref.read(announcementStateProvider.notifier).dismiss(),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(child: child),
      ],
    );
  }
}
