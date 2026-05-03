/// Maps raw Firebase / network exceptions to user-friendly messages.
///
/// Call [friendlyAuthError] for authentication screens.
/// Call [friendlyFirestoreError] for data-layer errors.
///
/// NEVER show `error.toString()` directly to users.
library;

String friendlyAuthError(Object error) {
  final raw = error.toString().toLowerCase();

  // ── Firebase Auth ──────────────────────────────────────────────────
  if (raw.contains('user-not-found') || raw.contains('no user record')) {
    return 'No account found with this email address.';
  }
  if (raw.contains('wrong-password') || raw.contains('invalid-credential')) {
    return 'Incorrect email or password.';
  }
  if (raw.contains('invalid credentials')) {
    return 'Incorrect email or password.';
  }
  if (raw.contains('email-already-in-use')) {
    return 'An account already exists with this email.';
  }
  if (raw.contains('weak-password')) {
    return 'Password is too weak. Use at least 8 characters.';
  }
  if (raw.contains('invalid-email')) {
    return 'Please enter a valid email address.';
  }
  if (raw.contains('user-disabled')) {
    return 'This account has been disabled. Contact support.';
  }
  if (raw.contains('too-many-requests')) {
    return 'Too many attempts. Please wait a moment and try again.';
  }
  if (raw.contains('operation-not-allowed')) {
    return 'Sign-in method not enabled. Contact support.';
  }
  if (raw.contains('requires-recent-login')) {
    return 'Please sign in again to continue.';
  }
  if (raw.contains('account-exists-with-different-credential')) {
    return 'An account already exists with a different sign-in method.';
  }

  // ── Google Sign-In ─────────────────────────────────────────────────
  if (raw.contains('sign_in_canceled') || raw.contains('sign_in_cancelled')) {
    return 'Sign-in was cancelled.';
  }
  if (raw.contains('sign_in_failed')) {
    return 'Google sign-in failed. Please try again.';
  }

  // ── Network ────────────────────────────────────────────────────────
  if (raw.contains('network-request-failed') ||
      raw.contains('socketexception') ||
      raw.contains('no internet')) {
    return 'Network error. Please check your connection.';
  }

  // ── Fallback ───────────────────────────────────────────────────────
  return 'Something went wrong. Please try again.';
}

String friendlyFirestoreError(Object error) {
  final raw = error.toString().toLowerCase();

  if (raw.contains('permission-denied')) {
    return 'You don\'t have permission to perform this action.';
  }
  if (raw.contains('not-found')) {
    return 'The requested data was not found.';
  }
  if (raw.contains('already-exists')) {
    return 'This record already exists.';
  }
  if (raw.contains('resource-exhausted') || raw.contains('quota')) {
    return 'Service limit reached. Please try again later.';
  }
  if (raw.contains('unavailable') || raw.contains('deadline-exceeded')) {
    return 'Service temporarily unavailable. Please try again.';
  }
  if (raw.contains('network') || raw.contains('socketexception')) {
    return 'Network error. Please check your connection.';
  }

  return 'Something went wrong. Please try again.';
}
