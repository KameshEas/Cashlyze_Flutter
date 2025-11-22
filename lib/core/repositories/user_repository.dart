import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/user_model.dart';
import '../services/realtime_db_service.dart';
import '../services/auth_service.dart';

/// User Repository for managing user data in Firestore
class UserRepository {
  final RealtimeDbService _db;
  static const String _usersCollection = 'users';

  UserRepository(this._db);

  /// Create a new user document in Firestore
  Future<void> createUser(UserModel user) async {
    await _db.set('$_usersCollection/${user.uid}', user.toRTDB());
  }

  /// Get user by ID
  Future<UserModel?> getUser(String uid) async {
    try {
      final snap = await _db.get('$_usersCollection/$uid');
      if (snap.exists && snap.value != null) {
        final map = (snap.value as Map).cast<String, dynamic>();
        return UserModel.fromRTDB(uid, map);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// Update user data
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    final updateData = {
      ...data,
      'updated_at_ms': ServerValue.timestamp,
    };
    await _db.update('$_usersCollection/$uid', updateData);
  }

  /// Delete user document
  Future<void> deleteUser(String uid) async {
    await _db.remove('$_usersCollection/$uid');
  }

  /// Stream user data
  Stream<UserModel?> streamUser(String uid) {
    return _db.onValue('$_usersCollection/$uid').map((event) {
      final snap = event.snapshot;
      if (snap.exists && snap.value != null) {
        final map = (snap.value as Map).cast<String, dynamic>();
        return UserModel.fromRTDB(uid, map);
      }
      return null;
    });
  }

  /// Update user preferences
  Future<void> updateUserPreferences(
    String uid,
    Map<String, dynamic> preferences,
  ) async {
    await updateUser(uid, {'preferences': preferences});
  }

  /// Update user profile
  Future<void> updateUserProfile({
    required String uid,
    String? displayName,
    String? photoURL,
  }) async {
    final data = <String, dynamic>{};
    if (displayName != null) data['displayName'] = displayName;
    if (photoURL != null) data['photoURL'] = photoURL;

    if (data.isNotEmpty) {
      await updateUser(uid, data);
    }
  }

  /// Check if user document exists
  Future<bool> userExists(String uid) async {
    final snap = await _db.get('$_usersCollection/$uid');
    return snap.exists;
  }

  /// Get or create user
  /// This is useful when a user signs in for the first time
  Future<UserModel> getOrCreateUser(String uid, String email) async {
    final user = await getUser(uid);
    if (user != null) {
      return user;
    }

    // Create new user
    final newUser = UserModel.fromFirebaseUser(uid, email);
    await createUser(newUser);
    return newUser;
  }
}

/// Provider for UserRepository
final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(realtimeDbServiceProvider));
});

/// Provider for current user data stream
final currentUserDataProvider = StreamProvider<UserModel?>((ref) {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) {
    return Stream.value(null);
  }

  return ref.watch(userRepositoryProvider).streamUser(currentUser.uid);
});

/// Provider to get or create current user
final currentUserModelProvider = FutureProvider<UserModel?>((ref) async {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) {
    return null;
  }

  final userRepo = ref.watch(userRepositoryProvider);
  return await userRepo.getOrCreateUser(currentUser.uid, currentUser.email!);
});
