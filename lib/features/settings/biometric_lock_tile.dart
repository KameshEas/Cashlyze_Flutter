import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/biometric_lock_providers.dart';
import '../../core/services/biometric_service.dart';

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
              return const ListTile(
                title: Text('Biometric Lock'),
                subtitle: Text('Not supported on this device'),
                enabled: false,
              );
            }

            return ListTile(
              title: const Text('Biometric Lock'),
              subtitle: Text(
                isEnabled
                    ? 'Biometric authentication required to access app'
                    : 'Enable biometric authentication',
              ),
              trailing: Switch(
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
                        ScaffoldMessenger.of(context).showSnackBar(
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
                      ScaffoldMessenger.of(context).showSnackBar(
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
      loading: () => const ListTile(
        title: Text('Biometric Lock'),
        trailing: CircularProgressIndicator(),
      ),
      error: (final _, final _) => const ListTile(
        title: Text('Biometric Lock'),
        subtitle: Text('Failed to load settings'),
      ),
    );
  }
}
