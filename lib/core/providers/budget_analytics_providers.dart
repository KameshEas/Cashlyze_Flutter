import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/budget_analytics_service.dart';

/// Fetches category breakdown from the server (more efficient for large datasets).
/// Returns a map of category IDs/names to spending amounts.
final serverCategoryBreakdownProvider =
    FutureProvider<Map<String, double>>((final ref) async {
  final service = ref.watch(budgetAnalyticsServiceProvider);
  return service.getCategoryBreakdown();
});

/// Fetches budget utilization data from the server for all budgets.
final serverBudgetUtilizationProvider =
    FutureProvider<Map<String, double>>((final ref) async {
  final service = ref.watch(budgetAnalyticsServiceProvider);
  return service.getBudgetUtilizationAll();
});

/// Fetches budget alerts from the server (budgets exceeding threshold).
final serverBudgetAlertsProvider =
    FutureProvider<List<Map<String, dynamic>>>((final ref) async {
  final service = ref.watch(budgetAnalyticsServiceProvider);
  return service.getBudgetAlerts();
});
