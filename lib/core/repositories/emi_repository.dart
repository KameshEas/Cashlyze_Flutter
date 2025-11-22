import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/emi.dart';

class EMIRepository {
  final FirestoreService _fs;
  static const String _collection = 'emi_plans';
  EMIRepository(this._fs);

  Future<EMIPlan> createPlan(EMIPlan plan) async {
    final doc = await _fs.addDocument(_collection, plan.toFirestore());
    final snap = await doc.get();
    return EMIPlan.fromFirestore(snap);
  }

  Future<void> addSchedule(String planId, List<EMIPayment> schedule) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final p in schedule) {
      final ref = FirebaseFirestore.instance.collection('$_collection/$planId/schedule').doc();
      batch.set(ref, p.toFirestore());
    }
    await batch.commit();
  }

  Stream<List<EMIPlan>> streamPlans(String userId) {
    return _fs.collection(_collection).where('userId', isEqualTo: userId).orderBy('updatedAt', descending: true).snapshots().map((s) => s.docs.map((d) => EMIPlan.fromFirestore(d)).toList());
  }

  Stream<List<EMIPayment>> streamSchedule(String planId) {
    return _fs.collection('$_collection/$planId/schedule').orderBy('dueDate').snapshots().map((s) => s.docs.map((d) => EMIPayment.fromFirestore(d)).toList());
  }

  Future<void> markPaid(String planId, String paymentId) async {
    await _fs.updateDocument('$_collection/$planId/schedule/$paymentId', {'paid': true, 'paidAt': FieldValue.serverTimestamp()});
  }
}

final emiRepositoryProvider = Provider<EMIRepository>((ref) => EMIRepository(ref.watch(firestoreServiceProvider)));

final userEMIPlansProvider = StreamProvider<List<EMIPlan>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(emiRepositoryProvider).streamPlans(user.uid);
});

final emiScheduleProvider = StreamProvider.family<List<EMIPayment>, String>((ref, planId) {
  return ref.watch(emiRepositoryProvider).streamSchedule(planId);
});