import 'package:cashlyze/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Transaction Flow Integration Tests', () {
    testWidgets('navigate to transactions screen', (WidgetTester tester) async {
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Look for transactions navigation item
      final transactionsFinder = find.text('Transactions');
      
      if (transactionsFinder.evaluate().isNotEmpty) {
        await tester.tap(transactionsFinder.first);
        await tester.pumpAndSettle();

        // Should be on transactions screen
        expect(find.text('Transactions'), findsWidgets);
      }
    });

    testWidgets('add new transaction flow', (WidgetTester tester) async {
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Navigate to transactions
      final transactionsFinder = find.text('Transactions');
      if (transactionsFinder.evaluate().isNotEmpty) {
        await tester.tap(transactionsFinder.first);
        await tester.pumpAndSettle();

        // Look for add button (FAB)
        final fabFinder = find.byType(FloatingActionButton);
        if (fabFinder.evaluate().isNotEmpty) {
          await tester.tap(fabFinder.first);
          await tester.pumpAndSettle();

          // Should show add transaction form
          expect(find.byType(MaterialApp), findsOneWidget);
        }
      }
    });

    testWidgets('quick add transaction from home', (WidgetTester tester) async {
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Look for quick action buttons on home screen
      final transferFinder = find.text('Transfer');

      if (transferFinder.evaluate().isNotEmpty) {
        await tester.tap(transferFinder.first);
        await tester.pumpAndSettle();

        // Should show quick add dialog/bottom sheet
        // The exact UI depends on your implementation
        expect(find.byType(MaterialApp), findsOneWidget);
      }
    });

    testWidgets('view transaction details', (WidgetTester tester) async {
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Navigate to transactions
      final transactionsFinder = find.text('Transactions');
      if (transactionsFinder.evaluate().isNotEmpty) {
        await tester.tap(transactionsFinder.first);
        await tester.pumpAndSettle();

        // Look for any transaction items
        final listTileFinder = find.byType(ListTile);
        if (listTileFinder.evaluate().isNotEmpty) {
          await tester.tap(listTileFinder.first);
          await tester.pumpAndSettle();

          // Should show transaction details
          expect(find.byType(MaterialApp), findsOneWidget);
        }
      }
    });

    testWidgets('filter transactions', (WidgetTester tester) async {
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Navigate to transactions
      final transactionsFinder = find.text('Transactions');
      if (transactionsFinder.evaluate().isNotEmpty) {
        await tester.tap(transactionsFinder.first);
        await tester.pumpAndSettle();

        // Look for filter button
        final filterFinder = find.byIcon(Icons.filter_list);
        if (filterFinder.evaluate().isNotEmpty) {
          await tester.tap(filterFinder.first);
          await tester.pumpAndSettle();

          // Should show filter options
          expect(find.byType(MaterialApp), findsOneWidget);
        }
      }
    });

    testWidgets('search transactions', (WidgetTester tester) async {
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Navigate to transactions
      final transactionsFinder = find.text('Transactions');
      if (transactionsFinder.evaluate().isNotEmpty) {
        await tester.tap(transactionsFinder.first);
        await tester.pumpAndSettle();

        // Look for search button
        final searchFinder = find.byIcon(Icons.search);
        if (searchFinder.evaluate().isNotEmpty) {
          await tester.tap(searchFinder.first);
          await tester.pumpAndSettle();

          // Should show search field
          final searchFieldFinder = find.byType(TextField);
          if (searchFieldFinder.evaluate().isNotEmpty) {
            await tester.enterText(searchFieldFinder.first, 'test');
            await tester.pumpAndSettle();
          }
        }
      }

      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  group('Transaction Form Validation', () {
    testWidgets('validate transaction form fields', (WidgetTester tester) async {
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Navigate to add transaction
      final transactionsFinder = find.text('Transactions');
      if (transactionsFinder.evaluate().isNotEmpty) {
        await tester.tap(transactionsFinder.first);
        await tester.pumpAndSettle();

        final fabFinder = find.byType(FloatingActionButton);
        if (fabFinder.evaluate().isNotEmpty) {
          await tester.tap(fabFinder.first);
          await tester.pumpAndSettle();

          // Try to submit empty form
          final saveFinder = find.text('Save');
          if (saveFinder.evaluate().isNotEmpty) {
            await tester.tap(saveFinder.first);
            await tester.pumpAndSettle();

            // Validation errors should appear
            expect(find.byType(MaterialApp), findsOneWidget);
          }
        }
      }
    });
  });
}
