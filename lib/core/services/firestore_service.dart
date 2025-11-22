import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for FirebaseFirestore instance
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

/// Firestore Service for database operations
class FirestoreService {
  final FirebaseFirestore _firestore;

  FirestoreService(this._firestore);

  /// Get a reference to a collection
  CollectionReference collection(String path) {
    return _firestore.collection(path);
  }

  /// Get a reference to a document
  DocumentReference doc(String path) {
    return _firestore.doc(path);
  }

  /// Add a document to a collection
  Future<DocumentReference> addDocument(
    String collectionPath,
    Map<String, dynamic> data,
  ) async {
    return await _firestore.collection(collectionPath).add(data);
  }

  /// Set a document (create or overwrite)
  Future<void> setDocument(
    String documentPath,
    Map<String, dynamic> data, {
    bool merge = false,
  }) async {
    await _firestore.doc(documentPath).set(data, SetOptions(merge: merge));
  }

  /// Update a document
  Future<void> updateDocument(
    String documentPath,
    Map<String, dynamic> data,
  ) async {
    await _firestore.doc(documentPath).update(data);
  }

  /// Delete a document
  Future<void> deleteDocument(String documentPath) async {
    await _firestore.doc(documentPath).delete();
  }

  /// Get a document
  Future<DocumentSnapshot> getDocument(String documentPath) async {
    return await _firestore.doc(documentPath).get();
  }

  /// Get a collection
  Future<QuerySnapshot> getCollection(String collectionPath) async {
    return await _firestore.collection(collectionPath).get();
  }

  /// Stream a document
  Stream<DocumentSnapshot> streamDocument(String documentPath) {
    return _firestore.doc(documentPath).snapshots();
  }

  /// Stream a collection
  Stream<QuerySnapshot> streamCollection(String collectionPath) {
    return _firestore.collection(collectionPath).snapshots();
  }

  /// Query a collection with filters, ordering, and limits
  Query queryCollection(
    String collectionPath, {
    List<Query> Function(CollectionReference ref)? build,
  }) {
    var ref = _firestore.collection(collectionPath);
    if (build != null) {
      final queries = build(ref);
      return queries.isNotEmpty ? queries.last : ref;
    }
    return ref;
  }

  /// Query a collection with filters
  Query queryCollectionWithFilters(
    String collectionPath, {
    List<QueryFilter>? filters,
    List<QueryOrder>? orderBy,
    int? limit,
  }) {
    Query query = _firestore.collection(collectionPath);

    if (filters != null) {
      for (var filter in filters) {
        query = query.where(
          filter.field,
          isEqualTo: filter.isEqualTo,
          isNotEqualTo: filter.isNotEqualTo,
          isLessThan: filter.isLessThan,
          isLessThanOrEqualTo: filter.isLessThanOrEqualTo,
          isGreaterThan: filter.isGreaterThan,
          isGreaterThanOrEqualTo: filter.isGreaterThanOrEqualTo,
          arrayContains: filter.arrayContains,
          arrayContainsAny: filter.arrayContainsAny,
          whereIn: filter.whereIn,
          whereNotIn: filter.whereNotIn,
          isNull: filter.isNull,
        );
      }
    }

    if (orderBy != null) {
      for (var order in orderBy) {
        query = query.orderBy(order.field, descending: order.descending);
      }
    }

    if (limit != null) {
      query = query.limit(limit);
    }

    return query;
  }

  /// Batch write operations
  WriteBatch batch() {
    return _firestore.batch();
  }

  /// Run a transaction
  Future<T> runTransaction<T>(TransactionHandler<T> transactionHandler) async {
    return await _firestore.runTransaction(transactionHandler);
  }
}

/// Query filter helper class
class QueryFilter {
  final String field;
  final dynamic isEqualTo;
  final dynamic isNotEqualTo;
  final dynamic isLessThan;
  final dynamic isLessThanOrEqualTo;
  final dynamic isGreaterThan;
  final dynamic isGreaterThanOrEqualTo;
  final dynamic arrayContains;
  final List<dynamic>? arrayContainsAny;
  final List<dynamic>? whereIn;
  final List<dynamic>? whereNotIn;
  final bool? isNull;

  QueryFilter({
    required this.field,
    this.isEqualTo,
    this.isNotEqualTo,
    this.isLessThan,
    this.isLessThanOrEqualTo,
    this.isGreaterThan,
    this.isGreaterThanOrEqualTo,
    this.arrayContains,
    this.arrayContainsAny,
    this.whereIn,
    this.whereNotIn,
    this.isNull,
  });
}

/// Query order helper class
class QueryOrder {
  final String field;
  final bool descending;

  QueryOrder(this.field, {this.descending = false});
}

/// Provider for FirestoreService
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService(ref.watch(firestoreProvider));
});
