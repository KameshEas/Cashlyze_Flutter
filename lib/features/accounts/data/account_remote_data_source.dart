import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/models/account.dart';

/// Remote data source for account endpoints:
/// - `GET /accounts`, `POST /accounts`, `PUT /accounts/{id}`, `DELETE /accounts/{id}`
/// - `GET /accounts/types`
/// - `GET /accounts/spend-summary`
class AccountRemoteDataSource {
  const AccountRemoteDataSource({required final ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<List<AccountModel>> getAll() async {
    final response = await _api.get<List<dynamic>>(ApiEndpoints.accounts);
    return (response.data as List)
        .map((final e) => AccountModel.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<AccountType>> getTypes() async {
    final response = await _api.get<List<dynamic>>(ApiEndpoints.accountTypes);
    return (response.data as List)
        .map((final e) => AccountType.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<AccountModel> create({
    required final String name,
    required final String typeId,
    final String? institution,
    final String? last4,
    final String? upiId,
    final String? currencyCode,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.accounts,
      data: {
        'name': name.trim(),
        'account_type_id': typeId,
        if (institution != null) 'institution': institution,
        if (last4 != null) 'last4': last4,
        if (upiId != null) 'upi_id': upiId,
        if (currencyCode != null) 'currency_code': currencyCode,
      },
    );
    return AccountModel.fromJson((response.data as Map).cast<String, dynamic>());
  }

  /// The card / UPI detail fields are always sent, so passing null clears one
  /// (the server leaves a field alone only when it is omitted).
  Future<AccountModel> update(
    final String id, {
    required final String name,
    final String? institution,
    final String? last4,
    final String? upiId,
  }) async {
    final response = await _api.put<Map<String, dynamic>>(
      ApiEndpoints.accountById(id),
      data: {
        'name': name.trim(),
        'institution': institution,
        'last4': last4,
        'upi_id': upiId,
      },
    );
    return AccountModel.fromJson((response.data as Map).cast<String, dynamic>());
  }

  Future<void> delete(final String id) async {
    await _api.delete<void>(ApiEndpoints.accountById(id));
  }

  Future<List<AccountSpend>> spendSummary({final DateTime? start, final DateTime? end}) async {
    String d(final DateTime v) =>
        '${v.year.toString().padLeft(4, '0')}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}';
    final response = await _api.get<List<dynamic>>(
      ApiEndpoints.accountsSpendSummary,
      queryParameters: {
        if (start != null) 'start_date': d(start),
        if (end != null) 'end_date': d(end),
      },
    );
    return (response.data as List)
        .map((final e) => AccountSpend.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }
}

final accountRemoteDataSourceProvider = Provider<AccountRemoteDataSource>((final ref) {
  return AccountRemoteDataSource(apiClient: ref.watch(apiClientProvider));
});
