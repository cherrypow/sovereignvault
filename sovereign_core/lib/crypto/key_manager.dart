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
///     Path 1 (daily unlock):  Argon2id(PIN) combined with a
///                              device-bound secret -> unwraps VMK
///     Path 2 (recovery/admin): Argon2id(master password) -> unwraps VMK
///
/// Neither the PIN nor the master password ever encrypts vault data
/// directly — they only ever unlock access to the VMK. Both wrapped
/// forms of the VMK live in SecureStore, machine-bound, on purpose:
/// the vault's encrypted DATA can be copied to a USB drive for
/// physical portability (see StoragePaths), but neither unlock path
/// works anywhere except the machine the vault was created on.
class KeyManager {
  KeyManager._();

  /// First-run setup: generates the VMK and wraps it under both the
  /// PIN path and the master-password path. Call once, when the vault
  /// is created.
  static Future<void> setUp({
    required String pin,
    required String masterPassword,
  }) async {
    final vmk = VaultCrypto.generateVmk();

    // Path 1: PIN + device-bound secret.
    final deviceSecret = VaultCrypto.randomBytes(32);
    final pinSalt = VaultCrypto.generateSalt();
    final pinDerived = await VaultCrypto.deriveKey(secret: pin, salt: pinSalt);
    final pinDerivedBytes = await pinDerived.extractBytes();
    final combinedPinKey = await VaultCrypto.combineSecrets(pinDerivedBytes, deviceSecret);
    final wrappedByPin = await VaultCrypto.encrypt(plaintext: vmk, key: combinedPinKey);

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
    await SecureStore.write(SecureStore.kPinSalt, base64Encode(pinSalt));
    await SecureStore.write(SecureStore.kMasterSalt, base64Encode(masterSalt));
    await SecureStore.write(SecureStore.kWrappedVmkByPin, jsonEncode(wrappedByPin.toJson()));
    await SecureStore.write(SecureStore.kWrappedVmkByMaster, jsonEncode(wrappedByMaster.toJson()));
  }

  /// Attempts to unlock the vault with the 6-digit PIN. Returns the
  /// raw VMK bytes on success (caller holds this in memory only — it
  /// is never written to disk), or throws [UnlockFailure] on a wrong
  /// PIN, and [VaultLockedException] if the lockout schedule is
  /// currently active.
  static Future<Uint8List> unlockWithPin(String pin) async {
    final lockout = await LockoutPolicy.checkStatus();
    if (lockout.isLockedOut) {
      throw VaultLockedException(lockout.lockoutUntil!);
    }

    try {
      final pinSalt = base64Decode((await SecureStore.read(SecureStore.kPinSalt))!);
      final deviceSecret = base64Decode((await SecureStore.read(SecureStore.kDeviceSecret))!);
      final wrappedJson =
          jsonDecode((await SecureStore.read(SecureStore.kWrappedVmkByPin))!) as Map<String, dynamic>;
      final wrapped = EncryptedBlob.fromJson(wrappedJson);

      final pinDerived = await VaultCrypto.deriveKey(secret: pin, salt: pinSalt);
      final pinDerivedBytes = await pinDerived.extractBytes();
      final combinedKey = await VaultCrypto.combineSecrets(pinDerivedBytes, deviceSecret);

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

  /// Unlocks with the master password. Also clears any active lockout
  /// — the escape hatch for a legitimate owner who triggered one. Like
  /// the PIN path, this only works on the machine the vault was
  /// created on, since the wrapped VMK and salt live in SecureStore.
  static Future<Uint8List> unlockWithMasterPassword(String password) async {
    final masterSalt = base64Decode((await SecureStore.read(SecureStore.kMasterSalt))!);
    final wrappedJson =
        jsonDecode((await SecureStore.read(SecureStore.kWrappedVmkByMaster))!) as Map<String, dynamic>;
    final wrapped = EncryptedBlob.fromJson(wrappedJson);

    final masterDerived = await VaultCrypto.deriveKey(secret: password, salt: masterSalt);
    final vmk = await VaultCrypto.decrypt(blob: wrapped, key: masterDerived);
    await LockoutPolicy.clearViaMasterPassword();
    return vmk;
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
