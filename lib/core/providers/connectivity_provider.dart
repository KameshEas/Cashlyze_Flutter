import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/connectivity_service.dart';

/// Provider that exposes connectivity status
/// Refreshes every 10 seconds to check connection state
final connectivityProvider = FutureProvider<bool>((final ref) async {
  return ConnectivityService.hasInternetConnection();
});

/// Notifier that tracks connectivity status
class ConnectivityNotifier extends Notifier<bool> {
  @override
  bool build() {
    _startMonitoring();
    return true;
  }

  void _startMonitoring() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 10));
      final isConnected = await ConnectivityService.hasInternetConnection();
      state = isConnected;
      return true;
    });
  }
}

/// NotifierProvider for real-time connectivity tracking
final connectivityStateProvider = NotifierProvider<ConnectivityNotifier, bool>(
  ConnectivityNotifier.new,
);
