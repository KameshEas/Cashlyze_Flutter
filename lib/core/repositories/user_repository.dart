import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../../features/auth/data/user_remote_data_source.dart';

class UserRepository {
  const UserRepository(this._dataSource);
  final UserRemoteDataSource _dataSource;

  Future<UserModel?> getUser(String uid) async {
    try {
      return await _dataSource.getMe();
    } catch (_) {
      return null;
    }
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _dataSource.updateMe(
      displayName: data['displayName'] as String?,
      photoURL: data['photoURL'] as String?,
      preferences: data['preferences'] as Map<String, dynamic>?,
    );
  }

  Future<UserModel> getOrCreateUser(String uid, String email) async {
    try {
      return await _dataSource.getMe();
    } catch (_) {
      return UserModel.fromFirebaseUser(uid, email);
    }
  }

  Stream<UserModel?> streamUser(String uid) =>
      Stream.fromFuture(getUser(uid));
}

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(userRemoteDataSourceProvider));
});

final currentUserDataProvider = StreamProvider<UserModel?>((ref) {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return Stream.value(null);
  return ref
      .watch(userRepositoryProvider)
      .streamUser(currentUser.userId)
      .handleError((_, __) {});
});

final currentUserModelProvider = FutureProvider<UserModel?>((ref) async {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return null;
  return ref
      .watch(userRepositoryProvider)
      .getOrCreateUser(currentUser.userId, currentUser.email);
});
