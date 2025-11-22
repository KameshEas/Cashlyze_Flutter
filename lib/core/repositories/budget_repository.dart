import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/budget.dart';

class BudgetRepository {
  final FirestoreService _fs;
  static const String _collection = 'budgets';

  BudgetRepository(this._fs);

  Future<BudgetModel> create({
    required String userId,
    required String name,
    required double allocated,
    required BudgetPeriod period,
    List<String> categoryIds = const [],
  }) async {
    final doc = await _fs.addDocument(_collection, {
      'userId': userId,
      'name': name.trim(),
      'allocated': allocated,
      'period': period.name,
      'categoryIds': categoryIds,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final snapshot = await doc.get();
    return BudgetModel.fromFirestore(snapshot);
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _fs.updateDocument('$_collection/$id', data);
  }

  Future<void> delete(String id) async {
    await _fs.deleteDocument('$_collection/$id');
  }

  Stream<List<BudgetModel>> streamForUser(String userId) {
    return _fs.collection(_collection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => BudgetModel.fromFirestore(d)).toList());
  }

  Future<void> addAdjustment({
    required String id,
    required double newAllocated,
    String? note,
    required double oldAllocated,
  }) async {
    await _fs.addDocument('$_collection/$id/adjustments', {
      'oldAllocated': oldAllocated,
      'newAllocated': newAllocated,
      'note': note,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await update(id, {'allocated': newAllocated});
  }
}

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(ref.watch(firestoreServiceProvider));
});

final userBudgetsProvider = StreamProvider<List<BudgetModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(budgetRepositoryProvider).streamForUser(user.uid);
});