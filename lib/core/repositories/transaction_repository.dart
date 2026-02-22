import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/realtime_db_service.dart';
import '../services/auth_service.dart';
import '../models/transaction.dart';

class TransactionRepository {
  final RealtimeDbService _db;
  TransactionRepository(this._db);

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
    final key = await _db.pushKey('users/$userId/transactions', data);
    return TransactionModel.fromRTDB(key, data);
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
  return TransactionRepository(ref.watch(realtimeDbServiceProvider));
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