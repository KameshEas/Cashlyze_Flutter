import 'dart:async';

/// What a tapped push notification asks the app to do (set from an
/// announcement's button in the admin console).
class PushAction {
  const PushAction({required this.ctaType, this.ctaValue});

  /// `url` | `route` | `store`
  final String ctaType;
  final String? ctaValue;
}

/// Reads the `data` an announcement push carries, or null if the notification
/// has no action for the app to take (e.g. a plain push).
PushAction? parsePushAction(final Map<String, dynamic>? data) {
  if (data == null) return null;
  final type = data['ctaType'];
  if (type is! String || !const {'url', 'route', 'store'}.contains(type)) return null;
  final value = data['ctaValue'];
  return PushAction(ctaType: type, ctaValue: value is String ? value : null);
}

/// Notification taps, from OneSignal's click listener (set up in `main`) to
/// the widget that can act on them.
///
/// Single-subscription on purpose: a tap that launches the app from a closed
/// state can arrive before that widget exists, and this queues it until the
/// widget starts listening instead of dropping it.
final pushActionEvents = StreamController<PushAction>();
