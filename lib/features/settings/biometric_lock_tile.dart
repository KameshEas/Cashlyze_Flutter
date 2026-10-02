import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/biometric_lock_providers.dart';
import '../../core/services/biometric_service.dart';
import '../../core/ui/constants.dart';

class BiometricLockTile extends ConsumerWidget {
  const BiometricLockTile({super.key});

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    return ref.watch(biometricLockProvider).when(
      data: (final isEnabled) {
        return FutureBuilder<bool>(
          future: BiometricService.isDeviceSupported(),
          builder: (final context, final snapshot) {
            final isSupported = snapshot.data ?? false;

            if (!isSupported) {
              return const _BiometricRow(
                title: 'Biometric Lock',
                subtitle: 'Not supported on this device',
                enabled: false,
              );
            }

            return _BiometricRow(
              title: 'Biometric Lock',
              subtitle: isEnabled
                  ? 'Biometric authentication required to access app'
                  : 'Enable biometric authentication',
              trailing: Switch.adaptive(
                value: isEnabled,
                onChanged: (final value) async {
                  if (value) {
                    final authenticated =
                        await BiometricService.authenticate();
                    if (authenticated && context.mounted) {
                      await ref
                          .read(biometricLockProvider.notifier)
                          .enable();
                      if (context.mounted) {
                        final messenger = ScaffoldMessenger.of(context);
                        await HapticFeedback.lightImpact();
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Biometric lock enabled',
                            ),
                          ),
                        );
                      }
                    }
                  } else {
                    await ref
                        .read(biometricLockProvider.notifier)
                        .disable();
                    if (context.mounted) {
                      final messenger = ScaffoldMessenger.of(context);
                      await HapticFeedback.lightImpact();
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Biometric lock disabled',
                          ),
                        ),
                      );
                    }
                  }
                },
              ),
            );
          },
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
