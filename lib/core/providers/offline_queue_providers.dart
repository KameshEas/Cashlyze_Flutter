import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqlite_async/sqlite_async.dart';

import '../../core/api/api_client.dart';
import '../../core/models/queued_transaction.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/offline_queue_service.dart';
import '../../core/services/sync_service.dart';

final _databaseProvider = FutureProvider<SqliteDatabase>((final ref) async {
  final db = SqliteDatabase(path: 'cashlyze_offline.db');
  return db;
});

final offlineQueueServiceProvider =
    FutureProvider<OfflineQueueService>((final ref) async {
  final db = await ref.watch(_databaseProvider.future);
  final service = OfflineQueueService(db);
  await service.initialize();
  return service;
});

final syncServiceProvider = Provider<SyncService>((final ref) {
  // This will be initialized when needed in OfflineQueueNotifier
  throw Exception('Sync service not initialized');
});

class OfflineQueueNotifier extends AsyncNotifier<List<QueuedTransaction>> {
  @override
  Future<List<QueuedTransaction>> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return [];

    final queueService = await ref.watch(offlineQueueServiceProvider.future);
    return queueService.getAllForUser(user.uid);
  }

  Future<void> addToQueue(final QueuedTransaction transaction) async {
    final queueService = await ref.watch(offlineQueueServiceProvider.future);
    await queueService.addTransaction(transaction);
    ref.invalidateSelf();
  }

  Future<void> removeFromQueue(final String transactionId) async {
    final queueService = await ref.watch(offlineQueueServiceProvider.future);
    await queueService.deleteTransaction(transactionId);
    ref.invalidateSelf();
  }

  Future<SyncResult> syncPending() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return SyncResult(
        success: false,
        syncedCount: 0,
        failedCount: 0,
        errors: [],
      );
    }

    final queueService = await ref.watch(offlineQueueServiceProvider.future);
    final apiClient = ref.watch(apiClientProvider);

    final syncService = SyncService(
      apiClient: apiClient,
      queueService: queueService,
    );

    final result = await syncService.syncPendingTransactions(user.uid);
    ref.invalidateSelf();
    return result;
  }
}

final offlineQueueProvider = AsyncNotifierProvider<
    OfflineQueueNotifier,
    List<QueuedTransaction>>(OfflineQueueNotifier.new);

final pendingTransactionCountProvider =
    FutureProvider<int>((final ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return 0;

  final queueService = await ref.watch(offlineQueueServiceProvider.future);
  return queueService.getPendingCount(user.uid);
});
