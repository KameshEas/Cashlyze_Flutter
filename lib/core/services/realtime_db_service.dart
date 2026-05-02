import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import '../../firebase_options.dart';

final realtimeDatabaseProvider = Provider<FirebaseDatabase>((ref) {
  final configuredUrl =
      (DefaultFirebaseOptions.currentPlatform.databaseURL != null &&
          DefaultFirebaseOptions.currentPlatform.databaseURL!.isNotEmpty)
      ? DefaultFirebaseOptions.currentPlatform.databaseURL!
      : 'https://cashlyze-b156c-default-rtdb.asia-southeast1.firebasedatabase.app';
  final app = Firebase.app();
  final db = FirebaseDatabase.instanceFor(app: app, databaseURL: configuredUrl);
  try {
    if (kReleaseMode) {
      db.setPersistenceEnabled(false);
    } else {
      db.setPersistenceEnabled(true);
    }
    db.goOnline();
  } catch (_) {}
  return db;
});

final databaseUrlProvider = Provider<String>((ref) {
  final url =
      (DefaultFirebaseOptions.currentPlatform.databaseURL != null &&
          DefaultFirebaseOptions.currentPlatform.databaseURL!.isNotEmpty)
      ? DefaultFirebaseOptions.currentPlatform.databaseURL!
      : 'https://cashlyze-b156c-default-rtdb.asia-southeast1.firebasedatabase.app';
  return url;
});

final databaseUrlMismatchProvider = Provider<bool>((ref) {
  final url = ref.watch(databaseUrlProvider);
  return !url.contains('asia-southeast1.firebasedatabase.app');
});

class RealtimeDbService {
  final FirebaseDatabase _db;
  final Dio _dio;
  final String _databaseUrl;
  final FirebaseAuth _auth;
  final bool _nativeSupported;

