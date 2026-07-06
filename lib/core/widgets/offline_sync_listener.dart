import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
            child: Container(
              color: Colors.red.shade700,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'You are offline',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
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
