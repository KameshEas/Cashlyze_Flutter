import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/realtime_db_service.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(ref.watch(realtimeDbServiceProvider));
});

class SyncService {
  final RealtimeDbService _db;
  final List<Map<String, dynamic>> _queue = [];
  bool _processing = false;

  SyncService(this._db);

  /// Enqueue a canonical transaction payload to be sent to server later.
  void enqueue(Map<String, dynamic> canonical) {
    _queue.add(canonical);
    // Optionally kick off processing
    _processQueue();
  }

  Future<void> _processQueue() async {
    if (_processing) return;
    _processing = true;
    try {
      while (_queue.isNotEmpty) {
        final item = _queue.first;
        try {
          // Map canonical to RTDB representation
          final userId = item['account_id'] ?? 'unknown_user';
          final data = {
            'title': item['merchant_name'] ?? item['normalized_description'] ?? 'Imported',
            'amount': (item['amount'] is num) ? (item['amount'] as num).toDouble() : 0.0,
            'categoryId': item['category'],
            'date_ms': DateTime.parse(item['date']).millisecondsSinceEpoch,
            'notes': item['normalized_description'],
            'tags': [],
            'created_at_ms': DateTime.now().millisecondsSinceEpoch,
            'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
          };
          await _db.pushKey('users/$userId/transactions', data);
          _queue.removeAt(0);
        } catch (_) {
          // If push failed, break and retry later
          break;
        }
      }
    } finally {
      _processing = false;
    }
  }
}
