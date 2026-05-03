import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/otp_pending_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/api/api_exception.dart';
import 'data/auth_remote_data_source.dart';
import 'data/otp_remote_data_source.dart';

class OtpScreen extends ConsumerStatefulWidget {
  /// Email is passed via route query parameter so the screen never depends
  /// on the auth provider being ready (avoids timing issues after signup).
  final String email;

  const OtpScreen({super.key, required this.email});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _otpController = TextEditingController();
  bool _sending = false;
  bool _verifying = false;
  // Two-phase UI: first "Send Now", then OTP input after sending.
  bool _otpSent = false;

  // Resend cooldown — user must wait 2 minutes before requesting another OTP.
  static const int _kCooldownSeconds = 120;
  int _resendCooldown = 0;  // 0 means the button is enabled
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Restore UI phase if this widget is recreated mid-session (e.g. after a
    // router rebuild triggered by Firebase authStateChanges).
    final notifier = ref.read(otpPendingProvider.notifier);
    if (notifier.otpAlreadySent) {
      _otpSent = true;
      _startCooldown();
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _resendCooldown = _kCooldownSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_resendCooldown > 0) {
          _resendCooldown--;
        } else {
          t.cancel();
        }
      });
    });
  }

  // Resolve email from route param first, then fall back to the signed-in
  // user's email. This makes the screen resilient when the router omits
  // the `email` query parameter.
  String get _userEmail {
    if (widget.email.isNotEmpty) return widget.email;
    final user = ref.read(currentUserProvider);
    return user?.email ?? '';
  }

  Future<void> _sendOtp() async {
    final email = _userEmail;
    if (email.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(otpRemoteDataSourceProvider).sendOtp(email: email);
      if (mounted) {
        ref.read(otpPendingProvider.notifier).markOtpSent();
        setState(() => _otpSent = true);
        _startCooldown();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OTP sent to $email. Check your inbox.')),
        );
      }
    } on ConflictException {
      ref.read(otpPendingProvider.notifier).clearPending();
      if (mounted) {
        GoRouter.of(context).go(
          '/login?notice=${Uri.encodeComponent('This email is already registered. Please login.')}',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send OTP: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verifyOtp() async {
    final entered = _otpController.text.trim();
    final email = _userEmail;
    if (entered.isEmpty || email.isEmpty) return;
    setState(() => _verifying = true);
    try {
      final result = await ref
          .read(otpRemoteDataSourceProvider)
          .verifyOtp(email: email, otp: entered);

      // After OTP verification, complete registration using the returned token.
      final notifier = ref.read(otpPendingProvider.notifier);
      final password = notifier.pendingPassword;
      final name = notifier.pendingName;
      final mobile = notifier.pendingMobile;
      final otpToken = result.otpToken;

      if (password.isNotEmpty) {
        await ref.read(authRemoteDataSourceProvider).register(
          email: email,
          password: password,
          otpToken: otpToken,
          name: name.isNotEmpty ? name : null,
          mobile: mobile.isNotEmpty ? mobile : null,
        );
      }

      // Clear pending state so router allows navigation to home.
      ref.read(otpPendingProvider.notifier).clearPending();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created. Please login using the account created.'),
            backgroundColor: Colors.green,
          ),
        );
        GoRouter.of(context).go(
          '/login?notice=${Uri.encodeComponent('Account created successfully. Please login using the account created.')}',
        );
      }
    } on ConflictException {
      ref.read(otpPendingProvider.notifier).clearPending();
      if (mounted) {
        GoRouter.of(context).go(
          '/login?notice=${Uri.encodeComponent('This email is already registered. Please login.')}',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final email = _userEmail;
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Account')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _otpSent
                      ? Icons.mark_email_read_outlined
                      : Icons.email_outlined,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  _otpSent ? 'Enter your OTP' : 'Verify your account',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _otpSent
                      ? 'A one-time code was sent to\n$email'
                      : 'We will send a one-time code to\n$email\nto verify your account.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),
                if (!_otpSent) ...([
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _sending ? null : _sendOtp,
                      icon: _sending
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_outlined),
                      label: Text(_sending ? 'Sending…' : 'Send Now'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ]) else ...[
                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    autofocus: true,
                    style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 8),
                    decoration: InputDecoration(
                      labelText: 'Enter OTP',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _verifying ? null : _verifyOtp,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _verifying
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Verify OTP'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: (_sending || _resendCooldown > 0) ? null : _sendOtp,
                    icon: _sending
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh),
                    label: Text(
                      _sending
                          ? 'Sending…'
                          : _resendCooldown > 0
                              ? 'Resend in ${_resendCooldown}s'
                              : 'Resend OTP',
                    ),
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
