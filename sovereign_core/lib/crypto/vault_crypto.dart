import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Low-level cryptographic primitives for the vault.
///
/// AES-256-GCM encrypts data; Argon2id turns human-memorable secrets
/// (the PIN, the master password) into 256-bit keys. Nothing in this
/// file ever writes a raw key to disk — callers are responsible for
/// wrapping/unwrapping keys via [KeyManager].
class VaultCrypto {
  VaultCrypto._();

  static final AesGcm aesGcm = AesGcm.with256bits();

  // Argon2id parameters. Memory cost is the primary defense against
  // GPU/ASIC cracking rigs — see the project's cryptography guide for
  // why this matters more than raising `iterations` alone.
  static final Argon2id argon2id = Argon2id(
    memory: 19456, // ~19 MiB, OWASP's minimum recommendation for interactive use
    iterations: 3,
    parallelism: 1,
    hashLength: 32,
  );

  static final _secureRandom = Random.secure();

  static Uint8List randomBytes(int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = _secureRandom.nextInt(256);
    }
    return bytes;
  }

  static Uint8List generateSalt() => randomBytes(16);
  static Uint8List generateVmk() => randomBytes(32);

  /// Derives a 256-bit key from a human secret (PIN or master password)
  /// and a salt, using Argon2id.
  static Future<SecretKey> deriveKey({
    required String secret,
    required List<int> salt,
  }) {
    return argon2id.deriveKeyFromPassword(password: secret, nonce: salt);
  }

  /// Combines two independent secrets (e.g. a PIN-derived key and a
  /// device-bound secret) into a single key via SHA-256, so that
  /// possessing only one of the two inputs is not enough to reconstruct
  /// the combined key.
  static Future<SecretKey> combineSecrets(
    List<int> a,
    List<int> b,
  ) async {
    final hash = await Sha256().hash([...a, ...b]);
    return SecretKey(hash.bytes);
  }

  /// Encrypts [plaintext] under [key], returning a self-contained blob
  /// (nonce + ciphertext + authentication tag) safe to store or transmit.
  static Future<EncryptedBlob> encrypt({
    required List<int> plaintext,
    required SecretKey key,
  }) async {
    final nonce = aesGcm.newNonce();
    final box = await aesGcm.encrypt(plaintext, secretKey: key, nonce: nonce);
    return EncryptedBlob(
      nonce: Uint8List.fromList(box.nonce),
      ciphertext: Uint8List.fromList(box.cipherText),
      mac: Uint8List.fromList(box.mac.bytes),
    );
  }

  /// Decrypts a blob produced by [encrypt]. Throws
  /// [SecretBoxAuthenticationError] if the key is wrong or the blob has
  /// been tampered with — GCM's authentication tag makes tampering fail
  /// loudly rather than silently returning corrupted data.
  static Future<Uint8List> decrypt({
    required EncryptedBlob blob,
    required SecretKey key,
  }) async {
    final box = SecretBox(
      blob.ciphertext,
      nonce: blob.nonce,
      mac: Mac(blob.mac),
    );
    final clear = await aesGcm.decrypt(box, secretKey: key);
    return Uint8List.fromList(clear);
  }
}

/// A self-contained encrypted payload: nonce + ciphertext + MAC, plus
/// JSON (de)serialization so it can be embedded in the vault's on-disk
/// index file.
class EncryptedBlob {
  final Uint8List nonce;
  final Uint8List ciphertext;
  final Uint8List mac;

  EncryptedBlob({required this.nonce, required this.ciphertext, required this.mac});

  Map<String, dynamic> toJson() => {
        'nonce': base64Encode(nonce),
        'ciphertext': base64Encode(ciphertext),
        'mac': base64Encode(mac),
      };

  factory EncryptedBlob.fromJson(Map<String, dynamic> json) => EncryptedBlob(
        nonce: base64Decode(json['nonce'] as String),
        ciphertext: base64Decode(json['ciphertext'] as String),
        mac: base64Decode(json['mac'] as String),
      );
}
