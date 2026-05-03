import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../api/api_endpoints.dart';
import '../services/secure_storage_service.dart';

// ── Event types ───────────────────────────────────────────────────────────────

/// A typed realtime event received over the WebSocket connection.
class WsEvent {
  const WsEvent({required this.type, required this.payload});

  final String type;
  final Map<String, dynamic> payload;

  @override
  String toString() => 'WsEvent(type: $type)';
}

// ── Connection state ──────────────────────────────────────────────────────────

enum WsConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

// ── Service ───────────────────────────────────────────────────────────────────

/// WebSocket service that connects to `/ws/user/{userId}?token={jwt}`.
///
/// Features:
/// - Automatic reconnect with exponential back-off (1 s → 2 s → 4 s … 32 s cap)
/// - Stops retrying after [maxConsecutiveFailures] consecutive failures and
///   falls back to polling (callers subscribe to [onFallbackToPoll]).
/// - Emits typed [WsEvent] objects on [events].
/// - Thread-safe: all state mutations happen on the main isolate.
class WsService {
  WsService({
    required SecureStorageService secureStorage,
    this.maxConsecutiveFailures = 6,
  }) : _secureStorage = secureStorage;

  final SecureStorageService _secureStorage;
  final int maxConsecutiveFailures;

  // ── State ─────────────────────────────────────────────────────────────────

  WsConnectionState _state = WsConnectionState.disconnected;
  WsConnectionState get connectionState => _state;

  String? _userId;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _channelSub;
  Timer? _reconnectTimer;

  int _consecutiveFailures = 0;
  int _reconnectDelay = 1; // seconds

  final _eventController = StreamController<WsEvent>.broadcast();
  final _stateController =
      StreamController<WsConnectionState>.broadcast();
  final _fallbackController = StreamController<void>.broadcast();

  /// Stream of inbound [WsEvent]s.
  Stream<WsEvent> get events => _eventController.stream;

  /// Stream of connection state changes.
  Stream<WsConnectionState> get connectionStateStream =>
      _stateController.stream;

  /// Fires once when the service gives up reconnecting and falls back to
  /// polling.  The caller should start polling at a sensible interval.
  Stream<void> get onFallbackToPoll => _fallbackController.stream;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Connects (or reconnects) for [userId].  Safe to call multiple times.
  Future<void> connect(String userId) async {
    _userId = userId;
    _consecutiveFailures = 0;
    _reconnectDelay = 1;
    await _connect();
  }

  /// Permanently disconnects and cleans up all resources.
  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _channelSub?.cancel();
    _channelSub = null;
    _channel?.sink.close();
    _channel = null;
    _userId = null;
    _setConnectionState(WsConnectionState.disconnected);
  }

  void dispose() {
    disconnect();
    _eventController.close();
    _stateController.close();
    _fallbackController.close();
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  Future<void> _connect() async {
    if (_userId == null) return;

    _setConnectionState(_consecutiveFailures == 0
        ? WsConnectionState.connecting
        : WsConnectionState.reconnecting);

    final token = await _secureStorage.getAuthToken();
    if (token == null) {
      _scheduleReconnect();
      return;
    }

    final url = ApiEndpoints.wsUser(_userId!, token);
    _debugLog('Connecting to $url');

    // Parse the URL and log parsed components to help diagnose host/port issues
    final uri = Uri.parse(url);
    _debugLog("Parsed URI -> scheme=${uri.scheme}, host=${uri.host}, port=${uri.hasPort ? uri.port : 'unspecified'}, path=${uri.path}");

    try {
      _channelSub?.cancel();
      _channel?.sink.close();

      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;

      _setConnectionState(WsConnectionState.connected);
      _consecutiveFailures = 0;
      _reconnectDelay = 1;
      _debugLog('WebSocket connected');

      _channelSub = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );
    } catch (e) {
      _debugLog('WebSocket connect error: $e');
      _consecutiveFailures++;
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    if (raw is! String) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final type = json['type'] as String? ?? 'unknown';
      final payload =
          (json['payload'] ?? json['data'] ?? const {}) as Map<String, dynamic>;
      _eventController.add(WsEvent(type: type, payload: payload));
    } catch (e) {
      _debugLog('WebSocket parse error: $e');
    }
  }

  void _onError(Object error, [StackTrace? _]) {
    _debugLog('WebSocket error: $error');
    _consecutiveFailures++;
    _scheduleReconnect();
  }

  void _onDone() {
    _debugLog('WebSocket closed');
    _consecutiveFailures++;
    if (_userId != null) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_consecutiveFailures >= maxConsecutiveFailures) {
      _setConnectionState(WsConnectionState.disconnected);
      _debugLog(
          'WebSocket gave up after $_consecutiveFailures failures — falling back to polling');
      _fallbackController.add(null);
      return;
    }

    final delay = Duration(seconds: _reconnectDelay);
    _debugLog('Reconnecting in ${delay.inSeconds}s (attempt $_consecutiveFailures)');
    _reconnectDelay = (_reconnectDelay * 2).clamp(1, 32);

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, _connect);
    _setConnectionState(WsConnectionState.reconnecting);
  }

  void _setConnectionState(WsConnectionState state) {
    if (_state == state) return;
    _state = state;
    _stateController.add(state);
  }

  static void _debugLog(String msg) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[WsService] $msg');
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final wsServiceProvider = Provider<WsService>((ref) {
  final storage = ref.watch(secureStorageServiceProvider);
  final service = WsService(secureStorage: storage);
  ref.onDispose(service.dispose);
  return service;
});

// ── Event-type constants ──────────────────────────────────────────────────────

/// Well-known event type strings sent by the backend.
abstract final class WsEventType {
  // Transactions
  static const String transactionCreated = 'transaction_created';
  static const String transactionUpdated = 'transaction_updated';
  static const String transactionDeleted = 'transaction_deleted';

  // Budgets
  static const String budgetCreated = 'budget_created';
  static const String budgetUpdated = 'budget_updated';
  static const String budgetDeleted = 'budget_deleted';

  // Categories
  static const String categoryCreated = 'category_created';
  static const String categoryUpdated = 'category_updated';
  static const String categoryDeleted = 'category_deleted';

  // EMI
  static const String emiPlanCreated = 'emi_created';
  static const String emiPlanUpdated = 'emi_updated';
  static const String emiPlanDeleted = 'emi_deleted';
}
