import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/models/transaction.dart';

/// Filter parameters for `GET /transactions`.
class TransactionFilters {
  const TransactionFilters({
    this.skip,
    this.limit,
    this.startDate,
    this.endDate,
    this.categoryId,
  });

  final int? skip;
  final int? limit;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? categoryId;

  Map<String, dynamic> toQueryParameters() => {
        if (skip != null) 'skip': skip,
        if (limit != null) 'limit': limit,
        if (startDate != null) 'start_date': _toQueryDate(startDate!),
        if (endDate != null) 'end_date': _toQueryDate(endDate!),
        if (categoryId != null) 'category_id': categoryId,
      };

  String _toQueryDate(final DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }
}

/// Remote data source for transaction endpoints:
/// - `POST /transactions`
/// - `GET /transactions` (+ filters)
/// - `GET /transactions/{id}`
/// - `PUT /transactions/{id}`
/// - `DELETE /transactions/{id}`
class TransactionRemoteDataSource {
  const TransactionRemoteDataSource({required final ApiClient apiClient})
      : _api = apiClient;

  final ApiClient _api;

  String _toApiDate(final DateTime value) {
    final d = DateTime(value.year, value.month, value.day);
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  String? _normalizeCategoryId(final String? value) {
    if (value == null) return null;
    final v = value.trim();
    if (v.isEmpty) return null;

    // Never send semantic labels as IDs. Backend expects category UUID/string id.
    final lowered = v.toLowerCase();
    if (lowered == 'income' || lowered == 'expense' || lowered == 'general') {
      return null;
    }
    return v;
  }

  // ── Create ────────────────────────────────────────────────────────────────

  Future<TransactionModel> create({
    required final String title,
    required final double amount,
    required final DateTime date,
    final String? categoryId,
    final String? categoryName,
    final bool isIncome = false,
    final String? notes,
    final List<String>? tags,
  }) async {
    final normalizedCategoryId = _normalizeCategoryId(categoryId);
    final transactionType = isIncome ? 'income' : 'expense';
    
    final response = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.transactions,
      data: {
        'title': title.trim(),
        'amount': amount,
        'transaction_date': _toApiDate(date),
        if (normalizedCategoryId != null) 'category_id': normalizedCategoryId,
        if (categoryName != null) 'category_name': categoryName,
        if (categoryName != null) 'category': categoryName,
        'type': transactionType,
        'transaction_type': transactionType,
        'is_income': isIncome,
        if (notes != null) 'notes': notes,
        if (tags != null && tags.isNotEmpty) 'tags': tags,
      },
    );
    return _fromApiJson((response.data as Map).cast<String, dynamic>());
  }

  // ── List ──────────────────────────────────────────────────────────────────

  Future<List<TransactionModel>> getAll([final TransactionFilters? filters]) async {
    final response = await _api.get<List<dynamic>>(
      ApiEndpoints.transactions,
      queryParameters: filters?.toQueryParameters(),
    );
    final list = (response.data as List).cast<Map<dynamic, dynamic>>();
    return list
        .map((final e) => _fromApiJson(e.cast<String, dynamic>()))
        .toList();
  }

  // ── Get by id ─────────────────────────────────────────────────────────────

  Future<TransactionModel> getById(final String id) async {
    final response = await _api.get<Map<String, dynamic>>(
      ApiEndpoints.transactionById(id),
    );
    return _fromApiJson((response.data as Map).cast<String, dynamic>());
  }

  // ── Update ────────────────────────────────────────────────────────────────

  Future<TransactionModel> update(
    final String id, {
    final String? title,
    final double? amount,
    final DateTime? date,
    final String? categoryId,
    final String? categoryName,
    final bool? isIncome,
    final String? notes,
    final List<String>? tags,
  }) async {
    final normalizedCategoryId = _normalizeCategoryId(categoryId);
    final transactionType = isIncome == true ? 'income' : 'expense';
    
    final response = await _api.put<Map<String, dynamic>>(
      ApiEndpoints.transactionById(id),
      data: {
        if (title != null) 'title': title.trim(),
        if (amount != null) 'amount': amount,
        if (date != null) 'transaction_date': _toApiDate(date),
        if (normalizedCategoryId != null) 'category_id': normalizedCategoryId,
        if (categoryName != null) 'category_name': categoryName,
        if (categoryName != null) 'category': categoryName,
        if (isIncome != null) 'type': transactionType,
        if (isIncome != null) 'transaction_type': transactionType,
        if (isIncome != null) 'is_income': isIncome,
        if (notes != null) 'notes': notes,
        if (tags != null) 'tags': tags,
      },
    );
    return _fromApiJson((response.data as Map).cast<String, dynamic>());
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> delete(final String id) async {
    await _api.delete<void>(ApiEndpoints.transactionById(id));
  }

  // ── Mapper ────────────────────────────────────────────────────────────────

  TransactionModel _fromApiJson(final Map<String, dynamic> json) {
    final dateRaw = json['transaction_date'] ?? json['date'];
    final date = dateRaw is String
        ? DateTime.parse(dateRaw)
        : DateTime.fromMillisecondsSinceEpoch((dateRaw as num).toInt());

    return TransactionModel(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? json['userId'] as String? ?? '',
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      categoryId: json['category_id'] as String? ?? json['categoryId'] as String?,
      categoryName: (json['category_name'] as String?) ?? (json['category'] as String?),
      date: date,
      notes: json['notes'] as String?,
      tags: (json['tags'] as List?)?.cast<String>(),
    );
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final transactionRemoteDataSourceProvider =
    Provider<TransactionRemoteDataSource>((final ref) {
  return TransactionRemoteDataSource(apiClient: ref.watch(apiClientProvider));
});
