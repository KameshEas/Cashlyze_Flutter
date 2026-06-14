import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/emi.dart';
import '../services/auth_service.dart';
import '../../features/emi/data/emi_remote_data_source.dart';

class EMIRepository {
  const EMIRepository(this._dataSource);
  final EmiRemoteDataSource _dataSource;

  Future<EMIPlan> createPlan(EMIPlan plan) =>
      _dataSource.createPlan(
        loanAmount: plan.loanAmount,
        annualInterestRate: plan.annualInterestRate,
        tenureMonths: plan.tenureMonths,
        startDate: plan.startDate,
        frequency: plan.frequency,
      );

  Future<void> updatePlan(EMIPlan plan) =>
      _dataSource
          .updatePlan(
            plan.id,
            loanAmount: plan.loanAmount,
            annualInterestRate: plan.annualInterestRate,
            tenureMonths: plan.tenureMonths,
            startDate: plan.startDate,
            frequency: plan.frequency,
            active: plan.active,
          )
          .then((_) {});

  Future<void> deletePlan(String userId, String planId) =>
      _dataSource.deletePlan(planId);

  Future<void> markPaid(String userId, String planId, String paymentId) =>
      _dataSource.markSchedulePaid(planId, paymentId).then((_) {});

  Future<List<EMIPlan>> getAllPlansForUser(String userId) =>
      _dataSource.getAllPlans();

  Stream<List<EMIPlan>> streamPlans(String userId) =>
      Stream.fromFuture(_dataSource.getAllPlans());

  Stream<List<EMIPayment>> streamSchedule(String userId, String planId) =>
      Stream.fromFuture(_dataSource.getSchedule(planId));

  Stream<List<EMIPayment>> streamUpcomingThisMonth(String userId) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month);
    final end = DateTime(now.year, now.month + 1);
    return Stream.fromFuture(
      _dataSource.getAllPlans().then((plans) async {
        final upcoming = <EMIPayment>[];
        for (final plan in plans) {
          final payments = await _dataSource.getSchedule(plan.id);
          upcoming.addAll(payments.where(
            (p) =>
                !p.paid &&
                p.dueDate.isAfter(start) &&
                p.dueDate.isBefore(end),
          ));
        }
        upcoming.sort((a, b) => a.dueDate.compareTo(b.dueDate));
        return upcoming;
      }),
    );
  }

  // Future-based helpers (preferred for UI caching)
  Future<List<EMIPayment>> getScheduleForPlan(String userId, String planId) async {
    return _dataSource.getSchedule(planId);
  }

  Future<List<EMIPayment>> getUpcomingPaymentsThisMonthFuture(String userId) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month);
    final end = DateTime(now.year, now.month + 1);
    final upcoming = <EMIPayment>[];
    final plans = await _dataSource.getAllPlans();
    for (final plan in plans) {
      final payments = await _dataSource.getSchedule(plan.id);
      upcoming.addAll(payments.where(
        (p) => !p.paid && p.dueDate.isAfter(start) && p.dueDate.isBefore(end),
      ));
    }
    upcoming.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return upcoming;
  }
}

final emiRepositoryProvider =
    Provider<EMIRepository>((ref) => EMIRepository(ref.watch(emiRemoteDataSourceProvider)));

final userEMIPlansProvider = FutureProvider<List<EMIPlan>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Future.value(<EMIPlan>[]);
  return ref.watch(emiRepositoryProvider).getAllPlansForUser(user.userId);
});

final emiScheduleProvider = FutureProvider.family<List<EMIPayment>, String>((ref, planId) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Future.value(<EMIPayment>[]);
  return ref.watch(emiRepositoryProvider).getScheduleForPlan(user.userId, planId);
});

final emiUpcomingProvider = FutureProvider<List<EMIPayment>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Future.value(<EMIPayment>[]);
  return ref.watch(emiRepositoryProvider).getUpcomingPaymentsThisMonthFuture(user.userId);
});
