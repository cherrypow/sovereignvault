import 'dart:math';

import 'words.dart';

/// Generates the vault's own daily-unlock passphrase — replaces the old
/// 6-digit PIN (~20 bits of entropy, 1-in-a-million) with 4 words drawn
/// from the full 2,048-word BIP-39 English list (~44 bits of entropy,
/// 1-in-1.76-trillion), fed into the same Argon2id + AES-256-GCM pipeline
/// KeyManager already uses.
///
/// Unlike PassphraseGenerator (sealed-export files handed to someone
/// else), this passphrase never leaves the device and is generated for
/// the owner to write down once at setup, the same way a crypto wallet
/// presents a seed phrase.
class VaultPassphrase {
  VaultPassphrase._();

  static final _secureRandom = Random.secure();

  static String generate({int wordCount = 4}) {
    return List.generate(
      wordCount,
      (_) => bip39EnglishWords[_secureRandom.nextInt(bip39EnglishWords.length)],
    ).join('-');
  }
}
