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

  // A deliberately harder profile for sealed exports (see
  // SealedExportService). The daily-unlock profile above is tuned to
  // stay fast on every unlock; an exported file has no server to
  // rate-limit guesses and may sit in an inbox for years, so it can
  // and should cost an attacker far more per guess. A few seconds on
  // export/import is an acceptable trade for a rare, deliberate action.
  //
  // Raised again (from 64 MiB/4 iterations) once sealed exports could
  // be protected by a 6-digit PIN instead of a 6-word passphrase —
  // ~20 bits of entropy instead of ~48. This raises the cost of each
  // guess substantially, but no amount of KDF hardening turns a
  // 1-in-a-million secret into a strong one on its own; it only raises
  // the bar for an opportunistic attacker, not a well-resourced one.
  //
  // Kept as plain constants (not read back off the Argon2id instance
  // below) so a sealed file can record exactly which parameters
  // encrypted it, independent of whatever this class's defaults are
  // when the file is later opened.
  static const argon2idExportMemory = 131072; // 128 MiB
  static const argon2idExportIterations = 5;
  static const argon2idExportParallelism = 1;
  static final Argon2id argon2idExport = Argon2id(
    memory: argon2idExportMemory,
    iterations: argon2idExportIterations,
    parallelism: argon2idExportParallelism,
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
  /// and a salt, using Argon2id. Pass [kdf] to use a different cost
  /// profile than the daily-unlock default (see [argon2idExport]).
  static Future<SecretKey> deriveKey({
    required String secret,
    required List<int> salt,
    Argon2id? kdf,
  }) {
    return (kdf ?? argon2id).deriveKeyFromPassword(password: secret, nonce: salt);
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
