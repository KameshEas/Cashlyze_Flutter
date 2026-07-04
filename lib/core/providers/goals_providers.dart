import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/models/goals_model.dart';

final goalsServiceProvider = Provider<GoalsService>((final ref) {
  final apiClient = ref.watch(apiClientProvider);
  return GoalsService(apiClient);
});

class GoalsService {
  GoalsService(this._apiClient);
  final ApiClient _apiClient;

  Future<List<GoalsModel>> listGoals({
    final bool activeOnly = false,
    final int skip = 0,
    final int limit = 100,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        ApiEndpoints.savingsGoals,
        queryParameters: {
          'active_only': activeOnly,
          'skip': skip,
          'limit': limit,
        },
      );
      final List<dynamic> data = response.data;
      return data.map((final e) => GoalsModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<GoalsModel> createGoal(final GoalsModel goal) async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.savingsGoals,
        data: goal.toJson(),
      );
      return GoalsModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  Future<GoalsModel> updateGoal(final String goalId, final GoalsModel goal) async {
    try {
      final response = await _apiClient.dio.put(
        '${ApiEndpoints.savingsGoals}/$goalId',
        data: goal.toJson(),
      );
      return GoalsModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteGoal(final String goalId) async {
    try {
      await _apiClient.dio.delete('${ApiEndpoints.savingsGoals}/$goalId');
    } catch (e) {
      rethrow;
    }
  }

  Future<GoalsModel> updateProgress(
    final String goalId,
    final double amount,
  ) async {
    try {
      final response = await _apiClient.dio.post(
        '${ApiEndpoints.savingsGoals}/$goalId/progress',
        queryParameters: {'amount': amount},
      );
      return GoalsModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }
}

final goalsListProvider = FutureProvider<List<GoalsModel>>((final ref) async {
  final service = ref.watch(goalsServiceProvider);
  return service.listGoals(activeOnly: false);
});

final goalsActiveListProvider = FutureProvider<List<GoalsModel>>((final ref) async {
  final service = ref.watch(goalsServiceProvider);
  return service.listGoals(activeOnly: true);
});

final goalDetailProvider =
    FutureProvider.family<GoalsModel, String>((final ref, final goalId) async {
  final goals = await ref.watch(goalsListProvider.future);
  return goals.firstWhere((final g) => g.id == goalId);
});
