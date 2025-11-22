import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/transaction_repository.dart';
import '../models/transaction.dart';
import '../services/auth_service.dart';

final recentTransactionsProvider = StreamProvider<List<TransactionModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(transactionRepositoryProvider).streamForUser(user.uid);
});

final monthlyTrendProvider = Provider<List<double>>((ref) {
  final txs = ref.watch(recentTransactionsProvider).maybeWhen(data: (d) => d, orElse: () => const []);
  final now = DateTime.now();
  final months = List.generate(6, (i) => DateTime(now.year, now.month - (5 - i), 1));
  final values = List<double>.filled(6, 0);
  for (final t in txs) {
    for (var i = 0; i < months.length; i++) {
      final m = months[i];
      final next = DateTime(m.year, m.month + 1, 1);
      if (t.date.isAfter(m) && t.date.isBefore(next)) {
        values[i] += t.amount.abs();
      }
    }
  }
  return values;
});

final categoryBreakdownProvider = Provider<Map<String, double>>((ref) {
  final txs = ref.watch(recentTransactionsProvider).maybeWhen(data: (d) => d, orElse: () => const []);
  final map = <String, double>{};
  for (final t in txs.where((t) => t.amount < 0)) {
    final cat = t.categoryId ?? 'Other';
    map[cat] = (map[cat] ?? 0) + t.amount.abs();
  }
  return map;
});