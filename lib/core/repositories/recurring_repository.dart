import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/realtime_db_service.dart';
import '../services/auth_service.dart';
import '../models/recurring.dart';

class RecurringRepository {
  final RealtimeDbService _db;
  RecurringRepository(this._db);

  Future<RecurringRule> createRule({
    required String userId,
    required String title,
    required double amount,
    required bool isIncome,
    String? categoryId,
    required DateTime startDate,
    required RecurringFrequency frequency,
  }) async {
    final data = {
      'userId': userId,
      'title': title.trim(),
      'amount': amount,
      'isIncome': isIncome,
      'categoryId': categoryId,
      'start_ms': startDate.millisecondsSinceEpoch,
      'last_ms': startDate.millisecondsSinceEpoch,
      'frequency': frequency == RecurringFrequency.weekly ? 'weekly' : 'monthly',
      'created_at_ms': DateTime.now().millisecondsSinceEpoch,
    };
    final key = await _db.pushKey('users/$userId/recurring_rules', data);
    return RecurringRule.fromRTDB(key, data);
  }

  Future<void> updateLastPosted(String userId, String id, DateTime last) async {
    await _db.update('users/$userId/recurring_rules/$id', {
      'last_ms': last.millisecondsSinceEpoch,
    });
  }

  Stream<List<RecurringRule>> streamForUser(String userId) {
    return _db.onValueMap('users/$userId/recurring_rules').map((map) {
      if (map == null) return <RecurringRule>[];
      final items = <RecurringRule>[];
      map.forEach((key, value) {
        if (value is Map) {
          final data = value.cast<String, dynamic>();
          items.add(RecurringRule.fromRTDB(key, data));
        }
      });
      items.sort((a, b) => (a.startDate).compareTo(b.startDate));
      return items;
    });
  }

  Future<List<RecurringRule>> getAllForUser(String userId) async {
    final snap = await _db.get('users/$userId/recurring_rules');
    if (snap.value == null) return <RecurringRule>[];
    final map = snap.value as Map<dynamic, dynamic>;
    final items = <RecurringRule>[];
    map.forEach((key, value) {
      if (value is Map) {
        final data = value.cast<String, dynamic>();
        items.add(RecurringRule.fromRTDB(key.toString(), data));
      }
    });
    items.sort((a, b) => (a.startDate).compareTo(b.startDate));
    return items;
  }
}

final recurringRepositoryProvider = Provider<RecurringRepository>((ref) {
  return RecurringRepository(ref.watch(realtimeDbServiceProvider));
});

final userRecurringRulesProvider = StreamProvider<List<RecurringRule>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(recurringRepositoryProvider).streamForUser(user.uid);
});
