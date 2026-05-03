import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/budget.dart';
import '../services/auth_service.dart';
import '../../features/budgets/data/budget_remote_data_source.dart';
import 'category_repository.dart';

class BudgetRepository {
  const BudgetRepository(this._dataSource, this._categoryRepo);
  final BudgetRemoteDataSource _dataSource;
  final CategoryRepository _categoryRepo;

  static final Map<String, StreamController<List<BudgetModel>>> _controllers =
      <String, StreamController<List<BudgetModel>>>{};
  static final Map<String, List<BudgetModel>> _cache =
      <String, List<BudgetModel>>{};
  static final Map<String, Timer> _pollers = <String, Timer>{};

  StreamController<List<BudgetModel>> _controllerFor(String userId) {
    return _controllers.putIfAbsent(
      userId,
      () => StreamController<List<BudgetModel>>.broadcast(),
    );
  }

  List<BudgetModel> _sorted(List<BudgetModel> list) {
    final copy = [...list];
    copy.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return copy;
  }

  String _signature(List<BudgetModel> list) {
    return list
        .map(
          (b) =>
              '${b.id}|${b.name}|${b.allocated}|${b.period.name}|${b.updatedAt?.millisecondsSinceEpoch ?? 0}|${b.categoryIds.join(',')}',
        )
        .join(';');
  }

  Future<void> _refreshUser(String userId) async {
    try {
      final fresh = _sorted(await _dataSource.getAll());
      if (!_cache.containsKey(userId)) {
        _cache[userId] = fresh;
        _controllerFor(userId).add(fresh);
        return;
      }

      final prev = _cache[userId]!;
      if (_signature(prev) != _signature(fresh)) {
        _cache[userId] = fresh;
        _controllerFor(userId).add(fresh);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Budget refresh failed: $e');
    }
  }


  void _startPolling(String userId) {
    if (_pollers.containsKey(userId)) return;
    _pollers[userId] = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshUser(userId),
    );
  }

  Future<BudgetModel> create({
    required String userId,
    required String name,
    required double allocated,
    required BudgetPeriod period,
    List<String> categoryIds = const [],
  }) async {
    final created = await _dataSource.create(
      name: name,
      allocated: allocated,
      period: period,
      categoryIds: categoryIds,
    );
    final current = [...(_cache[userId] ?? const <BudgetModel>[])];
    current.removeWhere((b) => b.id == created.id);
    current.insert(0, created);
    final next = _sorted(current);
    _cache[userId] = next;
    _controllerFor(userId).add(next);
    return created;
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    // Determine userId early so we can look up local cache and categories
    final userId = (data['userId'] as String?) ?? '';

    // Capture previous budget (if cached) to detect name->category rename case.
    // Search across caches since the provided data may not include userId.
    BudgetModel? previousBudget;
    String? previousUserId;
    for (final entry in _cache.entries) {
      final idx = entry.value.indexWhere((b) => b.id == id);
      if (idx >= 0) {
        previousBudget = entry.value[idx];
        previousUserId = entry.key;
        break;
      }
    }

    final updated = await _dataSource.update(
      id,
      name: data['name'] as String?,
      allocated: data['allocated'] != null
          ? (data['allocated'] as num).toDouble()
          : null,
      period: data['period'] != null
          ? BudgetPeriod.values.firstWhere(
              (p) => p.name == data['period'],
              orElse: () => BudgetPeriod.monthly,
            )
          : null,
      categoryIds: (data['categoryIds'] as List?)?.cast<String>(),
    );
    final resolvedUserId = userId.isNotEmpty ? userId : updated.userId;
    final current = [...(_cache[resolvedUserId] ?? const <BudgetModel>[])];
    final idx = current.indexWhere((b) => b.id == id);
    if (idx >= 0) {
      current[idx] = updated;
    } else {
      current.insert(0, updated);
    }
    final next = _sorted(current);
    _cache[resolvedUserId] = next;
    _controllerFor(resolvedUserId).add(next);

    // If the budget previously claimed categories by its name (no explicit
    // categoryIds) and the name changed, attempt to rename the matching
    // Category (if one exists) so the change is reflected across the UI.
    try {
      if (previousBudget != null && (previousBudget.categoryIds.isEmpty) && data['name'] != null) {
        final oldName = previousBudget.name.trim();
        final newName = (data['name'] as String).trim();
        if (oldName.isNotEmpty && newName.isNotEmpty && oldName.toLowerCase() != newName.toLowerCase()) {
          // Look up categories for the user and find a case-insensitive match
          final lookupUserId = previousUserId ?? resolvedUserId;
          final cats = await _categoryRepo.getAllForUser(lookupUserId);
          final matches = cats.where((c) => (c.name ?? '').trim().toLowerCase() == oldName.toLowerCase()).toList();
          if (matches.isNotEmpty) {
            final match = matches.first;
            await _categoryRepo.update(resolvedUserId, match.id, {'name': newName});
          }
        }
      }
    } catch (_) {}
  }

