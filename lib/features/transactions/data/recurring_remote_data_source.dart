import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/models/recurring.dart';

/// Remote data source for recurring rule endpoints:
/// - `POST /recurring-rules`
/// - `GET /recurring-rules`
/// - `GET /recurring-rules/{id}`
/// - `PUT /recurring-rules/{id}`
/// - `DELETE /recurring-rules/{id}`
/// - `POST /recurring-rules/{id}/trigger`
class RecurringRemoteDataSource {
  const RecurringRemoteDataSource({required final ApiClient apiClient})
      : _api = apiClient;

  final ApiClient _api;

  // ── Create ────────────────────────────────────────────────────────────────

  Future<RecurringRule> create({
    required final String title,
    required final double amount,
    required final bool isIncome,
    required final DateTime startDate,
    required final RecurringFrequency frequency,
    final String? categoryId,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.recurringRules,
      data: {
        'title': title.trim(),
        'amount': amount,
        'is_income': isIncome,
        'start_date': startDate.toIso8601String(),
        'frequency': frequency.name,
        if (categoryId != null) 'category_id': categoryId,
      },
    );
    return _fromApiJson((response.data as Map).cast<String, dynamic>());
  }

  // ── List ──────────────────────────────────────────────────────────────────

  Future<List<RecurringRule>> getAll() async {
    final response =
        await _api.get<List<dynamic>>(ApiEndpoints.recurringRules);
    final list = (response.data as List).cast<Map<dynamic, dynamic>>();
    return list.map((final e) => _fromApiJson(e.cast<String, dynamic>())).toList();
  }

  // ── Get by id ─────────────────────────────────────────────────────────────

  Future<RecurringRule> getById(final String id) async {
    final response = await _api.get<Map<String, dynamic>>(
      ApiEndpoints.recurringRuleById(id),
    );
    return _fromApiJson((response.data as Map).cast<String, dynamic>());
  }

  // ── Update ────────────────────────────────────────────────────────────────

  Future<RecurringRule> update(
    final String id, {
    final String? title,
    final double? amount,
    final bool? isIncome,
    final DateTime? startDate,
    final RecurringFrequency? frequency,
    final String? categoryId,
  }) async {
    final response = await _api.put<Map<String, dynamic>>(
      ApiEndpoints.recurringRuleById(id),
      data: {
        if (title != null) 'title': title.trim(),
        if (amount != null) 'amount': amount,
        if (isIncome != null) 'is_income': isIncome,
        if (startDate != null) 'start_date': startDate.toIso8601String(),
        if (frequency != null) 'frequency': frequency.name,
        if (categoryId != null) 'category_id': categoryId,
      },
    );
    return _fromApiJson((response.data as Map).cast<String, dynamic>());
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> delete(final String id) async {
    await _api.delete<void>(ApiEndpoints.recurringRuleById(id));
  }

  // ── Manual trigger ────────────────────────────────────────────────────────

  /// Manually triggers the recurring rule to post a transaction immediately.
  Future<void> trigger(final String id) async {
    await _api.post<void>(ApiEndpoints.recurringRuleTrigger(id));
  }

  // ── Mapper ────────────────────────────────────────────────────────────────

  RecurringRule _fromApiJson(final Map<String, dynamic> json) {
    final startRaw = json['start_date'] ?? json['start_ms'];
    final startDate = startRaw is String
        ? DateTime.parse(startRaw)
        : DateTime.fromMillisecondsSinceEpoch((startRaw as num).toInt());

    final lastRaw = json['last_posted_date'] ?? json['last_ms'];
    final lastPostedDate = lastRaw == null
        ? null
        : lastRaw is String
            ? DateTime.parse(lastRaw)
            : DateTime.fromMillisecondsSinceEpoch((lastRaw as num).toInt());

    final frequencyStr = json['frequency'] as String? ?? 'monthly';

    return RecurringRule(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? json['userId'] as String? ?? '',
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      isIncome: json['is_income'] as bool? ?? json['isIncome'] as bool? ?? false,
      categoryId: json['category_id'] as String? ?? json['categoryId'] as String?,
      startDate: startDate,
      lastPostedDate: lastPostedDate,
      frequency: frequencyStr == 'weekly'
          ? RecurringFrequency.weekly
          : RecurringFrequency.monthly,
    );
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final recurringRemoteDataSourceProvider =
    Provider<RecurringRemoteDataSource>((final ref) {
  return RecurringRemoteDataSource(apiClient: ref.watch(apiClientProvider));
});
