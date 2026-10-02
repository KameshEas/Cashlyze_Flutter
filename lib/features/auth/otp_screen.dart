import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/branding/animated_brand_logo.dart';
import '../../core/branding/flow_backdrop.dart';
import '../../core/providers/otp_pending_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/ui/constants.dart';
import '../../core/utils/repo_error_handler.dart';
import '../../l10n/app_localizations.dart';
import 'data/auth_remote_data_source.dart';
import 'data/otp_remote_data_source.dart';

class OtpScreen extends ConsumerStatefulWidget {

  const OtpScreen({super.key, required this.email});
  /// Email is passed via route query parameter so the screen never depends
  /// on the auth provider being ready (avoids timing issues after signup).
  final String email;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _otpController = TextEditingController();
  bool _sending = false;
  bool _verifying = false;
  // Two-phase UI: first "Send Now", then OTP input after sending.
  bool _otpSent = false;
  // Inline status (replaces snackbars, which are poorly announced and vanish).
  String? _message;
  bool _messageIsError = false;

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
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (final Timer t) {
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
        setState(() {
          _messageIsError = false;
          _message = AppLocalizations.of(context)?.otpSentBanner(email) ??
              'Code sent to $email. Check your inbox.';
        });
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
        setState(() {
          _messageIsError = true;
          _message = repoErrorMessage(e);
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verifyOtp() async {
    final entered = _otpController.text.trim();
    final email = _userEmail;
    if (email.isEmpty) return;
    if (entered.length != 6 || !RegExp(r'^\d{6}$').hasMatch(entered)) {
      setState(() {
        _messageIsError = true;
        _message = AppLocalizations.of(context)?.otpEnterAll ?? 'Enter all 6 digits of the code';
      });
      return;
    }
    setState(() {
      _verifying = true;
      _message = null;
    });
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
        setState(() {
          _messageIsError = true;
          _message = repoErrorMessage(e);
        });
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  /// Mistyped email escape hatch: pending state must be cleared first, or the
  /// router's OTP redirect would bounce the user straight back here.
  void _useDifferentEmail() {
    ref.read(otpPendingProvider.notifier).clearPending();
    GoRouter.of(context).go('/login');
  }

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final email = _userEmail;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: isDark ? const FlowBackdrop.ocean() : const FlowBackdrop.paper(),
          ),
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    children: [
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s24),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          width: keyboardOpen ? 120 : 170,
                          child: FittedBox(
                            child: PlayOnceBrandLogo(
                              color: isDark ? Colors.white : AppColors.brandTeal,
                              showTagline: false,
                              width: 170,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: _buildSheet(context, theme, scheme, isDark, l10n, email),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSheet(
    final BuildContext context,
    final ThemeData theme,
    final ColorScheme scheme,
    final bool isDark,
    final AppLocalizations? l10n,
    final String email,
  ) {
    final muted = scheme.onSurface.withValues(alpha: 0.72);
    final cooldownBucket = ((_resendCooldown + 9) ~/ 10) * 10; // announce coarsely
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: scheme.outline),
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(color: Color(0x1416201B), blurRadius: 28, offset: Offset(0, -8)),
              ],
      ),
      padding: EdgeInsets.fromLTRB(24, 28, 24, 24 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              _otpSent
                  ? (l10n?.otpTitleEnter ?? 'Enter your code')
                  : (l10n?.otpTitleSend ?? 'Verify your account'),
              style: theme.textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            _otpSent
                ? (l10n?.otpSubtitleSent(email) ?? 'A one-time code was sent to $email')
                : (l10n?.otpSubtitleSend(email) ??
                    "We'll send a one-time code to $email to verify your account."),
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
          const SizedBox(height: AppSpacing.s24),
          if (_message != null)
            Semantics(
              liveRegion: true,
              container: true,
              child: Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: AppSpacing.s16),
                decoration: BoxDecoration(
                  color: (_messageIsError ? scheme.error : scheme.primary).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (_messageIsError ? scheme.error : scheme.primary).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _messageIsError ? Icons.error_outline_rounded : Icons.mark_email_read_outlined,
                      size: 20,
                      color: _messageIsError
                          ? (isDark ? const Color(0xFFFF9A9A) : AppColors.error)
                          : (isDark ? AppColors.ocean400 : scheme.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_message!)),
                  ],
                ),
              ),
            ),
          if (!_otpSent)
            FilledButton(
              onPressed: _sending ? null : _sendOtp,
              child: _sending
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(l10n?.otpSendNow ?? 'Send code'),
            )
          else ...[
            _CodeField(
              controller: _otpController,
              label: l10n?.otpCodeLabel ?? 'Verification code, 6 digits',
              onCompleted: _verifying ? null : _verifyOtp,
            ),
            const SizedBox(height: AppSpacing.s20),
            FilledButton(
              onPressed: _verifying ? null : _verifyOtp,
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
              enabled: !(_sending || _resendCooldown > 0),
              excludeSemantics: true,
              label: _resendCooldown > 0
                  ? (l10n?.otpResendIn(cooldownBucket) ?? 'Resend in ${cooldownBucket}s')
                  : (l10n?.otpResend ?? 'Resend code'),
              onTap: (_sending || _resendCooldown > 0) ? null : _sendOtp,
              child: TextButton(
                onPressed: (_sending || _resendCooldown > 0) ? null : _sendOtp,
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                child: Text(
                  _sending
                      ? (l10n?.otpSending ?? 'Sending…')
                      : _resendCooldown > 0
                          ? (l10n?.otpResendIn(_resendCooldown) ?? 'Resend in ${_resendCooldown}s')
                          : (l10n?.otpResend ?? 'Resend code'),
                ),
              ),
            ),
          ],
          TextButton(
            onPressed: _useDifferentEmail,
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            child: Text(l10n?.otpUseDifferentEmail ?? 'Use a different email'),
          ),
        ],
      ),
    );
  }
}

/// Six display boxes over ONE real, invisible [TextField]. Screen readers
/// see a single labelled field (not six), paste and the OS one-time-code
/// autofill work, and there is no per-box focus logic to break on backspace.
class _CodeField extends StatelessWidget {
  const _CodeField({required this.controller, required this.label, this.onCompleted});

  final TextEditingController controller;
  final String label;
  final VoidCallback? onCompleted;

  static const int _length = 6;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final focus = isDark ? AppColors.ocean400 : theme.colorScheme.primary;

    return Semantics(
      label: label,
      textField: true,
      child: SizedBox(
        height: 60,
        child: Stack(
          children: [
            ExcludeSemantics(
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (final context, final value, final _) {
                  final text = value.text;
                  return Row(
                    children: [
                      for (var i = 0; i < _length; i++) ...[
                        if (i > 0) const SizedBox(width: AppSpacing.s8),
                        Expanded(
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurfaceHigh : Colors.white,
                              borderRadius: AppRadius.mdAll,
                              border: Border.all(
                                color: i == text.length.clamp(0, _length - 1)
                                    ? focus
                                    : theme.colorScheme.outline,
                                width: i == text.length.clamp(0, _length - 1) ? 2 : 1,
                              ),
                            ),
                            child: Text(
                              i < text.length ? text[i] : '',
                              style: theme.textTheme.headlineSmall,
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
            Positioned.fill(
              child: TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(_length),
                ],
                showCursor: false,
                enableInteractiveSelection: false,
                // Invisible: the boxes above are the visual.
                style: const TextStyle(color: Colors.transparent),
                decoration: const InputDecoration(
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  counterText: '',
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (final v) {
                  if (v.length == _length) onCompleted?.call();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