  Future<void> delete(String userId, String id) async {
    await _dataSource.delete(id);
    final current = [...(_cache[userId] ?? const <BudgetModel>[])];
    current.removeWhere((b) => b.id == id);
    _cache[userId] = current;
    _controllerFor(userId).add(current);
  }

  Stream<List<BudgetModel>> streamForUser(String userId) =>
      Stream<List<BudgetModel>>.multi((controller) async {
        final shared = _controllerFor(userId);
        final cached = _cache[userId];
        if (cached != null) {
          controller.add(cached);
        }

        unawaited(_refreshUser(userId));
        // Polling is controlled externally (prefer websocket-based updates).
        // Start polling only if explicitly requested via `enablePollingForUser`.

        final sub = shared.stream.listen(
          controller.add,
          onError: (_, __) {},
        );

        controller.onCancel = () => sub.cancel();
      });

  /// Public control: enable periodic polling for a user (used when websocket
  /// fallback to polling is active).
  void enablePollingForUser(String userId) {
    _startPolling(userId);
  }

  /// Public control: disable periodic polling for a user.
  void disablePollingForUser(String userId) {
    final t = _pollers.remove(userId);
    try {
      t?.cancel();
    } catch (_) {}
  }

  /// Apply a remote websocket budget event to the local cache.
  void applyRemoteBudgetEvent(String userId, String type, Map<String, dynamic> payload) {
    try {
      if (type == 'budget_deleted' || type == 'budget.deleted') {
        final id = payload['budget_id'] as String? ?? payload['id'] as String?;
        if (id != null) {
          final current = [...(_cache[userId] ?? const <BudgetModel>[])];
          current.removeWhere((b) => b.id == id);
          _cache[userId] = current;
          _controllerFor(userId).add(current);
        }
        return;
      }

      if (type == 'budget_created' || type == 'budget_updated' || type == 'budget_utilization_changed') {
        // Some backend events may include deletion markers in the payload
        // even when using update/create event types. Respect deletion
        // indicators and remove the budget from cache if present.
        final id = payload['id'] as String? ?? payload['budget_id'] as String?;
        if (id == null) return;

        final checkDeleted = (Map<String, dynamic> p) {
          if (p.containsKey('deleted')) {
            final v = p['deleted'];
            if (v == true || v == 1 || v == '1') return true;
          }
          if (p.containsKey('deleted_at')) {
            if (p['deleted_at'] != null) return true;
          }
          if (p.containsKey('deletedAt')) {
            if (p['deletedAt'] != null) return true;
          }
          if (p.containsKey('is_deleted')) {
            final v = p['is_deleted'];
            if (v == true || v == 1 || v == '1') return true;
          }
          if (p.containsKey('isDeleted')) {
            final v = p['isDeleted'];
            if (v == true || v == 1 || v == '1') return true;
          }
          return false;
        };

        if (checkDeleted(payload)) {
          final current = [...(_cache[userId] ?? const <BudgetModel>[])];
          current.removeWhere((b) => b.id == id);
          _cache[userId] = current;
          _controllerFor(userId).add(current);
          return;
        }

        final name = payload['name'] as String? ?? payload['title'] as String? ?? '';
        final num? allocatedFromPayload = (payload['allocated'] as num?) ?? (payload['amount'] as num?);
        double allocated;
        final cachedList = _cache[userId];
        if (allocatedFromPayload != null) {
          allocated = allocatedFromPayload.toDouble();
        } else if (cachedList != null) {
          final prev = cachedList.where((b) => b.id == id).toList();
          if (prev.isNotEmpty) {
            allocated = prev.first.allocated;
          } else {
            allocated = 0.0;
          }
        } else {
          allocated = 0.0;
        }
        final periodRaw = payload['period'] as String? ?? 'monthly';
        final period = BudgetPeriod.values.firstWhere(
          (p) => p.name == periodRaw.toLowerCase() || p.name == periodRaw,
          orElse: () => BudgetPeriod.monthly,
        );
        final rawCategoryIds = (payload['category_ids'] as List?) ?? (payload['categoryIds'] as List?);
        List<String> categoryIds;
        if (rawCategoryIds != null) {
          categoryIds = rawCategoryIds.cast<String>();
        } else if (cachedList != null) {
          final prev = cachedList.where((b) => b.id == id).toList();
          if (prev.isNotEmpty) {
            categoryIds = prev.first.categoryIds;
          } else {
            categoryIds = const [];
          }
        } else {
          categoryIds = const [];
        }

        DateTime createdAt = DateTime.fromMillisecondsSinceEpoch(0);
        final rawCreated = payload['created_at'] ?? payload['createdAt'];
        if (rawCreated is String) {
          createdAt = DateTime.tryParse(rawCreated) ??
              (int.tryParse(rawCreated) != null
                  ? DateTime.fromMillisecondsSinceEpoch(int.parse(rawCreated))
                  : createdAt);
        } else if (rawCreated is num) {
          final ms = rawCreated.toInt();
          final maybeMs = ms < 10000000000 ? ms * 1000 : ms;
          createdAt = DateTime.fromMillisecondsSinceEpoch(maybeMs);
        }

        DateTime? updatedAt;
        final rawUpdated = payload['updated_at'] ?? payload['updatedAt'];
        if (rawUpdated is String) {
          updatedAt = DateTime.tryParse(rawUpdated);
        } else if (rawUpdated is num) {
          final ms = rawUpdated.toInt();
          final maybeMs = ms < 10000000000 ? ms * 1000 : ms;
          updatedAt = DateTime.fromMillisecondsSinceEpoch(maybeMs);
        }

        final model = BudgetModel(
          id: id,
          userId: payload['user_id'] as String? ?? payload['userId'] as String? ?? userId,
          name: name,
          allocated: allocated,
          period: period,
          categoryIds: categoryIds,
          createdAt: createdAt,
          updatedAt: updatedAt,
        );

        final current = [...(_cache[userId] ?? const <BudgetModel>[])];
        final idx = current.indexWhere((b) => b.id == id);
        if (idx >= 0) {
          current[idx] = model;
        } else {
          current.insert(0, model);
        }
        final next = _sorted(current);
        _cache[userId] = next;
        _controllerFor(userId).add(next);
      }
    } catch (_) {}
  }

