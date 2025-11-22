import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cashlyze/firebase_options.dart';

Future<void> main() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final fs = FirebaseFirestore.instance;
  final rtdb = FirebaseDatabase.instance;
  rtdb.setPersistenceEnabled(false);

  await _migrateUsers(fs, rtdb);
  await _migrateCategories(fs, rtdb);
  await _migrateTransactions(fs, rtdb);
  await _migrateBudgets(fs, rtdb);
  await _migrateEmi(fs, rtdb);
}

Future<void> _migrateUsers(FirebaseFirestore fs, FirebaseDatabase db) async {
  final users = await fs.collection('users').get();
  for (final d in users.docs) {
    final m = d.data();
    final out = {
      'email': m['email'],
      'displayName': m['displayName'],
      'photoURL': m['photoURL'],
      'created_at_ms': (m['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
      'updated_at_ms': (m['updatedAt'] as Timestamp?)?.millisecondsSinceEpoch,
      'preferences': m['preferences'],
    };
    await db.ref('users/${d.id}').set(out);
  }
}

Future<void> _migrateCategories(FirebaseFirestore fs, FirebaseDatabase db) async {
  final cats = await fs.collection('categories').get();
  for (final d in cats.docs) {
    final m = d.data();
    final userId = m['userId'] as String?;
    if (userId == null) continue;
    final out = {
      'userId': userId,
      'name': m['name'],
      'icon': m['icon'],
      'color': m['color'],
    };
    await db.ref('users/$userId/categories/${d.id}').set(out);
  }
}

Future<void> _migrateTransactions(FirebaseFirestore fs, FirebaseDatabase db) async {
  final txs = await fs.collection('transactions').get();
  for (final d in txs.docs) {
    final m = d.data();
    final userId = m['userId'] as String?;
    if (userId == null) continue;
    final out = {
      'userId': userId,
      'title': m['title'],
      'amount': (m['amount'] as num).toDouble(),
      'categoryId': m['categoryId'],
      'date_ms': (m['date'] as Timestamp).millisecondsSinceEpoch,
      'notes': m['notes'],
      'tags': m['tags'],
      'created_at_ms': (m['createdAt'] as Timestamp?)?.millisecondsSinceEpoch,
      'updated_at_ms': (m['updatedAt'] as Timestamp?)?.millisecondsSinceEpoch,
    };
    await db.ref('users/$userId/transactions/${d.id}').set(out);
  }
}

Future<void> _migrateBudgets(FirebaseFirestore fs, FirebaseDatabase db) async {
  final budgets = await fs.collection('budgets').get();
  for (final d in budgets.docs) {
    final m = d.data();
    final userId = m['userId'] as String?;
    if (userId == null) continue;
    final out = {
      'userId': userId,
      'name': m['name'],
      'allocated': (m['allocated'] as num).toDouble(),
      'period': m['period'],
      'categoryIds': m['categoryIds'],
      'created_at_ms': (m['createdAt'] as Timestamp?)?.millisecondsSinceEpoch,
      'updated_at_ms': (m['updatedAt'] as Timestamp?)?.millisecondsSinceEpoch,
    };
    await db.ref('users/$userId/budgets/${d.id}').set(out);
    final adj = await fs.collection('budgets/${d.id}/adjustments').get();
    for (final a in adj.docs) {
      final am = a.data();
      final ao = {
        'oldAllocated': (am['oldAllocated'] as num).toDouble(),
        'newAllocated': (am['newAllocated'] as num).toDouble(),
        'note': am['note'],
        'created_at_ms': (am['createdAt'] as Timestamp?)?.millisecondsSinceEpoch,
      };
      await db.ref('users/$userId/budget_adjustments/${d.id}/${a.id}').set(ao);
    }
  }
}

Future<void> _migrateEmi(FirebaseFirestore fs, FirebaseDatabase db) async {
  final plans = await fs.collection('emi_plans').get();
  for (final d in plans.docs) {
    final m = d.data();
    final userId = m['userId'] as String?;
    if (userId == null) continue;
    final out = {
      'userId': userId,
      'loanAmount': (m['loanAmount'] as num).toDouble(),
      'annualInterestRate': (m['annualInterestRate'] as num).toDouble(),
      'tenureMonths': m['tenureMonths'],
      'startDate_ms': (m['startDate'] as Timestamp).millisecondsSinceEpoch,
      'frequency': m['frequency'],
      'active': m['active'] ?? true,
    };
    await db.ref('users/$userId/emi_plans/${d.id}').set(out);
    final sched = await fs.collection('emi_plans/${d.id}/schedule').get();
    for (final s in sched.docs) {
      final sm = s.data();
      final so = {
        'planId': d.id,
        'dueDate_ms': (sm['dueDate'] as Timestamp).millisecondsSinceEpoch,
        'installment': (sm['installment'] as num).toDouble(),
        'interest': (sm['interest'] as num).toDouble(),
        'principal': (sm['principal'] as num).toDouble(),
        'remainingPrincipal': (sm['remainingPrincipal'] as num).toDouble(),
        'paid': sm['paid'] ?? false,
        'paidAt_ms': (sm['paidAt'] as Timestamp?)?.millisecondsSinceEpoch,
      };
      await db.ref('users/$userId/emi_schedules/${d.id}/${s.id}').set(so);
    }
  }
}