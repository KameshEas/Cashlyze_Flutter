import 'package:sqlite_async/sqlite_async.dart';

import '../models/queued_transaction.dart';

class OfflineQueueService {
  OfflineQueueService(this._database);

  final SqliteDatabase _database;
  static const String _tableName = 'queued_transactions';

  Future<void> initialize() async {
    await _database.execute('''
      CREATE TABLE IF NOT EXISTS $_tableName (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        transaction_date TEXT NOT NULL,
        category_id TEXT,
        category_name TEXT,
        notes TEXT,
        tags TEXT,
        account_id TEXT,
        attachment_path TEXT,
        created_at TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        error_message TEXT,
        retry_count INTEGER NOT NULL DEFAULT 0,
        synced_at TEXT
      )
    ''');
  }

  Future<void> addTransaction(final QueuedTransaction transaction) async {
    await _database.execute(
      '''
      INSERT INTO $_tableName (
        id, user_id, title, amount, transaction_date, category_id,
        category_name, notes, tags, account_id, attachment_path,
        created_at, status, retry_count
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        transaction.id,
        transaction.userId,
        transaction.title,
        transaction.amount,
        transaction.transactionDate.toIso8601String(),
        transaction.categoryId,
        transaction.categoryName,
        transaction.notes,
        transaction.tags?.join(','),
        transaction.accountId,
        transaction.attachmentPath,
        transaction.createdAt.toIso8601String(),
        transaction.status,
        transaction.retryCount,
      ],
    );
  }

  Future<List<QueuedTransaction>> getPendingTransactions(
    final String userId,
  ) async {
    final rows = await _database.getAll(
      '''
      SELECT * FROM $_tableName
      WHERE user_id = ? AND (status = 'pending' OR status = 'failed')
      ORDER BY created_at ASC
      LIMIT 50
      ''',
      [userId],
    );

    return rows.map((final row) => _rowToTransaction(row)).toList();
  }

  Future<List<QueuedTransaction>> getAllForUser(final String userId) async {
    final rows = await _database.getAll(
      '''
      SELECT * FROM $_tableName
      WHERE user_id = ?
      ORDER BY created_at DESC
      ''',
      [userId],
    );

    return rows.map((final row) => _rowToTransaction(row)).toList();
  }

  Future<QueuedTransaction?> getTransaction(final String id) async {
    final row = await _database.getOptional(
      'SELECT * FROM $_tableName WHERE id = ?',
      [id],
    );

    return row != null ? _rowToTransaction(row) : null;
  }

  Future<void> updateStatus(
    final String id,
    final String status, {
    final String? errorMessage,
  }) async {
    await _database.execute(
      '''
      UPDATE $_tableName
      SET status = ?, error_message = ?
      WHERE id = ?
      ''',
      [status, errorMessage, id],
    );
  }

  Future<void> incrementRetryCount(final String id) async {
    await _database.execute(
      '''
      UPDATE $_tableName
      SET retry_count = retry_count + 1
      WHERE id = ?
      ''',
      [id],
    );
  }

  Future<void> deleteTransaction(final String id) async {
    await _database.execute(
      'DELETE FROM $_tableName WHERE id = ?',
      [id],
    );
  }

  Future<void> deleteAllForUser(final String userId) async {
    await _database.execute(
      'DELETE FROM $_tableName WHERE user_id = ?',
      [userId],
    );
  }

  Future<int> getPendingCount(final String userId) async {
    final result = await _database.getOptional(
      '''
      SELECT COUNT(*) as count FROM $_tableName
      WHERE user_id = ? AND (status = 'pending' OR status = 'failed')
      ''',
      [userId],
    );

    return result?['count'] as int? ?? 0;
  }

  QueuedTransaction _rowToTransaction(final Map<String, dynamic> row) {
    return QueuedTransaction(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      title: row['title'] as String,
      amount: row['amount'] as double,
      transactionDate: DateTime.parse(row['transaction_date'] as String),
      categoryId: row['category_id'] as String?,
      categoryName: row['category_name'] as String?,
      notes: row['notes'] as String?,
      tags: (row['tags'] as String?)?.split(','),
      accountId: row['account_id'] as String?,
      attachmentPath: row['attachment_path'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      status: row['status'] as String? ?? 'pending',
      errorMessage: row['error_message'] as String?,
      retryCount: row['retry_count'] as int? ?? 0,
    );
  }
}
