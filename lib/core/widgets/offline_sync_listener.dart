import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../providers/connectivity_provider.dart';
import '../providers/offline_queue_providers.dart';

class OfflineSyncListener extends ConsumerStatefulWidget {
  const OfflineSyncListener({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  ConsumerState<OfflineSyncListener> createState() =>
      _OfflineSyncListenerState();
}

class _OfflineSyncListenerState extends ConsumerState<OfflineSyncListener> {
  @override
  Widget build(final BuildContext context) {
    final isOnline = ref.watch(connectivityStateProvider);

    ref.listen(
      connectivityStateProvider,
      (final previous, final current) {
        if (previous == false && current == true) {
          // Connectivity restored, trigger sync
          _performSync();
        }
      },
    );

    return Stack(
      children: [
        widget.child,
        // Offline indicator
        if (!isOnline)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            // Calm, not alarming: being offline is a state, not a failure
            // (illustration system, docs/redesign/07).
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_off_rounded, size: 18, color: Theme.of(context).colorScheme.onSurface),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          AppLocalizations.of(context)?.offlineBanner ?? "You're offline. Some features may be unavailable.",
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _performSync() async {
    try {
      final result = await ref
          .read(offlineQueueProvider.notifier)
          .syncPending();

      if (mounted) {
        final message = result.success
            ? 'Synced ${result.syncedCount} transactions'
            : 'Sync failed for ${result.failedCount} transactions';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: result.success ? Colors.green : Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
