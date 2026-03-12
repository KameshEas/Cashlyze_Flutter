import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/auth_service.dart';
import 'package:go_router/go_router.dart';
import '../../core/repositories/user_repository.dart';
import '../../core/services/analytics_service.dart';
import '../../core/providers/shared_prefs_provider.dart';
import '../../core/providers/otp_pending_provider.dart';
import '../../core/services/biometric_service.dart';
import '../../core/utils/error_messages.dart';

class AuthScreen extends ConsumerStatefulWidget {
  final bool initialIsLogin;

  const AuthScreen({super.key, this.initialIsLogin = true});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  bool _canUseBiometrics = false;
  // Guards the finally-block setState when we navigate away mid-async.
  bool _navigatedAway = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _isLogin = widget.initialIsLogin;
    // Only check biometric availability — the toggle to enable/disable
    // biometrics lives in Settings, not here.
    Future(() async {
      final bio = await ref.read(biometricServiceProvider).isAvailable();
      if (mounted) {
        setState(() => _canUseBiometrics = bio);
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
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
        // Set pending BEFORE calling Firebase so the router guard is already
        // active when authStateChanges fires internally during account creation.
        // If creation fails below, the catch block clears it.
        ref.read(otpPendingProvider.notifier).setPending();

        final credential = await authService.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        final user = credential.user ?? ref.read(currentUserProvider);
        if (user != null) {
          await ref
              .read(userRepositoryProvider)
              .getOrCreateUser(user.uid, user.email!);
          await ref
              .read(analyticsServiceProvider)
              .logEvent('signup', params: {'method': 'email'});
          _navigatedAway = true;
          router.go('/otp?email=${Uri.encodeComponent(_emailController.text.trim())}');
          return;
        }
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
                      const SizedBox(height: 48),

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
                          // Show/hide toggle — a 2024 table-stakes UX requirement
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            tooltip: _obscurePassword
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
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

                      // Error Message
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
                      const SizedBox(height: 16),

                      // Toggle Login/Signup
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isLogin = !_isLogin;
                            _errorMessage = null;
                          });
                        },
                        child: Text(
                          _isLogin
                              ? "Don't have an account? Sign Up"
                              : 'Already have an account? Sign In',
                        ),
                      ),

                      // Forgot Password
                      // Note: biometric on/off toggle is in Settings → Preferences
                      // (showing a security toggle before the user is authenticated
                      //  is contextually wrong and confusing for new users)
                      if (_isLogin)
                        TextButton(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            if (_emailController.text.trim().isEmpty) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please enter your email first',
                                  ),
                                ),
                              );
                              return;
                            }

                            try {
                              await ref
                                  .read(authServiceProvider)
                                  .sendPasswordResetEmail(
                                    _emailController.text.trim(),
                                  );
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Password reset email sent!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } catch (e) {
                              messenger.showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            }
                          },
                          child: const Text('Forgot Password?'),
                        ),
                      if (_isLogin && _canUseBiometrics &&
                          ref.read(sharedPrefsServiceProvider).biometricEnabled)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final router = GoRouter.of(context);
                              final messenger = ScaffoldMessenger.of(context);
                              final ok = await ref
                                  .read(biometricServiceProvider)
                                  .authenticate(reason: 'Unlock Cashlyze');
                              if (ok) {
                                if (mounted) router.go('/');
                              } else {
                                if (mounted) {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('Biometric failed'),
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.fingerprint),
                            label: const Text('Use biometrics'),
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
