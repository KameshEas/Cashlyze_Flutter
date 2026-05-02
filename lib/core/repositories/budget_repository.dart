import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/budget.dart';
import '../services/auth_service.dart';
import '../../features/budgets/data/budget_remote_data_source.dart';

class BudgetRepository {
  const BudgetRepository(this._dataSource);
  final BudgetRemoteDataSource _dataSource;

  Future<BudgetModel> create({
    required String userId,
    required String name,
    required double allocated,
    required BudgetPeriod period,
    List<String> categoryIds = const [],
  }) =>
      _dataSource.create(
        name: name,
        allocated: allocated,
        period: period,
        categoryIds: categoryIds,
      );

  Future<void> update(String id, Map<String, dynamic> data) async {
    await _dataSource.update(
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
  }

  Future<void> delete(String userId, String id) =>
      _dataSource.delete(id);

  Stream<List<BudgetModel>> streamForUser(String userId) =>
      Stream<List<BudgetModel>>.multi((controller) async {
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

  Future<void> addAdjustment({
    required String userId,
    required String id,
    required double newAllocated,
    String? note,
    required double oldAllocated,
  }) =>
      _dataSource.update(id, allocated: newAllocated).then((_) {});

  Future<void> undoAdjustment({
    required String userId,
    required String id,
    required double previousAllocated,
  }) =>
      _dataSource.update(id, allocated: previousAllocated).then((_) {});
}

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(ref.watch(budgetRemoteDataSourceProvider));
});

final userBudgetsProvider = StreamProvider<List<BudgetModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(<BudgetModel>[]);
  return ref
      .watch(budgetRepositoryProvider)
      .streamForUser(user.userId)
      .map((list) {
    final hasGeneral =
        list.any((b) => (b.name ?? '').trim().toLowerCase() == 'general');
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
