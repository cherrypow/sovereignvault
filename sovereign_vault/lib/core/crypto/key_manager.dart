import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'lockout_policy.dart';
import 'secure_store.dart';
import 'vault_crypto.dart';

/// Orchestrates the dual-custody key architecture described in the
/// project's security guide:
///
///   VMK (256-bit) is generated once and wrapped two independent ways:
///     Path 1 (daily unlock):  Argon2id(passphrase) combined with a
///                              device-bound secret -> unwraps VMK
///     Path 2 (recovery/admin): Argon2id(master password) -> unwraps VMK
///
/// Neither the passphrase nor the master password ever encrypts vault
/// data directly — they only ever unlock access to the VMK. Both wrapped
/// forms of the VMK live in SecureStore, machine-bound, on purpose:
/// the vault's encrypted DATA can be copied to a USB drive for
/// physical portability (see StoragePaths), but neither unlock path
/// works anywhere except the machine the vault was created on.
///
/// Both paths are equally subject to LockoutPolicy: once a lockout is
/// active, neither the passphrase nor the master password can unlock
/// the vault until it expires. There is no escape hatch — see
/// LockoutPolicy for why.
class KeyManager {
  KeyManager._();

  /// First-run setup: generates the VMK and wraps it under both the
  /// passphrase path and the master-password path. Call once, when the
  /// vault is created.
  static Future<void> setUp({
    required String passphrase,
    required String masterPassword,
  }) async {
    final vmk = VaultCrypto.generateVmk();

    // Path 1: passphrase + device-bound secret.
    final deviceSecret = VaultCrypto.randomBytes(32);
    final passphraseSalt = VaultCrypto.generateSalt();
    final passphraseDerived = await VaultCrypto.deriveKey(secret: passphrase, salt: passphraseSalt);
    final passphraseDerivedBytes = await passphraseDerived.extractBytes();
    final combinedPassphraseKey = await VaultCrypto.combineSecrets(passphraseDerivedBytes, deviceSecret);
    final wrappedByPassphrase = await VaultCrypto.encrypt(plaintext: vmk, key: combinedPassphraseKey);

    // Path 2: master password alone.
    final masterSalt = VaultCrypto.generateSalt();
    final masterDerived = await VaultCrypto.deriveKey(secret: masterPassword, salt: masterSalt);
    final wrappedByMaster = await VaultCrypto.encrypt(plaintext: vmk, key: masterDerived);

    // Written sequentially, not via Future.wait: the Windows secure
    // storage backend is a single shared file rather than one entry
    // per key, and concurrent writes to it can race and silently drop
    // entries. Sequential awaits make each write durable before the
    // next one starts.
    await SecureStore.write(SecureStore.kDeviceSecret, base64Encode(deviceSecret));
    await SecureStore.write(SecureStore.kPassphraseSalt, base64Encode(passphraseSalt));
    await SecureStore.write(SecureStore.kMasterSalt, base64Encode(masterSalt));
    await SecureStore.write(SecureStore.kWrappedVmkByPassphrase, jsonEncode(wrappedByPassphrase.toJson()));
    await SecureStore.write(SecureStore.kWrappedVmkByMaster, jsonEncode(wrappedByMaster.toJson()));
  }

