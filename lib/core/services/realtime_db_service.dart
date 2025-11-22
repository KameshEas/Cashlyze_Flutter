import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';

final realtimeDatabaseProvider = Provider<FirebaseDatabase>((ref) {
  final db = FirebaseDatabase.instance;
  db.setPersistenceEnabled(true);
  return db;
});

class RealtimeDbService {
  final FirebaseDatabase _db;

  RealtimeDbService(this._db);

  DatabaseReference ref(String path) => _db.ref(path);

  Future<DatabaseReference> push(String path, Map<String, dynamic> data) async {
    final ref = _db.ref(path).push();
    await ref.set(data);
    return ref;
  }

  Future<void> set(String path, Map<String, dynamic> data) async {
    await _db.ref(path).set(data);
  }

  Future<void> update(String path, Map<String, dynamic> data) async {
    await _db.ref(path).update(data);
  }

  Future<void> updateMulti(Map<String, dynamic> dataTree) async {
    await _db.ref().update(dataTree);
  }

  Future<void> remove(String path) async {
    await _db.ref(path).remove();
  }

  Future<DataSnapshot> get(String path) async {
    return await _db.ref(path).get();
  }

  Stream<DatabaseEvent> onValue(String path) => _db.ref(path).onValue;
}

final realtimeDbServiceProvider = Provider<RealtimeDbService>((ref) {
  return RealtimeDbService(ref.watch(realtimeDatabaseProvider));
});