  RealtimeDbService(this._db)
    : _dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
          responseType: ResponseType.json,
        ),
      ),
      _auth = FirebaseAuth.instance,
      _databaseUrl =
          (DefaultFirebaseOptions.currentPlatform.databaseURL != null &&
              DefaultFirebaseOptions.currentPlatform.databaseURL!.isNotEmpty)
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

  /// Convert ServerValue objects to REST API format
  Map<String, dynamic> _convertServerValues(Map<String, dynamic> data) {
    return data.map((key, value) {
      if (value is ServerValue) {
        // ServerValue.timestamp is the only common server value used
        return MapEntry(key, {'.sv': 'timestamp'});
      } else if (value is Map<String, dynamic>) {
        return MapEntry(key, _convertServerValues(value));
      } else if (value is List) {
        return MapEntry(key, value.map((item) {
          if (item is ServerValue) {
            return {'.sv': 'timestamp'};
          } else if (item is Map<String, dynamic>) {
            return _convertServerValues(item);
          }
          return item;
        }).toList());
      }
      return MapEntry(key, value);
    });
  }

  Future<DatabaseReference> push(String path, Map<String, dynamic> data) async {
    if (_nativeSupported) {
      final ref = _db.ref(path).push();
      await ref.set(data);
      return ref;
    }
    try {
      final token = await _idToken();
      if (token == null) {
        throw Exception('Authentication required: No valid ID token available');
      }
      final convertedData = _convertServerValues(data);
      final res = await _dio.post(
        _url(path),
        data: convertedData,
        queryParameters: {'auth': token},
      );
      
      if (res.data == null || res.data is! Map) {
        throw Exception('Invalid response from Firebase: expected Map, got ${res.data.runtimeType}');
      }
      
      final name = (res.data as Map)['name'];
      if (name == null || name is! String) {
        throw Exception('Invalid response from Firebase: missing or invalid "name" field');
      }
      
      return _db.ref(path).child(name);
    } catch (e) {
      throw Exception('Failed to push data to $path: $e');
    }
  }

  Future<String> pushKey(String path, Map<String, dynamic> data) async {
    if (_nativeSupported) {
      final ref = _db.ref(path).push();
      await ref.set(data);
      return ref.key!;
    }
    try {
      final token = await _idToken();
      if (token == null) {
        throw Exception('Authentication required: No valid ID token available');
      }
      final convertedData = _convertServerValues(data);
      final res = await _dio.post(
        _url(path),
        data: convertedData,
        queryParameters: {'auth': token},
      );
      
      if (res.data == null || res.data is! Map) {
        throw Exception('Invalid response from Firebase: expected Map, got ${res.data.runtimeType}');
      }
      
      final name = (res.data as Map)['name'];
      if (name == null || name is! String) {
        throw Exception('Invalid response from Firebase: missing or invalid "name" field');
      }
      
      return name;
    } catch (e) {
      throw Exception('Failed to push key to $path: $e');
    }
  }

  Future<void> set(String path, Map<String, dynamic> data) async {
    if (_nativeSupported) {
      await _db.ref(path).set(data);
      return;
    }
    try {
      final token = await _idToken();
      if (token == null) {
        throw Exception('Authentication required: No valid ID token available');
      }
      final convertedData = _convertServerValues(data);
      final res = await _dio.put(
        _url(path),
        data: convertedData,
        queryParameters: {'auth': token},
      );
      
      if (res.statusCode != 200) {
        throw Exception('Failed to set data: HTTP ${res.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to set data at $path: $e');
    }
  }

  Future<void> update(String path, Map<String, dynamic> data) async {
    if (_nativeSupported) {
      await _db.ref(path).update(data);
      return;
    }
    try {
      final token = await _idToken();
      if (token == null) {
        throw Exception('Authentication required: No valid ID token available');
      }
      final convertedData = _convertServerValues(data);
      final res = await _dio.patch(
        _url(path),
        data: convertedData,
        queryParameters: {'auth': token},
      );
      
      if (res.statusCode != 200) {
        throw Exception('Failed to update data: HTTP ${res.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to update data at $path: $e');
    }
  }

  Future<void> updateMulti(Map<String, dynamic> dataTree) async {
    if (_nativeSupported) {
      await _db.ref().update(dataTree);
      return;
    }
    try {
      final token = await _idToken();
      if (token == null) {
        throw Exception('Authentication required: No valid ID token available');
      }
      final convertedData = _convertServerValues(dataTree);
      final res = await _dio.patch(
        _url(''),
        data: convertedData,
        queryParameters: {'auth': token},
      );
      
      if (res.statusCode != 200) {
        throw Exception('Failed to update multiple paths: HTTP ${res.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to update multiple paths: $e');
    }
  }

  Future<void> remove(String path) async {
    if (_nativeSupported) {
      await _db.ref(path).remove();
      return;
    }
    try {
      final token = await _idToken();
      if (token == null) {
        throw Exception('Authentication required: No valid ID token available');
      }
      final res = await _dio.delete(
        _url(path),
        queryParameters: {'auth': token},
      );
      
      if (res.statusCode != 200) {
        throw Exception('Failed to remove data: HTTP ${res.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to remove data at $path: $e');
    }
  }

  Future<DataSnapshot> get(String path) async {
    if (_nativeSupported) {
      return await _db.ref(path).get();
    }
    try {
      final token = await _idToken();
      if (token == null) {
        throw Exception('Authentication required: No valid ID token available');
      }
      await _dio.get(
        _url(path),
        queryParameters: {'auth': token},
      );
      
      // For REST API, return native snapshot as fallback
      final ref = _db.ref(path);
      return await ref.get();
    } catch (e) {
      throw Exception('Failed to fetch data from $path: $e');
    }
  }

  Stream<DatabaseEvent> onValue(String path) {
    if (_nativeSupported) return _db.ref(path).onValue;
    return const Stream.empty();
  }

  Stream<Map<String, dynamic>?> onValueMap(String path) {
    if (_nativeSupported) {
      return _db
          .ref(path)
          .onValue
          .map((e) {
            final v = e.snapshot.value;
            return (v is Map) ? (v).cast<String, dynamic>() : null;
          })
          .handleError((_) {});
    }
    if (_databaseUrl.isEmpty) {
      return const Stream<Map<String, dynamic>?>.empty();
    }
    return Stream.periodic(const Duration(seconds: 3))
        .asyncMap((_) async {
          final token = await _idToken();
          final res = await _dio.get(
            _url(path),
            queryParameters: token != null ? {'auth': token} : null,
          );
          return (res.data is Map)
              ? (res.data as Map).cast<String, dynamic>()
              : null;
        })
        .distinct((a, b) => a == b)
        .handleError((_) {});
  }
}

final realtimeDbServiceProvider = Provider<RealtimeDbService>((ref) {
  return RealtimeDbService(ref.watch(realtimeDatabaseProvider));
});