  /// Attempts to unlock the vault with the 4-word passphrase. Returns
  /// the raw VMK bytes on success (caller holds this in memory only —
  /// it is never written to disk), or throws [UnlockFailure] on a wrong
  /// passphrase, and [VaultLockedException] if the lockout schedule is
  /// currently active.
  static Future<Uint8List> unlockWithPassphrase(String passphrase) async {
    final lockout = await LockoutPolicy.checkStatus();
    if (lockout.isLockedOut) {
      throw VaultLockedException(lockout.lockoutUntil!);
    }

    try {
      final passphraseSalt = base64Decode((await SecureStore.read(SecureStore.kPassphraseSalt))!);
      final deviceSecret = base64Decode((await SecureStore.read(SecureStore.kDeviceSecret))!);
      final wrappedJson =
          jsonDecode((await SecureStore.read(SecureStore.kWrappedVmkByPassphrase))!) as Map<String, dynamic>;
      final wrapped = EncryptedBlob.fromJson(wrappedJson);

      final passphraseDerived = await VaultCrypto.deriveKey(secret: passphrase, salt: passphraseSalt);
      final passphraseDerivedBytes = await passphraseDerived.extractBytes();
      final combinedKey = await VaultCrypto.combineSecrets(passphraseDerivedBytes, deviceSecret);

      final vmk = await VaultCrypto.decrypt(blob: wrapped, key: combinedKey);
      await LockoutPolicy.recordSuccess();
      return vmk;
    } on SecretBoxAuthenticationError {
      final outcome = await LockoutPolicy.recordFailure();
      if (outcome.wiped) throw const VaultWipedException();
      if (outcome.lockedUntil != null) throw VaultLockedException(outcome.lockedUntil!);
      throw UnlockFailure(attemptsRemaining: outcome.attemptsRemainingInStage!);
    }
  }

  /// Unlocks with the master password. Subject to the same lockout gate
  /// as [unlockWithPassphrase] — an active lockout blocks this path too,
  /// and a successful master-password unlock does not clear or shorten
  /// it. Like the passphrase path, this only works on the machine the
  /// vault was created on, since the wrapped VMK and salt live in
  /// SecureStore.
  static Future<Uint8List> unlockWithMasterPassword(String password) async {
    final lockout = await LockoutPolicy.checkStatus();
    if (lockout.isLockedOut) {
      throw VaultLockedException(lockout.lockoutUntil!);
    }

    final masterSalt = base64Decode((await SecureStore.read(SecureStore.kMasterSalt))!);
    final wrappedJson =
        jsonDecode((await SecureStore.read(SecureStore.kWrappedVmkByMaster))!) as Map<String, dynamic>;
    final wrapped = EncryptedBlob.fromJson(wrappedJson);

    final masterDerived = await VaultCrypto.deriveKey(secret: password, salt: masterSalt);
    final vmk = await VaultCrypto.decrypt(blob: wrapped, key: masterDerived);
    return vmk;
  }

  /// Rewraps the vault's existing VMK under a brand-new passphrase —
  /// how a forgotten passphrase is recovered from, using the master
  /// password as proof of ownership instead of ever needing to know the
  /// old passphrase (which isn't stored anywhere to recover). Callers
  /// must already hold [vmk] from a successful [unlockWithMasterPassword]
  /// call. Does not touch the master-password wrapping or vault data.
  static Future<void> regeneratePassphrase({
    required Uint8List vmk,
    required String newPassphrase,
  }) async {
    final deviceSecret = VaultCrypto.randomBytes(32);
    final passphraseSalt = VaultCrypto.generateSalt();
    final passphraseDerived = await VaultCrypto.deriveKey(secret: newPassphrase, salt: passphraseSalt);
    final passphraseDerivedBytes = await passphraseDerived.extractBytes();
    final combinedPassphraseKey = await VaultCrypto.combineSecrets(passphraseDerivedBytes, deviceSecret);
    final wrappedByPassphrase = await VaultCrypto.encrypt(plaintext: vmk, key: combinedPassphraseKey);

    await SecureStore.write(SecureStore.kDeviceSecret, base64Encode(deviceSecret));
    await SecureStore.write(SecureStore.kPassphraseSalt, base64Encode(passphraseSalt));
    await SecureStore.write(SecureStore.kWrappedVmkByPassphrase, jsonEncode(wrappedByPassphrase.toJson()));
  }

  static Future<bool> vaultExists() => SecureStore.vaultExists();
}

class UnlockFailure implements Exception {
  final int attemptsRemaining;
  UnlockFailure({required this.attemptsRemaining});
}

class VaultLockedException implements Exception {
  final DateTime until;
  VaultLockedException(this.until);
}

class VaultWipedException implements Exception {
  const VaultWipedException();
}
