import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/realtime_db_service.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../models/transaction.dart';

class TransactionRepository {
  final RealtimeDbService _db;
  final SyncService? _sync;

  TransactionRepository(this._db, [this._sync]);

  Future<TransactionModel> create({
    required String userId,
    required String title,
    required double amount,
    String? categoryId,
    required DateTime date,
    String? notes,
    List<String>? tags,
  }) async {
    _validate(title: title, amount: amount, date: date);
    final data = {
      'userId': userId,
      'title': title.trim(),
      'amount': amount,
      'categoryId': categoryId,
      'date_ms': date.millisecondsSinceEpoch,
      'notes': notes,
      'tags': tags,
      'created_at_ms': ServerValue.timestamp,
      'updated_at_ms': ServerValue.timestamp,
    };
    try {
      final key = await _db.pushKey('users/$userId/transactions', data);
      return TransactionModel.fromRTDB(key, data);
    } catch (e) {
      // If push fails (offline), enqueue a canonical payload for later sync
      final canonical = {
        'id': 'local_${DateTime.now().millisecondsSinceEpoch}',
        'account_id': userId,
        'provider': 'local',
        'amount': amount,
        'currency': 'INR',
        'date': date.toIso8601String(),
        'transaction_type': amount < 0 ? 'debit' : 'credit',
        'merchant_name': title.trim(),
        'raw_description': notes ?? title.trim(),
        'normalized_description': title.trim(),
        'category': categoryId,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      _sync?.enqueue(canonical);
      // Return a local model so UI can reflect created txn immediately
      // Safely parse canonical['date'] which may be String, int (ms), double, or absent.
      final dynamic dateRaw = canonical['date'];
      late final int dateMs;
      if (dateRaw is int) {
        dateMs = dateRaw;
      } else if (dateRaw is double) {
        dateMs = DateTime.fromMillisecondsSinceEpoch(dateRaw.toInt()).millisecondsSinceEpoch;
      } else if (dateRaw is String) {
        try {
          dateMs = DateTime.parse(dateRaw).millisecondsSinceEpoch;
        } catch (_) {
          dateMs = DateTime.now().millisecondsSinceEpoch;
        }
      } else {
        dateMs = DateTime.now().millisecondsSinceEpoch;
      }

      return TransactionModel.fromRTDB(canonical['id'] as String, {
        'title': canonical['merchant_name'],
        'amount': canonical['amount'],
        'categoryId': canonical['category'],
        'date_ms': dateMs,
        'notes': canonical['normalized_description'],
        'tags': [],
        'created_at_ms': DateTime.now().millisecondsSinceEpoch,
        'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  /// Ingest a canonical transaction (from bank provider) and persist.
  Future<TransactionModel> ingestFromProvider({
    required String userId,
    required Map<String, dynamic> canonical,
  }) async {
    final title = (canonical['merchant_name'] as String?) ?? 'Imported';
    final amount = ((canonical['amount'] as num?) ?? 0).toDouble();
    final date = DateTime.parse((canonical['date'] as String?) ?? DateTime.now().toIso8601String());
    return create(userId: userId, title: title, amount: amount, date: date, notes: canonical['normalized_description'] as String?);
  }

  Future<void> update(String userId, String id, Map<String, dynamic> data) async {
    data['updated_at_ms'] = ServerValue.timestamp;
    await _db.update('users/$userId/transactions/$id', data);
  }

  Future<void> delete(String id) async {
    // We need userId to resolve path; delete by looking up owner id
    // In RTDB we store under users/{uid}/transactions/{id}
    // For simplicity, callers should pass userId via map or manage path externally.
    // Here we do nothing without userId; use dedicated deleteForUser
  }

  Future<void> deleteForUser(String userId, String id) async {
    await _db.remove('users/$userId/transactions/$id');
  }

  Stream<List<TransactionModel>> streamForUser(String userId) {
    return _db.onValueMap('users/$userId/transactions').map((map) {
      if (map == null) return <TransactionModel>[];
      final items = <TransactionModel>[];
      map.forEach((key, value) {
        if (value is Map) {
          final data = value.cast<String, dynamic>();
          items.add(TransactionModel.fromRTDB(key, data));
        }
      });
      items.sort((a, b) => b.date.compareTo(a.date));
      return items;
    });
  }

  Future<List<TransactionModel>> getAllForUser(String userId) async {
    final snapshot = await _db.get('users/$userId/transactions');
    if (snapshot.value == null) return <TransactionModel>[];
    final map = snapshot.value as Map<dynamic, dynamic>;
    final items = <TransactionModel>[];
    map.forEach((key, value) {
      if (value is Map) {
        final data = value.cast<String, dynamic>();
        items.add(TransactionModel.fromRTDB(key.toString(), data));
      }
    });
    items.sort((a, b) => b.date.compareTo(a.date));
    return items;
  }

  void _validate({required String title, required double amount, required DateTime date}) {
    if (title.trim().isEmpty) {
      throw ArgumentError('Title is required');
    }
    if (amount.isNaN) {
      throw ArgumentError('Amount must be a number');
    }
    if (date.isAfter(DateTime.now().add(const Duration(days: 1)))) {
      throw ArgumentError('Date cannot be in the future');
    }
  }
}

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(realtimeDbServiceProvider), ref.watch(syncServiceProvider));
});

final userTransactionsProvider = StreamProvider<List<TransactionModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  // Stream.empty() never emits → StreamProvider stays loading forever.
  // Use Stream.value([]) so it immediately resolves to data([]) for guests.
  if (user == null) return Stream.value(<TransactionModel>[]);
  final repo = ref.watch(transactionRepositoryProvider);
  // Mirror recentTransactionsProvider: eager getAllForUser() snapshot first so
  // the list appears instantly, then keep the RTDB listener for live updates.
  // A 5-second timeout prevents an infinite skeleton on cold connections.
  final stream = Stream<List<TransactionModel>>.multi((controller) async {
    try {
      final initial = await repo.getAllForUser(user.uid);
      controller.add(initial);
    } catch (_) {}
    await for (final items in repo.streamForUser(user.uid)) {
      controller.add(items);
    }
  });
  return stream.timeout(const Duration(seconds: 5)).handleError((_, __) {});
});