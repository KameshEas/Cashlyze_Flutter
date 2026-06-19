import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/shared_prefs_provider.dart';
import '../repositories/budget_repository.dart';
import '../services/auth_service.dart';
import '../services/local_notification_service.dart';
import '../services/notification_service.dart';
import 'budget_providers.dart';

/// Provider that listens to budget utilization changes and sends a
/// push notification when a budget crosses the user-configured threshold.
///
/// This provider must be watched (e.g. in `main.dart` App build) so it
/// registers its listener on app startup.
final budgetAlertsHandlerProvider = Provider<void>((final ref) {
  final notified = <String>{};

  ref.listen<Map<String, double>>(budgetsUtilizationProvider, (final previous, final next) {
    final prefs = ref.read(sharedPrefsServiceProvider);
    if (!prefs.alertsEnabled) return;
    final threshold = prefs.alertThreshold;

    // Access the latest budgets (async stream provider). Use whenData
    // to avoid awaiting inside the listener directly.
    final budgetsAsync = ref.read(userBudgetsProvider);
    budgetsAsync.whenData((final budgets) async {
      final user = ref.read(currentUserProvider);
      if (user == null) return;
      for (final b in budgets) {
        final prevSpent = previous == null ? 0.0 : (previous[b.id] ?? 0.0);
        final prevUtil = b.allocated == 0 ? 0.0 : (prevSpent / b.allocated);

        final newSpent = next[b.id] ?? 0.0;
        final newUtil = b.allocated == 0 ? 0.0 : (newSpent / b.allocated);

        final alreadyNotified = notified.contains(b.id);

        // Notify when we cross the threshold upward (avoid repeats).
        if (!alreadyNotified && newUtil >= threshold && prevUtil < threshold) {
          notified.add(b.id);

          final title = 'Budget alert: ${b.name}';
          final utilPercent = (b.allocated == 0) ? 100.0 : (newSpent / b.allocated * 100);
          final body = '${b.name} budget reached ${utilPercent.toStringAsFixed(0)}% of allocated (threshold ${(threshold * 100).toStringAsFixed(0)}%).';

          try {
            // 1) Show a local notification immediately on this device so the
            // user gets alerted even without a server-side push configured.
            await ref.read(localNotificationServiceProvider).showNotification(
              id: b.id,
              title: title,
              body: body,
              data: {'budgetId': b.id},
            );
          } catch (e) {
            if (kDebugMode) print('Failed to show local notification: $e');
          }

          try {
            // 2) Attempt immediate delivery via client-side NotificationService
            // (REST-based) if configured. This is best-effort and may be
            // disabled when there is no server REST key.
            await ref.read(notificationServiceProvider).sendBudgetThresholdNotification(
              userPlayerId: '',
              budgetId: b.id,
              budgetName: b.name,
              allocated: b.allocated,
              spent: newSpent,
              thresholdPercent: threshold,
            );
          } catch (e) {
            if (kDebugMode) print('Failed to trigger immediate remote notification: $e');
          }
        }

        // Clear notification flag when utilization drops below threshold
        // so future crossings can trigger again.
        if (alreadyNotified && newUtil < threshold) {
          notified.remove(b.id);
        }
      }
    });
  });
});
