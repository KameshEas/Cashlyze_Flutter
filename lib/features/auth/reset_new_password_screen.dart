import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/ui/constants.dart';
import '../../core/utils/repo_error_handler.dart';
import '../../l10n/app_localizations.dart';
import 'data/password_reset_remote_data_source.dart';
import 'widgets/auth_flow_shell.dart';

/// What step 3 needs from step 2. Handed over through GoRouter `extra` (kept
/// in memory) rather than the URL, so the one-time token never lands in
/// navigation history, logs or deep links.
class ResetPasswordArgs {
  const ResetPasswordArgs({required this.email, required this.resetToken});

  final String email;
  final String resetToken;
}

/// Mirrors the backend's password policy so a weak password is caught before
/// the request is made. Returns true when [password] is acceptable.
bool isAcceptableResetPassword(final String password) =>
    password.length >= 8 &&
    password.contains(RegExp('[A-Z]')) &&
    password.contains(RegExp('[a-z]')) &&
    password.contains(RegExp('[0-9]'));

/// Step 3 of 3: choose the new password.
class ResetNewPasswordScreen extends ConsumerStatefulWidget {
  const ResetNewPasswordScreen({super.key, required this.args});

  final ResetPasswordArgs args;

  @override
  ConsumerState<ResetNewPasswordScreen> createState() => _ResetNewPasswordScreenState();
}

class _ResetNewPasswordScreenState extends ConsumerState<ResetNewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(passwordResetRemoteDataSourceProvider).resetPassword(
            resetToken: widget.args.resetToken,
            newPassword: _passwordController.text,
          );
      if (!mounted) return;
      final notice = l10n?.resetSuccess ?? 'Password reset. Please log in with your new password.';
      context.go('/login?notice=${Uri.encodeComponent(notice)}');
    } on ValidationException catch (e) {
      if (!mounted) return;
      // The password already passed the local policy check, so a 400 here
      // means the reset session itself is gone (expired, used, or replaced by
      // a newer code). Start over rather than leave the user stuck.
      if (e.message.startsWith('New password')) {
        setState(() => _error = e.message);
      } else {
        final notice = l10n?.resetSessionExpired ??
            'Your reset session expired. Please request a new code.';
        context.go(
          '/forgot-password?email=${Uri.encodeComponent(widget.args.email)}'
          '&notice=${Uri.encodeComponent(notice)}',
        );
      }
    } on TooManyRequestsException {
      if (mounted) {
        setState(() => _error = l10n?.resetTooManyRequests ??
            'Too many attempts. Please wait a few minutes and try again.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = repoErrorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.72);
    final toggle = IconButton(
      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
      tooltip: _obscure
          ? (l10n?.authShowPassword ?? 'Show password')
          : (l10n?.authHidePassword ?? 'Hide password'),
      onPressed: () => setState(() => _obscure = !_obscure),
    );

    return AuthFlowShell(
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n?.resetNewTitle ?? 'Choose a new password',
            style: theme.textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        Text(
          l10n?.resetNewSubtitle ??
              'Use at least 8 characters, with uppercase and lowercase letters and a number.',
          style: theme.textTheme.bodyMedium?.copyWith(color: muted),
        ),
        const SizedBox(height: AppSpacing.s24),
        if (_error != null) AuthFlowBanner(message: _error!),
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              children: [
                TextFormField(
                  controller: _passwordController,
                  autofocus: true,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: InputDecoration(
                    labelText: l10n?.resetNewPassword ?? 'New password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: toggle,
                  ),
                  validator: (final String? value) {
                    if (value == null || value.isEmpty) {
                      return l10n?.authEnterPassword ?? 'Please enter your password';
                    }
                    if (!isAcceptableResetPassword(value)) {
                      return l10n?.resetPasswordWeak ??
                          'Use 8+ characters with an uppercase letter, a lowercase letter and a number.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmController,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: l10n?.resetConfirmPassword ?? 'Confirm new password',
                    prefixIcon: const Icon(Icons.lock_reset_rounded),
                  ),
                  validator: (final String? value) => value == _passwordController.text
                      ? null
                      : (l10n?.resetPasswordMismatch ?? "Passwords don't match"),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s20),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(l10n?.resetSubmit ?? 'Reset password'),
        ),
      ],
    );
  }
}
