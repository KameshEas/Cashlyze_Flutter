import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/auth_service.dart';

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
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: Image.asset('assets/logo_icon.png', fit: BoxFit.contain),
            ),
            const SizedBox(height: 16),
            const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: 12),
            Text('Loading...', style: theme.textTheme.bodyMedium),
            if (_timedOut) ...[
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Taking longer than expected. Check your connection, or sign out and try again.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _signOutAndRetry,
                child: const Text('Sign Out'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
