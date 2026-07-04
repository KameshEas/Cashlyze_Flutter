import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/providers/app_version_providers.dart';
import 'core/providers/budget_alerts_handler.dart';
import 'core/providers/realtime_provider.dart';
import 'core/providers/shared_prefs_provider.dart';
import 'core/services/local_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/offline_sync_listener.dart';
import 'features/force_update/widgets/force_update_dialog.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'routes/app_router.dart';

// Tracks whether Sentry has finished initialization.
bool _sentryReady = false;

Future<void> _runAppWithPrefs() async {
  final prefs = await SharedPreferences.getInstance();

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

  // Initialize OneSignal (fire-and-forget). App ID from .env.
  unawaited(() async {
    try {
      final oneSignalAppId = dotenv.env['ONESIGNAL_APP_ID'];
      if (oneSignalAppId == null || oneSignalAppId.isEmpty) {
        if (!kReleaseMode) debugPrint('ONESIGNAL_APP_ID not set — OneSignal disabled.');
        return;
      }
      await OneSignal.initialize(oneSignalAppId);
      if (!kReleaseMode) debugPrint('OneSignal initialized');
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
    if (!kReleaseMode) debugPrint('SENTRY_DSN not set — Sentry disabled.');
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

          // Use dynamic assignment to avoid signature mismatches across
          // different Sentry package versions.
          (options as dynamic).beforeSend = (final event, {final hint}) {
            if (!kReleaseMode) return null;

            // event is intentionally dynamic to stay compatible across
            // Sentry package versions; see the cast above.
            // ignore: avoid_dynamic_calls
            final ex = event.exceptions?.first;
            // ignore: avoid_dynamic_calls
            final exType = (ex?.type ?? '').toString();
            const skipTypes = [
              'FormatException',
              'AssertionError',
              'RangeError',
              'StateError'
            ];
            for (final skip in skipTypes) {
              if (exType.contains(skip)) return null;
            }
            return event;
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
    
    // Initialize local notifications (idempotent).
    Future.microtask(() async {
      try {
        await ref.read(localNotificationServiceProvider).init();
      } catch (e) {
        if (!kReleaseMode) debugPrint('LocalNotification init failed: $e');
      }
    });
    
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
        return OfflineSyncListener(
          child: _ForceUpdateMonitor(child: child!),
        );
      },
    );
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
