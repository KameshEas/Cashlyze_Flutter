import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/transactions/data/recurring_remote_data_source.dart';
import '../models/recurring.dart';
import '../services/auth_service.dart';

class RecurringRepository {
  const RecurringRepository(this._dataSource);
  final RecurringRemoteDataSource _dataSource;

  Future<RecurringRule> createRule({
    required final String userId,
    required final String title,
    required final double amount,
    required final bool isIncome,
    final String? categoryId,
    required final DateTime startDate,
    required final RecurringFrequency frequency,
  }) =>
      _dataSource.create(
        title: title,
        amount: amount,
        isIncome: isIncome,
        categoryId: categoryId,
        startDate: startDate,
        frequency: frequency,
      );

  Future<void> updateLastPosted(final String userId, final String id, final DateTime last) =>
      _dataSource.update(id, startDate: last).then((final _) {});

  Future<List<RecurringRule>> getAllForUser(final String userId) =>
      _dataSource.getAll();

  Stream<List<RecurringRule>> streamForUser(final String userId) =>
      Stream.fromFuture(_dataSource.getAll());
}

final recurringRepositoryProvider = Provider<RecurringRepository>((final ref) {
  return RecurringRepository(ref.watch(recurringRemoteDataSourceProvider));
});

final userRecurringRulesProvider = StreamProvider<List<RecurringRule>>((final ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref
      .watch(recurringRepositoryProvider)
      .streamForUser(user.userId)
      .handleError((_, _) {});
});
