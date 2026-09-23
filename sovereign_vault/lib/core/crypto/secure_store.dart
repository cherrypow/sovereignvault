import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wrapper around the OS-native secure storage API (Windows Credential
/// Manager / DPAPI, macOS & iOS Keychain, Android Keystore).
///
/// Every piece of key material lives here, and deliberately never
/// travels off this machine — including the wrapped-VMK blobs and
/// salts for BOTH the passphrase and master-password paths. That means
/// a vault's encrypted data files (see VaultRepository / StoragePaths)
/// can be copied to a USB drive for physical portability, but neither
/// the passphrase nor the master password will unlock that copy on any
/// computer other than the one the vault was created on — there is
/// nothing on the USB drive that can derive the VMK by itself. This
/// is intentional: it is a stronger, simpler guarantee than "works
/// anywhere with the right password."
///
/// IMPORTANT — current limitation (v1 beta): this uses each platform's
/// default secure-storage backend, which on Windows means DPAPI. DPAPI
/// ties protection to the Windows login and does NOT provide a
/// hardware-enforced attempt counter. Hardening this to a TPM-sealed
/// key with Dictionary Attack Prevention (Windows), Secure Enclave
/// (Apple), or StrongBox (Android) is tracked as a v2 item — see the
/// project's security architecture document, Section 5.
class SecureStore {
  SecureStore._();

  static const _storage = FlutterSecureStorage();

  static const kDeviceSecret = 'device_bound_secret';
  static const kPassphraseSalt = 'passphrase_path_salt';
  static const kMasterSalt = 'master_path_salt';
  static const kWrappedVmkByPassphrase = 'wrapped_vmk_by_passphrase';
  static const kWrappedVmkByMaster = 'wrapped_vmk_by_master';
  static const kLockoutState = 'lockout_state';

  static Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  static Future<String?> read(String key) => _storage.read(key: key);

  static Future<void> delete(String key) => _storage.delete(key: key);

  static Future<bool> containsKey(String key) => _storage.containsKey(key: key);

  /// Crypto-shred: deletes all key material. Once this runs, any
  /// ciphertext left on disk (or on a USB copy made before the shred)
  /// is permanently unreadable — there is nothing left that can
  /// reconstruct the VMK. This deliberately does NOT touch the
  /// encrypted data files themselves, since deleting a handful of
  /// small key blobs is instant and reliable, unlike overwriting a
  /// whole disk.
  static Future<void> cryptoShred() async {
    await delete(kDeviceSecret);
    await delete(kPassphraseSalt);
    await delete(kMasterSalt);
    await delete(kWrappedVmkByPassphrase);
    await delete(kWrappedVmkByMaster);
    await delete(kLockoutState);
  }

  static Future<bool> vaultExists() => containsKey(kWrappedVmkByPassphrase);
}
