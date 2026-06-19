import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/models/category.dart';

/// Remote data source for category endpoints:
/// - `POST /categories`
/// - `GET /categories`
/// - `GET /categories/{id}`
/// - `PUT /categories/{id}`
/// - `DELETE /categories/{id}`
class CategoryRemoteDataSource {
  const CategoryRemoteDataSource({required final ApiClient apiClient})
      : _api = apiClient;

  final ApiClient _api;

  // ── Create ────────────────────────────────────────────────────────────────

  Future<CategoryModel> create({
    required final String name,
    final String? icon,
    final int? color,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.categories,
      data: {
        'name': name.trim(),
        if (icon != null) 'icon': icon,
        if (color != null) 'color': color,
      },
    );
    return _fromApiJson((response.data as Map).cast<String, dynamic>());
  }

  // ── List ──────────────────────────────────────────────────────────────────

  Future<List<CategoryModel>> getAll() async {
    final response =
        await _api.get<List<dynamic>>(ApiEndpoints.categories);
    final list = (response.data as List).cast<Map<dynamic, dynamic>>();
    // Filter out soft-deleted entries that the API may return. The API
    // sometimes includes deleted items with fields like `deleted`,
    // `deleted_at` or `deletedAt`. Exclude those so the UI does not show
    // stale/removed categories (e.g., previously deleted "Food").
    final filtered = list.where((final entry) {
      final map = entry.cast<String, dynamic>();
      if (map.containsKey('deleted')) {
        final v = map['deleted'];
        if (v == true || v == 1 || v == '1') return false;
      }
      if (map.containsKey('deleted_at')) {
        if (map['deleted_at'] != null) return false;
      }
      if (map.containsKey('deletedAt')) {
        if (map['deletedAt'] != null) return false;
      }
      return true;
    }).toList();

    return filtered
        .map((final e) => _fromApiJson(e.cast<String, dynamic>()))
        .toList();
  }

  // ── Get by id ─────────────────────────────────────────────────────────────

  Future<CategoryModel> getById(final String id) async {
    final response = await _api.get<Map<String, dynamic>>(
      ApiEndpoints.categoryById(id),
    );
    return _fromApiJson((response.data as Map).cast<String, dynamic>());
  }

  // ── Update ────────────────────────────────────────────────────────────────

  Future<CategoryModel> update(
    final String id, {
    final String? name,
    final String? icon,
    final int? color,
  }) async {
    final response = await _api.put<Map<String, dynamic>>(
      ApiEndpoints.categoryById(id),
      data: {
        if (name != null) 'name': name.trim(),
        if (icon != null) 'icon': icon,
        if (color != null) 'color': color,
      },
    );
    return _fromApiJson((response.data as Map).cast<String, dynamic>());
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> delete(final String id) async {
    await _api.delete<void>(ApiEndpoints.categoryById(id));
  }

  // ── Mapper ────────────────────────────────────────────────────────────────

  CategoryModel _fromApiJson(final Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? json['userId'] as String? ?? '',
      name: json['name'] as String,
      icon: json['icon'] as String?,
      color: json['color'] as int?,
    );
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final categoryRemoteDataSourceProvider =
    Provider<CategoryRemoteDataSource>((final ref) {
  return CategoryRemoteDataSource(apiClient: ref.watch(apiClientProvider));
});
