import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

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
  final service = AuthService(
    authDataSource: ref.watch(authRemoteDataSourceProvider),
    secureStorage: ref.watch(secureStorageServiceProvider),
  );
  dbg('[AUTHDBG] authServiceProvider create ${identityHashCode(service)}');
  ref.onDispose(() {
    dbg('[AUTHDBG] authServiceProvider dispose ${identityHashCode(service)}');
    service.dispose();
  });
  return service;
});

/// Stream of the authenticated [AuthUser].  Emits `null` when signed out.
///
/// Replaces the Firebase `authStateChanges()` stream.  The first emission
/// is synchronous (via a seeded broadcast controller) so route guards never
/// see a spurious loading state on cold start.
final authStateChangesProvider = StreamProvider<AuthUser?>((final ref) {
  dbg('[AUTHDBG] authStateChangesProvider build');
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
    final Duration startupReadTimeout = defaultStartupReadTimeout,
  })  : _auth = authDataSource,
        _storage = secureStorage,
        _startupReadTimeout = startupReadTimeout {
    _init();
  }

  final AuthRemoteDataSource _auth;
  final SecureStorageService _storage;

  final _controller = StreamController<AuthUser?>.broadcast();
  StreamSubscription<void>? _forcedLogoutSub;

  // The latest emitted value, replayed to late subscribers. A plain broadcast
  // stream drops events nobody is listening to yet, and `_init` emits as soon
  // as the service is built - so on a cold start while signed in, a listener
  // that attached a moment later (the router's `authStateChangesProvider`)
  // never saw the first value and the app sat on the loading screen until some
  // unrelated event arrived.
  AuthUser? _last;
  bool _hasLast = false;

  void _emit(final AuthUser? user) {
    dbg('[AUTHDBG] emit ${user?.email}');
    _last = user;
    _hasLast = true;
    if (!_controller.isClosed) _controller.add(user);
  }

  /// Public stream of auth state changes. Replays the most recent value to
  /// each new subscriber, then follows live updates.
  Stream<AuthUser?> get authStateChanges => Stream<AuthUser?>.multi((final c) {
        if (_hasLast) c.add(_last);
        final sub = _controller.stream.listen(c.add, onError: c.addError, onDone: c.close);
        c.onCancel = sub.cancel;
      });

  // ── Initialisation ──────────────────────────────────────────────────────

  /// Called once on construction. Emits the cached user (or null) immediately
  /// so `authStateChangesProvider` has a value before any UI is shown.
  void _init() {
    _emitCurrentUser();
    _forcedLogoutSub = forcedLogoutEvents.stream.listen((final _) => forceSignOutLocally());
  }

  /// How long the cold-start read of the saved session may take before we
  /// give up and treat the user as signed out. Secure storage is backed by the
  /// Android Keystore, which can stall or throw (for example when an
  /// auto-backup restore brings back encrypted data without its key). Without
  /// this bound the router waited on the loading screen forever.
  static const Duration defaultStartupReadTimeout = Duration(seconds: 6);
  final Duration _startupReadTimeout;

  Timer? _startupTimer;

  Future<void> _emitCurrentUser() async {
    dbg('[AUTHDBG] emitCurrentUser start');
    // A hand-rolled bound (rather than Future.timeout) so the timer can be
    // cancelled the moment the read finishes or the service is disposed, and
    // never lingers past either.
    final read = Completer<String?>();
    _startupTimer = Timer(_startupReadTimeout, () {
      if (!read.isCompleted) read.completeError(TimeoutException('secure storage read', _startupReadTimeout));
    });
    unawaited(_storage.getAuthToken().then(
      (final token) {
        if (!read.isCompleted) read.complete(token);
      },
      onError: (final Object e, final StackTrace st) {
        if (!read.isCompleted) read.completeError(e, st);
      },
    ));
    try {
      final token = await read.future;
      dbg('[AUTHDBG] token read, present=${token != null}');
      _startupTimer?.cancel();
      if (token != null) {
        final user = await _loadCachedUser();
        dbg('[AUTHDBG] cached user ${user?.email}');
        _emit(user);
      } else {
        _emit(null);
      }
    } catch (e) {
      dbg('[AUTHDBG] startup read failed: $e');
      // Unreadable or unresponsive storage: fall back to signed-out so the
      // user reaches the login screen instead of a loading screen that never
      // resolves. A fresh sign-in rewrites the session.
      _startupTimer?.cancel();
      _emit(null);
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
    _emit(AuthUser(userId: userId, email: email));
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
    _emit(AuthUser(userId: userId, email: email));
  }

  // ── Sign out ────────────────────────────────────────────────────────────

  /// Clears tokens and emits `null` to all auth state listeners.
  Future<void> signOut() async {
    await _auth.clearTokens();
    await _clearCachedUser();
    _emit(null);
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
    _emit(null);
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
    _startupTimer?.cancel();
    _forcedLogoutSub?.cancel();
    _controller.close();
  }
}

/// TEMPORARY: append a timestamped line to the app's files dir so startup can
/// be traced on a device whose logcat drops Flutter logs.
void dbg(final String message) {
  try {
    File('/data/user/0/com.aspiredesignovation.cashlyze/files/dbg.log')
        .writeAsStringSync('${DateTime.now().toIso8601String()} $message\n', mode: FileMode.append);
  } catch (_) {}
}
