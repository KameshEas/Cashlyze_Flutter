import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage service for storing sensitive data.
///
/// This service uses platform-specific secure storage mechanisms:
/// - iOS: Keychain
/// - Android: EncryptedSharedPreferences
/// - Web: Web Crypto API
/// - Desktop: libsecret (Linux), Credential Manager (Windows), Keychain (macOS)
///
/// Example usage:
/// ```dart
/// final secureStorage = ref.read(secureStorageServiceProvider);
/// await secureStorage.saveAuthToken('your-token');
/// final token = await secureStorage.getAuthToken();
/// ```
class SecureStorageService {

  /// Creates a [SecureStorageService] with the given storage instance.
  ///
  /// Uses default Android options for better security:
  /// - encryptedSharedPreferences: true
  SecureStorageService(this._storage);
  final FlutterSecureStorage _storage;

  // Storage keys
  static const String _keyAuthToken = 'auth_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyEncryptionKey = 'encryption_key';
  static const String _keyUserId = 'user_id';
  static const String _keyPinCode = 'pin_code';

  // On-device AI / MCP OAuth keys - separate token pair from the main
  // Cashlyze session, scoped to `app: "mcp_cashlyze"` (see auth service's
  // OAuth flow). mcpClientId is the OAuth client_id registered once via
  // services/auth/scripts/seed_oauth_client.py, not a secret, but kept
  // alongside the tokens for convenience.
  static const String _keyMcpClientId = 'mcp_client_id';
  static const String _keyMcpAccessToken = 'mcp_access_token';
  static const String _keyMcpRefreshToken = 'mcp_refresh_token';

  /// Saves the authentication token securely.
  ///
  /// This token is used for API authentication and should be stored securely.
  Future<void> saveAuthToken(final String token) async {
    await _storage.write(key: _keyAuthToken, value: token);
  }

  /// Retrieves the authentication token.
  ///
  /// Returns null if no token is stored.
  Future<String?> getAuthToken() async {
    return await _storage.read(key: _keyAuthToken);
  }

  /// Deletes the authentication token.
  Future<void> deleteAuthToken() async {
    await _storage.delete(key: _keyAuthToken);
  }

  /// Saves the refresh token securely.
  Future<void> saveRefreshToken(final String token) async {
    await _storage.write(key: _keyRefreshToken, value: token);
  }

  /// Retrieves the refresh token.
  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _keyRefreshToken);
  }

  /// Deletes the refresh token.
  Future<void> deleteRefreshToken() async {
    await _storage.delete(key: _keyRefreshToken);
  }

  /// Saves the encryption key for local data encryption.
  ///
  /// This key is used to encrypt/decrypt sensitive local data.
  Future<void> saveEncryptionKey(final String key) async {
    await _storage.write(key: _keyEncryptionKey, value: key);
  }

  /// Retrieves the encryption key.
  ///
  /// Returns null if no key is stored.
  Future<String?> getEncryptionKey() async {
    return await _storage.read(key: _keyEncryptionKey);
  }

  /// Saves the user ID.
  Future<void> saveUserId(final String userId) async {
    await _storage.write(key: _keyUserId, value: userId);
  }

  /// Retrieves the user ID.
  Future<String?> getUserId() async {
    return await _storage.read(key: _keyUserId);
  }

  /// Saves the PIN code securely (hashed).
  ///
  /// Note: The PIN should be hashed before storing.
  Future<void> savePinCode(final String hashedPin) async {
    await _storage.write(key: _keyPinCode, value: hashedPin);
  }

  /// Retrieves the stored PIN code hash.
  Future<String?> getPinCode() async {
    return await _storage.read(key: _keyPinCode);
  }

  /// Deletes the PIN code.
  Future<void> deletePinCode() async {
    await _storage.delete(key: _keyPinCode);
  }

  /// Saves the registered MCP OAuth client_id (not a secret, but kept here
  /// alongside the tokens it's used with).
  Future<void> saveMcpClientId(final String clientId) async {
    await _storage.write(key: _keyMcpClientId, value: clientId);
  }

  /// Retrieves the registered MCP OAuth client_id.
  Future<String?> getMcpClientId() async {
    return await _storage.read(key: _keyMcpClientId);
  }

  /// Saves the MCP-scoped OAuth access token (`app: "mcp_cashlyze"`).
  ///
  /// This is intentionally a separate token from [saveAuthToken] - it is
  /// only valid against the MCP server, not the regular Cashlyze REST API.
  Future<void> saveMcpAccessToken(final String token) async {
    await _storage.write(key: _keyMcpAccessToken, value: token);
  }

  /// Retrieves the MCP-scoped OAuth access token.
  Future<String?> getMcpAccessToken() async {
    return await _storage.read(key: _keyMcpAccessToken);
  }

  /// Saves the MCP-scoped OAuth refresh token.
  Future<void> saveMcpRefreshToken(final String token) async {
    await _storage.write(key: _keyMcpRefreshToken, value: token);
  }

  /// Retrieves the MCP-scoped OAuth refresh token.
  Future<String?> getMcpRefreshToken() async {
    return await _storage.read(key: _keyMcpRefreshToken);
  }

  /// Clears the MCP OAuth token pair (not the client_id - that stays
  /// registered and reusable across a disconnect/reconnect).
  Future<void> clearMcpTokens() async {
    await _storage.delete(key: _keyMcpAccessToken);
    await _storage.delete(key: _keyMcpRefreshToken);
  }

  /// Clears all stored data.
  ///
  /// Use this when the user logs out.
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  /// Checks if a specific key exists in secure storage.
  Future<bool> containsKey(final String key) async {
    return await _storage.containsKey(key: key);
  }

  /// Reads all stored keys.
  ///
  /// Useful for debugging (use with caution in production).
  Future<Map<String, String>> readAll() async {
    return await _storage.readAll();
  }
}

/// Provider for FlutterSecureStorage instance.
final flutterSecureStorageProvider = Provider<FlutterSecureStorage>((final ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );
});

/// Provider for SecureStorageService.
final secureStorageServiceProvider = Provider<SecureStorageService>((final ref) {
  return SecureStorageService(ref.watch(flutterSecureStorageProvider));
});
