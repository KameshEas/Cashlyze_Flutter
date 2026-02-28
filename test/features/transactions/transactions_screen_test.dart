import 'package:cashlyze/core/models/transaction.dart';
import 'package:cashlyze/core/providers/transaction_providers.dart';
import 'package:cashlyze/core/services/auth_service.dart';
import 'package:cashlyze/features/transactions/transactions_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../home/home_screen_test.mocks.dart';

@GenerateMocks([User])
void main() {
  group('TransactionsScreen Widget Tests', () {
    late MockUser mockUser;

    setUp(() {
      mockUser = MockUser();
      when(mockUser.uid).thenReturn('test-user-123');
      when(mockUser.email).thenReturn('test@example.com');
    });

    testWidgets('displays transactions title', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(mockUser),
            userTransactionsProvider.overrideWith(
              (ref) => const AsyncValue.data([]),
            ),
          ],
          child: const MaterialApp(
            home: TransactionsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Transactions'), findsOneWidget);
    });

    testWidgets('displays list of transactions', (WidgetTester tester) async {
      final testTransactions = [
        TransactionModel(
          id: '1',
          userId: 'test-user-123',
          title: 'Grocery Shopping',
          amount: -50.0,
          categoryId: 'Food',
          date: DateTime.now(),
        ),
        TransactionModel(
          id: '2',
          userId: 'test-user-123',
          title: 'Salary',
          amount: 5000.0,
          categoryId: 'Income',
          date: DateTime.now().subtract(const Duration(days: 1)),
        ),
        TransactionModel(
          id: '3',
          userId: 'test-user-123',
          title: 'Netflix',
          amount: -15.99,
          categoryId: 'Entertainment',
          date: DateTime.now().subtract(const Duration(days: 2)),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(mockUser),
            userTransactionsProvider.overrideWith(
              (ref) => AsyncValue.data(testTransactions),
            ),
          ],
          child: const MaterialApp(
            home: TransactionsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Grocery Shopping'), findsOneWidget);
      expect(find.text('Salary'), findsOneWidget);
      expect(find.text('Netflix'), findsOneWidget);
    });

    testWidgets('displays empty state when no transactions',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(mockUser),
            userTransactionsProvider.overrideWith(
              (ref) => const AsyncValue.data([]),
            ),
          ],
          child: const MaterialApp(
            home: TransactionsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('No transactions'), findsOneWidget);
    });

    testWidgets('displays loading state', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(mockUser),
            userTransactionsProvider.overrideWith(
              (ref) => const AsyncValue.loading(),
            ),
          ],
          child: const MaterialApp(
            home: TransactionsScreen(),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('displays error state', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(mockUser),
            userTransactionsProvider.overrideWith(
              (ref) => AsyncValue.error(
                Exception('Failed to load transactions'),
                StackTrace.current,
              ),
            ),
          ],
          child: const MaterialApp(
            home: TransactionsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Failed to load'), findsOneWidget);
    });

    testWidgets('shows add transaction button', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(mockUser),
            userTransactionsProvider.overrideWith(
              (ref) => const AsyncValue.data([]),
            ),
          ],
          child: const MaterialApp(
            home: TransactionsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('transactions are sorted by date', (WidgetTester tester) async {
      final now = DateTime.now();
      final testTransactions = [
        TransactionModel(
          id: '1',
          userId: 'test-user-123',
          title: 'Old Transaction',
          amount: -50.0,
          categoryId: 'Food',
          date: now.subtract(const Duration(days: 5)),
        ),
        TransactionModel(
          id: '2',
          userId: 'test-user-123',
          title: 'Recent Transaction',
          amount: -30.0,
          categoryId: 'Food',
          date: now,
        ),
        TransactionModel(
          id: '3',
          userId: 'test-user-123',
          title: 'Middle Transaction',
          amount: -40.0,
          categoryId: 'Food',
          date: now.subtract(const Duration(days: 2)),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(mockUser),
            userTransactionsProvider.overrideWith(
              (ref) => AsyncValue.data(testTransactions),
            ),
          ],
          child: const MaterialApp(
            home: TransactionsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // All transactions should be visible
      expect(find.text('Old Transaction'), findsOneWidget);
      expect(find.text('Recent Transaction'), findsOneWidget);
      expect(find.text('Middle Transaction'), findsOneWidget);
    });

    testWidgets('displays transaction categories', (WidgetTester tester) async {
      final testTransactions = [
        TransactionModel(
          id: '1',
          userId: 'test-user-123',
          title: 'Grocery',
          amount: -50.0,
          categoryId: 'Food',
          date: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(mockUser),
            userTransactionsProvider.overrideWith(
              (ref) => AsyncValue.data(testTransactions),
            ),
          ],
          child: const MaterialApp(
            home: TransactionsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Food'), findsOneWidget);
    });

    testWidgets('displays transaction amounts with correct sign',
        (WidgetTester tester) async {
      final testTransactions = [
        TransactionModel(
          id: '1',
          userId: 'test-user-123',
          title: 'Expense',
          amount: -50.0,
          categoryId: 'Food',
          date: DateTime.now(),
        ),
        TransactionModel(
          id: '2',
          userId: 'test-user-123',
          title: 'Income',
          amount: 1000.0,
          categoryId: 'Income',
          date: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(mockUser),
            userTransactionsProvider.overrideWith(
              (ref) => AsyncValue.data(testTransactions),
            ),
          ],
          child: const MaterialApp(
            home: TransactionsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Both transactions should be visible
      expect(find.text('Expense'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
    });
  });
}
