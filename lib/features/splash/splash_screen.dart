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
  bool _timerDone = false; // reserved for future timed animations
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

    Future<void>.delayed(widget.duration, () {
      _timerDone = true;
      _maybeNavigate();
    });
  }

  void _maybeNavigate() {
    if (!mounted || _navigated) return;
    final authState = ref.read(authStateChangesProvider);
    final onboardingCompleted = ref.read(onboardingCompletedProvider);

    if (authState.isLoading) return;

    final user = authState.value;
    final target = !onboardingCompleted
        ? '/onboarding'
        : (user == null ? '/login' : '/');

    _navigated = true;
    if (mounted) context.go(target);
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
                Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 88,
                  color: theme.colorScheme.primary,
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
