import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/app_version.dart';
import '../providers/app_version_providers.dart';

/// Persistent notice shown at the top of the app while the backend has it in
/// read-only maintenance. Writes are rejected by [ReadOnlyInterceptor]; this
/// banner tells the user why.
class ReadOnlyMaintenanceBanner extends ConsumerWidget {
  const ReadOnlyMaintenanceBanner({required this.child, super.key});

  final Widget child;

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    final maintenance = ref.watch(maintenanceStateProvider);
    final info = maintenance.info;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        if (maintenance.isReadOnly && info != null)
          Material(
            color: colorScheme.tertiaryContainer,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 20,
                      color: colorScheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _text(info),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onTertiaryContainer,
                            ),
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

  static String _text(final MaintenanceInfo info) {
    final title = (info.title == null || info.title!.isEmpty)
        ? 'Maintenance in progress'
        : info.title!;
    final message = (info.message == null || info.message!.isEmpty)
        ? 'You can view your data, but changes are disabled for now.'
        : info.message!;
    final endsAt = info.endsAt;
    final eta = endsAt == null
        ? ''
        : ' Expected back ${DateFormat.MMMd().add_jm().format(endsAt.toLocal())}.';
    return '$title — $message$eta';
  }
}
