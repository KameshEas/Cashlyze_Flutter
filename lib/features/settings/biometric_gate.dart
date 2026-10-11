import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/biometric_lock_providers.dart';
import '../../core/services/auth_service.dart';
import 'biometric_lock_screen.dart';

/// Enforces Biometric Lock: covers the app with [BiometricLockScreen] when the
/// lock is on, a user is signed in, and the app hasn't been unlocked yet.
///
/// - Locks on cold start (a restored session still needs the fingerprint).
/// - Locks again after the app has been in the background for [relockAfter].
/// - Does not lock right after a fresh sign-in (they just proved who they are
///   with their password) or while the lock is off.
///
/// The app underneath stays mounted (just hidden), so the user returns to
/// exactly where they were.
class BiometricGate extends ConsumerStatefulWidget {
  const BiometricGate({
    super.key,
    required this.child,
    this.relockAfter = const Duration(seconds: 30),
  });

  final Widget child;
  final Duration relockAfter;

  @override
  ConsumerState<BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends ConsumerState<BiometricGate> with WidgetsBindingObserver {
  bool _unlocked = false;
  bool _sawSignedOut = false;
  bool _prompting = false;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(final AppLifecycleState state) {
    // The system biometric prompt can pause the app behind it; that isn't the
    // user leaving.
    if (_prompting) return;
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final pausedAt = _pausedAt;
      _pausedAt = null;
      if (pausedAt != null &&
          _unlocked &&
          DateTime.now().difference(pausedAt) >= widget.relockAfter) {
        setState(() => _unlocked = false);
      }
    }
  }

  void _unlock() {
    if (mounted) setState(() => _unlocked = true);
  }

  @override
  Widget build(final BuildContext context) {
    final lockEnabled = ref.watch(biometricLockProvider);
    final auth = ref.watch(authStateChangesProvider);
    final user = auth.value;

    // Derived state kept in sync here (idempotent, no setState needed).
    if (auth.hasValue && user == null) {
      _sawSignedOut = true;
      _unlocked = false;
    } else if (user != null && _sawSignedOut) {
      _sawSignedOut = false;
      _unlocked = true; // fresh sign-in this session
    }
    if (lockEnabled.value == false) _unlocked = true; // nothing to unlock

    final locked = user != null && !_unlocked;
    final stillLoadingSetting = lockEnabled.isLoading;
    final showLock = locked && lockEnabled.value == true;
    // Until we know whether the lock is on, hide a restored session behind a
    // plain surface instead of flashing its content.
    final showCover = locked && stillLoadingSetting;

    return Stack(
      fit: StackFit.passthrough,
      children: [
        Offstage(offstage: showLock || showCover, child: widget.child),
        if (showCover)
          Positioned.fill(child: ColoredBox(color: Theme.of(context).colorScheme.surface)),
        if (showLock)
          Positioned.fill(
            child: BiometricLockScreen(
              onUnlocked: _unlock,
              onBusyChanged: (final busy) => _prompting = busy,
            ),
          ),
      ],
    );
  }
}
