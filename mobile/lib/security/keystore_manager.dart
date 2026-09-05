import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:pointycastle/export.dart';
import 'package:shared_preferences/shared_preferences.dart';

class KeystoreManager {
  static const MethodChannel _channel = MethodChannel('com.transact/security');
  static const String _pubKeyPref = 'secp256r1_pubkey_hex';
  static const String _privKeyPref = 'secp256r1_privkey_hex';

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Returns the hex-encoded uncompressed SECP256R1 public key (04 || X || Y).
  static Future<String> getPublicKeyHex() async {
    try {
      final String? key = await _channel.invokeMethod('getPublicKeyHex');
      if (key != null && key.isNotEmpty) return key;
    } catch (_) {}
    return _loadOrGeneratePubKeyHex();
  }

  /// Signs the UTF-8 payload with ECDSA-SHA256 and returns the DER-encoded
  /// signature as lowercase hex.
  static Future<String> signPayload(String payload) async {
    try {
      final String? sig = await _channel.invokeMethod('signPayload', {
        'payload': payload,
      });
      if (sig != null && sig.isNotEmpty) return sig;
    } catch (_) {}
    return _sign(payload);
  }

  static Future<bool> isKeyGenerated() async {
    try {
      final bool? result = await _channel.invokeMethod('isKeyGenerated');
      if (result != null) return result;
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_pubKeyPref);
  }

  static Future<void> generateKeyPair() async {
    try {
      await _channel.invokeMethod('generateKeyPair');
      return;
    } catch (_) {}
    await _loadOrGeneratePubKeyHex(); // ensure keys exist
  }

  // ─── Real ECDSA Fallback (Web / Desktop) ───────────────────────────────────

  /// Loads the persisted keypair, generating a fresh one if none exists.
  static Future<String> _loadOrGeneratePubKeyHex() async {
    final prefs = await SharedPreferences.getInstance();
    String? pubHex = prefs.getString(_pubKeyPref);
    if (pubHex != null && pubHex.isNotEmpty) return pubHex;

    // Generate a real secp256r1 keypair using pointycastle
    final keypair = _generateSecp256r1KeyPair();
    final privKey = keypair.privateKey as ECPrivateKey;
    final pubKey = keypair.publicKey as ECPublicKey;

    final privHex = privKey.d!.toRadixString(16).padLeft(64, '0');
    final pubHex2 = _encodeUncompressedPoint(pubKey);

    await prefs.setString(_privKeyPref, privHex);
    await prefs.setString(_pubKeyPref, pubHex2);
    return pubHex2;
  }

  static Future<String> _sign(String payload) async {
    final prefs = await SharedPreferences.getInstance();
    String? privHex = prefs.getString(_privKeyPref);
    if (privHex == null || privHex.isEmpty) {
      // Generate keypair first
      await _loadOrGeneratePubKeyHex();
      privHex = prefs.getString(_privKeyPref)!;
    }

    final privBytes = _hexToBytes(privHex);
    final domainParams = ECDomainParameters('prime256v1'); // secp256r1
    final privKey = ECPrivateKey(
      _bigIntFromBytes(privBytes),
      domainParams,
    );

    // SHA-256 hash the payload
    final payloadBytes = Uint8List.fromList(utf8.encode(payload));
    final sha256 = SHA256Digest();
    final hash = sha256.process(payloadBytes);

    // ECDSA sign
    final signer = ECDSASigner(null, HMac(SHA256Digest(), 64));
    signer.init(true, PrivateKeyParameter<ECPrivateKey>(privKey));
    final sig = signer.generateSignature(hash) as ECSignature;

    // DER-encode the (r, s) signature – same format as Python's cryptography lib
    final derSig = _derEncodeSignature(sig.r, sig.s);
    return _bytesToHex(derSig);
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  static AsymmetricKeyPair<PublicKey, PrivateKey> _generateSecp256r1KeyPair() {
    final domainParams = ECDomainParameters('prime256v1');
    final secureRandom = FortunaRandom();
    final seedSource = Random.secure();
    final seeds = List<int>.generate(32, (_) => seedSource.nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));

    final generator = ECKeyGenerator()
      ..init(ParametersWithRandom(
        ECKeyGeneratorParameters(domainParams),
        secureRandom,
      ));
    return generator.generateKeyPair();
  }

  /// Encodes the EC public key as uncompressed point hex (04 || X || Y).
  static String _encodeUncompressedPoint(ECPublicKey pubKey) {
    final q = pubKey.Q!;
    final xBytes = _bigIntToBytes(q.x!.toBigInteger()!, 32);
    final yBytes = _bigIntToBytes(q.y!.toBigInteger()!, 32);
    final raw = Uint8List(65);
    raw[0] = 0x04;
    raw.setRange(1, 33, xBytes);
    raw.setRange(33, 65, yBytes);
    return _bytesToHex(raw);
  }

  /// DER-encodes an ECDSA (r, s) pair.
  static Uint8List _derEncodeSignature(BigInt r, BigInt s) {
    final rBytes = _positiveDerInt(r);
    final sBytes = _positiveDerInt(s);
    final seqLen = 2 + rBytes.length + 2 + sBytes.length;
    final buf = BytesBuilder();
    buf.addByte(0x30); // SEQUENCE
    buf.addByte(seqLen);
    buf.addByte(0x02); // INTEGER
    buf.addByte(rBytes.length);
    buf.add(rBytes);
    buf.addByte(0x02); // INTEGER
    buf.addByte(sBytes.length);
    buf.add(sBytes);
    return buf.toBytes();
  }

  /// Produces a DER-safe big-endian byte array for a BigInt (adds leading 0x00
  /// if the high bit would be set, which would indicate a negative number).
  static List<int> _positiveDerInt(BigInt v) {
    final hex = v.toRadixString(16).padLeft((v.bitLength + 7) ~/ 4 * 2, '0');
    final bytes = _hexToBytes(hex);
    if (bytes.isNotEmpty && bytes[0] & 0x80 != 0) {
      return [0x00, ...bytes];
    }
    return bytes;
  }

  static BigInt _bigIntFromBytes(List<int> bytes) {
    BigInt result = BigInt.zero;
    for (final b in bytes) {
      result = (result << 8) | BigInt.from(b);
    }
    return result;
  }

  static Uint8List _bigIntToBytes(BigInt v, int length) {
    final hex = v.toRadixString(16).padLeft(length * 2, '0');
    return _hexToBytes(hex);
  }

  static Uint8List _hexToBytes(String hex) {
    final clean = hex.length.isOdd ? '0$hex' : hex;
    final result = Uint8List(clean.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      result[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }

  static String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
