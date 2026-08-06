import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/data/auth_remote_data_source.dart';
import '../api/api_client.dart';
import '../models/auth_user.dart';
import 'auth_session_events.dart';
import 'secure_storage_service.dart';

// ── SharedPreferences keys ────────────────────────────────────────────────────
const _kUserId = 'auth_user_id';
const _kUserEmail = 'auth_user_email';

// ── Providers ─────────────────────────────────────────────────────────────────

/// Provides the [AuthService] singleton. Depends on [apiClientProvider] and
/// [secureStorageServiceProvider] so those must be in scope.
final authServiceProvider = Provider<AuthService>((final ref) {
  return AuthService(
    authDataSource: ref.watch(authRemoteDataSourceProvider),
    secureStorage: ref.watch(secureStorageServiceProvider),
  );
});

/// Stream of the authenticated [AuthUser].  Emits `null` when signed out.
///
/// Replaces the Firebase `authStateChanges()` stream.  The first emission
/// is synchronous (via a seeded broadcast controller) so route guards never
/// see a spurious loading state on cold start.
final authStateChangesProvider = StreamProvider<AuthUser?>((final ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

/// Synchronous snapshot of the currently signed-in user.
///
/// Returns `null` when no user is authenticated.
final currentUserProvider = Provider<AuthUser?>((final ref) {
  return ref.watch(authStateChangesProvider).value;
});

// ── AuthService ───────────────────────────────────────────────────────────────

/// JWT-backed authentication service.
///
/// Auth state is derived from token presence in [SecureStorageService] and a
/// lightweight user identity cached in [SharedPreferences] (non-sensitive).
class AuthService {
  AuthService({
    required final AuthRemoteDataSource authDataSource,
    required final SecureStorageService secureStorage,
  })  : _auth = authDataSource,
        _storage = secureStorage {
    _init();
  }

  final AuthRemoteDataSource _auth;
  final SecureStorageService _storage;

  final _controller = StreamController<AuthUser?>.broadcast();
  StreamSubscription<void>? _forcedLogoutSub;

  /// Public broadcast stream of auth state changes.
  Stream<AuthUser?> get authStateChanges => _controller.stream;

  // ── Initialisation ──────────────────────────────────────────────────────

  /// Called once on construction. Emits the cached user (or null) immediately
  /// so `authStateChangesProvider` has a value before any UI is shown.
  void _init() {
    _emitCurrentUser();
    _forcedLogoutSub = forcedLogoutEvents.stream.listen((final _) => forceSignOutLocally());
  }

  Future<void> _emitCurrentUser() async {
    final token = await _storage.getAuthToken();
    if (token != null) {
      final user = await _loadCachedUser();
      _controller.add(user);
    } else {
      _controller.add(null);
    }
  }

  // ── Sign in ─────────────────────────────────────────────────────────────

  /// Signs in with email + password via `POST /auth/login`.
  Future<void> signInWithEmailAndPassword({
    required final String email,
    required final String password,
  }) async {
    final tokens = await _auth.login(email: email, password: password);
    // Decode userId from the access token payload (sub claim).
    final userId = _extractSubject(tokens.accessToken) ?? email;
    await _persistUser(userId: userId, email: email);
    _controller.add(AuthUser(userId: userId, email: email));
  }

  // ── Register ────────────────────────────────────────────────────────────

  /// Registers a new user after OTP verification via `POST /auth/register`.
  ///
  /// [otpToken] is optional because some backend deployments track OTP
  /// verification server-side and do not return an explicit token.
  Future<void> createUserWithEmailAndPassword({
    required final String email,
    required final String password,
    final String? otpToken,
  }) async {
    final tokens = await _auth.register(
      email: email,
      password: password,
      otpToken: otpToken,
    );
    if (tokens == null) {
      return;
    }
    final userId = _extractSubject(tokens.accessToken) ?? email;
    await _persistUser(userId: userId, email: email);
    _controller.add(AuthUser(userId: userId, email: email));
  }

  // ── Sign out ────────────────────────────────────────────────────────────

  /// Clears tokens and emits `null` to all auth state listeners.
  Future<void> signOut() async {
    await _auth.clearTokens();
    await _clearCachedUser();
    _controller.add(null);
  }

  /// Emits `null` without any network call or re-clearing tokens (the caller
  /// - [ApiClient]'s `onForceLogout` - has already deleted them itself).
  ///
  /// Used when a background token refresh fails: clearing secure-storage
  /// tokens alone does not make the router redirect, since route guards
  /// read `authStateChangesProvider`/`currentUserProvider`, which are fed by
  /// this controller, not by a direct storage read. Without this, a user
  /// whose session died in the background would keep seeing a "logged in"
  /// UI (with every subsequent action silently failing) until the app is
  /// restarted or something else happens to re-check auth state.
  void forceSignOutLocally() {
    _cachedUser = null;
    _controller.add(null);
  }

  // ── Current user ────────────────────────────────────────────────────────

  AuthUser? _cachedUser;

  /// Returns the last-emitted [AuthUser], or `null` if signed out.
  AuthUser? get currentUser => _cachedUser;

  // ── Helpers ─────────────────────────────────────────────────────────────

  Future<void> _persistUser({
    required final String userId,
    required final String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserId, userId);
    await prefs.setString(_kUserEmail, email);
    _cachedUser = AuthUser(userId: userId, email: email);
  }

  Future<AuthUser?> _loadCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_kUserId);
    final email = prefs.getString(_kUserEmail);
    if (userId != null && email != null) {
      _cachedUser = AuthUser(userId: userId, email: email);
      return _cachedUser;
    }
    return null;
  }

  Future<void> _clearCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserId);
    await prefs.remove(_kUserEmail);
    _cachedUser = null;
  }

  /// Decodes the `sub` claim from a JWT without verifying the signature.
  /// Returns `null` on any parse failure.
  static String? _extractSubject(final String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return null;
      final decoded = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final payload = jsonDecode(decoded) as Map<String, dynamic>;
      return payload['sub'] as String?;
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _forcedLogoutSub?.cancel();
    _controller.close();
  }
}
