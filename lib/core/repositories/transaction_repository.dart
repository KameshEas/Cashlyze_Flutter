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
    final ref = await _db.push('users/$userId/transactions', data);
    final snap = await ref.get();
    final map = (snap.value as Map).cast<String, dynamic>();
    return TransactionModel.fromRTDB(ref.key!, map);
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
    final ref = _db.ref('users/$userId/transactions').orderByChild('date_ms');
    return ref.onValue.map((event) {
      final snapshot = event.snapshot;
      if (!snapshot.exists) return <TransactionModel>[];
      final children = snapshot.children.toList();
      final items = children.map((c) {
        final data = (c.value as Map).cast<String, dynamic>();
        return TransactionModel.fromRTDB(c.key!, data);
      }).toList();
      items.sort((a, b) => b.date.compareTo(a.date));
      return items;
    });
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
  if (user == null) return const Stream.empty();
  return ref.watch(transactionRepositoryProvider).streamForUser(user.uid);
});