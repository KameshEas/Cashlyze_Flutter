import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/category.dart';

class CategoryRepository {
  final FirestoreService _fs;
  static const String _collection = 'categories';

  CategoryRepository(this._fs);

  Future<CategoryModel> create({
    required String userId,
    required String name,
    String? icon,
    int? color,
  }) async {
    final doc = await _fs.addDocument(_collection, {
      'userId': userId,
      'name': name.trim(),
      'icon': icon,
      'color': color,
    });
    final snapshot = await doc.get();
    return CategoryModel.fromFirestore(snapshot);
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await _fs.updateDocument('$_collection/$id', data);
  }

  Future<void> delete(String id) async {
    await _fs.deleteDocument('$_collection/$id');
  }

  Stream<List<CategoryModel>> streamForUser(String userId) {
    return _fs.collection(_collection)
        .where('userId', isEqualTo: userId)
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs.map((d) => CategoryModel.fromFirestore(d)).toList());
  }
}

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(firestoreServiceProvider));
});

final userCategoriesProvider = StreamProvider<List<CategoryModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(categoryRepositoryProvider).streamForUser(user.uid);
});