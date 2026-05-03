import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction.dart';
import '../services/auth_service.dart';
import '../../features/transactions/data/transaction_remote_data_source.dart';

class TransactionRepository {
  const TransactionRepository(this._dataSource);
  final TransactionRemoteDataSource _dataSource;

  static final Map<String, StreamController<List<TransactionModel>>> _controllers =
      <String, StreamController<List<TransactionModel>>>{};
  static final Map<String, List<TransactionModel>> _cache =
      <String, List<TransactionModel>>{};
  static final Map<String, Timer> _pollers = <String, Timer>{};

  StreamController<List<TransactionModel>> _controllerFor(String userId) {
    return _controllers.putIfAbsent(
      userId,
      () => StreamController<List<TransactionModel>>.broadcast(),
    );
  }

  List<TransactionModel> _sorted(List<TransactionModel> list) {
    final copy = [...list];
    copy.sort((a, b) => b.date.compareTo(a.date));
    return copy;
  }

  String _signature(List<TransactionModel> list) {
    return list
        .map(
          (t) =>
              '${t.id}|${t.title}|${t.amount}|${t.categoryId ?? ''}|${t.date.millisecondsSinceEpoch}|${t.notes ?? ''}|${(t.tags ?? const <String>[]).join(',')}',
        )
        .join(';');
  }

  Future<void> _refreshUser(String userId) async {
    try {
      final fresh = _sorted(await _dataSource.getAll());
      final prev = _cache[userId] ?? const <TransactionModel>[];
      if (_signature(prev) != _signature(fresh)) {
        _cache[userId] = fresh;
        _controllerFor(userId).add(fresh);
      }
    } catch (_) {}
  }

  void _startPolling(String userId) {
    if (_pollers.containsKey(userId)) return;
    _pollers[userId] = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshUser(userId),
    );
  }

  Future<TransactionModel> create({
    required String userId,
    required String title,
    required double amount,
    String? categoryId,
    String? categoryName,
    bool isIncome = false,
    required DateTime date,
    String? notes,
    List<String>? tags,
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
    current.removeWhere((t) => t.id == created.id);
    current.insert(0, created);
    final next = _sorted(current);
    _cache[userId] = next;
    _controllerFor(userId).add(next);
    return created;
  }

  Future<void> update(String userId, String id, Map<String, dynamic> data) async {
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
      final idx = current.indexWhere((t) => t.id == id);
      if (idx >= 0) {
        current[idx] = updated;
      } else {
        current.insert(0, updated);
      }
      final next = _sorted(current);
      _cache[userId] = next;
      _controllerFor(userId).add(next);
  }

  Future<void> deleteForUser(String userId, String id) async {
    await _dataSource.delete(id);
    final current = [...(_cache[userId] ?? const <TransactionModel>[])];
    current.removeWhere((t) => t.id == id);
    _cache[userId] = current;
    _controllerFor(userId).add(current);
  }

  Future<List<TransactionModel>> getAllForUser(String userId) =>
      _dataSource.getAll();

  Stream<List<TransactionModel>> streamForUser(String userId) =>
      Stream<List<TransactionModel>>.multi((controller) async {
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

  /// Apply a remote websocket transaction event to the local cache.
  void applyRemoteTransactionEvent(String userId, String type, Map<String, dynamic> payload) {
    try {
      if (type == 'transaction_deleted' || type == 'transaction.deleted') {
        final id = payload['transaction_id'] as String? ?? payload['id'] as String?;
        if (id != null) {
          final current = [...(_cache[userId] ?? const <TransactionModel>[])];
          current.removeWhere((t) => t.id == id);
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
        final idx = current.indexWhere((t) => t.id == id);
        if (idx >= 0) {
          current[idx] = created;
        } else {
          current.insert(0, created);
        }
        final next = _sorted(current);
        _cache[userId] = next;
        _controllerFor(userId).add(next);
      }
    } catch (_) {}
  }
}

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(transactionRemoteDataSourceProvider));
});

final userTransactionsProvider = StreamProvider<List<TransactionModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(<TransactionModel>[]);
  return ref
      .watch(transactionRepositoryProvider)
      .streamForUser(user.userId)
      .handleError((_, __) {});
});