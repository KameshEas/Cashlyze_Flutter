import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_user.dart';
import '../repositories/budget_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/emi_repository.dart';
import '../repositories/transaction_repository.dart';
import '../services/auth_service.dart';
import '../services/ws_service.dart';

/// Provider that ensures the WebSocket service connects when a user signs
/// in and listens to realtime events. On relevant events it invalidates
/// the corresponding Riverpod providers so the UI refreshes immediately.
final wsListenerProvider = Provider<void>((final ref) {
  final ws = ref.watch(wsServiceProvider);
  StreamSubscription<WsEvent>? sub;
  StreamSubscription<WsConnectionState>? stateSub;
  StreamSubscription<void>? fallbackSub;

  // React to auth changes and connect/disconnect accordingly.
  ref.listen<AuthUser?>(currentUserProvider, (final previous, final next) {
    // If a previous user exists, clean up their pollers and listeners.
    if (previous != null) {
      try {
        final prevId = previous.userId;
        final txnRepo = ref.read(transactionRepositoryProvider);
        final budgetRepo = ref.read(budgetRepositoryProvider);
        txnRepo.disposeForUser(prevId);
        budgetRepo.disposeForUser(prevId);
      } catch (e) {
        debugPrint('[wsListenerProvider] cleanup previous user failed: $e');
      }
    }

    if (next == null) {
      // Signed out: cancel subscription and disconnect
      try {
        sub?.cancel();
      } catch (e) {
        debugPrint('[wsListenerProvider] sub cancel failed: $e');
      }
      try {
        stateSub?.cancel();
      } catch (e) {
        debugPrint('[wsListenerProvider] stateSub cancel failed: $e');
      }
      try {
        fallbackSub?.cancel();
      } catch (e) {
        debugPrint('[wsListenerProvider] fallbackSub cancel failed: $e');
      }
      try {
        ws.disconnect();
      } catch (e) {
        debugPrint('[wsListenerProvider] ws disconnect failed: $e');
      }
      sub = null;
      return;
    }

    // Signed in: enable polling immediately while attempting websocket connect,
    // then connect and switch to websocket-driven updates when connected.
    Future.microtask(() async {
      final txnRepo = ref.read(transactionRepositoryProvider);
      final budgetRepo = ref.read(budgetRepositoryProvider);
      try {
        txnRepo.enablePollingForUser(next.userId);
        budgetRepo.enablePollingForUser(next.userId);
      } catch (e) {
        debugPrint('[wsListenerProvider] enablePolling failed: $e');
      }
      try {
        await ws.connect(next.userId);
      } catch (e) {
        if (kDebugMode) debugPrint('Ws connect failed: $e');
      }

      try {
        await sub?.cancel();
      } catch (e) {
        debugPrint('[wsListenerProvider] sub cancel 2 failed: $e');
      }

      // Cancel previous listeners
      try {
        await stateSub?.cancel();
      } catch (e) {
        debugPrint('[wsListenerProvider] stateSub cancel 2 failed: $e');
      }
      try {
        await fallbackSub?.cancel();
      } catch (e) {
        debugPrint('[wsListenerProvider] fallbackSub cancel 2 failed: $e');
      }

      sub = ws.events.listen((final event) {
        final t = event.type;
        final payload = event.payload;

        // Categories: refresh category list — only on category-specific events
        if (t == WsEventType.categoryCreated ||
            t == WsEventType.categoryUpdated ||
            t == WsEventType.categoryDeleted) {
          try {
            ref.invalidate(userCategoriesProvider);
          } catch (e) {
            debugPrint('[wsListenerProvider] invalidate categories failed: $e');
          }
          return;
        }

        if (t == WsEventType.transactionCreated ||
            t == WsEventType.transactionUpdated ||
            t == WsEventType.transactionDeleted) {
          try {
            txnRepo.applyRemoteTransactionEvent(next.userId, t, payload);
            // Only invalidate categories if a category-specific event arrives,
            // not on every transaction event with category metadata.
          } catch (e) {
            debugPrint('[wsListenerProvider] transaction event failed: $e');
          }
          return;
        }

        // Budgets: update cache directly
        if (t == WsEventType.budgetCreated ||
            t == WsEventType.budgetUpdated ||
            t == 'budget_utilization_changed' ||
            t == WsEventType.budgetDeleted) {
          try {
            budgetRepo.applyRemoteBudgetEvent(next.userId, t, payload);
          } catch (e) {
            debugPrint('[wsListenerProvider] budget event failed: $e');
          }
          return;
        }

        // EMI plans: no local cache to update directly - just refetch.
        if (t == WsEventType.emiPlanCreated ||
            t == WsEventType.emiPlanUpdated ||
            t == WsEventType.emiPlanDeleted) {
          try {
            ref.invalidate(userEMIPlansProvider);
          } catch (e) {
            debugPrint('[wsListenerProvider] invalidate EMI plans failed: $e');
          }
          return;
        }
      });

      // Connection state changes: when connected disable polling, otherwise keep current.
      stateSub = ws.connectionStateStream.listen((final state) {
        try {
          if (state == WsConnectionState.connected) {
            txnRepo.disablePollingForUser(next.userId);
            budgetRepo.disablePollingForUser(next.userId);
          }
        } catch (e) {
          debugPrint('[wsListenerProvider] state change failed: $e');
        }
      });

      // If websocket falls back to polling, enable periodic polling on repos.
      fallbackSub = ws.onFallbackToPoll.listen((final _) {
        try {
          txnRepo.enablePollingForUser(next.userId);
          budgetRepo.enablePollingForUser(next.userId);
        } catch (e) {
          debugPrint('[wsListenerProvider] fallback poll failed: $e');
        }
      });
    });
  });

  ref.onDispose(() {
    try {
      sub?.cancel();
    } catch (e) {
      debugPrint('[wsListenerProvider] dispose sub cancel failed: $e');
    }
    try {
      stateSub?.cancel();
    } catch (e) {
      debugPrint('[wsListenerProvider] dispose stateSub cancel failed: $e');
    }
    try {
      fallbackSub?.cancel();
    } catch (e) {
      debugPrint('[wsListenerProvider] dispose fallbackSub cancel failed: $e');
    }
    try {
      ws.disconnect();
    } catch (e) {
      debugPrint('[wsListenerProvider] dispose ws disconnect failed: $e');
    }
  });

});
