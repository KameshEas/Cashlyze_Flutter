import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/realtime_db_service.dart';
import '../services/auth_service.dart';
import '../models/category.dart';

class CategoryRepository {
  final RealtimeDbService _db;
  CategoryRepository(this._db);

  Future<CategoryModel> create({
    required String userId,
    required String name,
    String? icon,
    int? color,
  }) async {
    final data = {
      'userId': userId,
      'name': name.trim(),
      'icon': icon,
      'color': color,
    };
    final key = await _db.pushKey('users/$userId/categories', data);
    return CategoryModel.fromRTDB(key, data);
  }

  Future<void> update(String userId, String id, Map<String, dynamic> data) async {
    await _db.update('users/$userId/categories/$id', data);
  }

  Future<void> delete(String userId, String id) async {
    await _db.remove('users/$userId/categories/$id');
  }

  Stream<List<CategoryModel>> streamForUser(String userId) {
    return _db.onValueMap('users/$userId/categories').map((map) {
      if (map == null) return <CategoryModel>[];
      final items = <CategoryModel>[];
      map.forEach((key, value) {
        if (value is Map) {
          final data = value.cast<String, dynamic>();
          items.add(CategoryModel.fromRTDB(key, data));
        }
      });
      items.sort((a, b) => a.name.compareTo(b.name));
      return items;
    });
  }

  Future<List<CategoryModel>> getAllForUser(String userId) async {
    final snapshot = await _db.get('users/$userId/categories');
    if (snapshot.value == null) return <CategoryModel>[];
    final map = snapshot.value as Map<dynamic, dynamic>;
    final items = <CategoryModel>[];
    map.forEach((key, value) {
      if (value is Map) {
        final data = value.cast<String, dynamic>();
        items.add(CategoryModel.fromRTDB(key.toString(), data));
      }
    });
    items.sort((a, b) => a.name.compareTo(b.name));
    return items;
  }
}

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(realtimeDbServiceProvider));
});

final userCategoriesProvider = StreamProvider<List<CategoryModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(<CategoryModel>[]);
  final s = ref.watch(categoryRepositoryProvider).streamForUser(user.uid);
  return s.timeout(const Duration(seconds: 5), onTimeout: (sink) {
    sink.add(<CategoryModel>[]);
  }).handleError((_, __) {});
});