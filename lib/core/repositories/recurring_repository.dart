import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/recurring.dart';
import '../services/auth_service.dart';
import '../../features/transactions/data/recurring_remote_data_source.dart';

class RecurringRepository {
  const RecurringRepository(this._dataSource);
  final RecurringRemoteDataSource _dataSource;

  Future<RecurringRule> createRule({
    required String userId,
    required String title,
    required double amount,
    required bool isIncome,
    String? categoryId,
    required DateTime startDate,
    required RecurringFrequency frequency,
  }) =>
      _dataSource.create(
        title: title,
        amount: amount,
        isIncome: isIncome,
        categoryId: categoryId,
        startDate: startDate,
        frequency: frequency,
      );

  Future<void> updateLastPosted(String userId, String id, DateTime last) =>
      _dataSource.update(id, startDate: last).then((_) {});

  Future<List<RecurringRule>> getAllForUser(String userId) =>
      _dataSource.getAll();

  Stream<List<RecurringRule>> streamForUser(String userId) =>
      Stream.fromFuture(_dataSource.getAll());
}

final recurringRepositoryProvider = Provider<RecurringRepository>((ref) {
  return RecurringRepository(ref.watch(recurringRemoteDataSourceProvider));
});

final userRecurringRulesProvider = StreamProvider<List<RecurringRule>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref
      .watch(recurringRepositoryProvider)
      .streamForUser(user.userId)
      .handleError((_, __) {});
});
