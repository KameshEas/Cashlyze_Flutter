import 'package:flutter/material.dart';

import '../api/api_exception.dart';

// Small helper to centralize repository error presentation to the user.
String repoErrorMessage(final Object err, {final String? fallback}) {
  if (err is ApiException) return err.message;
  return fallback ?? 'Something went wrong. Please try again.';
}

void showRepoErrorSnackBar(final ScaffoldMessengerState messenger, final Object err, {final String? fallback}) {
  final msg = fallback ?? repoErrorMessage(err);
  try {
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ),
    );
  } catch (_) {}
}
