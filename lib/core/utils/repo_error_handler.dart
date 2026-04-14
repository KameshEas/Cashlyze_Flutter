import 'package:flutter/material.dart';

// Small helper to centralize repository error presentation to the user.
String repoErrorMessage(Object err) {
  try {
    return err.toString();
  } catch (_) {
    return 'Operation failed';
  }
}

void showRepoErrorSnackBar(ScaffoldMessengerState messenger, Object err, {String? fallback}) {
  final msg = fallback ?? repoErrorMessage(err);
  try {
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  } catch (_) {}
}
