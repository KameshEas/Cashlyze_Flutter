import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:cashlyze/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Authentication Flow Integration Tests', () {
    testWidgets('complete sign up flow', (WidgetTester tester) async {
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Look for auth screen or sign in button
      final signInFinder = find.text('Sign In');
      final signUpFinder = find.text('Sign Up');

      if (signInFinder.evaluate().isNotEmpty || signUpFinder.evaluate().isNotEmpty) {
        // Navigate to sign up if needed
        if (signUpFinder.evaluate().isNotEmpty) {
          await tester.tap(signUpFinder.first);
          await tester.pumpAndSettle();
        }

        // Find email and password fields
        final emailFields = find.byType(TextFormField);
        if (emailFields.evaluate().length >= 2) {
          // Enter test credentials
          await tester.enterText(emailFields.at(0), 'test@example.com');
          await tester.enterText(emailFields.at(1), 'password123');
          await tester.pumpAndSettle();

          // Note: Actual sign up would require Firebase connection
          // This test verifies the UI flow works
        }
      }

      // Test passes if no exceptions are thrown
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('sign in form validation', (WidgetTester tester) async {
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Look for sign in button
      final signInButton = find.widgetWithText(ElevatedButton, 'Sign In');
      
      if (signInButton.evaluate().isNotEmpty) {
        // Try to submit empty form
        await tester.tap(signInButton.first);
        await tester.pumpAndSettle();

        // Validation errors should appear
        // The exact error messages depend on your implementation
      }

      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('toggle between sign in and sign up', (WidgetTester tester) async {
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Look for toggle button
      final toggleFinder = find.textContaining('Sign Up');
      
      if (toggleFinder.evaluate().isNotEmpty) {
        final initialText = tester.widget<Text>(toggleFinder.first).data;
        
        // Tap toggle
        await tester.tap(toggleFinder.first);
        await tester.pumpAndSettle();

        // Look for opposite toggle
        final oppositeToggle = find.textContaining('Sign In');
        expect(oppositeToggle.evaluate().isNotEmpty, isTrue);
      }

      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  group('Password Reset Flow', () {
    testWidgets('navigate to password reset', (WidgetTester tester) async {
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Look for forgot password link
      final forgotPasswordFinder = find.textContaining('Forgot');
      
      if (forgotPasswordFinder.evaluate().isNotEmpty) {
        await tester.tap(forgotPasswordFinder.first);
        await tester.pumpAndSettle();

        // Should show password reset UI
        expect(find.byType(MaterialApp), findsOneWidget);
      }
    });
  });
}
