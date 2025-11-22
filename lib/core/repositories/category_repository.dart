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
    final ref = await _db.push('users/$userId/categories', data);
    final snap = await ref.get();
    final map = (snap.value as Map).cast<String, dynamic>();
    return CategoryModel.fromRTDB(ref.key!, map);
  }

  Future<void> update(String userId, String id, Map<String, dynamic> data) async {
    await _db.update('users/$userId/categories/$id', data);
  }

  Future<void> delete(String userId, String id) async {
    await _db.remove('users/$userId/categories/$id');
  }

  Stream<List<CategoryModel>> streamForUser(String userId) {
    final ref = _db.ref('users/$userId/categories').orderByChild('name');
    return ref.onValue.map((event) {
      final s = event.snapshot;
      if (!s.exists) return <CategoryModel>[];
      final items = s.children.map((c) {
        final data = (c.value as Map).cast<String, dynamic>();
        return CategoryModel.fromRTDB(c.key!, data);
      }).toList();
      items.sort((a, b) => a.name.compareTo(b.name));
      return items;
    });
  }
}

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(realtimeDbServiceProvider));
});

final userCategoriesProvider = StreamProvider<List<CategoryModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(categoryRepositoryProvider).streamForUser(user.uid);
});