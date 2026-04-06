import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
// Note: We intentionally avoid calling OneSignal SDK methods here because
// the app initializes OneSignal in `main.dart` and server-side delivery
// should be preferred. This service will attempt REST delivery when a
// REST key is provided; otherwise it logs the notification for later
// processing by backend components.

/// Simple notification service that sends budget-alert notifications.
///
/// Behavior:
/// - If `ONESIGNAL_REST_KEY` is present in the environment, uses the
///   OneSignal REST API to post a notification to the current device.
/// - Otherwise attempts to use the OneSignal SDK `postNotification`.
/// - If both fail, logs the payload in debug mode.
class NotificationService {
  final String appId;
  final String? restKey;

  NotificationService({required this.appId, required this.restKey});

  Future<void> sendBudgetThresholdNotification({
    required String userPlayerId,
    required String budgetId,
    required String budgetName,
    required double allocated,
    required double spent,
    required double thresholdPercent,
  }) async {
    final title = 'Budget alert: $budgetName';
    final utilPercent = (allocated == 0) ? 100.0 : (spent / allocated * 100);
    final body = '$budgetName budget reached ${utilPercent.toStringAsFixed(0)}% of allocated (threshold ${(thresholdPercent * 100).toStringAsFixed(0)}%). Allocated: ${allocated.toStringAsFixed(2)}, Spent: ${spent.toStringAsFixed(2)}.';

    // Prefer server-side REST API when REST key available.
    if (restKey != null && restKey!.isNotEmpty && userPlayerId.isNotEmpty) {
      final url = Uri.parse('https://onesignal.com/api/v1/notifications');
      final payload = {
        'app_id': appId,
        'include_player_ids': [userPlayerId],
        'headings': {'en': title},
        'contents': {'en': body},
        'data': {'budgetId': budgetId, 'type': 'budget_alert'},
      };
      try {
        final res = await http.post(
          url,
          headers: {
            'Authorization': 'Basic $restKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(payload),
        );
        if (res.statusCode >= 200 && res.statusCode < 300) {
          if (kDebugMode) debugPrint('OneSignal REST: notification posted for $budgetId');
        } else {
          if (kDebugMode) debugPrint('OneSignal REST failed: ${res.statusCode} ${res.body}');
        }
        return;
      } catch (e) {
        if (kDebugMode) debugPrint('OneSignal REST exception: $e');
      }
    }

    // No SDK fallback available here — rely on server-side processing.
    if (kDebugMode) debugPrint('No immediate SDK delivery attempted for $budgetId (REST key not configured)');

    // Final fallback: log payload for debugging.
    if (kDebugMode) {
      debugPrint('Notification fallback: $title - $body');
    }
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final appId = dotenv.env['ONESIGNAL_APP_ID'] ?? '37af7f2d-22d4-4eac-972b-50cb1377fbb8';
  final restKey = dotenv.env['ONESIGNAL_REST_KEY'];
  return NotificationService(appId: appId, restKey: restKey);
});
