import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/auth_service.dart';
import 'package:go_router/go_router.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _sending = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    // Attempt to send a verification email when the screen opens
    // to ensure the user gets a link without extra taps.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendVerification();
    });
  }

  Future<void> _sendVerification() async {
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authServiceProvider).sendEmailVerification();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Verification email sent. Check your inbox.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _continue() async {
    setState(() => _checking = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      await ref.read(authServiceProvider).reloadUser();
      final user = ref.read(currentUserProvider);
      if (user != null && user.emailVerified) {
        if (!mounted) return;
        router.go('/');
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('Email not verified yet. Please check again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Verify your email')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.mark_email_read_outlined, size: 88, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'We sent a verification link to your email.\nPlease verify to continue.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _sending ? null : _sendVerification,
                child: _sending
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Resend verification email'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _checking ? null : _continue,
                child: _checking
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text("I've verified, continue"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}