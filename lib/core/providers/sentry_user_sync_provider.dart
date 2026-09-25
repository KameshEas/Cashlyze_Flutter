import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../models/auth_user.dart';
import '../services/auth_service.dart';

/// Keeps Sentry's user scope in sync with sign-in state, so crash reports
/// can be grouped by user without sending PII: only the internal user id
/// (a UUID, not the email), matching this app's "anonymous id only" choice.
///
/// Must be watched (e.g. in `main.dart` App build) so it registers its
/// listener on app startup, the same as `budgetAlertsHandlerProvider`.
final sentryUserSyncProvider = Provider<void>((final ref) {
  ref.listen<AuthUser?>(currentUserProvider, (final previous, final next) {
    Sentry.configureScope((final scope) {
      scope.setUser(next == null ? null : SentryUser(id: next.userId));
    });
  }, fireImmediately: true);
});
