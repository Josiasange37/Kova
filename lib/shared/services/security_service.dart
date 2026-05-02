import 'package:encrypt/encrypt.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/api.dart' as pc;
import 'package:pointycastle/key_generators/rsa_key_generator.dart';
import 'package:pointycastle/key_generators/api.dart';
import 'package:pointycastle/random/fortuna_random.dart';
import 'dart:math';
import 'dart:typed_data';
import 'dart:convert';

class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  late RSAKeyParser _parser;
  RSAPrivateKey? _privateKey;
  RSAPublicKey? _publicKey;
  
  // The Public Key of the OTHER device (Parent or Child)
  RSAPublicKey? _peerPublicKey;

  void init() {
    _parser = RSAKeyParser();
    // In a real app, you'd load these from secure storage (flutter_secure_storage)
    // For the hackathon, we generate them if they don't exist.
  }

  /// GENERATE KEYS (Do this once during app setup)
  /// Note: 2048-bit is secure, but 1024-bit is faster for old tablets.
  Map<String, String> generateKeyPair() {
    final keyPair = _generateRSAKeyPair(2048);
    
    _publicKey = keyPair.publicKey as RSAPublicKey;
    _privateKey = keyPair.privateKey as RSAPrivateKey;

    return {
      'public': _encodePublicKeyToPemPKCS1(_publicKey!),
      'private': _encodePrivateKeyToPemPKCS1(_privateKey!),
    };
  }

  /// SET PEER KEY (Call this when you receive the public key via UDP/TCP)
  void setPeerPublicKey(String keyString) {
    try {
      if (keyString.startsWith('{')) {
        final map = jsonDecode(keyString);
        _peerPublicKey = RSAPublicKey(BigInt.parse(map['n']), BigInt.parse(map['e']));
      } else {
        _peerPublicKey = _parser.parse(keyString) as RSAPublicKey;
      }
    } catch (e) {
      print('Error parsing peer public key: $e');
    }
  }

  /// ENCRYPT (Child calls this before sending)
  String encryptPayload(String plainText) {
    if (_peerPublicKey == null) return plainText; // Fallback if not paired
    
    final encrypter = Encrypter(RSA(publicKey: _peerPublicKey));
    final encrypted = encrypter.encrypt(plainText);
    return encrypted.base64;
  }

  /// DECRYPT (Parent calls this upon receiving)
  String decryptPayload(String base64Cipher) {
    if (_privateKey == null) return "DECRYPTION_ERROR: NO_PRIVATE_KEY";
    if (base64Cipher.startsWith('{')) return base64Cipher; // Fallback if plain JSON
    
    try {
      final encrypter = Encrypter(RSA(privateKey: _privateKey));
      final decrypted = encrypter.decrypt(Encrypted.fromBase64(base64Cipher));
      return decrypted;
    } catch (e) {
      return base64Cipher;
    }
  }

  // --- Helpers for RSA key generation without extra packages ---

  pc.AsymmetricKeyPair<pc.PublicKey, pc.PrivateKey> _generateRSAKeyPair(int bitLength) {
    // Create an RSA key generator and initialize it
    final keyGen = RSAKeyGenerator()
      ..init(pc.ParametersWithRandom(
          RSAKeyGeneratorParameters(BigInt.parse('65537'), bitLength, 64),
          _getSecureRandom()));

    // Use the generator to create a key pair
    final pair = keyGen.generateKeyPair();
    return pair;
  }

  pc.SecureRandom _getSecureRandom() {
    final secureRandom = FortunaRandom();
    final random = Random.secure();
    final seeds = <int>[];
    for (int i = 0; i < 32; i++) {
      seeds.add(random.nextInt(256));
    }
    secureRandom.seed(pc.KeyParameter(Uint8List.fromList(seeds)));
    return secureRandom;
  }

  String _encodePublicKeyToPemPKCS1(RSAPublicKey publicKey) {
    // Simple mock formatting for the hackathon (encrypt package parses PEM automatically usually)
    // A proper implementation would ASN1 encode the key.
    // For this demonstration, we'll use a placeholder or basic string encoding,
    // but the encrypt package requires valid PEM. We'll manually construct a basic PEM structure 
    // or rely on a helper if it existed.
    // For now, let's use a simplified approach since encrypt doesn't have an encoder built-in
    // but parser can parse ASN1.
    // Wait, let's just serialize modulus and exponent to keep it simple, but setPeerPublicKey expects PEM.
    // I'll return a JSON string and parse it manually if PEM is too hard to encode by hand here.
    return jsonEncode({'n': publicKey.modulus.toString(), 'e': publicKey.exponent.toString()});
  }

  String _encodePrivateKeyToPemPKCS1(RSAPrivateKey privateKey) {
    return jsonEncode({'n': privateKey.modulus.toString(), 'd': privateKey.privateExponent.toString(), 'p': privateKey.p.toString(), 'q': privateKey.q.toString()});
  }
}
