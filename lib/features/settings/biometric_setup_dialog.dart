import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/services/biometric_service.dart';

/// Tells the user no fingerprint / face is set up and, on Android, takes them
/// straight to the system screen where they can add one. iOS has no public way
/// to open that screen, so there it explains where to find it.
Future<void> showBiometricSetupDialog(
  final BuildContext context,
  final BiometricService service,
) async {
  final isAndroid = defaultTargetPlatform == TargetPlatform.android;
  final openSettings = await showDialog<bool>(
    context: context,
    builder: (final ctx) => AlertDialog(
      icon: const Icon(Icons.fingerprint_rounded, size: 40),
      title: const Text('Set up biometrics'),
      content: Text(
        isAndroid
            ? 'No fingerprint or face is set up on this phone yet. Add one in '
                'your phone settings, then come back and turn on Biometric Lock.'
            : 'No Face ID or Touch ID is set up on this device yet. Add one in '
                'Settings > Face ID & Passcode (or Touch ID & Passcode), then '
                'come back and turn on Biometric Lock.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(isAndroid ? 'Not now' : 'OK'),
        ),
        if (isAndroid)
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Open settings'),
          ),
      ],
    ),
  );

  if (openSettings != true) return;
  final opened = await service.openEnrollmentSettings();
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Open Settings > Security on your phone to add a fingerprint or face.'),
      ),
    );
  }
}
