import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final data = {
      'userId': userId,
      'name': name.trim(),
      'allocated': allocated,
      'period': period.name,
      'categoryIds': categoryIds,
      'created_at_ms': nowMs,
      'updated_at_ms': nowMs,
    };
    final key = await _db.pushKey('users/$userId/budgets', data);
    return BudgetModel.fromRTDB(key, data);
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    data['updated_at_ms'] = DateTime.now().millisecondsSinceEpoch;
    final userId = data['userId'] as String?;
    if (userId == null) throw ArgumentError('userId required for update');
    await _db.update('users/$userId/budgets/$id', data);
  }

  Future<void> delete(String userId, String id) async {
    await _db.remove('users/$userId/budgets/$id');
  }

  Stream<List<BudgetModel>> streamForUser(String userId) {
    return _db.onValueMap('users/$userId/budgets').map((map) {
      if (map == null) return <BudgetModel>[];
      final items = <BudgetModel>[];
      map.forEach((key, value) {
        if (value is Map) {
          final data = value.cast<String, dynamic>();
          items.add(BudgetModel.fromRTDB(key, data));
        }
      });
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
    await _db.push(path, {
      'oldAllocated': oldAllocated,
      'newAllocated': newAllocated,
      'note': note,
      'created_at_ms': DateTime.now().millisecondsSinceEpoch,
    });
    await _db.update('users/$userId/budgets/$id', {
      'allocated': newAllocated,
      'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
    });
  }
}

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(ref.watch(realtimeDbServiceProvider));
});

final userBudgetsProvider = StreamProvider<List<BudgetModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(<BudgetModel>[]);
  final s = ref.watch(budgetRepositoryProvider).streamForUser(user.uid);
  return s
      .timeout(
        const Duration(seconds: 5),
        onTimeout: (sink) {
          sink.add(<BudgetModel>[]);
        },
      )
      .handleError((_, __) {});
});
