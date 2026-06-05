import 'package:flutter/foundation.dart';

/// Lightweight representation of the currently authenticated user.
///
/// Replaces `firebase_auth.User` throughout the codebase.  The identity is
/// backed by the JWT issued by the Cashlyze backend — not by Firebase Auth.
@immutable
class AuthUser {
  const AuthUser({
    required this.userId,
    required this.email,
  });

  /// The user's unique ID (as returned by `POST /auth/login` or
  /// `POST /auth/register` in the `user_id` field).
  final String userId;

  /// The user's email address.
  final String email;

  /// Always `true` — OTP-based signup guarantees the email is verified before
  /// the account is created.
  bool get emailVerified => true;

  /// Legacy alias so code that previously read `user.uid` (Firebase) continues
  /// to compile without changes while the migration is in progress.
  String get uid => userId;

  @override
  String toString() => 'AuthUser(userId: $userId, email: $email)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthUser &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          email == other.email;

  @override
  int get hashCode => Object.hash(userId, email);
}