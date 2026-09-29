import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../core/constants/feature_flags.dart';
import '../core/providers/app_version_providers.dart';
import '../core/providers/onboarding_provider.dart';
import '../core/providers/otp_pending_provider.dart';
import '../core/services/auth_service.dart';
import '../core/ui/motion.dart';
import '../features/ai_assistant/ai_assistant_screen.dart';
import '../features/auth/auth_screen.dart';
import '../features/auth/loader_screen.dart';
import '../features/auth/otp_screen.dart';
import '../features/budgets/budget_planner_screen.dart';
import '../features/categories/categories_screen.dart';
import '../features/emi/emi_dashboard_screen.dart';
import '../features/emi/emi_form_screen.dart';
import '../features/goals/goals_screen.dart';
import '../features/home/home_screen.dart';
import '../features/insights/insights_screen.dart';
import '../features/onboarding/help_center_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/scan/scan_receipt_screen.dart';
import '../features/scan/scan_result_screen.dart';
import '../features/search/search_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/transactions/transactions_screen.dart';
import 'widgets/app_shell_scaffold.dart';

// Root navigator key for accessing Navigator context from anywhere
final rootNavigatorKeyProvider = Provider<GlobalKey<NavigatorState>>((final ref) {
  return GlobalKey<NavigatorState>();
});

/// Maps flaggable route paths to the feature flag that must be enabled to
/// reach them — defense-in-depth against direct deep links bypassing a
/// hidden nav/quick-menu entry (see AppBottomNavBar, RadialQuickMenu).
const _kRouteFeatureFlags = {
  '/transactions': FeatureFlags.transactions,
  '/budgets': FeatureFlags.budgets,
  '/insights': FeatureFlags.insights,
  '/goals': FeatureFlags.goals,
  '/categories': FeatureFlags.categories,
  '/emi': FeatureFlags.emi,
  '/emi/new': FeatureFlags.emi,
  '/search': FeatureFlags.search,
  '/scan': FeatureFlags.scan,
  '/scan/result': FeatureFlags.scan,
  '/help_center': FeatureFlags.helpCenter,
  '/ai-assistant': FeatureFlags.aiAssistant,
};

/// Tells GoRouter to re-run its `redirect` callback on the *current* route,
/// without rebuilding the router itself - unlike `ref.watch` inside
/// [appRouterProvider], which would reconstruct a brand-new [GoRouter] (and
/// silently discard whatever it just navigated to) every time auth state,
/// onboarding, feature flags, or OTP-pending changes. That reset is exactly
/// what broke deep links resolving after login: the resolved destination was
/// reached, then wiped out moments later when feature flags finished loading
/// and rebuilt the whole provider.
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(this._ref) {
    _ref.listen(onboardingCompletedProvider, (final _, final _) => notifyListeners());
    _ref.listen(authStateChangesProvider, (final _, final _) => notifyListeners());
    _ref.listen(currentUserProvider, (final _, final _) => notifyListeners());
    _ref.listen(otpPendingProvider, (final _, final _) => notifyListeners());
    _ref.listen(featureFlagsProvider, (final _, final _) => notifyListeners());
  }

  final Ref _ref;
}

