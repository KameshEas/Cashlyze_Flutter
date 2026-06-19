import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/emi/data/emi_remote_data_source.dart';
import '../models/emi.dart';
import '../services/auth_service.dart';

class EMIRepository {
  const EMIRepository(this._dataSource);
  final EmiRemoteDataSource _dataSource;

  Future<EMIPlan> createPlan(final EMIPlan plan) =>
      _dataSource.createPlan(
        loanAmount: plan.loanAmount,
        annualInterestRate: plan.annualInterestRate,
        tenureMonths: plan.tenureMonths,
        startDate: plan.startDate,
        frequency: plan.frequency,
      );

  Future<void> updatePlan(final EMIPlan plan) =>
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
          .then((final _) {});

  Future<void> deletePlan(final String userId, final String planId) =>
      _dataSource.deletePlan(planId);

  Future<void> markPaid(final String userId, final String planId, final String paymentId) =>
      _dataSource.markSchedulePaid(planId, paymentId).then((final _) {});

  Future<List<EMIPlan>> getAllPlansForUser(final String userId) =>
      _dataSource.getAllPlans();

  Stream<List<EMIPlan>> streamPlans(final String userId) =>
      Stream.fromFuture(_dataSource.getAllPlans());

  Stream<List<EMIPayment>> streamSchedule(final String userId, final String planId) =>
      Stream.fromFuture(_dataSource.getSchedule(planId));

  Stream<List<EMIPayment>> streamUpcomingThisMonth(final String userId) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month);
    final end = DateTime(now.year, now.month + 1);
    return Stream.fromFuture(
      _dataSource.getAllPlans().then((final plans) async {
        final upcoming = <EMIPayment>[];
        for (final plan in plans) {
          final payments = await _dataSource.getSchedule(plan.id);
          upcoming.addAll(payments.where(
            (final p) =>
                !p.paid &&
                p.dueDate.isAfter(start) &&
                p.dueDate.isBefore(end),
          ));
        }
        upcoming.sort((final a, final b) => a.dueDate.compareTo(b.dueDate));
        return upcoming;
      }),
    );
  }

  // Future-based helpers (preferred for UI caching)
  Future<List<EMIPayment>> getScheduleForPlan(final String userId, final String planId) async {
    return _dataSource.getSchedule(planId);
  }

  Future<List<EMIPayment>> getUpcomingPaymentsThisMonthFuture(final String userId) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month);
    final end = DateTime(now.year, now.month + 1);
    final upcoming = <EMIPayment>[];
    final plans = await _dataSource.getAllPlans();
    for (final plan in plans) {
      final payments = await _dataSource.getSchedule(plan.id);
      upcoming.addAll(payments.where(
        (final p) => !p.paid && p.dueDate.isAfter(start) && p.dueDate.isBefore(end),
      ));
    }
    upcoming.sort((final a, final b) => a.dueDate.compareTo(b.dueDate));
    return upcoming;
  }
}

final emiRepositoryProvider =
    Provider<EMIRepository>((final ref) => EMIRepository(ref.watch(emiRemoteDataSourceProvider)));

final userEMIPlansProvider = FutureProvider<List<EMIPlan>>((final ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Future.value(<EMIPlan>[]);
  return ref.watch(emiRepositoryProvider).getAllPlansForUser(user.userId);
});

final emiScheduleProvider = FutureProvider.family<List<EMIPayment>, String>((final ref, final planId) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Future.value(<EMIPayment>[]);
  return ref.watch(emiRepositoryProvider).getScheduleForPlan(user.userId, planId);
});

final emiUpcomingProvider = FutureProvider<List<EMIPayment>>((final ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Future.value(<EMIPayment>[]);
  return ref.watch(emiRepositoryProvider).getUpcomingPaymentsThisMonthFuture(user.userId);
});
