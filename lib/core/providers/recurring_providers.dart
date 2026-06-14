import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/recurring.dart';
import '../repositories/recurring_repository.dart';
import '../repositories/transaction_repository.dart';
import '../services/analytics_service.dart';
import '../services/auth_service.dart';

DateTime _nextDue(DateTime from, RecurringFrequency f) {
  if (f == RecurringFrequency.weekly) {
    return from.add(const Duration(days: 7));
  }
  final m = DateTime(from.year, from.month + 1, from.day);
  final lastDayNextMonth = DateTime(m.year, m.month + 1, 0).day;
  final day = from.day.clamp(1, lastDayNextMonth);
  return DateTime(m.year, m.month, day);
}

final recurringProcessorProvider = FutureProvider<int>((ref) async {
  final user = ref.read(currentUserProvider);
  if (user == null) return 0;
  final repo = ref.read(recurringRepositoryProvider);
  final txRepo = ref.read(transactionRepositoryProvider);
  final rules = await repo.getAllForUser(user.uid);
  int posted = 0;
  final today = DateTime.now();
  for (final r in rules) {
    var next = r.lastPostedDate ?? r.startDate;
    while (!next.isAfter(today)) {
      if (!next.isBefore(r.startDate)) {
        await txRepo.create(
          userId: user.uid,
          title: r.title,
          amount: r.isIncome ? r.amount.abs() : -r.amount.abs(),
          categoryId: r.categoryId,
          date: next,
        );
        posted++;
      }
      next = _nextDue(next, r.frequency);
      await repo.updateLastPosted(user.uid, r.id, next);
    }
  }
  if (posted > 0) {
    await ref
        .read(analyticsServiceProvider)
        .logEvent('recurring_post', params: {'count': posted});
  }
  return posted;
});
