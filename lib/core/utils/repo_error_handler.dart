import 'package:flutter/material.dart';

// Small helper to centralize repository error presentation to the user.
String repoErrorMessage(final Object err) {
  try {
    return err.toString();
  } catch (_) {
    return 'Operation failed';
  }
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
