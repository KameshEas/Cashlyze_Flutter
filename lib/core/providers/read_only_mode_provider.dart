import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the backend has put the app in read-only maintenance.
///
/// Kept in its own dependency-free file so the API client can read it without
/// importing the version providers (which themselves depend on the API client).
class ReadOnlyModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  // ignore: use_setters_to_change_properties
  void update(final bool value) => state = value;
}

final readOnlyModeProvider =
    NotifierProvider<ReadOnlyModeNotifier, bool>(ReadOnlyModeNotifier.new);
