import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/realtime_db_service.dart';
import '../services/auth_service.dart';
import '../models/emi.dart';

class EMIRepository {
  final RealtimeDbService _db;
  EMIRepository(this._db);

  Future<EMIPlan> createPlan(EMIPlan plan) async {
    final data = plan.toRTDB();
    final ref = await _db.push('users/${plan.userId}/emi_plans', data);
    final snap = await ref.get();
    final map = (snap.value as Map).cast<String, dynamic>();
    return EMIPlan.fromRTDB(ref.key!, map);
  }

  Future<void> addSchedule(String userId, String planId, List<EMIPayment> schedule) async {
    final updates = <String, dynamic>{};
    for (final p in schedule) {
      final ref = _db.ref('users/$userId/emi_schedules/$planId').push();
      updates['users/$userId/emi_schedules/$planId/${ref.key}'] = p.toRTDB();
    }
    await _db.updateMulti(updates);
  }

  Stream<List<EMIPlan>> streamPlans(String userId) {
    final ref = _db.ref('users/$userId/emi_plans');
    return ref.onValue.map((event) {
      final s = event.snapshot;
      if (!s.exists) return <EMIPlan>[];
      final items = s.children.map((c) {
        final data = (c.value as Map).cast<String, dynamic>();
        return EMIPlan.fromRTDB(c.key!, data);
      }).toList();
      return items;
    });
  }

  Stream<List<EMIPayment>> streamSchedule(String userId, String planId) {
    final ref = _db.ref('users/$userId/emi_schedules/$planId').orderByChild('dueDate_ms');
    return ref.onValue.map((event) {
      final s = event.snapshot;
      if (!s.exists) return <EMIPayment>[];
      final items = s.children.map((c) {
        final data = (c.value as Map).cast<String, dynamic>();
        return EMIPayment.fromRTDB(c.key!, data);
      }).toList();
      items.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      return items;
    });
  }

  Future<void> markPaid(String userId, String planId, String paymentId) async {
    await _db.update('users/$userId/emi_schedules/$planId/$paymentId', {'paid': true, 'paidAt_ms': ServerValue.timestamp});
  }
}

final emiRepositoryProvider = Provider<EMIRepository>((ref) => EMIRepository(ref.watch(realtimeDbServiceProvider)));

final userEMIPlansProvider = StreamProvider<List<EMIPlan>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(emiRepositoryProvider).streamPlans(user.uid);
});

final emiScheduleProvider = StreamProvider.family<List<EMIPayment>, String>((ref, planId) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(emiRepositoryProvider).streamSchedule(user.uid, planId);
});