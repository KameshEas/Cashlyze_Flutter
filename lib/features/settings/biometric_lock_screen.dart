import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/biometric_lock_providers.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/biometric_service.dart';

class BiometricLockScreen extends ConsumerStatefulWidget {
  const BiometricLockScreen({super.key});

  @override
  ConsumerState<BiometricLockScreen> createState() =>
      _BiometricLockScreenState();
}

class _BiometricLockScreenState extends ConsumerState<BiometricLockScreen> {
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerAuthentication();
    });
  }

  int _failedAttempts = 0;

  Future<void> _triggerAuthentication() async {
    if (_isAuthenticating) return;

    setState(() => _isAuthenticating = true);

    final authenticated = await BiometricService.authenticate();
    if (authenticated && mounted) {
      Navigator.of(context).pop();
    } else if (mounted) {
      setState(() {
        _isAuthenticating = false;
        _failedAttempts++;
      });
    }
  }

  Future<void> _disableLockAndContinue() async {
    await ref.read(biometricLockProvider.notifier).disable();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _signOut() async {
    await ref.read(authServiceProvider).signOut();
    // The router's redirect logic sends signed-out users to /login; popping
    // this screen lets that redirect take over.
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    // Give up after a couple of failed attempts so a user with broken/removed
    // biometrics isn't stuck behind PopScope(canPop: false) with no way out.
    final showEscapeHatch = _failedAttempts >= 2;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.fingerprint,
                  size: 80,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Authenticate to unlock',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                Text(
                  _isAuthenticating
                      ? 'Waiting for authentication...'
                      : 'Use your biometric to access Cashlyze',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (!_isAuthenticating)
                  ElevatedButton.icon(
                    onPressed: _triggerAuthentication,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Authenticate'),
                  )
                else
                  const CircularProgressIndicator(),
                if (showEscapeHatch) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Having trouble? You can turn off biometric lock or sign out.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _disableLockAndContinue,
                    child: const Text('Disable Biometric Lock'),
                  ),
                  TextButton(
                    onPressed: _signOut,
                    child: Text('Sign Out', style: TextStyle(color: theme.colorScheme.error)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
