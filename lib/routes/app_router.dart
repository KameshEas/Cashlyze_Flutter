import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/ui/motion.dart';
import '../core/providers/onboarding_provider.dart';
import '../core/services/auth_service.dart';
import '../core/providers/otp_pending_provider.dart';
import '../features/auth/auth_screen.dart';
import '../features/auth/loader_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/home/home_screen.dart';
import '../features/transactions/transactions_screen.dart';
import '../features/budgets/budget_planner_screen.dart';
import '../features/insights/insights_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/auth/otp_screen.dart';
import '../features/categories/categories_screen.dart';
import '../features/emi/emi_form_screen.dart';
import '../features/emi/emi_dashboard_screen.dart';
import '../features/onboarding/help_center_screen.dart';

// Root navigator key for accessing Navigator context from anywhere
final rootNavigatorKeyProvider = Provider<GlobalKey<NavigatorState>>((ref) {
  return GlobalKey<NavigatorState>();
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final rootKey = ref.watch(rootNavigatorKeyProvider);
  final onboardingCompleted = ref.watch(onboardingCompletedProvider);
  final authState = ref.watch(authStateChangesProvider);
  final currentUser = ref.watch(currentUserProvider);
  final otpPending = ref.watch(otpPendingProvider);
  const kRouteFadeDuration = AppMotion.pageDuration;
  final shellKey = GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/loading',
        name: 'loading',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
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
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const SplashScreen(),
          transitionsBuilder: AppMotion.fadeThrough,
          transitionDuration: MediaQuery.of(context).disableAnimations
              ? Duration.zero
              : kRouteFadeDuration,
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return Scaffold(
            body: navigationShell,
            bottomNavigationBar: NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: (index) {
                if (index == 4) {
                  navigationShell.goBranch(index, initialLocation: true);
                } else {
                  navigationShell.goBranch(index);
                }
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long),
                  label: 'Transactions',
                ),
                NavigationDestination(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  selectedIcon: Icon(Icons.account_balance_wallet),
                  label: 'Budgets',
                ),
                NavigationDestination(
                  icon: Icon(Icons.insights_outlined),
                  selectedIcon: Icon(Icons.insights),
                  label: 'Insights',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
          );
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: shellKey,
            routes: [
              GoRoute(
                path: '/',
                name: 'home',
                pageBuilder: (context, state) => CustomTransitionPage(
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
                pageBuilder: (context, state) => CustomTransitionPage(
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
                pageBuilder: (context, state) => CustomTransitionPage(
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
                pageBuilder: (context, state) => CustomTransitionPage(
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
                pageBuilder: (context, state) => CustomTransitionPage(
                  key: state.pageKey,
                  child: const SettingsScreen(),
                  transitionsBuilder: AppMotion.fadeThrough,
                  transitionDuration: MediaQuery.of(context).disableAnimations
                      ? Duration.zero
                      : kRouteFadeDuration,
                ),
              ),
              GoRoute(
                path: '/emi',
                name: 'emi_dashboard',
                pageBuilder: (context, state) => CustomTransitionPage(
                  key: state.pageKey,
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
                pageBuilder: (context, state) => CustomTransitionPage(
                  key: state.pageKey,
                  child: const EMIFormScreen(),
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
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
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
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const AuthScreen(initialIsLogin: true),
          transitionsBuilder: AppMotion.fadeThrough,
          transitionDuration: MediaQuery.of(context).disableAnimations
              ? Duration.zero
              : kRouteFadeDuration,
        ),
      ),
      GoRoute(
        path: '/signup',
        name: 'signup',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
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
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
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
        pageBuilder: (context, state) {
          final email = state.uri.queryParameters['email'] ?? '';
          return CustomTransitionPage(
            key: state.pageKey,
            child: OtpScreen(email: email),
            transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                AppMotion.fadeThrough(context, animation, secondaryAnimation, child),
            transitionDuration: MediaQuery.of(context).disableAnimations
                ? Duration.zero
                : kRouteFadeDuration,
          );
        },
      ),
      GoRoute(
        path: '/categories',
        name: 'categories',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
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
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
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
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const HelpCenterScreen(),
          transitionsBuilder: AppMotion.fadeThrough,
          transitionDuration: MediaQuery.of(context).disableAnimations
              ? Duration.zero
              : kRouteFadeDuration,
        ),
      ),

    ],
    redirect: (context, state) {
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
