import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/auth_service.dart';
import '../../core/providers/onboarding_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  final Duration duration;

  const SplashScreen({
    super.key,
    this.duration = const Duration(milliseconds: 600),
  });

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _fadeIn = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
    _controller.forward();

    // Try navigating after the fade-in completes. Do not force a long
    // fixed delay here — if auth state is still loading, `_maybeNavigate`
    // will defer and be triggered again by listeners.
    Future<void>.delayed(widget.duration, () {
      _maybeNavigate();
    });
  }

  void _maybeNavigate() {
    if (!mounted || _navigated) return;
    final authState = ref.read(authStateChangesProvider);
    final currentUser = ref.read(currentUserProvider);
    final onboardingCompleted = ref.read(onboardingCompletedProvider);

    // If onboarding not completed, navigate there immediately.
    if (!onboardingCompleted) {
      _navigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/onboarding');
      });
      return;
    }

    // Wait for the auth state stream to resolve before deciding whether to
    // show the login screen or proceed to the app. If it's still loading,
    // defer navigation; a listener will call `_maybeNavigate` again when
    // the auth state updates.
    if (authState.isLoading) return;

    final user = currentUser ?? authState.value;
    final target = (user == null) ? '/login' : '/';

    _navigated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go(target);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeNavigate();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateChangesProvider, (previous, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeNavigate());
    });
    ref.listen(onboardingCompletedProvider, (previous, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeNavigate());
    });
    final theme = Theme.of(context);
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeIn,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.surface,
                theme.colorScheme.surface.withValues(alpha: 0.8),
              ],
            ),
          ),
          child: Center(
                child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Use the branded logo asset so it is visible on all themes.
                SizedBox(
                  width: 88,
                  height: 88,
                  child: Image.asset(
                    'assets/logo_icon.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Cashlyze',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
