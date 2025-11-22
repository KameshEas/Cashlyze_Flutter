import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/realtime_db_service.dart';
import '../services/auth_service.dart';
import '../models/budget.dart';

class BudgetRepository {
  final RealtimeDbService _db;
  BudgetRepository(this._db);

  Future<BudgetModel> create({
    required String userId,
    required String name,
    required double allocated,
    required BudgetPeriod period,
    List<String> categoryIds = const [],
  }) async {
    final data = {
      'userId': userId,
      'name': name.trim(),
      'allocated': allocated,
      'period': period.name,
      'categoryIds': categoryIds,
      'created_at_ms': ServerValue.timestamp,
      'updated_at_ms': ServerValue.timestamp,
    };
    final ref = await _db.push('users/$userId/budgets', data);
    final snap = await ref.get();
    final map = (snap.value as Map).cast<String, dynamic>();
    return BudgetModel.fromRTDB(ref.key!, map);
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    data['updated_at_ms'] = ServerValue.timestamp;
    final userId = data['userId'] as String?;
    if (userId == null) throw ArgumentError('userId required for update');
    await _db.update('users/$userId/budgets/$id', data);
  }

  Future<void> delete(String userId, String id) async {
    await _db.remove('users/$userId/budgets/$id');
  }

  Stream<List<BudgetModel>> streamForUser(String userId) {
    final ref = _db.ref('users/$userId/budgets').orderByChild('created_at_ms');
    return ref.onValue.map((event) {
      final s = event.snapshot;
      if (!s.exists) return <BudgetModel>[];
      final items = s.children.map((c) {
        final data = (c.value as Map).cast<String, dynamic>();
        return BudgetModel.fromRTDB(c.key!, data);
      }).toList();
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    });
  }

  Future<void> addAdjustment({
    required String userId,
    required String id,
    required double newAllocated,
    String? note,
    required double oldAllocated,
  }) async {
    // Flattened adjustments under users/{uid}/budget_adjustments/{budgetId}/{adjustmentId}
    final path = 'users/$userId/budget_adjustments/$id';
    final ref = await _db.push(path, {
      'oldAllocated': oldAllocated,
      'newAllocated': newAllocated,
      'note': note,
      'created_at_ms': ServerValue.timestamp,
    });
    await _db.update('users/$userId/budgets/$id', {'allocated': newAllocated, 'updated_at_ms': ServerValue.timestamp});
  }
}

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(ref.watch(realtimeDbServiceProvider));
});

final userBudgetsProvider = StreamProvider<List<BudgetModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(budgetRepositoryProvider).streamForUser(user.uid);
});