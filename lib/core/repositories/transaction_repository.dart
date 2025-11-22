import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/transaction.dart';

class TransactionRepository {
  final FirestoreService _fs;
  static const String _collection = 'transactions';

  TransactionRepository(this._fs);

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
    final doc = await _fs.addDocument(_collection, {
      'userId': userId,
      'title': title.trim(),
      'amount': amount,
      'categoryId': categoryId,
      'date': Timestamp.fromDate(date),
      'notes': notes,
      'tags': tags,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final snapshot = await doc.get();
    return TransactionModel.fromFirestore(snapshot);
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _fs.updateDocument('$_collection/$id', data);
  }

  Future<void> delete(String id) async {
    await _fs.deleteDocument('$_collection/$id');
  }

  Stream<List<TransactionModel>> streamForUser(String userId) {
    return _fs.collection(_collection)
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => TransactionModel.fromFirestore(d)).toList());
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
  return TransactionRepository(ref.watch(firestoreServiceProvider));
});

final userTransactionsProvider = StreamProvider<List<TransactionModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(transactionRepositoryProvider).streamForUser(user.uid);
});