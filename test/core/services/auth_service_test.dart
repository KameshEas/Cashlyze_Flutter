import 'package:cashlyze/core/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'auth_service_test.mocks.dart';

@GenerateMocks([FirebaseAuth, UserCredential, User])
void main() {
  group('AuthService', () {
    late MockFirebaseAuth mockFirebaseAuth;
    late AuthService authService;
    late MockUserCredential mockUserCredential;
    late MockUser mockUser;

    setUp(() {
      mockFirebaseAuth = MockFirebaseAuth();
      authService = AuthService(mockFirebaseAuth);
      mockUserCredential = MockUserCredential();
      mockUser = MockUser();
    });

    group('signInWithEmailAndPassword', () {
      test('successfully signs in user', () async {
        when(mockFirebaseAuth.signInWithEmailAndPassword(
          email: anyNamed('email'),
          password: anyNamed('password'),
        )).thenAnswer((_) async => mockUserCredential);

        final result = await authService.signInWithEmailAndPassword(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(result, mockUserCredential);
        verify(mockFirebaseAuth.signInWithEmailAndPassword(
          email: 'test@example.com',
          password: 'password123',
        )).called(1);
      });

      test('throws error for invalid email', () async {
        when(mockFirebaseAuth.signInWithEmailAndPassword(
          email: anyNamed('email'),
          password: anyNamed('password'),
        )).thenThrow(
          FirebaseAuthException(code: 'invalid-email'),
        );

        expect(
          () => authService.signInWithEmailAndPassword(
            email: 'invalid',
            password: 'password123',
          ),
          throwsA(isA<String>()),
        );
      });

      test('throws error for wrong password', () async {
        when(mockFirebaseAuth.signInWithEmailAndPassword(
          email: anyNamed('email'),
          password: anyNamed('password'),
        )).thenThrow(
          FirebaseAuthException(code: 'wrong-password'),
        );

        expect(
          () => authService.signInWithEmailAndPassword(
            email: 'test@example.com',
            password: 'wrongpassword',
          ),
          throwsA(isA<String>()),
        );
      });

      test('throws error for user not found', () async {
        when(mockFirebaseAuth.signInWithEmailAndPassword(
          email: anyNamed('email'),
          password: anyNamed('password'),
        )).thenThrow(
          FirebaseAuthException(code: 'user-not-found'),
        );

        expect(
          () => authService.signInWithEmailAndPassword(
            email: 'nonexistent@example.com',
            password: 'password123',
          ),
          throwsA(isA<String>()),
        );
      });
    });

    group('createUserWithEmailAndPassword', () {
      test('successfully creates user', () async {
        when(mockFirebaseAuth.createUserWithEmailAndPassword(
          email: anyNamed('email'),
          password: anyNamed('password'),
        )).thenAnswer((_) async => mockUserCredential);

        final result = await authService.createUserWithEmailAndPassword(
          email: 'newuser@example.com',
          password: 'password123',
        );

        expect(result, mockUserCredential);
        verify(mockFirebaseAuth.createUserWithEmailAndPassword(
          email: 'newuser@example.com',
          password: 'password123',
        )).called(1);
      });

      test('throws error for weak password', () async {
        when(mockFirebaseAuth.createUserWithEmailAndPassword(
          email: anyNamed('email'),
          password: anyNamed('password'),
        )).thenThrow(
          FirebaseAuthException(code: 'weak-password'),
        );

        expect(
          () => authService.createUserWithEmailAndPassword(
            email: 'test@example.com',
            password: '123',
          ),
          throwsA(isA<String>()),
        );
      });

      test('throws error for email already in use', () async {
        when(mockFirebaseAuth.createUserWithEmailAndPassword(
          email: anyNamed('email'),
          password: anyNamed('password'),
        )).thenThrow(
          FirebaseAuthException(code: 'email-already-in-use'),
        );

        expect(
          () => authService.createUserWithEmailAndPassword(
            email: 'existing@example.com',
            password: 'password123',
          ),
          throwsA(isA<String>()),
        );
      });
    });

    group('signOut', () {
      test('successfully signs out user', () async {
        when(mockFirebaseAuth.signOut()).thenAnswer((_) async => {});

        await authService.signOut();

        verify(mockFirebaseAuth.signOut()).called(1);
      });
    });

    group('sendPasswordResetEmail', () {
      test('successfully sends password reset email', () async {
        when(mockFirebaseAuth.sendPasswordResetEmail(
          email: anyNamed('email'),
        )).thenAnswer((_) async => {});

        await authService.sendPasswordResetEmail('test@example.com');

        verify(mockFirebaseAuth.sendPasswordResetEmail(
          email: 'test@example.com',
        )).called(1);
      });

      test('throws error for invalid email', () async {
        when(mockFirebaseAuth.sendPasswordResetEmail(
          email: anyNamed('email'),
        )).thenThrow(
          FirebaseAuthException(code: 'invalid-email'),
        );

        expect(
          () => authService.sendPasswordResetEmail('invalid'),
          throwsA(isA<String>()),
        );
      });
    });

    group('sendEmailVerification', () {
      test('sends verification email for unverified user', () async {
        when(mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(mockUser.emailVerified).thenReturn(false);
        when(mockUser.reload()).thenAnswer((_) async => {});
        when(mockUser.sendEmailVerification()).thenAnswer((_) async => {});

        await authService.sendEmailVerification();

        verify(mockUser.sendEmailVerification()).called(1);
      });

      test('does not send verification for verified user', () async {
        when(mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(mockUser.emailVerified).thenReturn(true);

        await authService.sendEmailVerification();

        verifyNever(mockUser.sendEmailVerification());
      });

      test('handles null user', () async {
        when(mockFirebaseAuth.currentUser).thenReturn(null);

        await authService.sendEmailVerification();

        verifyNever(mockUser.sendEmailVerification());
      });
    });

    group('currentUser', () {
      test('returns current user when signed in', () {
        when(mockFirebaseAuth.currentUser).thenReturn(mockUser);

        final user = authService.currentUser;

        expect(user, mockUser);
      });

      test('returns null when not signed in', () {
        when(mockFirebaseAuth.currentUser).thenReturn(null);

        final user = authService.currentUser;

        expect(user, isNull);
      });
    });

    group('updateProfile', () {
      test('successfully updates display name', () async {
        when(mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(mockUser.updateDisplayName(any)).thenAnswer((_) async => {});
        when(mockUser.updatePhotoURL(any)).thenAnswer((_) async => {});
        when(mockUser.reload()).thenAnswer((_) async => {});

        await authService.updateProfile(displayName: 'John Doe');

        verify(mockUser.updateDisplayName('John Doe')).called(1);
        verify(mockUser.reload()).called(1);
      });

      test('successfully updates photo URL', () async {
        when(mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(mockUser.updateDisplayName(any)).thenAnswer((_) async => {});
        when(mockUser.updatePhotoURL(any)).thenAnswer((_) async => {});
        when(mockUser.reload()).thenAnswer((_) async => {});

        await authService.updateProfile(photoURL: 'https://example.com/photo.jpg');

        verify(mockUser.updatePhotoURL('https://example.com/photo.jpg')).called(1);
        verify(mockUser.reload()).called(1);
      });
    });

    group('deleteAccount', () {
      test('successfully deletes user account', () async {
        when(mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(mockUser.delete()).thenAnswer((_) async => {});

        await authService.deleteAccount();

        verify(mockUser.delete()).called(1);
      });

      test('handles null user', () async {
        when(mockFirebaseAuth.currentUser).thenReturn(null);

        await authService.deleteAccount();

        verifyNever(mockUser.delete());
      });
    });
  });
}
