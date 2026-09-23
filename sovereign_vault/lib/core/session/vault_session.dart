import 'package:cryptography/cryptography.dart';

import '../services/vault_repository.dart';
import 'idle_timer.dart';

/// Holds the unlocked state for the current session: the VMK (in
/// memory only, never persisted) and the decrypted repository. Call
/// [lock] to clear the key from memory — e.g. on an idle timeout or
/// when the user explicitly locks the vault.
class VaultSession {
  VaultSession._();
  static final instance = VaultSession._();

  SecretKey? _vmk;
  VaultRepository? repository;

  bool get isUnlocked => _vmk != null;

  Future<void> unlock(List<int> vmkBytes) async {
    _vmk = SecretKey(vmkBytes);
    repository = VaultRepository(_vmk!);
    await repository!.load();
    IdleTimer.instance.reset();
  }

  /// Clears the VMK and decrypted data from memory. This does not
  /// touch anything on disk — it's a session lock, not a wipe.
  void lock() {
    _vmk = null;
    repository = null;
    IdleTimer.instance.stop();
  }
}
