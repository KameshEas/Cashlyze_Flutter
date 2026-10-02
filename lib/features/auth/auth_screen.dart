import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/branding/animated_brand_logo.dart';
import '../../core/branding/flow_backdrop.dart';
import '../../core/providers/otp_pending_provider.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/ui/constants.dart';
import '../../core/utils/error_messages.dart';
import '../../l10n/app_localizations.dart';
import 'data/auth_remote_data_source.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.initialIsLogin = true});
  final bool initialIsLogin;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _mobileFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  String? _noticeMessage;
  bool _noticeHydrated = false;
  final _bannerKey = GlobalKey();
  String? _revealedError;
  // Guards the finally-block setState when we navigate away mid-async.
  bool _navigatedAway = false;

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _mobileFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _isLogin = widget.initialIsLogin;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_noticeHydrated) return;
    final notice = GoRouterState.of(context).uri.queryParameters['notice'];
    if (notice != null && notice.isNotEmpty) {
      _noticeMessage = notice;
    }
    _noticeHydrated = true;
  }

  /// Best-effort precheck before OTP send.
  ///
  /// Backend currently returns 409 Conflict with "Email already registered"
  /// on duplicate registration attempts, which lets us fail fast in signup.
  Future<bool> _isEmailAlreadyRegistered({
    required final String email,
    required final String password,
  }) async {
    try {
      await ref
          .read(authRemoteDataSourceProvider)
          .register(email: email, password: password);
      // Unexpected success for precheck path — treat as not-registered for OTP
      // flow and immediately clear any persisted auth state.
      await ref.read(authServiceProvider).signOut();
      return false;
    } on ConflictException catch (_) {
      return true;
    } catch (_) {
      // Any non-conflict response (for example "OTP verification required")
      // means we should continue with OTP flow.
      return false;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _noticeMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final messenger = ScaffoldMessenger.of(context);
      final router = GoRouter.of(context);

      if (_isLogin) {
        await authService.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        await ref
            .read(analyticsServiceProvider)
            .logEvent('login', params: {'method': 'email'});
      } else {
        final email = _emailController.text.trim();
        final password = _passwordController.text;

        final alreadyRegistered = await _isEmailAlreadyRegistered(
          email: email,
          password: password,
        );
        if (alreadyRegistered) {
          setState(() {
            _errorMessage =
                'This email is already registered. Please sign in instead.';
            _isLogin = true;
          });
          return;
        }

        // Store email + password so the OTP screen can complete registration
        // once the OTP is verified and an otpToken is returned. Also store
        // name and mobile for richer user profile creation.
        final name = _nameController.text.trim();
        final mobile = _mobileController.text.trim();
        ref
            .read(otpPendingProvider.notifier)
            .setPending(
              email: email,
              password: password,
              name: name,
              mobile: mobile,
            );
        await ref
            .read(analyticsServiceProvider)
            .logEvent('signup_initiated', params: {'method': 'email'});
        _navigatedAway = true;
        // The account isn't verified yet, so don't offer to save it.
        TextInput.finishAutofillContext(shouldSave: false);
        router.go('/otp?email=${Uri.encodeComponent(email)}');
        return;
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _isLogin
                ? 'Signed in successfully!'
                : 'Account created successfully!',
          ),
        ),
      );
      _navigatedAway = true;
      // Let the password manager offer to save the credentials.
      TextInput.finishAutofillContext();
      router.go('/');
    } catch (e) {
      if (_isLogin) {
        final raw = e.toString().toLowerCase();
        final isInvalidCredentials =
            e is UnauthorizedException || raw.contains('invalid credentials');

        if (isInvalidCredentials) {
          final email = _emailController.text.trim();
          final password = _passwordController.text;
          final alreadyRegistered = await _isEmailAlreadyRegistered(
            email: email,
            password: password,
          );
          if (!mounted) return;

          if (!alreadyRegistered) {
            setState(() {
              _isLogin = false;
              _errorMessage =
                  'No account found for this email. Please create an account.';
            });
            return;
          }
        }
      }

      // If signup failed, the pending flag was set pre-emptively — clear it.
      if (!_isLogin) {
        ref.read(otpPendingProvider.notifier).clearPending();
      }
      setState(() {
        // Use human-readable messages — never expose raw Firebase error codes.
        _errorMessage = friendlyAuthError(e);
      });
    } finally {
      if (mounted && !_navigatedAway) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _switchMode({required final bool login}) {
    if (_isLogin == login) return;
    setState(() {
      _isLogin = login;
      // A stale notice/error from the other mode would be misleading.
      _errorMessage = null;
      _noticeMessage = null;
    });
  }

  /// Scrolls a freshly shown error banner into view so it can't sit hidden
  /// behind the keyboard.
  void _revealErrorIfNew() {
    final error = _errorMessage;
    if (error == null || error == _revealedError) return;
    _revealedError = error;
    WidgetsBinding.instance.addPostFrameCallback((final _) {
      final ctx = _bannerKey.currentContext;
      if (!mounted || ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 200),
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;
    // Read above the Scaffold: inside its body the keyboard inset is consumed.
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    _revealErrorIfNew();

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: isDark ? const FlowBackdrop.ocean() : const FlowBackdrop.paper(),
          ),
          SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (final context, final box) {
                // The logo stays mounted (so its one-shot animation never
                // replays) and is simply scaled down when space is tight.
                final compact = keyboardOpen || box.maxHeight < 600;
                return CustomScrollView(
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
                              curve: Curves.easeOutCubic,
                              width: compact ? 150 : 230,
                              child: FittedBox(
                                child: PlayOnceBrandLogo(
                                  color: isDark ? Colors.white : AppColors.brandTeal,
                                  taglineColor: isDark
                                      ? Colors.white.withValues(alpha: 0.8)
                                      : const Color(0xFF666666),
                                  width: 230,
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 480),
                              child: _buildSheet(context, theme, scheme, isDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// The bottom form sheet: Sign In / Sign Up tabs, fields, submit.
  Widget _buildSheet(
    final BuildContext context,
    final ThemeData theme,
    final ColorScheme scheme,
    final bool isDark,
  ) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: scheme.outline),
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x1416201B),
                  blurRadius: 28,
                  offset: Offset(0, -8),
                ),
              ],
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _AuthTab(
                      label: l10n?.authSignIn ?? 'Sign In',
                      selected: _isLogin,
                      onTap: () => _switchMode(login: true),
                    ),
                  ),
                  Expanded(
                    child: _AuthTab(
                      label: l10n?.authSignUp ?? 'Sign Up',
                      selected: !_isLogin,
                      onTap: () => _switchMode(login: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_isLogin) ...[
                      TextFormField(
                        controller: _nameController,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.name],
                        onFieldSubmitted: (_) =>
                            FocusScope.of(context).requestFocus(_mobileFocusNode),
                        decoration: InputDecoration(
                          labelText: l10n?.authName ?? 'Name',
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                        ),
                        validator: (final String? value) =>
                            value == null || value.trim().isEmpty
                                ? l10n?.authEnterName ?? 'Please enter your name'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _mobileController,
                        focusNode: _mobileFocusNode,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                          LengthLimitingTextInputFormatter(15),
                        ],
                        onFieldSubmitted: (_) =>
                            FocusScope.of(context).requestFocus(_emailFocusNode),
                        decoration: InputDecoration(
                          labelText: l10n?.authMobile ?? 'Mobile',
                          prefixIcon: const Icon(Icons.phone_outlined),
                        ),
                        validator: (final String? value) {
                          if (value == null || value.trim().isEmpty) {
                            return l10n?.authEnterMobile ?? 'Please enter your mobile number';
                          }
                          if (value.trim().length < 6) {
                            return l10n?.authMobileMin ?? 'Mobile number must be at least 6 digits';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _emailController,
                      focusNode: _emailFocusNode,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: _isLogin
                          ? const [AutofillHints.username, AutofillHints.email]
                          : const [AutofillHints.email],
                      onFieldSubmitted: (_) =>
                          FocusScope.of(context).requestFocus(_passwordFocusNode),
                      decoration: InputDecoration(
                        labelText: l10n?.authEmail ?? 'Email',
                        prefixIcon: const Icon(Icons.mail_outline_rounded),
                      ),
                      validator: (final String? value) {
                        if (value == null || value.isEmpty) {
                          return l10n?.authEnterEmail ?? 'Please enter your email';
                        }
                        if (!value.contains('@')) {
                          return l10n?.authValidEmail ?? 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      focusNode: _passwordFocusNode,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: [
                        _isLogin ? AutofillHints.password : AutofillHints.newPassword,
                      ],
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: l10n?.authPassword ?? 'Password',
                        // The rule is stated up front on sign-up instead of
                        // surfacing only after a failed submit.
                        helperText: _isLogin
                            ? null
                            : (l10n?.authPasswordHelper ?? 'At least 6 characters'),
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          tooltip: _obscurePassword
                              ? (l10n?.authShowPassword ?? 'Show password')
                              : (l10n?.authHidePassword ?? 'Hide password'),
                          onPressed: () =>
                              setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (final String? value) {
                        if (value == null || value.isEmpty) {
                          return l10n?.authEnterPassword ?? 'Please enter your password';
                        }
                        if (value.length < 6) {
                          return l10n?.authPasswordMin ?? 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    // Forgot Password / social sign-in intentionally omitted:
                    // there is no reset flow, support channel or Google/Apple
                    // auth endpoint wired up yet, so showing them would be
                    // dead ends.
                    const SizedBox(height: 20),
                    if (_noticeMessage != null)
                      _AuthBanner(
                        message: _noticeMessage!,
                        icon: Icons.info_outline_rounded,
                        color: scheme.primary,
                        textColor: isDark ? AppColors.ocean400 : scheme.primary,
                      ),
                    if (_errorMessage != null)
                      _AuthBanner(
                        key: _bannerKey,
                        message: _errorMessage!,
                        icon: Icons.error_outline_rounded,
                        color: scheme.error,
                        textColor: isDark ? const Color(0xFFFF9A9A) : AppColors.error,
                      ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              _isLogin
                                  ? (l10n?.authSignIn ?? 'Sign In')
                                  : (l10n?.authCreateAccount ?? 'Create Account'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_isLogin) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 20),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: 4),
              // Inline mode switch for users who miss the tabs.
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    _isLogin
                        ? (l10n?.authNoAccountPrompt ?? "Don't have an account?")
                        : (l10n?.authHaveAccountPrompt ?? 'Already have an account?'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _switchMode(login: !_isLogin),
                    style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                    child: Text(
                      _isLogin
                          ? (l10n?.authSignUp ?? 'Sign Up')
                          : (l10n?.authSignIn ?? 'Sign In'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One of the two underline tabs at the top of the form sheet.
class _AuthTab extends StatelessWidget {
  const _AuthTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final active = isDark ? AppColors.ocean400 : theme.colorScheme.primary;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? active
                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: selected ? 3 : 1,
              decoration: BoxDecoration(
                color: selected ? active : theme.colorScheme.outline,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline notice/error banner. Announced to screen readers when it appears
/// and carries an icon so state isn't conveyed by colour alone.
class _AuthBanner extends StatelessWidget {
  const _AuthBanner({
    super.key,
    required this.message,
    required this.icon,
    required this.color,
    required this.textColor,
  });

  final String message;
  final IconData icon;
  final Color color;
  final Color textColor;

  @override
  Widget build(final BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: textColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: TextStyle(color: textColor)),
            ),
          ],
        ),
      ),
    );
  }
}
