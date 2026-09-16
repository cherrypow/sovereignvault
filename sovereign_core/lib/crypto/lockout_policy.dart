import 'dart:convert';

import 'secure_store.dart';

/// Escalating lockout schedule for PIN attempts:
///   10 wrong in a row  -> 24 hour lockout
///   10 more wrong      -> 72 hour lockout
///   10 more wrong      -> crypto-shred (vault destroyed)
///
/// LIMITATION (v1 beta): this counter is persisted in the OS secure
/// storage, which is a real improvement over a plain file, but it is
/// still software-enforced. An attacker who images the disk before
/// attempting PINs and restores that image after each lockout can
/// reset this counter indefinitely. Making this trustworthy against
/// that attack requires anchoring it to a hardware monotonic counter
/// (TPM Dictionary Attack Prevention / Secure Enclave / StrongBox) —
/// see the project's security architecture document, Section 5. This
/// class is written so that hardening can slot in underneath it later
/// without changing the calling code in KeyManager.
class LockoutPolicy {
  LockoutPolicy._();

  static const _attemptsPerStage = 10;
  static const _stageDurations = [
    Duration(hours: 24),
    Duration(hours: 72),
  ];

  static Future<LockoutState> _load() async {
    final raw = await SecureStore.read(SecureStore.kLockoutState);
    if (raw == null) return LockoutState(failedAttempts: 0, stage: 0, lockoutUntil: null);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return LockoutState(
      failedAttempts: json['failedAttempts'] as int,
      stage: json['stage'] as int,
      lockoutUntil: json['lockoutUntil'] == null
          ? null
          : DateTime.parse(json['lockoutUntil'] as String),
    );
  }

  static Future<void> _save(LockoutState state) => SecureStore.write(
        SecureStore.kLockoutState,
        jsonEncode({
          'failedAttempts': state.failedAttempts,
          'stage': state.stage,
          'lockoutUntil': state.lockoutUntil?.toIso8601String(),
        }),
      );

  /// Returns the current lockout status. Call before attempting to
  /// unlock with a PIN.
  static Future<LockoutState> checkStatus() => _load();

  /// Records a failed PIN attempt and returns the resulting state,
  /// including whether this failure triggered a lockout or a wipe.
  static Future<LockoutOutcome> recordFailure() async {
    final state = await _load();
    final failedAttempts = state.failedAttempts + 1;

    if (failedAttempts >= _attemptsPerStage) {
      final nextStage = state.stage + 1;
      if (nextStage > _stageDurations.length) {
        // Final stage exhausted -> wipe.
        await SecureStore.cryptoShred();
        return LockoutOutcome.wipedOutcome;
      }
      final until = DateTime.now().add(_stageDurations[nextStage - 1]);
      await _save(LockoutState(failedAttempts: 0, stage: nextStage, lockoutUntil: until));
      return LockoutOutcome.lockedOut(until);
    }

    await _save(LockoutState(
      failedAttempts: failedAttempts,
      stage: state.stage,
      lockoutUntil: state.lockoutUntil,
    ));
    return LockoutOutcome.attemptRemaining(_attemptsPerStage - failedAttempts);
  }

  /// Called on a successful PIN unlock — resets the counter for the
  /// current stage but does not clear the stage itself (a stage only
  /// clears via the master-password escape hatch, so that a series of
  /// successful unlocks between lockouts doesn't quietly reset an
  /// attacker's progress toward being locked out).
  static Future<void> recordSuccess() async {
    final state = await _load();
    await _save(LockoutState(failedAttempts: 0, stage: state.stage, lockoutUntil: null));
  }

  /// The master-password escape hatch: authenticating with the
  /// stronger secret clears the lockout entirely, since a legitimate
  /// owner shouldn't be stuck waiting out a 72-hour lockout they
  /// triggered themselves.
  static Future<void> clearViaMasterPassword() async {
    await _save(LockoutState(failedAttempts: 0, stage: 0, lockoutUntil: null));
  }
}

class LockoutState {
  final int failedAttempts;
  final int stage;
  final DateTime? lockoutUntil;

  LockoutState({required this.failedAttempts, required this.stage, this.lockoutUntil});

  bool get isLockedOut => lockoutUntil != null && DateTime.now().isBefore(lockoutUntil!);
}

class LockoutOutcome {
  final int? attemptsRemainingInStage;
  final DateTime? lockedUntil;
  final bool wiped;

  LockoutOutcome._({this.attemptsRemainingInStage, this.lockedUntil, this.wiped = false});

  factory LockoutOutcome.attemptRemaining(int remaining) =>
      LockoutOutcome._(attemptsRemainingInStage: remaining);

  factory LockoutOutcome.lockedOut(DateTime until) => LockoutOutcome._(lockedUntil: until);

  static final wipedOutcome = LockoutOutcome._(wiped: true);
}
