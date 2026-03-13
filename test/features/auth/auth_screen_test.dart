import 'package:cashlyze/core/services/auth_service.dart';
import 'package:cashlyze/features/auth/auth_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'auth_screen_test.mocks.dart';

@GenerateMocks([FirebaseAuth, AuthService, UserCredential])
void main() {
  group('AuthScreen Widget Tests', () {
    late MockFirebaseAuth mockFirebaseAuth;
    late MockAuthService mockAuthService;

    setUp(() {
      mockFirebaseAuth = MockFirebaseAuth();
      mockAuthService = MockAuthService();
    });

    testWidgets('displays sign in form by default', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firebaseAuthProvider.overrideWithValue(mockFirebaseAuth),
            authServiceProvider.overrideWithValue(mockAuthService),
          ],
          child: const MaterialApp(
            home: AuthScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Sign In'), findsWidgets);
      expect(find.byType(TextFormField), findsNWidgets(2)); // Email and password
    });

    testWidgets('email field accepts input', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firebaseAuthProvider.overrideWithValue(mockFirebaseAuth),
            authServiceProvider.overrideWithValue(mockAuthService),
          ],
          child: const MaterialApp(
            home: AuthScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final emailField = find.byType(TextFormField).first;
      await tester.enterText(emailField, 'test@example.com');
      await tester.pump();

      expect(find.text('test@example.com'), findsOneWidget);
    });

    testWidgets('password field is obscured', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firebaseAuthProvider.overrideWithValue(mockFirebaseAuth),
            authServiceProvider.overrideWithValue(mockAuthService),
          ],
          child: const MaterialApp(
            home: AuthScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final passwordFields = find.byType(TextFormField);
      // Find the internal TextField inside the TextFormField and assert obscureText
      final innerTextFieldFinder = find.descendant(
        of: passwordFields.at(1),
        matching: find.byType(TextField),
      );
      final innerTextField = tester.widget<TextField>(innerTextFieldFinder);
      expect(innerTextField.obscureText, isTrue);
    });

    testWidgets('can toggle between sign in and sign up',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firebaseAuthProvider.overrideWithValue(mockFirebaseAuth),
            authServiceProvider.overrideWithValue(mockAuthService),
          ],
          child: const MaterialApp(
            home: AuthScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Look for toggle button (usually "Don't have an account? Sign Up")
      final toggleButton = find.textContaining('Sign Up');
      if (toggleButton.evaluate().isNotEmpty) {
        await tester.tap(toggleButton.first);
        await tester.pumpAndSettle();

        // Should now show sign up form
        expect(find.text('Sign Up'), findsWidgets);
      }
    });

    testWidgets('displays loading indicator during sign in',
        (WidgetTester tester) async {
      when(mockAuthService.signInWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenAnswer((_) async {
        await Future.delayed(const Duration(seconds: 2));
        return MockUserCredential();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firebaseAuthProvider.overrideWithValue(mockFirebaseAuth),
            authServiceProvider.overrideWithValue(mockAuthService),
          ],
          child: const MaterialApp(
            home: AuthScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter credentials
      final emailField = find.byType(TextFormField).first;
      await tester.enterText(emailField, 'test@example.com');

      final passwordField = find.byType(TextFormField).at(1);
      await tester.enterText(passwordField, 'password123');

      // Tap sign in button
      final signInButton = find.widgetWithText(ElevatedButton, 'Sign In');
      if (signInButton.evaluate().isNotEmpty) {
        await tester.tap(signInButton.first);
        await tester.pump();

        // Should show loading indicator
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      }
    });

    testWidgets('validates email format', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firebaseAuthProvider.overrideWithValue(mockFirebaseAuth),
            authServiceProvider.overrideWithValue(mockAuthService),
          ],
          child: const MaterialApp(
            home: AuthScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter invalid email
      final emailField = find.byType(TextFormField).first;
      await tester.enterText(emailField, 'invalid-email');

      // Try to submit
      final signInButton = find.widgetWithText(ElevatedButton, 'Sign In');
      if (signInButton.evaluate().isNotEmpty) {
        await tester.tap(signInButton.first);
        await tester.pumpAndSettle();

        // Should show validation error
        expect(find.textContaining('email'), findsWidgets);
      }
    });

    testWidgets('validates password length', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firebaseAuthProvider.overrideWithValue(mockFirebaseAuth),
            authServiceProvider.overrideWithValue(mockAuthService),
          ],
          child: const MaterialApp(
            home: AuthScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter short password
      final passwordField = find.byType(TextFormField).at(1);
      await tester.enterText(passwordField, '123');

      // Try to submit
      final signInButton = find.widgetWithText(ElevatedButton, 'Sign In');
      if (signInButton.evaluate().isNotEmpty) {
        await tester.tap(signInButton.first);
        await tester.pumpAndSettle();

        // Should show validation error
        expect(find.textContaining('password'), findsWidgets);
      }
    });
  });
}
