import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/ui/constants.dart';
import '../../core/utils/repo_error_handler.dart';
import '../../l10n/app_localizations.dart';
import 'data/password_reset_remote_data_source.dart';
import 'widgets/auth_flow_shell.dart';

final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Step 1 of 3: ask for the account email and send a 6-digit code.
///
/// The server answers identically whether or not the email is registered, so
/// this always continues to the code screen on success (no account probing).
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = '', this.notice});

  final String initialEmail;

  /// Shown as an informational banner, e.g. when a reset session expired.
  final String? notice;

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController =
      TextEditingController(text: widget.initialEmail);
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending || !(_formKey.currentState?.validate() ?? false)) return;
    final email = _emailController.text.trim().toLowerCase();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(passwordResetRemoteDataSourceProvider).requestCode(email: email);
      if (!mounted) return;
      context.go('/reset-code?email=${Uri.encodeComponent(email)}');
    } on TooManyRequestsException {
      if (mounted) {
        setState(() => _error = AppLocalizations.of(context)?.resetTooManyRequests ??
            'Too many attempts. Please wait a few minutes and try again.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = repoErrorMessage(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.72);

    return AuthFlowShell(
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n?.resetTitle ?? 'Reset your password',
            style: theme.textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        Text(
          l10n?.resetSubtitle ?? "Enter your account email and we'll send you a 6-digit code.",
          style: theme.textTheme.bodyMedium?.copyWith(color: muted),
        ),
        const SizedBox(height: AppSpacing.s24),
        if (widget.notice != null) AuthFlowBanner(message: widget.notice!, isError: false),
        if (_error != null) AuthFlowBanner(message: _error!),
        Form(
          key: _formKey,
          child: TextFormField(
            controller: _emailController,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            onFieldSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: l10n?.authEmail ?? 'Email',
              prefixIcon: const Icon(Icons.mail_outline_rounded),
            ),
            validator: (final String? value) {
              final v = value?.trim() ?? '';
              if (v.isEmpty) return l10n?.authEnterEmail ?? 'Please enter your email';
              if (!_emailPattern.hasMatch(v)) {
                return l10n?.authValidEmail ?? 'Please enter a valid email';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: AppSpacing.s20),
        FilledButton(
          onPressed: _sending ? null : _submit,
          child: _sending
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(l10n?.otpSendNow ?? 'Send code'),
        ),
        TextButton(
          onPressed: () => context.go('/login'),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          child: Text(l10n?.resetBackToLogin ?? 'Back to login'),
        ),
      ],
    );
  }
}
