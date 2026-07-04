import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../models/queued_transaction.dart';
import 'offline_queue_service.dart';

class SyncService {
  SyncService({
    required this.apiClient,
    required this.queueService,
  });

  final ApiClient apiClient;
  final OfflineQueueService queueService;

  Future<SyncResult> syncPendingTransactions(final String userId) async {
    final pending = await queueService.getPendingTransactions(userId);

    if (pending.isEmpty) {
      return SyncResult(
        success: true,
        syncedCount: 0,
        failedCount: 0,
        errors: [],
      );
    }

    final results = SyncResult(
      success: true,
      syncedCount: 0,
      failedCount: 0,
      errors: [],
    );

    for (final transaction in pending) {
      await _syncTransaction(transaction, results);
    }

    return results;
  }

  Future<void> _syncTransaction(
    final QueuedTransaction transaction,
    final SyncResult results,
  ) async {
    try {
      // Update status to syncing
      await queueService.updateStatus(transaction.id, 'syncing');

      // Create the request payload
      final payload = {
        'title': transaction.title,
        'amount': transaction.amount,
        'category_id': transaction.categoryId,
        'transaction_date': transaction.transactionDate.toIso8601String().split('T')[0],
        'notes': transaction.notes,
        'tags': transaction.tags,
        'account_id': transaction.accountId,
        'attachment_path': transaction.attachmentPath,
      };

      // Try to sync to backend
      final response = await apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.transactions,
        data: payload,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        // Mark as synced
        await queueService.deleteTransaction(transaction.id);
        results.syncedCount++;
      } else {
        throw Exception('Sync failed with status ${response.statusCode}');
      }
    } catch (e) {
      // Mark as failed
      await queueService.updateStatus(
        transaction.id,
        'failed',
        errorMessage: e.toString(),
      );

      // Increment retry count
      await queueService.incrementRetryCount(transaction.id);

      results.failedCount++;
      results.errors.add(SyncError(
        transactionId: transaction.id,
        error: e.toString(),
      ));
      results.success = false;
    }
  }
}

class SyncResult {
  SyncResult({
    required this.success,
    required this.syncedCount,
    required this.failedCount,
    required this.errors,
  });

  bool success;
  int syncedCount;
  int failedCount;
  List<SyncError> errors;
}

class SyncError {
  SyncError({
    required this.transactionId,
    required this.error,
  });

  final String transactionId;
  final String error;
}
