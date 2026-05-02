import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction.dart';
import '../services/auth_service.dart';
import '../../features/transactions/data/transaction_remote_data_source.dart';

class TransactionRepository {
  const TransactionRepository(this._dataSource);
  final TransactionRemoteDataSource _dataSource;

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
  }) =>
      _dataSource.create(
        title: title,
        amount: amount,
        date: date,
        categoryId: categoryId,
        categoryName: categoryName,
        isIncome: isIncome,
        notes: notes,
        tags: tags,
      );

  Future<void> update(String userId, String id, Map<String, dynamic> data) =>
      _dataSource
          .update(
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
          )
          .then((_) {});

  Future<void> deleteForUser(String userId, String id) =>
      _dataSource.delete(id);

  Future<List<TransactionModel>> getAllForUser(String userId) =>
      _dataSource.getAll();

  Stream<List<TransactionModel>> streamForUser(String userId) =>
      Stream<List<TransactionModel>>.multi((controller) async {
        try {
          controller.add(await _dataSource.getAll());
        } catch (_) {}

        final sub = Stream.periodic(const Duration(seconds: 5))
            .asyncMap((_) => _dataSource.getAll())
            .listen(
          controller.add,
          onError: (_, __) {},
        );

        controller.onCancel = () => sub.cancel();
      });
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