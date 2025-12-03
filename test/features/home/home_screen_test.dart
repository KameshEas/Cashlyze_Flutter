import 'package:cashlyze/core/models/transaction.dart';
import 'package:cashlyze/core/providers/insights_providers.dart';
import 'package:cashlyze/core/providers/transaction_providers.dart';
import 'package:cashlyze/core/services/auth_service.dart';
import 'package:cashlyze/features/home/home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'home_screen_test.mocks.dart';

@GenerateMocks([User])
void main() {
  group('HomeScreen Widget Tests', () {
    late MockUser mockUser;

    setUp(() {
      mockUser = MockUser();
      when(mockUser.uid).thenReturn('test-user-123');
      when(mockUser.email).thenReturn('test@example.com');
      when(mockUser.emailVerified).thenReturn(true);
    });

    testWidgets('displays dashboard title', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(mockUser),
            kpisProvider.overrideWith((ref) => const Kpis(
                  5000, // income
                  3000, // expense
                  2000, // net
                  0.4, // savingsRate
                  100, // avgDailySpend
                  10, // txCount
                  500, // largestExpense
                )),
            recentTransactionsProvider.overrideWith(
              (ref) => const AsyncValue<List<TransactionModel>>.data([]),
            ),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Dashboard'), findsOneWidget);
    });

    testWidgets('displays balance card with correct values',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(mockUser),
            kpisProvider.overrideWith((ref) => const Kpis(
                  5000, 3000, 2000, 0.4, 100, 10, 500,
                )),
            recentTransactionsProvider.overrideWith(
              (ref) => const AsyncValue<List<TransactionModel>>.data([]),
            ),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Total Balance'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Expense'), findsOneWidget);
    });

    testWidgets('displays quick actions', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(mockUser),
            kpisProvider.overrideWith((ref) => const Kpis(
                  5000, 3000, 2000, 0.4, 100, 10, 500,
                )),
            recentTransactionsProvider.overrideWith(
              (ref) => const AsyncValue<List<TransactionModel>>.data([]),
            ),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Quick Actions'), findsOneWidget);
      expect(find.text('Transfer'), findsOneWidget);
      expect(find.text('Top-up'), findsOneWidget);
      expect(find.text('Bill'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);
    });

    testWidgets('displays recent transactions section',
        (WidgetTester tester) async {
      final now = DateTime.now();
      final testTransactions = [
        TransactionModel(
          id: '1',
          userId: 'test-user-123',
          title: 'Grocery Shopping',
          amount: -50.0,
          categoryId: 'Food',
          date: now,
        ),
        TransactionModel(
          id: '2',
          userId: 'test-user-123',
          title: 'Salary',
          amount: 5000.0,
          categoryId: 'Income',
          date: now,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(mockUser),
            kpisProvider.overrideWith((ref) => const Kpis(
                  5000, 50, 4950, 0.99, 1.67, 2, 50,
                )),
            recentTransactionsProvider.overrideWith(
              (ref) => AsyncValue<List<TransactionModel>>.data(testTransactions),
            ),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Recent Transactions'), findsOneWidget);
      expect(find.text('Grocery Shopping'), findsOneWidget);
      expect(find.text('Salary'), findsOneWidget);
    });

    testWidgets('displays empty state when no transactions',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(mockUser),
            kpisProvider.overrideWith((ref) => const Kpis(
                  0, 0, 0, 0, 0, 0, 0,
                )),
            recentTransactionsProvider.overrideWith(
              (ref) => const AsyncValue<List<TransactionModel>>.data([]),
            ),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No recent transactions'), findsOneWidget);
    });

    testWidgets('displays loading state', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(mockUser),
            kpisProvider.overrideWith((ref) => const Kpis(
                  0, 0, 0, 0, 0, 0, 0,
                )),
            recentTransactionsProvider.overrideWith(
              (ref) => const AsyncValue<List<TransactionModel>>.loading(),
            ),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pump();

      // Should show skeleton loaders
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('displays error state', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(mockUser),
            kpisProvider.overrideWith((ref) => const Kpis(
                  0, 0, 0, 0, 0, 0, 0,
                )),
            recentTransactionsProvider.overrideWith(
              (ref) => AsyncValue<List<TransactionModel>>.error(
                Exception('Failed to load'),
                StackTrace.current,
              ),
            ),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Failed to load'), findsOneWidget);
    });

    testWidgets('notifications button is present', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(mockUser),
            kpisProvider.overrideWith((ref) => const Kpis(
                  0, 0, 0, 0, 0, 0, 0,
                )),
            recentTransactionsProvider.overrideWith(
              (ref) => const AsyncValue<List<TransactionModel>>.data([]),
            ),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
    });

    testWidgets('EMI tracker section is present', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(mockUser),
            kpisProvider.overrideWith((ref) => const Kpis(
                  0, 0, 0, 0, 0, 0, 0,
                )),
            recentTransactionsProvider.overrideWith(
              (ref) => const AsyncValue<List<TransactionModel>>.data([]),
            ),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('EMI Tracker'), findsOneWidget);
    });
  });
}
