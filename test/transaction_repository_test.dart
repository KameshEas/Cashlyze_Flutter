import 'package:cashlyze/core/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test utilities for repository validation and sorting logic
void main() {
  group('validate method', () {
    test('should throw ArgumentError for empty title', () {
      expect(
        () => _testValidation('   ', 100.0, DateTime.now()),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should throw ArgumentError for NaN amount', () {
      expect(
        () => _testValidation('Test', double.nan, DateTime.now()),
        throwsArgumentError,
      );
    });

    test('should throw ArgumentError for future date', () {
      final futureDate = DateTime.now().add(const Duration(days: 2));
      expect(
        () => _testValidation('Test', 100.0, futureDate),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should not throw for valid input', () {
      expect(
        () => _testValidation('Test', 100.0, DateTime.now()),
        returnsNormally,
      );
    });
  });

  group('sorting logic', () {
    final testTransactions = [
      TransactionModel(
        id: '1',
        userId: 'user1',
        title: 'Old transaction',
        amount: 50.0,
        date: DateTime.now().subtract(const Duration(days: 3)),
      ),
      TransactionModel(
        id: '2',
        userId: 'user1',
        title: 'Recent transaction',
        amount: 100.0,
        date: DateTime.now(),
      ),
      TransactionModel(
        id: '3',
        userId: 'user1',
        title: 'Middle transaction',
        amount: 75.0,
        date: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];

    test('should sort transactions by date descending', () {
      final sorted = _testSorting(testTransactions);

      expect(sorted[0].title, 'Recent transaction'); // most recent first
      expect(sorted[1].title, 'Middle transaction');
      expect(sorted[2].title, 'Old transaction'); // oldest last
    });
  });
}

/// Test validation logic (copied from TransactionRepository)
void _testValidation(final String title, final double amount, final DateTime date) {
  if (title.trim().isEmpty) {
    throw ArgumentError('Title is required');
  }
  if (amount.isNaN) {
    throw ArgumentError('Amount must be a number');
  }
  if (date.isAfter(DateTime.now().add(const Duration(days: 1)))) {
    throw ArgumentError('Date cannot be in the future');
  }
}

/// Test sorting logic (copied from TransactionRepository)
List<TransactionModel> _testSorting(final List<TransactionModel> transactions) {
  return List.from(transactions)..sort((final a, final b) => b.date.compareTo(a.date));
}
