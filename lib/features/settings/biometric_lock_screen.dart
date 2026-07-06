import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  Future<void> _triggerAuthentication() async {
    if (_isAuthenticating) return;

    setState(() => _isAuthenticating = true);

    final authenticated = await BiometricService.authenticate();
    if (authenticated && mounted) {
      Navigator.of(context).pop();
    } else {
      setState(() => _isAuthenticating = false);
    }
  }

  @override
  Widget build(final BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.fingerprint,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 24),
              const Text(
                'Authenticate to unlock',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _isAuthenticating
                    ? 'Waiting for authentication...'
                    : 'Use your biometric to access Cashlyze',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
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
            ],
          ),
        ),
      ),
    );
  }
}
