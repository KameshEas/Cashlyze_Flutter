import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/aspire_services_config.dart';
import 'core/config/env_config.dart';
import 'core/providers/app_version_providers.dart';
import 'core/providers/budget_alerts_handler.dart';
import 'core/providers/realtime_provider.dart';
import 'core/providers/sentry_user_sync_provider.dart';
import 'core/providers/shared_prefs_provider.dart';
import 'core/services/local_notification_service.dart';
import 'core/services/push_actions.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/announcement_banner.dart';
import 'core/widgets/announcement_dialog_host.dart';
import 'core/widgets/offline_sync_listener.dart';
import 'core/widgets/push_action_listener.dart';
import 'core/widgets/read_only_maintenance_banner.dart';
import 'features/force_update/widgets/force_update_dialog.dart';
import 'features/maintenance/widgets/maintenance_screen.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'routes/app_router.dart';

// Tracks whether Sentry has finished initialization.
bool _sentryReady = false;

Future<void> _runAppWithPrefs() async {
  final prefs = await SharedPreferences.getInstance();

  // Initialize LocalNotificationService before starting the app
  // so it's ready when budgetAlertsHandlerProvider needs it.
  try {
    final notificationService = LocalNotificationService();
    await notificationService.init();
  } catch (e) {
    if (!kReleaseMode) debugPrint('LocalNotificationService init failed: $e');
  }

  runApp(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: const App(),
    ),
  );
}

Future<void> _appRunner() async {
  try {
    // Avoid duplicate initialization if another piece of code has already
    // initialized Firebase (some plugins may auto-init). Check `Firebase.apps`.
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      if (!kReleaseMode) debugPrint('Firebase already initialized');
    }
  } catch (e) {
    if (!kReleaseMode) debugPrint('Firebase init failed: $e');
  }

  // Use runZonedGuarded so we can capture uncaught errors from the zone.
  // Initialize bindings inside the zone so `ensureInitialized` and
  // `runApp` execute in the same zone (prevents zone mismatch assertions).
  unawaited(runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    // Must complete before anything reads EnvConfig.baseUrl.
    await AspireServicesConfig.load();
    // Fire-and-forget: some devices/emulators throw when querying supported
    // display modes, and this should never block app startup either way.
    unawaited(FlutterDisplayMode.setHighRefreshRate().catchError((final _) {}));
    await _runAppWithPrefs();
  }, (final error, final stack) async {
    // Forward to Sentry only after initialization completed.
    if (_sentryReady) {
      try {
        await Sentry.captureException(error, stackTrace: stack);
      } catch (_) {}
    } else {
      if (!kReleaseMode) debugPrint('Uncaught error: $error');
    }
  }));
}

