import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/biometric_lock_providers.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/biometric_service.dart';
import 'biometric_setup_dialog.dart';

/// Full-screen lock shown by `BiometricGate` while Biometric Lock is on and the
/// app hasn't been unlocked. It prompts for the fingerprint / face as soon as
/// it appears and, if that can't work (nothing enrolled any more, locked out,
/// repeated failures), offers a way out so nobody is stuck behind it.
class BiometricLockScreen extends ConsumerStatefulWidget {
  const BiometricLockScreen({super.key, required this.onUnlocked, this.onBusyChanged});

  /// Called once the user has authenticated, or chosen to turn the lock off or
  /// sign out.
  final VoidCallback onUnlocked;

  /// Reports when the system biometric prompt is up, so the gate doesn't treat
  /// the app being briefly paused behind that prompt as "left the app".
  final ValueChanged<bool>? onBusyChanged;

  @override
  ConsumerState<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends ConsumerState<BiometricLockScreen>
    with WidgetsBindingObserver {
  bool _isAuthenticating = false;
  int _failedAttempts = 0;
  BiometricAuthResult? _lastResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _triggerAuthentication());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Back from system settings after setting up a fingerprint: try again.
  @override
  void didChangeAppLifecycleState(final AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _lastResult == BiometricAuthResult.notEnrolled &&
        !_isAuthenticating) {
      _triggerAuthentication();
    }
  }

  Future<void> _triggerAuthentication() async {
    if (_isAuthenticating || !mounted) return;
    setState(() => _isAuthenticating = true);
    widget.onBusyChanged?.call(true);

    final result = await ref.read(biometricServiceProvider).authenticate();

    widget.onBusyChanged?.call(false);
    if (!mounted) return;
    if (result == BiometricAuthResult.success) {
      widget.onUnlocked();
      return;
    }
    setState(() {
      _isAuthenticating = false;
      _lastResult = result;
      if (result == BiometricAuthResult.failed) _failedAttempts++;
    });
  }

  Future<void> _disableLockAndContinue() async {
    await ref.read(biometricLockProvider.notifier).disable();
    if (mounted) widget.onUnlocked();
  }

  Future<void> _signOut() async {
    await ref.read(authServiceProvider).signOut();
    // The router redirects signed-out users to /login once the lock steps aside.
    if (mounted) widget.onUnlocked();
  }

  String get _message {
    if (_isAuthenticating) return 'Waiting for authentication...';
    return switch (_lastResult) {
      BiometricAuthResult.notEnrolled =>
        'No fingerprint or face is set up on this phone any more. Set one up '
            'again, or turn off Biometric Lock.',
      BiometricAuthResult.lockedOut =>
        'Too many attempts. Wait a moment, then try again.',
      BiometricAuthResult.unavailable =>
        "Biometric authentication isn't available right now.",
      _ => 'Use your biometric to access Cashlyze',
    };
  }

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final needsSetup = _lastResult == BiometricAuthResult.notEnrolled;
    // Offer a way out after a couple of misses, or straight away when
    // biometrics can't work, so nobody is stuck behind the lock.
    final showEscapeHatch = _failedAttempts >= 2 ||
        (_lastResult != null &&
            _lastResult != BiometricAuthResult.failed &&
            !_isAuthenticating);

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.fingerprint, size: 80, color: theme.colorScheme.primary),
                const SizedBox(height: 24),
                Text(
                  'Authenticate to unlock',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 32),
                if (_isAuthenticating)
                  const CircularProgressIndicator()
                else if (needsSetup)
                  FilledButton.icon(
                    onPressed: () =>
                        showBiometricSetupDialog(context, ref.read(biometricServiceProvider)),
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Set up biometrics'),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _triggerAuthentication,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Authenticate'),
                  ),
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
                    child: const Text('Turn off Biometric Lock'),
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
