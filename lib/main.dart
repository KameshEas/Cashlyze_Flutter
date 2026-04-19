import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'firebase_options_placeholder.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kReleaseMode;
import 'core/theme/app_theme.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'routes/app_router.dart';
import 'routes/app_router.dart' show rootNavigatorKeyProvider;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/providers/shared_prefs_provider.dart';
import 'core/providers/budget_alerts_handler.dart';
import 'core/services/local_notification_service.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'core/providers/app_version_providers.dart';
import 'features/force_update/widgets/force_update_dialog.dart';

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
  final usePlaceholder =
      const bool.fromEnvironment('FIREBASE_PLACEHOLDER') && !kReleaseMode;

  try {
    // Avoid duplicate initialization if another piece of code has already
    // initialized Firebase (some plugins may auto-init). Check `Firebase.apps`.
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: usePlaceholder
            ? (defaultTargetPlatform == TargetPlatform.iOS
                ? DefaultFirebaseOptionsPlaceholder.ios
                : DefaultFirebaseOptionsPlaceholder.android)
            : DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      if (!kReleaseMode) debugPrint('Firebase already initialized');
    }
  } catch (e) {
    if (!kReleaseMode) debugPrint('Firebase init failed: $e');
  }

  try {
    // Initially only record Flutter errors to Crashlytics. Sentry will be
    // enabled asynchronously after init completes to avoid blocking UI.
    FlutterError.onError = (FlutterErrorDetails details) {
      FirebaseCrashlytics.instance.recordFlutterError(details);
      FlutterError.dumpErrorToConsole(details);
    };
  } catch (e) {
    if (!kReleaseMode) debugPrint('Crashlytics init failed: $e');
  }

  // Use runZonedGuarded so we can capture uncaught errors from the zone.
  // Initialize bindings inside the zone so `ensureInitialized` and
  // `runApp` execute in the same zone (prevents zone mismatch assertions).
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await _runAppWithPrefs();
  }, (error, stack) async {
    try {
      await FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    } catch (_) {}

    // Forward to Sentry only after initialization completed.
    if (_sentryReady) {
      try {
        await Sentry.captureException(error, stackTrace: stack);
      } catch (_) {}
    } else {
      if (!kReleaseMode) debugPrint('Uncaught error: $error');
    }
  });
}

void main() async {
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    if (!kReleaseMode) debugPrint('Failed to load .env file: $e');
  }

  // Start the app asynchronously so Sentry cannot block UI startup. We will
  // initialize the Flutter bindings inside the runZonedGuarded zone to make
  // sure binding initialization and `runApp` happen in the same zone.
  _appRunner();

  // Initialize OneSignal (fire-and-forget). App ID from request.
  () async {
    try {
      await OneSignal.initialize('37af7f2d-22d4-4eac-972b-50cb1377fbb8');
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
  }();

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
      : const String.fromEnvironment(
          'SENTRY_DSN',
          defaultValue:
              'https://bc9d78a3c4da4aa4f78f3620f1eea37c@o4511054838300672.ingest.us.sentry.io/4511054843674624',
        );

  if (sentryDsn.isEmpty) {
    if (!kReleaseMode) debugPrint('SENTRY_DSN not set — Sentry disabled.');
    return;
  }

  // Fire-and-forget Sentry initialization.
  () async {
    try {
      await SentryFlutter.init(
        (options) {
          options.dsn = sentryDsn;
          options.tracesSampleRate = 0.0;
          options.environment = const String.fromEnvironment(
            'SENTRY_ENV',
            defaultValue: kReleaseMode ? 'production' : 'development',
          );

          // Use dynamic assignment to avoid signature mismatches across
          // different Sentry package versions.
          (options as dynamic).beforeSend = (event, {hint}) {
            if (!kReleaseMode) return null;

            final ex = event.exceptions?.first;
            final exType = ex?.type ?? '';
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

      // Now enable forwarding of Flutter framework errors to Sentry in
      // release builds. Crashlytics remains the primary recorder.
      FlutterError.onError = (FlutterErrorDetails details) {
        FirebaseCrashlytics.instance.recordFlutterError(details);
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
  }();
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appRouter = ref.watch(appRouterProvider);
    // Ensure budget alert handler is initialized
    ref.watch(budgetAlertsHandlerProvider);
    
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
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return _ForceUpdateMonitor(child: child!);
      },
    );
  }
}

/// Widget that monitors force update state and shows dialog when needed
class _ForceUpdateMonitor extends ConsumerStatefulWidget {
  final Widget child;

  const _ForceUpdateMonitor({required this.child});

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
  Widget build(BuildContext context) {
    // Listen for force update state changes
    ref.listen<ForceUpdateState>(forceUpdateStateProvider, (previous, next) {
      next.whenOrNull(
        updateRequired: (config) {
          if (mounted) {
            // Use Future.microtask to navigate after frame is complete
            Future.microtask(() {
              final rootKey = ref.read(rootNavigatorKeyProvider);
              final navigatorContext = rootKey.currentContext;
              
              if (navigatorContext != null) {
                // Push full-page force update screen
                Navigator.of(navigatorContext).pushReplacement(
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        ForceUpdateDialog(versionConfig: config),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
                    if (navContext != null) {
                      Navigator.of(navContext).pushReplacement(
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) =>
                              ForceUpdateDialog(versionConfig: config),
                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