void main() async {
  try {
    await dotenv.load();
  } catch (e) {
    if (!kReleaseMode) debugPrint('Failed to load .env file: $e');
  }

  // Start the app and wait for the zone-initialized startup to complete so
  // subsequent fire-and-forget inits don't race with binding initialization.
  // Initialize the Flutter bindings inside the runZonedGuarded zone to make
  // sure binding initialization and `runApp` happen in the same zone.
  await _appRunner();

  // Initialize OneSignal (fire-and-forget). The App ID comes from `.env`, which
  // the pipeline writes from its secrets; there is no default in the source.
  unawaited(() async {
    try {
      final oneSignalAppId = EnvConfig.oneSignalAppId;
      if (oneSignalAppId == null) {
        // Unconditional (not gated behind kReleaseMode), like the SENTRY_DSN check
        // below, so a build without the key is visible via `adb logcat` instead of
        // its devices silently never registering for push.
        debugPrint('ONESIGNAL_APP_ID not set - push notifications disabled for this build.');
        return;
      }
      await OneSignal.initialize(oneSignalAppId);
      if (!kReleaseMode) debugPrint('OneSignal initialized');
      // A tapped announcement push carries the announcement's button action.
      OneSignal.Notifications.addClickListener((final event) {
        final action = parsePushAction(event.notification.additionalData);
        if (action != null) pushActionEvents.add(action);
      });
      try {
        final canRequest = await OneSignal.Notifications.canRequest();
        if (canRequest) {
          final granted = await OneSignal.Notifications.requestPermission(true);
          if (!kReleaseMode) debugPrint('Notification permission granted: $granted');
        } else {
          if (!kReleaseMode) debugPrint('Notification permission prompt not available');
        }
      } catch (e) {
        if (!kReleaseMode) debugPrint('OneSignal permission request failed: $e');
      }
    } catch (e) {
      if (!kReleaseMode) debugPrint('OneSignal init failed: $e');
    }
  }());

  // Resolve DSN from .env first then compile-time env. If provided,
  // initialize Sentry asynchronously (do not await) so the app UI is not
  // blocked by Sentry init. Once ready, update error forwarding.
  String? sentryFromDotenv;
  try {
    sentryFromDotenv = dotenv.env['SENTRY_DSN'];
  } catch (_) {
    sentryFromDotenv = null;
  }

  final sentryDsn = (sentryFromDotenv != null && sentryFromDotenv.isNotEmpty)
      ? sentryFromDotenv
      : const String.fromEnvironment('SENTRY_DSN');

  if (sentryDsn.isEmpty) {
    // Unconditional (not gated behind kReleaseMode) so this is visible via
    // `adb logcat` even against a release build during manual QA, not just
    // in a `flutter run --debug` session.
    debugPrint('SENTRY_DSN not set - Sentry disabled for this build.');
    // Loud failure for debug/profile/CI testing (a misconfigured pipeline
    // should be caught before a release ships with no crash reporting at
    // all) - but `assert` is compiled out of `--release` builds entirely,
    // so this can never crash a real user's already-running app over a
    // build-config gap the way a plain `throw` here would.
    assert(false, 'SENTRY_DSN must be set - crash reporting would otherwise ship disabled.');
    return;
  }

  // Fire-and-forget Sentry initialization.
  unawaited(() async {
    try {
      await SentryFlutter.init(
        (final options) {
          options.dsn = sentryDsn;
          options.tracesSampleRate = 0.0;
          options.environment = const String.fromEnvironment(
            'SENTRY_ENV',
            defaultValue: kReleaseMode ? 'production' : 'development',
          );

          // Maximize diagnostic detail per event (none of this costs extra
          // quota - it's richer data on the same error events):
          // - device/app/OS context is attached by default; these add to it.
          options.attachStacktrace = true;
          // Thread/process state at the moment of the crash.
          options.attachThreads = true;
          // Breadcrumbs (nav, HTTP, taps, logs) leading up to the error.
          options.maxBreadcrumbs = 150;
          // Never a screenshot or on-screen widget tree - this app shows
          // balances/transactions, and neither is worth the privacy tradeoff.
          options.attachScreenshot = false;
          options.attachViewHierarchy = false;
          // Never IP/email/device-name; Sentry only gets the internal user id
          // set explicitly via `sentryUserSyncProvider`, not full PII.
          options.sendDefaultPii = false;
          // Session data (for crash-free-rate / release health), not gated
          // behind kReleaseMode below - safe to send from every build.
          options.enableAutoSessionTracking = true;

          // Only scrub obvious secrets from breadcrumb data, then only send
          // events at all from release builds (debug/profile noise from local
          // dev isn't useful and would burn the free-tier quota).
          (options as dynamic).beforeSend = (final event, {final hint}) {
            if (!kReleaseMode) return null;
            return event;
          };
          (options as dynamic).beforeBreadcrumb = (final breadcrumb, {final hint}) {
            // ignore: avoid_dynamic_calls
            final data = breadcrumb?.data;
            if (data is Map) {
              for (final key in ['authorization', 'token', 'password', 'pin', 'otp']) {
                if (data.containsKey(key)) data[key] = '[redacted]';
              }
            }
            return breadcrumb;
          };
        },
      );

      _sentryReady = true;

      // Forward Flutter framework errors to Sentry in release builds.
      FlutterError.onError = (final FlutterErrorDetails details) {
        if (kReleaseMode) {
          Sentry.captureException(details.exception, stackTrace: details.stack);
        } else {
          FlutterError.dumpErrorToConsole(details);
        }
      };

      if (!kReleaseMode) debugPrint('Sentry initialized');
    } catch (e) {
      if (!kReleaseMode) debugPrint('Sentry init failed: $e');
    }
  }());
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    final appRouter = ref.watch(appRouterProvider);
    // Ensure budget alert handler is initialized
    ref.watch(budgetAlertsHandlerProvider);
    // Ensure websocket listener (realtime updates) is initialized
    ref.watch(wsListenerProvider);
    // Keep Sentry's user scope (anonymous id only) in sync with sign-in state
    ref.watch(sentryUserSyncProvider);

    final locale = ref.watch(localeProvider);
    return MaterialApp.router(
      title: AppLocalizations.of(context)?.appTitle ?? 'Cashlyze',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: appRouter,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      builder: (final context, final child) {
        return _MaintenanceGate(
          child: OfflineSyncListener(
            child: PushActionListener(
              child: AnnouncementDialogHost(
                child: ReadOnlyMaintenanceBanner(
                  child: AnnouncementBanner(
                    child: _ForceUpdateMonitor(child: child!),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Widget that checks maintenance-mode status on launch and, if active,
/// replaces the entire routed app content with a blocking notice — takes
/// priority over force-update/announcement since the app is unusable either
/// way while under maintenance.
class _MaintenanceGate extends ConsumerStatefulWidget {
  const _MaintenanceGate({required this.child});
  final Widget child;

  @override
  ConsumerState<_MaintenanceGate> createState() => _MaintenanceGateState();
}

class _MaintenanceGateState extends ConsumerState<_MaintenanceGate>
    with WidgetsBindingObserver {
  bool _checkInitiated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_checkInitiated) {
        _checkInitiated = true;
        _recheckAll();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Maintenance can start or end while the app sits in the background, so
  // re-check whenever the user comes back to it.
  @override
  void didChangeAppLifecycleState(final AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _recheckAll();
  }

  // Re-checks maintenance mode and the announcement banner together, since
  // both come from the same config fetch and "Try Again" on the maintenance
  // screen should refresh the whole picture, not just whether it can dismiss
  // itself — otherwise an announcement that only became active while the app
  // was blocked by maintenance would never get picked up.
  void _recheckAll() {
    ref.read(maintenanceStateProvider.notifier).check();
    ref.read(announcementStateProvider.notifier).check();
  }

  @override
  Widget build(final BuildContext context) {
    final maintenance = ref.watch(maintenanceStateProvider);

    if (maintenance.isBlocking) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: MaintenanceScreen(
          info: maintenance.info!,
          onRetry: _recheckAll,
        ),
      );
    }

    return widget.child;
  }
}

/// Widget that monitors force update state and shows dialog when needed
class _ForceUpdateMonitor extends ConsumerStatefulWidget {

  const _ForceUpdateMonitor({required this.child});
  final Widget child;

  @override
  ConsumerState<_ForceUpdateMonitor> createState() => _ForceUpdateMonitorState();
}

class _ForceUpdateMonitorState extends ConsumerState<_ForceUpdateMonitor> {
  bool _checkInitiated = false;

  @override
  void initState() {
    super.initState();
    // Trigger force update check on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_checkInitiated) {
        _checkInitiated = true;
        _performForceUpdateCheck();
      }
    });
  }

  @override
  Widget build(final BuildContext context) {
    // Listen for force update state changes
    ref.listen<ForceUpdateState>(forceUpdateStateProvider, (final previous, final next) {
      next.whenOrNull(
        updateRequired: (final config) {
          if (mounted) {
            // Use Future.microtask to navigate after frame is complete
            Future.microtask(() {
              final rootKey = ref.read(rootNavigatorKeyProvider);
              final navigatorContext = rootKey.currentContext;

              if (navigatorContext != null && navigatorContext.mounted) {
                // Push full-page force update screen
                Navigator.of(navigatorContext).pushReplacement(
                  PageRouteBuilder(
                    pageBuilder: (final context, final animation, final secondaryAnimation) =>
                        ForceUpdateDialog(versionConfig: config),
                    transitionsBuilder: (final context, final animation, final secondaryAnimation, final child) {
                      return FadeTransition(
                        opacity: animation,
                        child: child,
                      );
                    },
                    transitionDuration: const Duration(milliseconds: 600),
                  ),
                );
              } else {
                // Retry after a short delay if context not ready
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted) {
                    final navContext = ref.read(rootNavigatorKeyProvider).currentContext;
                    if (navContext != null && navContext.mounted) {
                      Navigator.of(navContext).pushReplacement(
                        PageRouteBuilder(
                          pageBuilder: (final context, final animation, final secondaryAnimation) =>
                              ForceUpdateDialog(versionConfig: config),
                          transitionsBuilder: (final context, final animation, final secondaryAnimation, final child) {
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                          transitionDuration: const Duration(milliseconds: 600),
                        ),
                      );
                    }
                  }
                });
              }
            });
          }
        },
        noUpdateRequired: () {},
        loading: () {},
      );
    });

    return widget.child;
  }

  Future<void> _performForceUpdateCheck() async {
    try {
      await ref.read(forceUpdateStateProvider.notifier).checkForceUpdate();
    } catch (e) {
      // Silently fail if force update check errors
    }
  }
}
