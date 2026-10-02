import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/branding/animated_brand_logo.dart';
import '../../core/branding/cash_count_loader.dart';
import '../../core/branding/flow_backdrop.dart';
import '../../core/providers/onboarding_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/ui/constants.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({
    super.key,
    this.duration = const Duration(milliseconds: 1900),
  });
  final Duration duration;

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _dotsController;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
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
    // The splash is always the deep-ocean brand moment (both themes), so the
    // white logo variant is used and status-bar icons are forced light.
    final logoWidth = (MediaQuery.sizeOf(context).width * 0.72).clamp(220.0, 340.0);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.ocean900,
        body: FlowBackdrop.ocean(
          drift: _dotsController,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBrandLogo(
                  progress: _controller,
                  color: Colors.white,
                  taglineColor: Colors.white.withValues(alpha: 0.85),
                  width: logoWidth,
                ),
                const SizedBox(height: 48),
                FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _controller,
                    curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
                  ),
                  child: const CashCountLoader(width: 170),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
