import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/branding/animated_brand_logo.dart';
import '../../core/branding/cash_count_loader.dart';
import '../../core/branding/flow_backdrop.dart';
import '../../core/services/auth_service.dart';
import '../../core/ui/constants.dart';

class LoaderScreen extends ConsumerStatefulWidget {
  const LoaderScreen({super.key});

  @override
  ConsumerState<LoaderScreen> createState() => _LoaderScreenState();
}

class _LoaderScreenState extends ConsumerState<LoaderScreen> {
  static const _timeoutDuration = Duration(seconds: 12);
  Timer? _timeoutTimer;
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    _timeoutTimer = Timer(_timeoutDuration, () {
      if (mounted) setState(() => _timedOut = true);
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _signOutAndRetry() async {
    _timeoutTimer?.cancel();
    await ref.read(authServiceProvider).signOut();
    // The router's redirect logic will pick up the signed-out state and
    // send the user to /login on its own.
  }

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final logoWidth = (MediaQuery.sizeOf(context).width * 0.62).clamp(200.0, 300.0);
    // Same brand moment as the splash (white lockup on the ocean backdrop),
    // so launch -> splash -> loading reads as one continuous screen.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.ocean900,
        body: FlowBackdrop.ocean(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PlayOnceBrandLogo(
                    color: Colors.white,
                    taglineColor: Colors.white.withValues(alpha: 0.85),
                    width: logoWidth,
                  ),
                  const SizedBox(height: 48),
                  const CashCountLoader(width: 170),
                  const SizedBox(height: 12),
                  Text(
                    'Counting things up…',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                  if (_timedOut) ...[
                    const SizedBox(height: 28),
                    Text(
                      'Taking longer than expected. Check your connection, or sign out and try again.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _signOutAndRetry,
                      style: TextButton.styleFrom(foregroundColor: AppColors.ocean400),
                      child: const Text('Sign Out'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
