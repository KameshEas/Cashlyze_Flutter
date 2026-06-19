import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'secure_storage_service.dart';

/// Encryption service for encrypting and decrypting sensitive data.
///
/// This service uses AES-256 encryption in GCM mode for maximum security.
/// The encryption key is stored securely in the device's secure storage.
///
/// Example usage:
/// ```dart
/// final encryptionService = ref.read(encryptionServiceProvider);
/// await encryptionService.initialize();
///
/// final encrypted = await encryptionService.encryptString('sensitive data');
/// final decrypted = await encryptionService.decryptString(encrypted);
/// ```
class EncryptionService {

  EncryptionService(this._secureStorage);
  final SecureStorageService _secureStorage;
  encrypt.Key? _key;
  bool _initialized = false;

  /// Initializes the encryption service.
  ///
  /// This must be called before using any encryption/decryption methods.
  /// It will either load an existing encryption key or generate a new one.
  Future<void> initialize() async {
    if (_initialized) return;

    // Try to load existing key
    final storedKey = await _secureStorage.getEncryptionKey();

    if (storedKey != null) {
      // Use existing key
      _key = encrypt.Key.fromBase64(storedKey);
    } else {
      // Generate new key
      _key = encrypt.Key.fromSecureRandom(32); // 256-bit key
      await _secureStorage.saveEncryptionKey(_key!.base64);
    }

    _initialized = true;
  }

  /// Ensures the service is initialized before use.
  void _ensureInitialized() {
    if (!_initialized || _key == null) {
      throw StateError(
        'EncryptionService must be initialized before use. Call initialize() first.',
      );
    }
  }

  /// Encrypts a string value.
  ///
  /// Returns the encrypted string in base64 format with IV prepended.
  ///
  /// Throws [StateError] if the service is not initialized.
  Future<String> encryptString(final String plainText) async {
    _ensureInitialized();

    final iv = encrypt.IV.fromSecureRandom(16); // 128-bit IV
    final encrypter = encrypt.Encrypter(
      encrypt.AES(_key!, mode: encrypt.AESMode.gcm),
    );

    final encrypted = encrypter.encrypt(plainText, iv: iv);

    // Combine IV and encrypted data
    final combined = '${iv.base64}:${encrypted.base64}';
    return combined;
  }

  /// Decrypts a string value.
  ///
  /// The input should be in the format returned by [encryptString].
  ///
  /// Throws [StateError] if the service is not initialized.
  /// Throws [FormatException] if the input format is invalid.
  Future<String> decryptString(final String encryptedText) async {
    _ensureInitialized();

    try {
      final parts = encryptedText.split(':');
      if (parts.length != 2) {
        throw const FormatException('Invalid encrypted text format');
      }

      final iv = encrypt.IV.fromBase64(parts[0]);
      final encrypted = encrypt.Encrypted.fromBase64(parts[1]);

      final encrypter = encrypt.Encrypter(
        encrypt.AES(_key!, mode: encrypt.AESMode.gcm),
      );

      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      throw FormatException('Failed to decrypt: $e');
    }
  }

  /// Encrypts a map to JSON string.
  ///
  /// Useful for encrypting structured data like user preferences.
  Future<String> encryptMap(final Map<String, dynamic> data) async {
    final jsonString = jsonEncode(data);
    return await encryptString(jsonString);
  }

  /// Decrypts a JSON string to a map.
  Future<Map<String, dynamic>> decryptMap(final String encryptedText) async {
    final jsonString = await decryptString(encryptedText);
    return jsonDecode(jsonString) as Map<String, dynamic>;
  }

  /// Encrypts binary data (Uint8List).
  ///
  /// Useful for encrypting files or images.
  Future<Uint8List> encryptBytes(final Uint8List plainBytes) async {
    _ensureInitialized();

    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(
      encrypt.AES(_key!, mode: encrypt.AESMode.gcm),
    );

    final encrypted = encrypter.encryptBytes(plainBytes, iv: iv);

    // Combine IV and encrypted data
    final combined = Uint8List.fromList([...iv.bytes, ...encrypted.bytes]);
    return combined;
  }

  /// Decrypts binary data (Uint8List).
  Future<Uint8List> decryptBytes(final Uint8List encryptedBytes) async {
    _ensureInitialized();

    try {
      // Extract IV (first 16 bytes) and encrypted data
      final iv = encrypt.IV(encryptedBytes.sublist(0, 16));
      final encryptedData = encrypt.Encrypted(encryptedBytes.sublist(16));

      final encrypter = encrypt.Encrypter(
        encrypt.AES(_key!, mode: encrypt.AESMode.gcm),
      );

      return Uint8List.fromList(encrypter.decryptBytes(encryptedData, iv: iv));
    } catch (e) {
      throw FormatException('Failed to decrypt bytes: $e');
    }
  }

  /// Generates a hash of the input string using SHA-256.
  ///
  /// Useful for hashing passwords or PINs before storage.
  String hashString(final String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verifies if a plain text matches a hash.
  bool verifyHash(final String plainText, final String hash) {
    final computedHash = hashString(plainText);
    return computedHash == hash;
  }

  /// Generates a secure random string of specified length.
  ///
  /// Useful for generating tokens or keys.
  String generateRandomString(final int length) {
    final random = encrypt.Key.fromSecureRandom(length);
    return random.base64.substring(0, length);
  }

  /// Resets the encryption key.
  ///
  /// WARNING: This will make all previously encrypted data unrecoverable.
  /// Use only when necessary (e.g., user account deletion).
  Future<void> resetKey() async {
    _key = encrypt.Key.fromSecureRandom(32);
    await _secureStorage.saveEncryptionKey(_key!.base64);
    _initialized = true;
  }

  /// Checks if the service is initialized.
  bool get isInitialized => _initialized;
}

/// Provider for EncryptionService.
final encryptionServiceProvider = Provider<EncryptionService>((final ref) {
  return EncryptionService(ref.watch(secureStorageServiceProvider));
});
