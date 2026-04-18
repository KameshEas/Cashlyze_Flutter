import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/realtime_db_service.dart';
import '../services/auth_service.dart';
import '../models/budget.dart';
import 'category_repository.dart';

class BudgetRepository {
  final RealtimeDbService _db;
  BudgetRepository(this._db);

  Future<List<String>> _resolveOrCreateCategoryIds(String userId, List<String>? rawCategoryKeys) async {
    if (rawCategoryKeys == null || rawCategoryKeys.isEmpty) return const [];
    final catRepo = CategoryRepository(_db);
    final existing = await catRepo.getAllForUser(userId);
    final Map<String, String> nameToId = {};
    final Set<String> idSet = {};
    for (final c in existing) {
      final n = (c.name ?? '').trim();
      if (n.isNotEmpty) nameToId[n.toLowerCase()] = c.id;
      idSet.add(c.id);
    }

    final List<String> resolved = [];
    for (final raw in rawCategoryKeys) {
      final key = raw.trim();
      if (key.isEmpty) continue;
      // Skip pseudo or generic budgets
      if (key == '__general_budget' || key.toLowerCase() == 'general') continue;

      // If it looks like an id already, keep it
      if (idSet.contains(key)) {
        resolved.add(key);
        continue;
      }

      // If a category with that name exists, use its id
      final lower = key.toLowerCase();
      if (nameToId.containsKey(lower)) {
        resolved.add(nameToId[lower]!);
        continue;
      }

      // Otherwise, create a new category (best-effort)
      try {
        final created = await catRepo.create(userId: userId, name: key);
        resolved.add(created.id);
      } catch (_) {
        // If creation fails, fallback to storing the original string
        resolved.add(key);
      }
    }

    // Deduplicate while preserving order
    final seen = <String>{};
    final dedup = <String>[];
    for (final r in resolved) {
      if (r.isEmpty) continue;
      if (seen.add(r)) dedup.add(r);
    }
    return dedup;
  }

  Future<BudgetModel> create({
    required String userId,
    required String name,
    required double allocated,
    required BudgetPeriod period,
    List<String> categoryIds = const [],
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // Resolve category ids (create categories if necessary)
    final resolvedCategoryIds = await _resolveOrCreateCategoryIds(userId, categoryIds);

    final data = {
      'userId': userId,
      'name': name.trim(),
      'allocated': allocated,
      'period': period.name,
      'categoryIds': resolvedCategoryIds,
      'created_at_ms': nowMs,
      'updated_at_ms': nowMs,
    };
    final key = await _db.pushKey('users/$userId/budgets', data);
    return BudgetModel.fromRTDB(key, data);
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final userId = data['userId'] as String?;
    if (userId == null) throw ArgumentError('userId required for update');

    // If caller supplied categoryIds, resolve them (create categories when needed)
    if (data.containsKey('categoryIds')) {
      final raw = data['categoryIds'] as List?;
      if (raw != null) {
        try {
          final resolved = await _resolveOrCreateCategoryIds(userId, raw.cast<String>());
          data['categoryIds'] = resolved;
        } catch (_) {
          // Best-effort: leave provided values unchanged on failure
        }
      }
    }

    final newName = (data['name'] as String?)?.trim();

    // If the budget name is changing, update any transactions that stored
    // the old budget name as their `categoryId` so they reflect the new
    // budget name. This keeps legacy transactions that stored display
    // names in sync when a budget is renamed.
    try {
      final snap = await _db.get('users/$userId/budgets/$id');
      String? oldName;
      if (snap.value is Map) {
        final map = (snap.value as Map).cast<String, dynamic>();
        oldName = (map['name'] as String?)?.trim();
      }

      if (newName != null && oldName != null && newName != oldName) {
        final txSnap = await _db.get('users/$userId/transactions');
        if (txSnap.value is Map) {
          final txMap = (txSnap.value as Map).cast<dynamic, dynamic>();
          final patch = <String, dynamic>{};
          txMap.forEach((key, value) {
            if (value is Map) {
              final dataMap = value.cast<String, dynamic>();
              final cat = (dataMap['categoryId'] as String?)?.trim();
              if (cat == oldName) {
                patch['users/$userId/transactions/$key/categoryId'] = newName;
              }
            }
          });
          if (patch.isNotEmpty) {
            await _db.updateMulti(patch);
          }
        }
      }
    } catch (_) {
      // Best-effort migration: ignore failures and continue updating budget.
    }

    data['updated_at_ms'] = nowMs;
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
  return s.map((list) {
    // Always provide a default constant "General" budget in the UI so
    // users have a catch-all budget option. Do not override a real
    // user-created "General" budget if one exists.
    final hasGeneral = list.any((b) => (b.name ?? '').trim().toLowerCase() == 'general');
    if (hasGeneral) return list;

    final general = BudgetModel(
      id: '__general_budget',
      userId: user.uid,
      name: 'General',
      allocated: double.infinity,
      period: BudgetPeriod.monthly,
      categoryIds: const [],
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: null,
    );
    return [general, ...list];
  });
});