final appRouterProvider = Provider<GoRouter>((final ref) {
  final rootKey = ref.watch(rootNavigatorKeyProvider);
  final refreshNotifier = _RouterRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);
  const kRouteFadeDuration = AppMotion.pageDuration;
  final shellKey = GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: '/splash',
    // Leaves a breadcrumb trail of route names for every crash report - route
    // names only (e.g. "transactions"), never the data shown on the screen.
    observers: [SentryNavigatorObserver()],
    // Re-evaluates `redirect` on the current location when auth/onboarding/
    // feature-flag/OTP state changes, instead of GoRouter itself being
    // recreated (see _RouterRefreshNotifier).
    refreshListenable: refreshNotifier,
    routes: [
      GoRoute(
        path: '/loading',
        name: 'loading',
        pageBuilder: (final context, final state) => CustomTransitionPage(
          child: const LoaderScreen(),
          transitionsBuilder: AppMotion.fadeThrough,
          transitionDuration: MediaQuery.of(context).disableAnimations
              ? Duration.zero
              : kRouteFadeDuration,
        ),
      ),
      GoRoute(
        path: '/splash',
        name: 'splash',
        pageBuilder: (final context, final state) => CustomTransitionPage(
          child: const SplashScreen(),
          transitionsBuilder: AppMotion.fadeThrough,
          transitionDuration: MediaQuery.of(context).disableAnimations
              ? Duration.zero
              : kRouteFadeDuration,
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (final context, final state, final navigationShell) {
          return AppShellScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: shellKey,
            routes: [
              GoRoute(
                path: '/',
                name: 'home',
                pageBuilder: (final context, final state) => CustomTransitionPage(
                  key: state.pageKey,
                  child: const HomeScreen(),
                  transitionsBuilder: AppMotion.fadeThrough,
                  transitionDuration: MediaQuery.of(context).disableAnimations
                      ? Duration.zero
                      : kRouteFadeDuration,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/transactions',
                name: 'transactions',
                pageBuilder: (final context, final state) => CustomTransitionPage(
                  key: state.pageKey,
                  child: const TransactionsScreen(),
                  transitionsBuilder: AppMotion.fadeThrough,
                  transitionDuration: MediaQuery.of(context).disableAnimations
                      ? Duration.zero
                      : kRouteFadeDuration,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/budgets',
                name: 'budgets',
                pageBuilder: (final context, final state) => CustomTransitionPage(
                  key: state.pageKey,
                  child: const BudgetPlannerScreen(),
                  transitionsBuilder: AppMotion.fadeThrough,
                  transitionDuration: MediaQuery.of(context).disableAnimations
                      ? Duration.zero
                      : kRouteFadeDuration,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/insights',
                name: 'insights',
                pageBuilder: (final context, final state) => CustomTransitionPage(
                  key: state.pageKey,
                  child: const InsightsScreen(),
                  transitionsBuilder: AppMotion.fadeThrough,
                  transitionDuration: MediaQuery.of(context).disableAnimations
                      ? Duration.zero
                      : kRouteFadeDuration,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                name: 'settings',
                pageBuilder: (final context, final state) => CustomTransitionPage(
                  key: state.pageKey,
                  child: const SettingsScreen(),
                  transitionsBuilder: AppMotion.fadeThrough,
                  transitionDuration: MediaQuery.of(context).disableAnimations
                      ? Duration.zero
                      : kRouteFadeDuration,
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/auth',
        name: 'auth',
        pageBuilder: (final context, final state) => CustomTransitionPage(
          child: const AuthScreen(),
          transitionsBuilder: AppMotion.fadeThrough,
          transitionDuration: MediaQuery.of(context).disableAnimations
              ? Duration.zero
              : kRouteFadeDuration,
        ),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        pageBuilder: (final context, final state) => CustomTransitionPage(
          child: const AuthScreen(),
          transitionsBuilder: AppMotion.fadeThrough,
          transitionDuration: MediaQuery.of(context).disableAnimations
              ? Duration.zero
              : kRouteFadeDuration,
        ),
      ),
      GoRoute(
        path: '/signup',
        name: 'signup',
        pageBuilder: (final context, final state) => CustomTransitionPage(
          child: const AuthScreen(initialIsLogin: false),
          transitionsBuilder: AppMotion.fadeThrough,
          transitionDuration: MediaQuery.of(context).disableAnimations
              ? Duration.zero
              : kRouteFadeDuration,
        ),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        pageBuilder: (final context, final state) => CustomTransitionPage(
          child: const OnboardingScreen(),
          transitionsBuilder: AppMotion.fadeThrough,
          transitionDuration: MediaQuery.of(context).disableAnimations
              ? Duration.zero
              : kRouteFadeDuration,
        ),
      ),
      GoRoute(
        path: '/otp',
        name: 'otp',
        pageBuilder: (final context, final state) {
          final email = state.uri.queryParameters['email'] ?? '';
          return CustomTransitionPage(
            child: OtpScreen(email: email),
            transitionsBuilder: AppMotion.fadeThrough,
            transitionDuration: MediaQuery.of(context).disableAnimations
                ? Duration.zero
                : kRouteFadeDuration,
          );
        },
      ),
      GoRoute(
        path: '/categories',
        name: 'categories',
        pageBuilder: (final context, final state) => CustomTransitionPage(
          child: const CategoriesScreen(),
          transitionsBuilder: AppMotion.fadeThrough,
          transitionDuration: MediaQuery.of(context).disableAnimations
              ? Duration.zero
              : kRouteFadeDuration,
        ),
      ),
      GoRoute(
        path: '/onboarding_preview',
        name: 'onboarding_preview',
        pageBuilder: (final context, final state) => CustomTransitionPage(
          child: const OnboardingScreen(),
          transitionsBuilder: AppMotion.fadeThrough,
          transitionDuration: MediaQuery.of(context).disableAnimations
              ? Duration.zero
              : kRouteFadeDuration,
        ),
      ),
      GoRoute(
        path: '/help_center',
        name: 'help_center',
        pageBuilder: (final context, final state) => CustomTransitionPage(
          child: const HelpCenterScreen(),
          transitionsBuilder: AppMotion.fadeThrough,
          transitionDuration: MediaQuery.of(context).disableAnimations
              ? Duration.zero
              : kRouteFadeDuration,
        ),
      ),
      GoRoute(
        path: '/search',
        name: 'search',
        pageBuilder: (final context, final state) => CustomTransitionPage(
          child: const SearchScreen(),
          transitionsBuilder: AppMotion.fadeThrough,
          transitionDuration: MediaQuery.of(context).disableAnimations
              ? Duration.zero
              : kRouteFadeDuration,
        ),
      ),
      GoRoute(
        path: '/emi',
        name: 'emi_dashboard',
        pageBuilder: (final context, final state) => CustomTransitionPage(
          child: const EMIDashboardScreen(),
          transitionsBuilder: AppMotion.fadeThrough,
          transitionDuration: MediaQuery.of(context).disableAnimations
              ? Duration.zero
              : kRouteFadeDuration,
        ),
      ),
      GoRoute(
        path: '/emi/new',
        name: 'emi_new',
        pageBuilder: (final context, final state) => CustomTransitionPage(
          child: const EMIFormScreen(),
          transitionsBuilder: AppMotion.fadeThrough,
          transitionDuration: MediaQuery.of(context).disableAnimations
              ? Duration.zero
              : kRouteFadeDuration,
        ),
      ),
      GoRoute(
        path: '/goals',
        name: 'goals',
        pageBuilder: (final context, final state) => CustomTransitionPage(
          child: const GoalsScreen(),
          transitionsBuilder: AppMotion.fadeThrough,
          transitionDuration: MediaQuery.of(context).disableAnimations
              ? Duration.zero
              : kRouteFadeDuration,
        ),
      ),
      GoRoute(
        path: '/scan',
        name: 'scan',
        pageBuilder: (final context, final state) => CustomTransitionPage(
          child: const ScanReceiptScreen(),
          transitionsBuilder: AppMotion.fadeThrough,
          transitionDuration: MediaQuery.of(context).disableAnimations
              ? Duration.zero
              : kRouteFadeDuration,
        ),
      ),
      GoRoute(
        path: '/scan/result',
        name: 'scan_result',
        pageBuilder: (final context, final state) => CustomTransitionPage(
          child: const ScanResultScreen(),
          transitionsBuilder: AppMotion.fadeThrough,
          transitionDuration: MediaQuery.of(context).disableAnimations
              ? Duration.zero
              : kRouteFadeDuration,
        ),
      ),
      GoRoute(
        path: '/ai-assistant',
        name: 'ai_assistant',
        pageBuilder: (final context, final state) => CustomTransitionPage(
          child: const AiAssistantScreen(),
          transitionsBuilder: AppMotion.fadeThrough,
          transitionDuration: MediaQuery.of(context).disableAnimations
              ? Duration.zero
              : kRouteFadeDuration,
        ),
      ),
    ],
    redirect: (final context, final state) {
      // Android hands a deep link's full URL (https://<domain>/l/{code}) to
      // Flutter as the platform's initial route, and GoRouter tries to match
      // it as one of its own paths before DeepLinkListener ever sees it -
      // none of our routes start with a scheme, so this always fails with
      // "no routes for location". Bounce it to splash instead: the app still
      // starts normally, and DeepLinkListener (via app_links, a separate,
      // slightly later path) resolves the same URL and navigates for real
      // once it knows where "https://.../l/{code}" actually leads.
      if (state.uri.hasScheme) {
        return '/splash';
      }

      // Read fresh on every redirect evaluation (not captured once at router
      // construction) - refreshListenable is what triggers this callback to
      // re-run when any of these change; ref.read here gets this run's
      // current value rather than whatever was true when the GoRouter was
      // first built.
      final onboardingCompleted = ref.read(onboardingCompletedProvider);
      final authState = ref.read(authStateChangesProvider);
      final currentUser = ref.read(currentUserProvider);
      final otpPending = ref.read(otpPendingProvider);
      final featureFlags = ref.read(featureFlagsProvider).maybeWhen(
        data: (final flags) => flags,
        orElse: () => const <String, bool>{},
      );

      final isOnboarding = state.matchedLocation == '/onboarding';
      final isAuthRoute =
          state.matchedLocation == '/auth' ||
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup';
      final isSplash = state.matchedLocation == '/splash';

      final isOtp = state.matchedLocation.startsWith('/otp');

      final isLoadingRoute = state.matchedLocation == '/loading';

      // If auth state is still resolving, show the loader route so the
      // user doesn't briefly land on the login page before the router
      // redirects to home.
      if (authState.isLoading) {
        if (isLoadingRoute) return null;
        return '/loading';
      }

      final user = currentUser ?? authState.value;

      if (isSplash) {
        return null;
      }

      // If OTP verification is pending, always stay on /otp regardless of
      // auth state changes — prevents the isAuthRoute redirect race.
      if (otpPending) {
        if (isOtp) return null;
        final pendingEmail = ref.read(otpPendingProvider.notifier).pendingEmail;
        final emailParam = pendingEmail.isNotEmpty
            ? '?email=${Uri.encodeComponent(pendingEmail)}'
            : '';
        return '/otp$emailParam';
      }

      if (user != null) {
        if (isAuthRoute || isOnboarding) {
          return '/';
        }
        final requiredFlag = _kRouteFeatureFlags[state.matchedLocation];
        if (requiredFlag != null && featureFlags[requiredFlag] == false) {
          return '/';
        }
        return null;
      }

      if (!onboardingCompleted) {
        // Ensure onboarding route is allowed until completed
        if (!isOnboarding) return '/onboarding';
        return null;
      }
      if (onboardingCompleted && isOnboarding) return '/login';
      if (!isAuthRoute) return '/login';
      return null;
    },
  );
});
