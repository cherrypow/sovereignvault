import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../crypto/vault_crypto.dart';
import '../models/document_entry.dart';
import '../models/vault.dart';
import '../models/vault_entry.dart';
import 'storage_paths.dart';

/// Persists the vault index (all vaults + entries + document metadata)
/// as a single AES-256-GCM-encrypted file, and stores each uploaded
/// document's bytes as its own encrypted file alongside it. Everything
/// on disk is ciphertext; the VMK only ever exists in memory for the
/// duration of an unlocked session.
class VaultRepository {
  final SecretKey _vmk;
  List<Vault> vaults = [];
  List<DocumentEntry> documents = [];

  VaultRepository(this._vmk);

  static Future<Directory> _appDir() async {
    final vaultDir = await StoragePaths.resolveDataDir();
    final docsDir = Directory(p.join(vaultDir.path, 'documents'));
    if (!await docsDir.exists()) await docsDir.create(recursive: true);
    return vaultDir;
  }

  static Future<File> _indexFile() async {
    final dir = await _appDir();
    return File(p.join(dir.path, 'index.enc'));
  }

  /// True if an encrypted vault index already exists at the resolved
  /// data location. Used at startup to tell a genuine first run apart
  /// from a "foreign vault" — encrypted data present (e.g. from a USB
  /// drive) whose keys live on a different machine's SecureStore.
  /// Those two cases must never be confused: proceeding with setup in
  /// the second case would generate a new VMK and either overwrite or
  /// fail to decrypt the existing file.
  static Future<bool> indexFileExists() async {
    final file = await _indexFile();
    return file.exists();
  }

  /// Loads and decrypts the vault index from disk. If no index exists
  /// yet (first run after setup), starts with an empty, sample-free
  /// state.
  Future<void> load() async {
    final file = await _indexFile();
    if (!await file.exists()) {
      // First run: seed one clickable demo vault so the home screen
      // never opens on a bare, unexplained "no vaults yet" state.
      // Its entries double as an inline walkthrough of reveal/copy —
      // the user can delete it once they've clicked through it.
      vaults = [_demoVault()];
      documents = [];
      await save();
      return;
    }
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final blob = EncryptedBlob.fromJson(json);
    final clear = await VaultCrypto.decrypt(blob: blob, key: _vmk);
    final data = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
    vaults = (data['vaults'] as List)
        .map((v) => Vault.fromJson(v as Map<String, dynamic>))
        .toList();
    documents = (data['documents'] as List? ?? [])
        .map((d) => DocumentEntry.fromJson(d as Map<String, dynamic>))
        .toList();
  }

  /// Re-encrypts the current in-memory state and writes it to disk.
  /// Call after any mutation (add vault, add entry, add document).
  Future<void> save() async {
    final data = jsonEncode({
      'vaults': vaults.map((v) => v.toJson()).toList(),
      'documents': documents.map((d) => d.toJson()).toList(),
    });
    final blob = await VaultCrypto.encrypt(plaintext: utf8.encode(data), key: _vmk);
    final file = await _indexFile();
    await file.writeAsString(jsonEncode(blob.toJson()));
  }

  static Vault _demoVault() {
    const uuid = Uuid();
    final now = DateTime.now();
    return Vault(
      id: uuid.v4(),
      name: 'Getting Started',
      category: 'Tutorial — delete anytime',
      entries: [
        VaultEntry(
          id: uuid.v4(),
          name: 'How to reveal a key',
          value: 'Click the eye icon on the right to unmask this value.',
          addedDate: now,
        ),
        VaultEntry(
          id: uuid.v4(),
          name: 'How to copy a key',
          value: 'Click the copy icon to copy this value to your clipboard.',
          addedDate: now,
        ),
        VaultEntry(
          id: uuid.v4(),
          name: 'Non-sensitive fields',
          value: 'Fields like this can be marked "not sensitive" and shown in the clear, unmasked.',
          addedDate: now,
          sensitive: false,
        ),
      ],
    );
  }

  /// Encrypts and stores a document's raw bytes under its own id.
  /// Metadata (name, size, date) lives in the index; the bytes live in
  /// their own file so the index stays small and fast to decrypt.
  Future<void> storeDocumentBytes(String id, Uint8List bytes) async {
    final dir = await _appDir();
    final blob = await VaultCrypto.encrypt(plaintext: bytes, key: _vmk);
    final file = File(p.join(dir.path, 'documents', '$id.enc'));
    await file.writeAsString(jsonEncode(blob.toJson()));
  }

  Future<Uint8List> readDocumentBytes(String id) async {
    final dir = await _appDir();
    final file = File(p.join(dir.path, 'documents', '$id.enc'));
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final blob = EncryptedBlob.fromJson(json);
    return VaultCrypto.decrypt(blob: blob, key: _vmk);
  }

  /// Deletes a document's encrypted file from disk. Callers are
  /// responsible for also removing its DocumentEntry from whichever
  /// list holds it and calling save() — this only cleans up the bytes.
  Future<void> deleteDocumentFile(String id) async {
    final dir = await _appDir();
    final file = File(p.join(dir.path, 'documents', '$id.enc'));
    if (await file.exists()) await file.delete();
  }

}
