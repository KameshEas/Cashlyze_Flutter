import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/connectivity_service.dart';

/// Provider that exposes connectivity status
/// Refreshes every 10 seconds to check connection state
final connectivityProvider = FutureProvider<bool>((final ref) async {
  return ConnectivityService.hasInternetConnection();
});

/// Notifier that tracks connectivity status
class ConnectivityNotifier extends Notifier<bool> {
  Timer? _timer;

  @override
  bool build() {
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
    });
    _startMonitoring();
    return true;
  }

  void _startMonitoring() {
    _timer = Timer(const Duration(seconds: 10), () async {
      final isConnected = await ConnectivityService.hasInternetConnection();
      state = isConnected;
      _startMonitoring();
    });
  }
}

/// NotifierProvider for real-time connectivity tracking
final connectivityStateProvider = NotifierProvider<ConnectivityNotifier, bool>(
  ConnectivityNotifier.new,
);
