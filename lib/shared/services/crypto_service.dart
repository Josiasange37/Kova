import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';

/// Handles End-to-End Encryption (E2EE) for KOVA using AES-GCM.
/// Derives a stable 256-bit encryption key from the shared pair token.
class CryptoService {
  late final Key _key;

  CryptoService(String pairToken) {
    // Hash the pairToken using SHA-256 to ensure exactly 32 bytes (256-bit) length
    final tokenBytes = utf8.encode(pairToken);
    final digest = sha256.convert(tokenBytes);
    _key = Key(Uint8List.fromList(digest.bytes));
  }

  /// Encrypts a string payload. Returns a map with base64 encoded 'iv' and 'data'.
  Map<String, String> encryptPayload(String plaintext) {
    if (plaintext.isEmpty) return {'iv': '', 'data': ''};
    
    final iv = IV.fromSecureRandom(16);
    final encrypter = Encrypter(AES(_key, mode: AESMode.gcm));
    
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    
    return {
      'iv': iv.base64,
      'data': encrypted.base64,
    };
  }

  /// Decrypts a base64 encoded string using its provided base64 IV.
  String decryptPayload(String encryptedBase64, String ivBase64) {
    if (encryptedBase64.isEmpty || ivBase64.isEmpty) return '';
    
    try {
      final iv = IV.fromBase64(ivBase64);
      final encrypter = Encrypter(AES(_key, mode: AESMode.gcm));
      
      return encrypter.decrypt(Encrypted.fromBase64(encryptedBase64), iv: iv);
    } catch (e) {
      print('CryptoService decryption error: $e');
      return '';
    }
  }
}