  Future<void> addAdjustment({
    required String userId,
    required String id,
    required double newAllocated,
    String? note,
    required double oldAllocated,
  }) async {
    final updated = await _dataSource.update(id, allocated: newAllocated);
    final current = [...(_cache[userId] ?? const <BudgetModel>[])];
    final idx = current.indexWhere((b) => b.id == id);
    if (idx >= 0) {
      current[idx] = updated;
    } else {
      current.insert(0, updated);
    }
    final next = _sorted(current);
    _cache[userId] = next;
    _controllerFor(userId).add(next);
  }

  Future<void> undoAdjustment({
    required String userId,
    required String id,
    required double previousAllocated,
  }) async {
    final updated = await _dataSource.update(id, allocated: previousAllocated);
    final current = [...(_cache[userId] ?? const <BudgetModel>[])];
    final idx = current.indexWhere((b) => b.id == id);
    if (idx >= 0) {
      current[idx] = updated;
    } else {
      current.insert(0, updated);
    }
    final next = _sorted(current);
    _cache[userId] = next;
    _controllerFor(userId).add(next);
  }
}

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(
    ref.watch(budgetRemoteDataSourceProvider),
    ref.watch(categoryRepositoryProvider),
  );
});

final userBudgetsProvider = StreamProvider<List<BudgetModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(<BudgetModel>[]);
  return ref
      .watch(budgetRepositoryProvider)
      .streamForUser(user.userId)
      .map((list) {
    final hasGeneral =
      list.any((b) => b.name.trim().toLowerCase() == 'general');
    if (hasGeneral) return list;

    final general = BudgetModel(
      id: '__general_budget',
      userId: user.userId,
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
