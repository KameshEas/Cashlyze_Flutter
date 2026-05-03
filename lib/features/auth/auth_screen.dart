import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/auth_service.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/analytics_service.dart';
import '../../core/providers/otp_pending_provider.dart';
import '../../core/api/api_exception.dart';
import '../../core/utils/error_messages.dart';
import 'data/auth_remote_data_source.dart';

class AuthScreen extends ConsumerStatefulWidget {
  final bool initialIsLogin;

  const AuthScreen({super.key, this.initialIsLogin = true});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  String? _noticeMessage;
  bool _noticeHydrated = false;
  // Guards the finally-block setState when we navigate away mid-async.
  bool _navigatedAway = false;

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
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
    required String email,
    required String password,
  }) async {
    try {
      await ref.read(authRemoteDataSourceProvider).register(
        email: email,
        password: password,
      );
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
        ref.read(otpPendingProvider.notifier).setPending(
          email: email,
          password: password,
          name: name,
          mobile: mobile,
        );
        await ref
            .read(analyticsServiceProvider)
            .logEvent('signup_initiated', params: {'method': 'email'});
        _navigatedAway = true;
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
          backgroundColor: Colors.green,
        ),
      );
      _navigatedAway = true;
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

          if (!alreadyRegistered) {
            setState(() {
              _isLogin = false;
              _errorMessage =
                  'No account found for this email. Please register the user.';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surface.withValues(alpha: 0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo or App Name
                      Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 80,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Cashlyze',
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isLogin ? 'Welcome back!' : 'Create an account',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // Card container
                      Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header tabs
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          _isLogin = true;
                                          _errorMessage = null;
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        decoration: BoxDecoration(
                                          color: _isLogin
                                              ? theme.colorScheme.primary.withOpacity(0.12)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Center(
                                          child: Text(
                                            'Sign In',
                                            style: theme.textTheme.bodyLarge?.copyWith(
                                              color: _isLogin
                                                  ? theme.colorScheme.primary
                                                  : theme.colorScheme.onSurface,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          _isLogin = false;
                                          _errorMessage = null;
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        decoration: BoxDecoration(
                                          color: !_isLogin
                                              ? theme.colorScheme.primary.withOpacity(0.12)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Center(
                                          child: Text(
                                            'Sign Up',
                                            style: theme.textTheme.bodyLarge?.copyWith(
                                              color: !_isLogin
                                                  ? theme.colorScheme.primary
                                                  : theme.colorScheme.onSurface,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Animated form content: smooth size + fade transition
                            ClipRect(
                              child: AnimatedSize(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutCubic,
                                alignment: Alignment.topCenter,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 220),
                                  switchInCurve: Curves.easeIn,
                                  switchOutCurve: Curves.easeOut,
                                  layoutBuilder: (currentChild, previousChildren) {
                                    return Stack(
                                      alignment: Alignment.topCenter,
                                      children: [
                                        ...previousChildren,
                                        if (currentChild != null) currentChild,
                                      ],
                                    );
                                  },
                                  transitionBuilder: (child, animation) {
                                    final fade = CurvedAnimation(parent: animation, curve: Curves.easeIn);
                                    final size = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
                                    return FadeTransition(
                                      opacity: fade,
                                      child: SizeTransition(
                                        sizeFactor: size,
                                        axis: Axis.vertical,
                                        axisAlignment: -1.0,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Column(
                                    key: ValueKey<String>(_isLogin ? 'auth-login' : 'auth-signup'),
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // Name & Mobile (Sign Up only)
                                      if (!_isLogin) ...[
                                        TextFormField(
                                          controller: _nameController,
                                          decoration: InputDecoration(
                                            labelText: 'Name',
                                            prefixIcon: const Icon(Icons.person_outline),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            filled: true,
                                          ),
                                          validator: (value) {
                                            if (!_isLogin) {
                                              if (value == null || value.trim().isEmpty) {
                                                return 'Please enter your name';
                                              }
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 12),
                                        TextFormField(
                                          controller: _mobileController,
                                          keyboardType: TextInputType.phone,
                                          decoration: InputDecoration(
                                            labelText: 'Mobile',
                                            prefixIcon: const Icon(Icons.phone_outlined),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            filled: true,
                                          ),
                                          validator: (value) {
                                            if (!_isLogin) {
                                              if (value == null || value.trim().isEmpty) {
                                                return 'Please enter your mobile number';
                                              }
                                              if (value.trim().length < 6) {
                                                return 'Mobile number must be at least 6 digits';
                                              }
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 16),
                                      ],

                                      // Email Field
                                      TextFormField(
                                        controller: _emailController,
                                        keyboardType: TextInputType.emailAddress,
                                        decoration: InputDecoration(
                                          labelText: 'Email',
                                          prefixIcon: const Icon(Icons.email_outlined),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          filled: true,
                                        ),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please enter your email';
                                          }
                                          if (!value.contains('@')) {
                                            return 'Please enter a valid email';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 16),

                                      // Password Field
                                      TextFormField(
                                        controller: _passwordController,
                                        obscureText: _obscurePassword,
                                        decoration: InputDecoration(
                                          labelText: 'Password',
                                          prefixIcon: const Icon(Icons.lock_outline),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          filled: true,
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _obscurePassword
                                                  ? Icons.visibility_outlined
                                                  : Icons.visibility_off_outlined,
                                            ),
                                            tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                          ),
                                        ),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please enter your password';
                                          }
                                          if (value.length < 6) {
                                            return 'Password must be at least 6 characters';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 24),

                                      // Notice / Error
                                      if (_noticeMessage != null)
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          margin: const EdgeInsets.only(bottom: 12),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Text(
                                            _noticeMessage!,
                                            style: TextStyle(color: theme.colorScheme.primary),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),

                                      if (_errorMessage != null)
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          margin: const EdgeInsets.only(bottom: 16),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: Colors.red.withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Text(
                                            _errorMessage!,
                                            style: TextStyle(color: Colors.red[300]),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),

                                      // Submit Button
                                      FilledButton(
                                        onPressed: _isLoading ? null : _submit,
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          minimumSize: const Size.fromHeight(52),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        child: _isLoading
                                            ? const SizedBox(
                                                height: 20,
                                                width: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : Text(
                                                _isLogin ? 'Sign In' : 'Sign Up',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                      ),
                                      const SizedBox(height: 12),

                                      // Forgot Password (only for Sign In)
                                      if (_isLogin)
                                        TextButton(
                                          onPressed: () async {
                                            final messenger = ScaffoldMessenger.of(context);
                                            if (_emailController.text.trim().isEmpty) {
                                              messenger.showSnackBar(
                                                const SnackBar(
                                                  content: Text('Please enter your email first'),
                                                ),
                                              );
                                              return;
                                            }

                                            messenger.showSnackBar(
                                              const SnackBar(
                                                content: Text('Password reset is not available yet. Please contact support.'),
                                              ),
                                            );
                                          },
                                          child: const Text('Forgot Password?'),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
