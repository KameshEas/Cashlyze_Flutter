import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// RFC 7636 PKCE code_verifier / code_challenge pair (S256).
///
/// Used once per MCP OAuth authorize/token exchange - see [McpOAuthClient].
class PkcePair {
  PkcePair._(this.codeVerifier, this.codeChallenge);

  /// Generates a new, cryptographically random PKCE pair.
  factory PkcePair.generate() {
    final verifier = _generateCodeVerifier();
    final challenge = _codeChallengeFor(verifier);
    return PkcePair._(verifier, challenge);
  }

  /// 43-128 character unreserved-character string, sent to `/oauth/token`
  /// alongside the authorization code.
  final String codeVerifier;

  /// `BASE64URL-ENCODE(SHA256(codeVerifier))`, sent to `/oauth/authorize`.
  final String codeChallenge;

  static String _generateCodeVerifier() {
    final random = Random.secure();
    // 96 random bytes -> 128 base64url chars, within the 43-128 spec range.
    final bytes = List<int>.generate(96, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  static String _codeChallengeFor(final String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }
}

/// Generates a random `state` parameter to guard the authorize/token
/// round-trip against CSRF (even though this flow never leaves the app -
/// there's no browser redirect - it's cheap defense-in-depth and mirrors
/// standard OAuth client behavior).
String generateOAuthState() {
  final random = Random.secure();
  final bytes = List<int>.generate(24, (_) => random.nextInt(256));
  return base64UrlEncode(bytes).replaceAll('=', '');
}
