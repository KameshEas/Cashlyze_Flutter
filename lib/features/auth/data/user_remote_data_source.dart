import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/models/user_model.dart';

/// Remote data source for user profile endpoints:
/// - `GET /users/me`
/// - `PUT /users/me`
class UserRemoteDataSource {
  const UserRemoteDataSource({required ApiClient apiClient})
      : _api = apiClient;

  final ApiClient _api;

  // ── GET /users/me ─────────────────────────────────────────────────────────

  /// Fetches the authenticated user's profile.
  Future<UserModel> getMe() async {
    final response =
        await _api.get<Map<String, dynamic>>(ApiEndpoints.usersMe);
    final data = (response.data as Map).cast<String, dynamic>();
    return _fromApiJson(data);
  }

  // ── PUT /users/me ─────────────────────────────────────────────────────────

  /// Updates the authenticated user's profile.
  ///
  /// Only pass the fields you want to change; omitted fields are left untouched
  /// by the backend.
  Future<UserModel> updateMe({
    String? displayName,
    String? photoURL,
    Map<String, dynamic>? preferences,
  }) async {
    final body = <String, dynamic>{
      if (displayName != null) 'display_name': displayName,
      if (photoURL != null) 'photo_url': photoURL,
      if (preferences != null) 'preferences': preferences,
    };
    final response = await _api.put<Map<String, dynamic>>(
      ApiEndpoints.usersMe,
      data: body,
    );
    final data = (response.data as Map).cast<String, dynamic>();
    return _fromApiJson(data);
  }

  // ── Mapper ────────────────────────────────────────────────────────────────

  UserModel _fromApiJson(Map<String, dynamic> json) {
    final createdAtRaw = json['created_at'];
    final updatedAtRaw = json['updated_at'];
    return UserModel(
      uid: json['id'] as String? ?? json['uid'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String? ?? json['displayName'] as String?,
      photoURL: json['photo_url'] as String? ?? json['photoURL'] as String?,
      createdAt: createdAtRaw is String
          ? DateTime.parse(createdAtRaw)
          : DateTime.fromMillisecondsSinceEpoch((createdAtRaw as num).toInt()),
      updatedAt: updatedAtRaw == null
          ? null
          : updatedAtRaw is String
              ? DateTime.parse(updatedAtRaw)
              : DateTime.fromMillisecondsSinceEpoch(
                  (updatedAtRaw as num).toInt()),
      preferences: json['preferences'] as Map<String, dynamic>?,
    );
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final userRemoteDataSourceProvider = Provider<UserRemoteDataSource>((ref) {
  return UserRemoteDataSource(apiClient: ref.watch(apiClientProvider));
});
