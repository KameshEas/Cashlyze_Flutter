import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final FlutterSecureStorage _storage;

  /// Creates a [SecureStorageService] with the given storage instance.
  ///
  /// Uses default Android options for better security:
  /// - encryptedSharedPreferences: true
  SecureStorageService(this._storage);

  // Storage keys
  static const String _keyAuthToken = 'auth_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyEncryptionKey = 'encryption_key';
  static const String _keyUserId = 'user_id';
  static const String _keyPinCode = 'pin_code';

  /// Saves the authentication token securely.
  ///
  /// This token is used for API authentication and should be stored securely.
  Future<void> saveAuthToken(String token) async {
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
  Future<void> saveRefreshToken(String token) async {
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
  Future<void> saveEncryptionKey(String key) async {
    await _storage.write(key: _keyEncryptionKey, value: key);
  }

  /// Retrieves the encryption key.
  ///
  /// Returns null if no key is stored.
  Future<String?> getEncryptionKey() async {
    return await _storage.read(key: _keyEncryptionKey);
  }

  /// Saves the user ID.
  Future<void> saveUserId(String userId) async {
    await _storage.write(key: _keyUserId, value: userId);
  }

  /// Retrieves the user ID.
  Future<String?> getUserId() async {
    return await _storage.read(key: _keyUserId);
  }

  /// Saves the PIN code securely (hashed).
  ///
  /// Note: The PIN should be hashed before storing.
  Future<void> savePinCode(String hashedPin) async {
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

  /// Clears all stored data.
  ///
  /// Use this when the user logs out.
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  /// Checks if a specific key exists in secure storage.
  Future<bool> containsKey(String key) async {
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
final flutterSecureStorageProvider = Provider<FlutterSecureStorage>((ref) {
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
final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService(ref.watch(flutterSecureStorageProvider));
});
