import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import 'package:cashlyze/firebase_options.dart';

final realtimeDatabaseProvider = Provider<FirebaseDatabase>((ref) {
  final configuredUrl = (DefaultFirebaseOptions.currentPlatform.databaseURL != null && DefaultFirebaseOptions.currentPlatform.databaseURL!.isNotEmpty)
      ? DefaultFirebaseOptions.currentPlatform.databaseURL!
      : 'https://cashlyze-b156c-default-rtdb.asia-southeast1.firebasedatabase.app';
  final app = Firebase.app();
  final db = FirebaseDatabase.instanceFor(app: app, databaseURL: configuredUrl);
  try {
    db.setPersistenceEnabled(true);
  } catch (_) {}
  return db;
});

class RealtimeDbService {
  final FirebaseDatabase _db;
  final Dio _dio;
  final String _databaseUrl;
  final FirebaseAuth _auth;
  final bool _nativeSupported;

  RealtimeDbService(this._db)
      : _dio = Dio(),
        _auth = FirebaseAuth.instance,
        _databaseUrl = (DefaultFirebaseOptions.currentPlatform.databaseURL != null && DefaultFirebaseOptions.currentPlatform.databaseURL!.isNotEmpty)
            ? DefaultFirebaseOptions.currentPlatform.databaseURL!
            : 'https://cashlyze-b156c-default-rtdb.asia-southeast1.firebasedatabase.app',
        _nativeSupported = !kIsWeb;

  DatabaseReference ref(String path) => _db.ref(path);

  Future<String?> _idToken() async {
    try {
      final u = _auth.currentUser;
      if (u == null) return null;
      return await u.getIdToken();
    } catch (_) {
      return null;
    }
  }

  String _url(String path) {
    final trimmed = path.startsWith('/') ? path.substring(1) : path;
    return '$_databaseUrl/$trimmed.json';
  }

  Future<DatabaseReference> push(String path, Map<String, dynamic> data) async {
    if (_nativeSupported) {
      final ref = _db.ref(path).push();
      await ref.set(data);
      return ref;
    }
    final token = await _idToken();
    final res = await _dio.post(_url(path), data: data, queryParameters: token != null ? {'auth': token} : null);
    final name = (res.data as Map)['name'] as String;
    return _db.ref(path).child(name);
  }

  Future<String> pushKey(String path, Map<String, dynamic> data) async {
    if (_nativeSupported) {
      final ref = _db.ref(path).push();
      await ref.set(data);
      return ref.key!;
    }
    final token = await _idToken();
    final res = await _dio.post(_url(path), data: data, queryParameters: token != null ? {'auth': token} : null);
    final name = (res.data as Map)['name'] as String;
    return name;
  }

  Future<void> set(String path, Map<String, dynamic> data) async {
    if (_nativeSupported) {
      await _db.ref(path).set(data);
      return;
    }
    final token = await _idToken();
    await _dio.put(_url(path), data: data, queryParameters: token != null ? {'auth': token} : null);
  }

  Future<void> update(String path, Map<String, dynamic> data) async {
    if (_nativeSupported) {
      await _db.ref(path).update(data);
      return;
    }
    final token = await _idToken();
    await _dio.patch(_url(path), data: data, queryParameters: token != null ? {'auth': token} : null);
  }

  Future<void> updateMulti(Map<String, dynamic> dataTree) async {
    if (_nativeSupported) {
      await _db.ref().update(dataTree);
      return;
    }
    final token = await _idToken();
    await _dio.patch(_url(''), data: dataTree, queryParameters: token != null ? {'auth': token} : null);
  }

  Future<void> remove(String path) async {
    if (_nativeSupported) {
      await _db.ref(path).remove();
      return;
    }
    final token = await _idToken();
    await _dio.delete(_url(path), queryParameters: token != null ? {'auth': token} : null);
  }

  Future<DataSnapshot> get(String path) async {
    if (_nativeSupported) {
      return await _db.ref(path).get();
    }
    final token = await _idToken();
    final res = await _dio.get(_url(path), queryParameters: token != null ? {'auth': token} : null);
    final ref = _db.ref(path);
    // Populate a local DataSnapshot via native ref.get() when possible; otherwise emulate minimal snapshot
    // For callers using value directly, prefer using onValueMap/getMap
    final tmp = await ref.get();
    return tmp;
  }

  Stream<DatabaseEvent> onValue(String path) {
    if (_nativeSupported) return _db.ref(path).onValue;
    return const Stream.empty();
  }

  Stream<Map<String, dynamic>?> onValueMap(String path) {
    if (_nativeSupported) {
      return _db.ref(path).onValue.map((e) {
        final v = e.snapshot.value;
        return (v is Map) ? (v).cast<String, dynamic>() : null;
      }).handleError((_) {});
    }
    if (_databaseUrl.isEmpty) {
      return const Stream<Map<String, dynamic>?>.empty();
    }
    return Stream.periodic(const Duration(seconds: 3)).asyncMap((_) async {
      final token = await _idToken();
      final res = await _dio.get(_url(path), queryParameters: token != null ? {'auth': token} : null);
      return (res.data is Map) ? (res.data as Map).cast<String, dynamic>() : null;
    }).distinct((a, b) => a == b).handleError((_) {});
  }
}

final realtimeDbServiceProvider = Provider<RealtimeDbService>((ref) {
  return RealtimeDbService(ref.watch(realtimeDatabaseProvider));
});
