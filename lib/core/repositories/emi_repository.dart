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
    final key = await _db.pushKey('users/${plan.userId}/emi_plans', data);
    return EMIPlan.fromRTDB(key, data);
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
    return _db.onValueMap('users/$userId/emi_plans').map((map) {
      if (map == null) return <EMIPlan>[];
      final items = <EMIPlan>[];
      map.forEach((key, value) {
        if (value is Map) {
          final data = value.cast<String, dynamic>();
          items.add(EMIPlan.fromRTDB(key, data));
        }
      });
      return items;
    });
  }

  Stream<List<EMIPayment>> streamSchedule(String userId, String planId) {
    return _db.onValueMap('users/$userId/emi_schedules/$planId').map((map) {
      if (map == null) return <EMIPayment>[];
      final items = <EMIPayment>[];
      map.forEach((key, value) {
        if (value is Map) {
          final data = value.cast<String, dynamic>();
          items.add(EMIPayment.fromRTDB(key, data));
        }
      });
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
  if (user == null) return Stream.value(<EMIPlan>[]);
  final s = ref.watch(emiRepositoryProvider).streamPlans(user.uid);
  return s.timeout(const Duration(seconds: 5), onTimeout: (sink) {
    sink.add(<EMIPlan>[]);
  }).handleError((_, __) {});
});

final emiScheduleProvider = StreamProvider.family<List<EMIPayment>, String>((ref, planId) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(<EMIPayment>[]);
  final s = ref.watch(emiRepositoryProvider).streamSchedule(user.uid, planId);
  return s.timeout(const Duration(seconds: 5), onTimeout: (sink) {
    sink.add(<EMIPayment>[]);
  }).handleError((_, __) {});
});