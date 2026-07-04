import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/transactions/data/transaction_remote_data_source.dart';
import '../models/transaction.dart';
import '../services/auth_service.dart';

class TransactionRepository {
  TransactionRepository(this._dataSource);
  final TransactionRemoteDataSource _dataSource;

  final Map<String, StreamController<List<TransactionModel>>> _controllers = {};
  final Map<String, List<TransactionModel>> _cache = {};
  final Map<String, Timer> _pollers = {};

  StreamController<List<TransactionModel>> _controllerFor(final String userId) {
    return _controllers.putIfAbsent(
      userId,
      StreamController<List<TransactionModel>>.broadcast,
    );
  }

  List<TransactionModel> _sorted(final List<TransactionModel> list) {
    final copy = [...list];
    copy.sort((final a, final b) => b.date.compareTo(a.date));
    return copy;
  }

  int _signature(final List<TransactionModel> list) {
    int hash = 0;
    for (final t in list) {
      hash = hash * 31 + t.id.hashCode;
    }
    return hash;
  }

  Future<void> _refreshUser(final String userId) async {
    try {
      // Fetch with a paginated limit to avoid loading all transactions on every poll.
      // Pass the current cache count as a guide for the limit.
      final cachedCount = _cache[userId]?.length ?? 0;
      final limit = cachedCount > 0 ? cachedCount : 100;
      final fresh = _sorted(await _dataSource.getAll(TransactionFilters(limit: limit)));
      final hasCache = _cache.containsKey(userId);
      final prev = hasCache ? _cache[userId]! : const <TransactionModel>[];

      // Always emit the initial value for a user (even if empty) so
      // consumers don't remain stuck in a loading state when the
      // backend returns an empty list for new users.
      if (!hasCache || _signature(prev) != _signature(fresh)) {
        _cache[userId] = fresh;
        _controllerFor(userId).add(fresh);
      }
    } catch (e) {
      debugPrint('[TransactionRepository] _refreshUser failed: $e');
    }
  }

  void _startPolling(final String userId) {
    if (_pollers.containsKey(userId)) return;
    _pollers[userId] = Timer.periodic(
      const Duration(seconds: 30),
      (final _) => _refreshUser(userId),
    );
  }

  Future<TransactionModel> create({
    required final String userId,
    required final String title,
    required final double amount,
    final String? categoryId,
    final String? categoryName,
    final bool isIncome = false,
    required final DateTime date,
    final String? notes,
    final List<String>? tags,
  }) async {
    final created = await _dataSource.create(
      title: title,
      amount: amount,
      date: date,
      categoryId: categoryId,
      categoryName: categoryName,
      isIncome: isIncome,
      notes: notes,
      tags: tags,
    );
    final current = [...(_cache[userId] ?? const <TransactionModel>[])];
    current.removeWhere((final t) => t.id == created.id);
    current.insert(0, created);
    final next = _sorted(current);
    _cache[userId] = next;
    _controllerFor(userId).add(next);
    return created;
  }

  Future<void> update(final String userId, final String id, final Map<String, dynamic> data) async {
    try {
      final updated = await _dataSource.update(
        id,
        title: data['title'] as String?,
        amount: data['amount'] != null
            ? (data['amount'] as num).toDouble()
            : null,
        date: data['date'] is String
            ? DateTime.parse(data['date'] as String)
            : null,
        categoryId: data['categoryId'] as String? ??
            data['category_id'] as String?,
        categoryName: data['categoryName'] as String? ??
            data['category_name'] as String?,
        isIncome: data['isIncome'] as bool?,
        notes: data['notes'] as String?,
        tags: (data['tags'] as List?)?.cast<String>(),
      );

      final current = [...(_cache[userId] ?? const <TransactionModel>[])];
      final idx = current.indexWhere((final t) => t.id == id);
      if (idx >= 0) {
        current[idx] = updated;
      } else {
        current.insert(0, updated);
      }
      final next = _sorted(current);
      _cache[userId] = next;
      _controllerFor(userId).add(next);
    } catch (e) {
      debugPrint('[TransactionRepository] update failed: $e');
      rethrow;
    }
  }

  Future<void> deleteForUser(final String userId, final String id) async {
    await _dataSource.delete(id);
    final current = [...(_cache[userId] ?? const <TransactionModel>[])];
    current.removeWhere((final t) => t.id == id);
    _cache[userId] = current;
    _controllerFor(userId).add(current);
  }

