import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/user_remote_data_source.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class UserRepository {
  const UserRepository(this._dataSource);
  final UserRemoteDataSource _dataSource;

  Future<UserModel?> getUser(final String uid) async {
    try {
      return await _dataSource.getMe();
    } catch (_) {
      return null;
    }
  }

  Future<void> updateUser(final String uid, final Map<String, dynamic> data) async {
    await _dataSource.updateMe(
      displayName: data['displayName'] as String?,
      photoURL: data['photoURL'] as String?,
      preferences: data['preferences'] as Map<String, dynamic>?,
    );
  }

  Future<UserModel> getOrCreateUser(final String uid, final String email) async {
    try {
      return await _dataSource.getMe();
    } catch (_) {
      return UserModel.fromFirebaseUser(uid, email);
    }
  }

  Stream<UserModel?> streamUser(final String uid) =>
      Stream.fromFuture(getUser(uid));
}

final userRepositoryProvider = Provider<UserRepository>((final ref) {
  return UserRepository(ref.watch(userRemoteDataSourceProvider));
});

final currentUserDataProvider = StreamProvider<UserModel?>((final ref) {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return Stream.value(null);
  return ref
      .watch(userRepositoryProvider)
      .streamUser(currentUser.userId)
      .handleError((_, _) {});
});

final currentUserModelProvider = FutureProvider<UserModel?>((final ref) async {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return null;
  return ref
      .watch(userRepositoryProvider)
      .getOrCreateUser(currentUser.userId, currentUser.email);
});
