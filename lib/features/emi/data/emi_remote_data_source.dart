import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/models/emi.dart';

/// Remote data source for EMI plan + schedule endpoints:
/// - `POST /emi-plans`
/// - `GET /emi-plans`
/// - `GET /emi-plans/{id}`
/// - `PUT /emi-plans/{id}`
/// - `DELETE /emi-plans/{id}`
/// - `GET /emi-plans/{id}/schedules`
/// - `PUT /emi-plans/{planId}/schedules/{scheduleId}` (mark paid)
class EmiRemoteDataSource {
  const EmiRemoteDataSource({required ApiClient apiClient})
      : _api = apiClient;

  final ApiClient _api;

  // ── Plans ─────────────────────────────────────────────────────────────────

  Future<EMIPlan> createPlan({
    required double loanAmount,
    required double annualInterestRate,
    required int tenureMonths,
    required DateTime startDate,
    required PaymentFrequency frequency,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.emiPlans,
      data: {
        'loan_amount': loanAmount,
        'annual_interest_rate': annualInterestRate,
        'tenure_months': tenureMonths,
        // API expects a date (YYYY-MM-DD) for start_date — send date-only string
        'start_date': startDate.toIso8601String().split('T').first,
        // Server doesn't support weekly frequency; map weekly -> monthly
        'frequency': frequency.name == 'weekly' ? 'monthly' : frequency.name,
      },
    );
    return _planFromApiJson((response.data as Map).cast<String, dynamic>());
  }

  Future<List<EMIPlan>> getAllPlans() async {
    final response = await _api.get<List<dynamic>>(ApiEndpoints.emiPlans);
    final list = (response.data as List).cast<Map<dynamic, dynamic>>();
    return list.map((e) => _planFromApiJson(e.cast<String, dynamic>())).toList();
  }

  Future<EMIPlan> getPlanById(String id) async {
    final response =
        await _api.get<Map<String, dynamic>>(ApiEndpoints.emiPlanById(id));
    return _planFromApiJson((response.data as Map).cast<String, dynamic>());
  }

  Future<EMIPlan> updatePlan(
    String id, {
    double? loanAmount,
    double? annualInterestRate,
    int? tenureMonths,
    DateTime? startDate,
    PaymentFrequency? frequency,
    bool? active,
  }) async {
    final response = await _api.put<Map<String, dynamic>>(
      ApiEndpoints.emiPlanById(id),
      data: {
        if (loanAmount != null) 'loan_amount': loanAmount,
        if (annualInterestRate != null)
          'annual_interest_rate': annualInterestRate,
        if (tenureMonths != null) 'tenure_months': tenureMonths,
        if (startDate != null)
          'start_date': startDate.toIso8601String().split('T').first,
        if (frequency != null)
          'frequency': frequency.name == 'weekly' ? 'monthly' : frequency.name,
        if (active != null) 'active': active,
      },
    );
    return _planFromApiJson((response.data as Map).cast<String, dynamic>());
  }

  Future<void> deletePlan(String id) async {
    await _api.delete<void>(ApiEndpoints.emiPlanById(id));
  }

  // ── Schedules ─────────────────────────────────────────────────────────────

  Future<List<EMIPayment>> getSchedule(String planId) async {
    final response = await _api.get<List<dynamic>>(
      ApiEndpoints.emiSchedules(planId),
    );
    final list = (response.data as List).cast<Map<dynamic, dynamic>>();
    return list
        .map((e) => _paymentFromApiJson(planId, e.cast<String, dynamic>()))
        .toList();
  }

  /// Marks a schedule entry as paid.
  Future<EMIPayment> markSchedulePaid(String planId, String scheduleId) async {
    final response = await _api.put<Map<String, dynamic>>(
      ApiEndpoints.emiScheduleById(planId, scheduleId),
      data: {'paid': true},
    );
    return _paymentFromApiJson(
      planId,
      (response.data as Map).cast<String, dynamic>(),
    );
  }

  // ── Mappers ───────────────────────────────────────────────────────────────

  EMIPlan _planFromApiJson(Map<String, dynamic> json) {
    final startDateRaw = json['start_date'] ?? json['startDate_ms'];
    final startDate = startDateRaw is String
        ? DateTime.parse(startDateRaw)
        : DateTime.fromMillisecondsSinceEpoch((startDateRaw as num).toInt());

    return EMIPlan(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? json['userId'] as String? ?? '',
      loanAmount: (json['loan_amount'] ?? json['loanAmount'] as num).toDouble(),
      annualInterestRate:
          (json['annual_interest_rate'] ?? json['annualInterestRate'] as num)
              .toDouble(),
      tenureMonths:
          (json['tenure_months'] ?? json['tenureMonths']) as int,
      startDate: startDate,
      frequency: PaymentFrequency.values.firstWhere(
        (f) => f.name == (json['frequency'] as String? ?? 'monthly'),
        orElse: () => PaymentFrequency.monthly,
      ),
      active: json['active'] as bool? ?? true,
    );
  }

  EMIPayment _paymentFromApiJson(
      String planId, Map<String, dynamic> json) {
    final dueDateRaw = json['due_date'] ?? json['dueDate_ms'];
    final dueDate = dueDateRaw is String
        ? DateTime.parse(dueDateRaw)
        : DateTime.fromMillisecondsSinceEpoch((dueDateRaw as num).toInt());

    final paidAtRaw = json['paid_at'] ?? json['paidAt_ms'];
    final paidAt = paidAtRaw == null
        ? null
        : paidAtRaw is String
            ? DateTime.parse(paidAtRaw)
            : DateTime.fromMillisecondsSinceEpoch((paidAtRaw as num).toInt());

    // Backend historically returned `amount` only. Support both shapes
    final installmentRaw = json['installment'] ?? json['amount'];
    final interestRaw = json['interest'];
    final principalRaw = json['principal'];
    final remainingRaw = json['remaining_principal'] ?? json['remainingPrincipal'];

    final installment = installmentRaw != null ? (installmentRaw as num).toDouble() : 0.0;
    final interest = interestRaw != null ? (interestRaw as num).toDouble() : 0.0;
    final principal = principalRaw != null ? (principalRaw as num).toDouble() : 0.0;
    final remaining = remainingRaw != null ? (remainingRaw as num).toDouble() : 0.0;

    return EMIPayment(
      id: json['id'] as String,
      planId: json['plan_id'] as String? ?? planId,
      dueDate: dueDate,
      installment: installment,
      interest: interest,
      principal: principal,
      remainingPrincipal: remaining,
      paid: json['paid'] as bool? ?? false,
      paidAt: paidAt,
    );
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final emiRemoteDataSourceProvider = Provider<EmiRemoteDataSource>((ref) {
  return EmiRemoteDataSource(apiClient: ref.watch(apiClientProvider));
});
