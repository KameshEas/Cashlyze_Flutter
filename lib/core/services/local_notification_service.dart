import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LocalNotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);

    try {
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (final response) {
          if (kDebugMode) debugPrint('Local notification tapped: ${response.payload}');
        },
      );
      _initialized = true;
      if (kDebugMode) debugPrint('LocalNotificationService initialized');
    } catch (e) {
      if (kDebugMode) debugPrint('LocalNotificationService init failed: $e');
    }
  }

  Future<void> showNotification({
    required final String id,
    required final String title,
    required final String body,
    final Map<String, dynamic>? data,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'budget_alerts_channel',
        'Budget Alerts',
        channelDescription: 'Notifications when budgets cross thresholds',
        importance: Importance.high,
        priority: Priority.high,
      );
      const iosDetails = DarwinNotificationDetails();
      const notifDetails = NotificationDetails(android: androidDetails, iOS: iosDetails);

      final payload = data == null ? null : jsonEncode(data);
      await _plugin.show(
        id: id.hashCode & 0x7fffffff,
        title: title,
        body: body,
        notificationDetails: notifDetails,
        payload: payload,
      );
      if (kDebugMode) debugPrint('Local notification shown: $title');
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to show local notification: $e');
    }
  }
}

final localNotificationServiceProvider = Provider<LocalNotificationService>((final ref) {
  return LocalNotificationService();
});