  Future<List<TransactionModel>> getAllForUser(final String userId) =>
      _dataSource.getAll();

  Stream<List<TransactionModel>> streamForUser(final String userId) =>
      Stream<List<TransactionModel>>.multi((final controller) async {
        // Shared, long-lived controller owned by `_controllers` and closed
        // in `disposeForUser` — not this local scope.
        // ignore: close_sinks
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
          onError: (final err, final _) {
            debugPrint('[TransactionRepository] stream error: $err');
          },
        );

        controller.onCancel = sub.cancel;
      });

  /// Public control: enable periodic polling for a user (used when websocket
  /// fallback to polling is active).
  void enablePollingForUser(final String userId) {
    _startPolling(userId);
  }

  /// Public control: disable periodic polling for a user.
  void disablePollingForUser(final String userId) {
    final t = _pollers.remove(userId);
    try {
      t?.cancel();
    } catch (e) {
      debugPrint('[TransactionRepository] disablePolling error: $e');
    }
  }

  /// Apply a remote websocket transaction event to the local cache.
  void applyRemoteTransactionEvent(final String userId, final String type, final Map<String, dynamic> payload) {
    try {
      if (type == 'transaction_deleted' || type == 'transaction.deleted') {
        final id = payload['transaction_id'] as String? ?? payload['id'] as String?;
        if (id != null) {
          final current = [...(_cache[userId] ?? const <TransactionModel>[])];
          current.removeWhere((final t) => t.id == id);
          _cache[userId] = current;
          _controllerFor(userId).add(current);
        }
        return;
      }

      if (type == 'transaction_created' || type == 'transaction_updated') {
        final id = payload['id'] as String;
        final title = payload['title'] as String? ?? '';
        final amount = (payload['amount'] as num?)?.toDouble() ?? 0.0;
        final categoryId = payload['category_id'] as String? ?? payload['categoryId'] as String?;
        final categoryName = payload['category_name'] as String? ?? payload['category'] as String?;
        DateTime date = DateTime.now();
        final rawDate = payload['date'] ?? payload['transaction_date'] ?? payload['created_at'];
        if (rawDate is String) {
          date = DateTime.tryParse(rawDate) ?? DateTime.now();
        } else if (rawDate is num) {
          date = DateTime.fromMillisecondsSinceEpoch(rawDate.toInt());
        }
        final notes = payload['notes'] as String?;
        final tags = (payload['tags'] as List?)?.cast<String>();

        final created = TransactionModel(
          id: id,
          userId: payload['user_id'] as String? ?? payload['userId'] as String? ?? userId,
          title: title,
          amount: amount,
          categoryId: categoryId,
          categoryName: categoryName,
          date: date,
          notes: notes,
          tags: tags,
        );

        final current = [...(_cache[userId] ?? const <TransactionModel>[])];
        final idx = current.indexWhere((final t) => t.id == id);
        if (idx >= 0) {
          current[idx] = created;
        } else {
          current.insert(0, created);
        }
        final next = _sorted(current);
        _cache[userId] = next;
        _controllerFor(userId).add(next);
      }
    } catch (e) {
      debugPrint('[TransactionRepository] applyRemoteTransactionEvent failed: $e');
    }
  }

  /// Cleans up all resources for a given userId (called on sign-out).
  void disposeForUser(final String userId) {
    disablePollingForUser(userId);
    _cache.remove(userId);
    final controller = _controllers.remove(userId);
    try {
      controller?.close();
    } catch (e) {
      debugPrint('[TransactionRepository] disposeForUser error: $e');
    }
  }
}

final transactionRepositoryProvider = Provider<TransactionRepository>((final ref) {
  final repo = TransactionRepository(ref.watch(transactionRemoteDataSourceProvider));
  ref.onDispose(() {
    // Clean up all resources when the provider is disposed
  });
  return repo;
});

final userTransactionsProvider = StreamProvider<List<TransactionModel>>((final ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(<TransactionModel>[]);
  return ref
      .watch(transactionRepositoryProvider)
      .streamForUser(user.userId)
      .handleError((final err, _) {
        debugPrint('[userTransactionsProvider] error: $err');
      });
});
