import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/biometric_lock_providers.dart';
import '../../core/services/biometric_service.dart';
import '../../core/ui/constants.dart';
import 'biometric_setup_dialog.dart';

class BiometricLockTile extends ConsumerStatefulWidget {
  const BiometricLockTile({super.key});

  @override
  ConsumerState<BiometricLockTile> createState() => _BiometricLockTileState();
}

class _BiometricLockTileState extends ConsumerState<BiometricLockTile>
    with WidgetsBindingObserver {
  BiometricStatus? _status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // The user may have just enrolled a fingerprint in system settings.
  @override
  void didChangeAppLifecycleState(final AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    final status = await ref.read(biometricServiceProvider).status();
    if (mounted) setState(() => _status = status);
  }

  void _toast(final String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _turnOn() async {
    final service = ref.read(biometricServiceProvider);
    final status = await service.status();
    if (!mounted) return;
    setState(() => _status = status);

    switch (status) {
      case BiometricStatus.unsupported:
        _toast('This device does not support biometric authentication.');
        return;
      case BiometricStatus.notEnrolled:
        await showBiometricSetupDialog(context, service);
        return;
      case BiometricStatus.available:
        break;
    }

    // Prove it works (and that it's really the owner) before locking the app.
    final result = await service.authenticate(reason: 'Confirm to turn on Biometric Lock');
    if (!mounted) return;
    switch (result) {
      case BiometricAuthResult.success:
        await ref.read(biometricLockProvider.notifier).enable();
        if (!mounted) return;
        await HapticFeedback.lightImpact();
        _toast('Biometric lock enabled');
      case BiometricAuthResult.notEnrolled:
        await showBiometricSetupDialog(context, service);
      case BiometricAuthResult.lockedOut:
        _toast('Too many attempts. Please try again in a moment.');
      case BiometricAuthResult.unavailable:
        _toast('Biometric authentication is unavailable right now.');
      case BiometricAuthResult.failed:
        break; // cancelled or not recognised: leave the switch off, no noise
    }
  }

  Future<void> _turnOff() async {
    await ref.read(biometricLockProvider.notifier).disable();
    if (!mounted) return;
    await HapticFeedback.lightImpact();
    _toast('Biometric lock disabled');
  }

  @override
  Widget build(final BuildContext context) {
    return ref.watch(biometricLockProvider).when(
      data: (final isEnabled) {
        final status = _status;
        if (status == BiometricStatus.unsupported && !isEnabled) {
          return const _BiometricRow(
            title: 'Biometric Lock',
            subtitle: 'Not supported on this device',
            enabled: false,
          );
        }

        final subtitle = isEnabled
            ? 'Biometric authentication required to access app'
            : status == BiometricStatus.notEnrolled
                ? 'Set up a fingerprint or face unlock to turn this on'
                : 'Enable biometric authentication';

        return _BiometricRow(
          title: 'Biometric Lock',
          subtitle: subtitle,
          trailing: Switch.adaptive(
            value: isEnabled,
            onChanged: (final value) => value ? _turnOn() : _turnOff(),
          ),
        );
      },
      loading: () => const _BiometricRow(
        title: 'Biometric Lock',
        trailing: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (final _, final _) => const _BiometricRow(
        title: 'Biometric Lock',
        subtitle: 'Failed to load settings',
      ),
    );
  }
}

/// Same row anatomy as the other Settings rows (icon tile, title + muted
/// caption, trailing control), so this tile no longer looks like a stock
/// Material ListTile dropped into the group.
class _BiometricRow extends StatelessWidget {
  const _BiometricRow({
    required this.title,
    this.subtitle,
    this.trailing,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool enabled;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceHigh : AppColors.tint050,
                borderRadius: AppRadius.mdAll,
              ),
              child: Icon(
                Icons.fingerprint_rounded,
                size: 18,
                color: isDark ? AppColors.ocean400 : AppColors.ocean700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.66),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          ],
        ),
      ),
    );
  }
}
