import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/categories/data/category_remote_data_source.dart';
import '../models/category.dart';
import '../services/auth_service.dart';

class CategoryRepository {
  const CategoryRepository(this._dataSource);
  final CategoryRemoteDataSource _dataSource;

  Future<CategoryModel> create({
    required String userId,
    required String name,
    String? icon,
    int? color,
  }) =>
      _dataSource.create(name: name, icon: icon, color: color);

  Future<void> update(
    String userId,
    String id,
    Map<String, dynamic> data,
  ) async {
    await _dataSource.update(
      id,
      name: data['name'] as String?,
      icon: data['icon'] as String?,
      color: data['color'] as int?,
    );
  }

  Future<void> delete(String userId, String id) =>
      _dataSource.delete(id);

  Future<List<CategoryModel>> getAllForUser(String userId) =>
      _dataSource.getAll();

  Stream<List<CategoryModel>> streamForUser(String userId) =>
      Stream.fromFuture(_dataSource.getAll());
}

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(categoryRemoteDataSourceProvider));
});

final userCategoriesProvider = StreamProvider<List<CategoryModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(<CategoryModel>[]);
  return ref
      .watch(categoryRepositoryProvider)
      .streamForUser(user.userId)
      .handleError((_, __) {});
});
