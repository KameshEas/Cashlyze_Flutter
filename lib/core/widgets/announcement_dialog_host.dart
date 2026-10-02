import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../routes/app_router.dart';
import '../models/app_version.dart';
import '../providers/app_version_providers.dart';
import 'announcement_actions.dart';

/// Shows the highest-priority live announcement placed as a dialog, one at a
/// time, on top of the routed app. It lives above the router, so the dialog
/// is opened through the root navigator.
class AnnouncementDialogHost extends ConsumerStatefulWidget {
  const AnnouncementDialogHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AnnouncementDialogHost> createState() => _AnnouncementDialogHostState();
}

class _AnnouncementDialogHostState extends ConsumerState<AnnouncementDialogHost> {
  bool _showing = false;

  @override
  Widget build(final BuildContext context) {
    ref.listen<AnnouncementState>(announcementStateProvider, (final _, final next) {
      final dialog = next.dialog;
      if (dialog != null && !_showing) _show(dialog);
    });
    return widget.child;
  }

  Future<void> _show(final AnnouncementInfo announcement) async {
    _showing = true;
    try {
      // The navigator may not exist yet on the very first frames.
      BuildContext? navigatorContext;
      for (var i = 0; i < 10 && navigatorContext == null; i++) {
        navigatorContext = ref.read(rootNavigatorKeyProvider).currentContext;
        if (navigatorContext == null) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          if (!mounted) return;
        }
      }
      if (navigatorContext == null || !navigatorContext.mounted) return;
      // A forced update takes over the whole screen; don't pile a dialog on it.
      if (ref.read(forceUpdateStateProvider).isUpdateRequired) return;

      await showDialog<void>(
        context: navigatorContext,
        barrierDismissible: announcement.dismissible,
        builder: (final dialogContext) => _AnnouncementDialog(
          announcement: announcement,
          onCta: () async {
            Navigator.of(dialogContext).pop();
            await runAnnouncementCta(ref, announcement);
          },
        ),
      );
      if (mounted) {
        await ref.read(announcementStateProvider.notifier).dismiss(announcement);
      }
    } finally {
      _showing = false;
    }

    // Another dialog may have become the top one while this was open.
    final next = ref.read(announcementStateProvider).dialog;
    if (mounted && next != null) unawaited(_show(next));
  }
}

class _AnnouncementDialog extends StatelessWidget {
  const _AnnouncementDialog({required this.announcement, required this.onCta});

  final AnnouncementInfo announcement;
  final VoidCallback onCta;

  @override
  Widget build(final BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final style = announcementStyle(colorScheme, announcement.type);
    final title = announcement.title;

    return PopScope(
      canPop: announcement.dismissible,
      child: AlertDialog(
        icon: Icon(style.icon, size: 32, color: style.accent),
        title: (title == null || title.isEmpty) ? null : Text(title, textAlign: TextAlign.center),
        content: Text(announcement.body),
        actions: [
          if (announcement.dismissible)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Dismiss'),
            ),
          // Nothing to press otherwise: give a required notice an explicit way out.
          if (!announcement.dismissible && !announcement.hasCta)
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          if (announcement.hasCta)
            FilledButton(
              onPressed: onCta,
              child: Text(announcement.ctaLabel!),
            ),
        ],
      ),
    );
  }
}
