import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/models/budget.dart';

/// Remote data source for budget endpoints:
/// - `POST /budgets`
/// - `GET /budgets`
/// - `GET /budgets/{id}`
/// - `PUT /budgets/{id}`
/// - `DELETE /budgets/{id}`
class BudgetRemoteDataSource {
  const BudgetRemoteDataSource({required ApiClient apiClient})
      : _api = apiClient;

  final ApiClient _api;

  // ── Create ────────────────────────────────────────────────────────────────

  Future<BudgetModel> create({
    required String name,
    required double allocated,
    required BudgetPeriod period,
    List<String> categoryIds = const [],
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.budgets,
      data: {
        'name': name.trim(),
        'allocated': allocated,
        'period': period.name,
        'category_ids': categoryIds,
        'categoryIds': categoryIds,
      },
    );
    return _fromApiJson((response.data as Map).cast<String, dynamic>());
  }

  // ── List ──────────────────────────────────────────────────────────────────

  Future<List<BudgetModel>> getAll({int? skip, int? limit}) async {
    final response = await _api.get<List<dynamic>>(
      ApiEndpoints.budgets,
      queryParameters: {
        if (skip != null) 'skip': skip,
        if (limit != null) 'limit': limit,
      },
    );
    final list = (response.data as List).cast<Map<dynamic, dynamic>>();
    return list
        .map((e) => _fromApiJson(e.cast<String, dynamic>()))
        .toList();
  }

  // ── Get by id ─────────────────────────────────────────────────────────────

  Future<BudgetModel> getById(String id) async {
    final response =
        await _api.get<Map<String, dynamic>>(ApiEndpoints.budgetById(id));
    return _fromApiJson((response.data as Map).cast<String, dynamic>());
  }

  // ── Update ────────────────────────────────────────────────────────────────

  Future<BudgetModel> update(
    String id, {
    String? name,
    double? allocated,
    BudgetPeriod? period,
    List<String>? categoryIds,
  }) async {
    final response = await _api.put<Map<String, dynamic>>(
      ApiEndpoints.budgetById(id),
      data: {
        if (name != null) 'name': name.trim(),
        if (allocated != null) 'allocated': allocated,
        if (period != null) 'period': period.name,
        if (categoryIds != null) ...
          {
            'category_ids': categoryIds,
            'categoryIds': categoryIds,
          },
      },
    );
    return _fromApiJson((response.data as Map).cast<String, dynamic>());
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> delete(String id) async {
    await _api.delete<void>(ApiEndpoints.budgetById(id));
  }

  // ── Mapper ────────────────────────────────────────────────────────────────

  BudgetModel _fromApiJson(Map<String, dynamic> json) {
    final createdAtRaw = json['created_at'];
    final updatedAtRaw = json['updated_at'];

    final rawCategoryIds = json['category_ids'] ?? json['categoryIds'];

    return BudgetModel(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? json['userId'] as String? ?? '',
      name: json['name'] as String,
      allocated: (json['allocated'] as num).toDouble(),
      period: BudgetPeriod.values.firstWhere(
        (p) => p.name == (json['period'] as String),
        orElse: () => BudgetPeriod.monthly,
      ),
      categoryIds: (rawCategoryIds as List?)?.cast<String>() ?? const [],
      createdAt: createdAtRaw is String
          ? DateTime.parse(createdAtRaw)
          : DateTime.fromMillisecondsSinceEpoch((createdAtRaw as num).toInt()),
      updatedAt: updatedAtRaw == null
          ? null
          : updatedAtRaw is String
              ? DateTime.parse(updatedAtRaw)
              : DateTime.fromMillisecondsSinceEpoch(
                  (updatedAtRaw as num).toInt()),
    );
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final budgetRemoteDataSourceProvider =
    Provider<BudgetRemoteDataSource>((ref) {
  return BudgetRemoteDataSource(apiClient: ref.watch(apiClientProvider));
});
