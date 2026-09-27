import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/onboarding_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/widgets/brand_logo.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({
    super.key,
    this.duration = const Duration(milliseconds: 1100),
  });
  final Duration duration;

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  late final Animation<double> _logoScale;
  late final Animation<double> _glow;
  late final AnimationController _dotsController;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _fadeIn = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOutBack),
      ),
    );
    _glow = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.1, 1.0, curve: Curves.easeOut),
    );
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _controller.forward();

    // Try navigating after the fade-in completes. Do not force a long
    // fixed delay here — if auth state is still loading, `_maybeNavigate`
    // will defer and be triggered again by listeners.
    Future<void>.delayed(widget.duration, _maybeNavigate);
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
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    ref.listen(authStateChangesProvider, (final previous, final next) {
      WidgetsBinding.instance.addPostFrameCallback(
        (final _) => _maybeNavigate(),
      );
    });
    ref.listen(onboardingCompletedProvider, (final previous, final next) {
      WidgetsBinding.instance.addPostFrameCallback(
        (final _) => _maybeNavigate(),
      );
    });
    final theme = Theme.of(context);
    final glowColor = theme.colorScheme.primary;
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (final context, final child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // Soft radial glow that blooms in behind the wordmark.
                Opacity(
                  opacity: _glow.value * 0.35,
                  child: Container(
                    width: 320,
                    height: 320,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [glowColor, glowColor.withValues(alpha: 0)],
                      ),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.scale(
                      scale: _logoScale.value,
                      child: FadeTransition(
                        opacity: _fadeIn,
                        child: const SizedBox(
                          width: 240,
                          height: 96,
                          child: BrandLogo(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    FadeTransition(opacity: _fadeIn, child: child),
                  ],
                ),
              ],
            );
          },
          child: _PulsingDots(controller: _dotsController, color: glowColor),
        ),
      ),
    );
  }
}

/// Three dots that pulse in sequence — a lighter, brand-owned stand-in for
/// the default [CircularProgressIndicator] while auth/onboarding state
/// resolves.
class _PulsingDots extends StatelessWidget {
  const _PulsingDots({required this.controller, required this.color});

  final AnimationController controller;
  final Color color;

  @override
  Widget build(final BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (final context, final child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (final i) {
            final t = (controller.value - i * 0.2) % 1.0;
            final scale = 0.6 + 0.4 * (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
