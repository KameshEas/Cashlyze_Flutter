import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';

class BudgetAnalyticsService {
  final ApiClient _client;

  BudgetAnalyticsService(this._client);

  /// Fetches category breakdown data from the server.
  /// Returns a map of category IDs to spending amounts.
  Future<Map<String, double>> getCategoryBreakdown() async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.budgetsCategoryBreakdown,
    );

    final data = response.data;
    if (data is Map<String, dynamic>) {
      return Map<String, double>.from(
        data.map(
          (final key, final value) =>
              MapEntry(key, (value as num).toDouble()),
        ),
      );
    }

    return {};
  }

  /// Fetches budget utilization data for all budgets.
  Future<Map<String, double>> getBudgetUtilizationAll() async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.budgetsUtilizationAll,
    );

    final data = response.data;
    if (data is Map<String, dynamic>) {
      return Map<String, double>.from(
        data.map(
          (final key, final value) =>
              MapEntry(key, (value as num).toDouble()),
        ),
      );
    }

    return {};
  }

  /// Fetches budget alerts (budgets exceeding threshold).
  Future<List<Map<String, dynamic>>> getBudgetAlerts() async {
    final response = await _client.get<List<dynamic>>(
      ApiEndpoints.budgetsAlertsCurrent,
    );

    final data = response.data;
    if (data is List<dynamic>) {
      return List<Map<String, dynamic>>.from(
        data.cast<Map<String, dynamic>>(),
      );
    }

    return [];
  }
}

final budgetAnalyticsServiceProvider =
    Provider<BudgetAnalyticsService>((final ref) {
  final client = ref.watch(apiClientProvider);
  return BudgetAnalyticsService(client);
});
