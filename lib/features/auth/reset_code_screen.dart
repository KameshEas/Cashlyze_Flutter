import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/ui/constants.dart';
import '../../core/utils/repo_error_handler.dart';
import '../../l10n/app_localizations.dart';
import 'data/password_reset_remote_data_source.dart';
import 'reset_new_password_screen.dart';
import 'widgets/auth_flow_shell.dart';
import 'widgets/otp_code_field.dart';

/// Step 2 of 3: enter the 6-digit code that was emailed.
///
/// The server allows [kMaxCodeAttempts] wrong guesses per code and then voids
/// it (and rate limits per IP / email), so this screen mirrors that: it counts
/// wrong guesses locally, locks the field when they are spent, and offers a
/// resend after a cooldown. The server stays authoritative; the counter is
/// only there so the user isn't surprised.
class ResetCodeScreen extends ConsumerStatefulWidget {
  const ResetCodeScreen({super.key, required this.email});

  final String email;

  static const int kMaxCodeAttempts = 5;

  /// Matches the backend's one-email-per-60-seconds throttle, so "Resend"
  /// never enables while the server would silently ignore it.
  static const int kResendCooldownSeconds = 60;

  @override
  ConsumerState<ResetCodeScreen> createState() => _ResetCodeScreenState();
}

class _ResetCodeScreenState extends ConsumerState<ResetCodeScreen> {
  final _codeController = TextEditingController();
  bool _verifying = false;
  bool _resending = false;
  int _wrongAttempts = 0;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;
  String? _message;
  bool _messageIsError = false;

  bool get _locked => _wrongAttempts >= ResetCodeScreen.kMaxCodeAttempts;

  @override
  void initState() {
    super.initState();
    // The code was sent by the previous screen just now.
    _startCooldown();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _resendCooldown = ResetCodeScreen.kResendCooldownSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (final t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_resendCooldown > 0) _resendCooldown--;
        if (_resendCooldown == 0) t.cancel();
      });
    });
  }

  void _showError(final String text) => setState(() {
        _messageIsError = true;
        _message = text;
      });

  Future<void> _verify() async {
    if (_verifying || _locked) return;
    final l10n = AppLocalizations.of(context);
    final code = _codeController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      _showError(l10n?.otpEnterAll ?? 'Enter all 6 digits of the code');
      return;
    }
    setState(() {
      _verifying = true;
      _message = null;
    });
    try {
      final token = await ref
          .read(passwordResetRemoteDataSourceProvider)
          .verifyCode(email: widget.email, otp: code);
      if (!mounted) return;
      context.go(
        '/reset-password',
        extra: ResetPasswordArgs(email: widget.email, resetToken: token),
      );
    } on ValidationException {
      // 400: wrong or expired code. The server doesn't say which.
      if (!mounted) return;
      _codeController.clear();
      setState(() => _wrongAttempts++);
      _showError(_locked
          ? (l10n?.resetCodeLocked ?? 'Too many wrong attempts. Request a new code to continue.')
          : (_wrongAttempts >= ResetCodeScreen.kMaxCodeAttempts - 2
              ? (l10n?.resetCodeAttemptsLeft(ResetCodeScreen.kMaxCodeAttempts - _wrongAttempts) ??
                  'That code is incorrect. Attempts left: ${ResetCodeScreen.kMaxCodeAttempts - _wrongAttempts}.')
              : (l10n?.resetCodeWrong ?? 'That code is incorrect or has expired.')));
    } on TooManyRequestsException {
      if (mounted) {
        _showError(l10n?.resetTooManyRequests ??
            'Too many attempts. Please wait a few minutes and try again.');
      }
    } catch (e) {
      if (mounted) _showError(repoErrorMessage(e));
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    if (_resending || _resendCooldown > 0) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _resending = true;
      _message = null;
    });
    try {
      await ref.read(passwordResetRemoteDataSourceProvider).requestCode(email: widget.email);
      if (!mounted) return;
      // A new code replaces the old one server-side, with a fresh attempt budget.
      _codeController.clear();
      setState(() {
        _wrongAttempts = 0;
        _messageIsError = false;
        _message = l10n?.resetCodeSent ?? 'A new code is on its way.';
      });
      _startCooldown();
    } on TooManyRequestsException {
      if (mounted) {
        _showError(l10n?.resetTooManyRequests ??
            'Too many attempts. Please wait a few minutes and try again.');
        _startCooldown();
      }
    } catch (e) {
      if (mounted) _showError(repoErrorMessage(e));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.72);
    final canResend = !_resending && _resendCooldown == 0;
    final cooldownBucket = ((_resendCooldown + 9) ~/ 10) * 10; // announce coarsely

    return AuthFlowShell(
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n?.resetCodeTitle ?? 'Check your email',
            style: theme.textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        Text(
          l10n?.resetCodeSubtitle(widget.email) ??
              'If an account exists for ${widget.email}, we sent a 6-digit code. It expires in 10 minutes.',
          style: theme.textTheme.bodyMedium?.copyWith(color: muted),
        ),
        const SizedBox(height: AppSpacing.s24),
        if (_message != null) AuthFlowBanner(message: _message!, isError: _messageIsError),
        OtpCodeField(
          controller: _codeController,
          label: l10n?.otpCodeLabel ?? 'Verification code, 6 digits',
          enabled: !_locked,
          onCompleted: (_verifying || _locked) ? null : _verify,
        ),
        const SizedBox(height: AppSpacing.s20),
        FilledButton(
          onPressed: (_verifying || _locked) ? null : _verify,
          child: _verifying
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(l10n?.otpVerify ?? 'Verify'),
        ),
        const SizedBox(height: AppSpacing.s4),
        Semantics(
          button: true,
          enabled: canResend,
          excludeSemantics: true,
          label: _resendCooldown > 0
              ? (l10n?.otpResendIn(cooldownBucket) ?? 'Resend in ${cooldownBucket}s')
              : (l10n?.otpResend ?? 'Resend code'),
          onTap: canResend ? _resend : null,
          child: TextButton(
            onPressed: canResend ? _resend : null,
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            child: Text(
              _resending
                  ? (l10n?.otpSending ?? 'Sending…')
                  : _resendCooldown > 0
                      ? (l10n?.otpResendIn(_resendCooldown) ?? 'Resend in ${_resendCooldown}s')
                      : (l10n?.otpResend ?? 'Resend code'),
            ),
          ),
        ),
        TextButton(
          onPressed: () => context.go('/forgot-password'),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          child: Text(l10n?.otpUseDifferentEmail ?? 'Use a different email'),
        ),
      ],
    );
  }
}
