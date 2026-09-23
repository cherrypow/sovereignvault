import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../models/document_entry.dart';
import '../models/vault.dart';
import '../services/vault_repository.dart';
import 'vault_crypto.dart';

/// The current sealed-export file format version. Bump this if the
/// payload shape below ever changes, so a future app version can tell
/// old exports apart from new ones.
const sealedVaultFormatVersion = 1;

/// A portable, encrypted snapshot of a single [Vault] — its entries and
/// the raw bytes of any documents it holds — meant to travel through an
/// untrusted channel (email, cloud storage, a USB stick) and be opened
/// by whoever separately learns the passphrase over a different
/// channel (a phone call, a text). The online service that carries the
/// file never sees anything but ciphertext; it's never part of the
/// trust boundary.
///
/// The file carries the salt and the exact Argon2id parameters used to
/// derive its key, so it can always be decrypted by whatever app
/// version created it, even if [VaultCrypto.argon2idExport]'s defaults
/// change later.
class SealedVaultFile {
  final int version;
  final Uint8List kdfSalt;
  final int kdfMemory;
  final int kdfIterations;
  final int kdfParallelism;
  final EncryptedBlob payload;

  SealedVaultFile({
    required this.version,
    required this.kdfSalt,
    required this.kdfMemory,
    required this.kdfIterations,
    required this.kdfParallelism,
    required this.payload,
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        'kdfSalt': base64Encode(kdfSalt),
        'kdfMemory': kdfMemory,
        'kdfIterations': kdfIterations,
        'kdfParallelism': kdfParallelism,
        'payload': payload.toJson(),
      };

  factory SealedVaultFile.fromJson(Map<String, dynamic> json) => SealedVaultFile(
        version: json['version'] as int,
        kdfSalt: base64Decode(json['kdfSalt'] as String),
        kdfMemory: json['kdfMemory'] as int,
        kdfIterations: json['kdfIterations'] as int,
        kdfParallelism: json['kdfParallelism'] as int,
        payload: EncryptedBlob.fromJson(json['payload'] as Map<String, dynamic>),
      );
}

/// The result of successfully opening a [SealedVaultFile]: the vault's
/// entries, plus the raw bytes of each of its documents keyed by
/// [DocumentEntry.id] — ready to hand to
/// [VaultRepository.storeDocumentBytes] one at a time when importing.
class UnsealedVault {
  final Vault vault;
  final Map<String, Uint8List> documentBytes;

  UnsealedVault({required this.vault, required this.documentBytes});
}

class SealedExportService {
  SealedExportService._();

  /// Packages [vault] — its entries and, via [repository], the raw
  /// bytes of every document it holds — into a single encrypted file
  /// protected by [passphrase]. The caller is responsible for getting
  /// the resulting file to the recipient and the passphrase to them
  /// through a separate channel.
  static Future<SealedVaultFile> export({
    required Vault vault,
    required VaultRepository repository,
    required String passphrase,
  }) async {
    final documentBytes = <String, String>{};
    for (final doc in vault.documents) {
      final bytes = await repository.readDocumentBytes(doc.id);
      documentBytes[doc.id] = base64Encode(bytes);
    }

    final payloadJson = jsonEncode({
      'vault': vault.toJson(),
      'documentBytes': documentBytes,
    });

    final salt = VaultCrypto.generateSalt();
    final key = await VaultCrypto.deriveKey(
      secret: passphrase,
      salt: salt,
      kdf: VaultCrypto.argon2idExport,
    );
    final blob = await VaultCrypto.encrypt(plaintext: utf8.encode(payloadJson), key: key);

    return SealedVaultFile(
      version: sealedVaultFormatVersion,
      kdfSalt: salt,
      kdfMemory: VaultCrypto.argon2idExportMemory,
      kdfIterations: VaultCrypto.argon2idExportIterations,
      kdfParallelism: VaultCrypto.argon2idExportParallelism,
      payload: blob,
    );
  }

  /// Reverses [export]. Throws [SecretBoxAuthenticationError] if
  /// [passphrase] is wrong — the same failure mode a wrong PIN or
  /// master password produces elsewhere in the app.
  static Future<UnsealedVault> import({
    required SealedVaultFile file,
    required String passphrase,
  }) async {
    final kdf = Argon2id(
      memory: file.kdfMemory,
      iterations: file.kdfIterations,
      parallelism: file.kdfParallelism,
      hashLength: 32,
    );
    final key = await VaultCrypto.deriveKey(secret: passphrase, salt: file.kdfSalt, kdf: kdf);
    final clear = await VaultCrypto.decrypt(blob: file.payload, key: key);
    final data = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;

    final vault = Vault.fromJson(data['vault'] as Map<String, dynamic>);
    final rawDocumentBytes = data['documentBytes'] as Map<String, dynamic>? ?? {};
    final documentBytes = rawDocumentBytes.map(
      (key, value) => MapEntry(key, base64Decode(value as String)),
    );

    return UnsealedVault(vault: vault, documentBytes: documentBytes);
  }
}
