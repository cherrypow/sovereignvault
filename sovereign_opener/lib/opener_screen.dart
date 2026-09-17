import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sovereign_core/sovereign_core.dart';

/// The Opener's entire job: unseal a .svlt file with its PIN and write
/// its contents to a folder the person chooses. No account, no
/// Sovereign Vault purchase, no vault of their own required. Reuses
/// SealedExportService directly from sovereign_core, so this never
/// re-implements decryption -- it's the exact same code path the paid
/// app uses to unseal a file, just without anywhere to put entries
/// except a plain text file.
class OpenerScreen extends StatefulWidget {
  const OpenerScreen({super.key});

  @override
  State<OpenerScreen> createState() => _OpenerScreenState();
}

class _OpenerScreenState extends State<OpenerScreen> {
  SealedVaultFile? _pickedFile;
  String? _pickedFileName;
  final _pinController = TextEditingController();
  bool _unlocking = false;
  String? _error;
  UnsealedVault? _unsealed;
  bool _saving = false;
  String? _savedToPath;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;
    try {
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      setState(() {
        _pickedFile = SealedVaultFile.fromJson(json);
        _pickedFileName = file.name;
        _error = null;
        _unsealed = null;
        _savedToPath = null;
      });
    } catch (_) {
      setState(() {
        _error = "That doesn't look like a Sovereign Vault sealed file.";
        _pickedFile = null;
        _pickedFileName = null;
      });
    }
  }

  Future<void> _unlock() async {
    final pickedFile = _pickedFile;
    if (pickedFile == null) return;
    setState(() {
      _unlocking = true;
      _error = null;
    });
    try {
      final unsealed = await SealedExportService.import(
        file: pickedFile,
        passphrase: _pinController.text,
      );
      if (!mounted) return;
      setState(() {
        _unsealed = unsealed;
        _unlocking = false;
      });
    } on SecretBoxAuthenticationError {
      if (!mounted) return;
      setState(() {
        _error = 'Wrong PIN.';
        _unlocking = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not open this file: $e';
        _unlocking = false;
      });
    }
  }

  /// Writes each document under its original filename, and — only if
  /// the vault actually has entries or notes worth keeping — a plain
  /// text summary alongside them. Appends " (1)", " (2)", etc. rather
  /// than silently overwriting anything already in the chosen folder.
  Future<void> _saveToFolder() async {
    final unsealed = _unsealed;
    if (unsealed == null) return;
    final folder = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Save unsealed files to…');
    if (folder == null) return;

    setState(() => _saving = true);
    try {
      for (final doc in unsealed.vault.documents) {
        final bytes = unsealed.documentBytes[doc.id];
        if (bytes == null) continue;
        final target = _uniquePath(folder, doc.originalName);
        await File(target).writeAsBytes(bytes);
      }

      final vault = unsealed.vault;
      if (vault.entries.isNotEmpty || vault.notes.trim().isNotEmpty) {
        final buffer = StringBuffer()
          ..writeln(vault.name)
          ..writeln(vault.category)
          ..writeln();
        for (final entry in vault.entries) {
          buffer.writeln('${entry.name}: ${entry.value}');
        }
        if (vault.notes.trim().isNotEmpty) {
          buffer
            ..writeln()
            ..writeln('Notes:')
            ..writeln(vault.notes.trim());
        }
        final target = _uniquePath(folder, '${vault.name} - entries.txt');
        await File(target).writeAsString(buffer.toString());
      }

      if (!mounted) return;
      setState(() {
        _savedToPath = folder;
        _saving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not save to that folder: $e';
        _saving = false;
      });
    }
  }

  String _uniquePath(String folder, String fileName) {
    var target = p.join(folder, fileName);
    if (!File(target).existsSync()) return target;
    final ext = p.extension(fileName);
    final base = p.basenameWithoutExtension(fileName);
    var i = 1;
    while (File(target).existsSync()) {
      target = p.join(folder, '$base ($i)$ext');
      i++;
    }
    return target;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const AuroraLogo(size: 40, radius: 10),
                    const SizedBox(width: 14),
                    Text('SOVEREIGN VAULT OPENER',
                        style: TextStyle(fontFamily: AppFonts.mono, fontSize: 12, letterSpacing: 2, color: AppColors.mutedAt(1))),
                  ],
                ),
                const SizedBox(height: 32),
                if (_savedToPath != null)
                  _savedView(_savedToPath!)
                else if (_unsealed != null)
                  _previewView(_unsealed!)
                else
                  _pickAndUnlockView(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pickAndUnlockView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Someone sent you a sealed vault file. Enter the PIN they shared '
          'separately — over a call or a text, not in the same message as the file.',
          style: TextStyle(fontFamily: AppFonts.mono, fontSize: 11, height: 1.6, color: AppColors.mutedAt(1)),
        ),
        const SizedBox(height: 22),
        InkWell(
          onTap: _pickFile,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            alignment: Alignment.center,
            decoration: BoxDecoration(border: Border.all(color: AppColors.borderAt(0.25))),
            child: Text(
              _pickedFileName == null ? 'CHOOSE SEALED FILE…' : _pickedFileName!.toUpperCase(),
              style: TextStyle(fontFamily: AppFonts.mono, fontSize: 11, letterSpacing: 1, color: AppColors.mutedAt(1)),
            ),
          ),
        ),
        if (_pickedFile != null) ...[
          const SizedBox(height: 22),
          Text('PIN', style: TextStyle(fontFamily: AppFonts.mono, fontSize: 9, letterSpacing: 1.2, color: AppColors.mutedAt(1))),
          const SizedBox(height: 8),
          TextField(
            controller: _pinController,
            style: TextStyle(fontFamily: AppFonts.mono, color: AppColors.text, letterSpacing: 4),
            decoration: InputDecoration(
              hintText: '123456',
              hintStyle: TextStyle(color: AppColors.mutedAt(0.6)),
              border: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.borderAt(0.16))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.borderAt(0.16))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.borderAt(0.5))),
            ),
            onSubmitted: (_) => _unlock(),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _unlocking ? null : _unlock,
            child: Container(
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: const BoxDecoration(color: AppColors.buttonDark),
              child: _unlocking
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.text),
                    )
                  : Text('UNLOCK', style: TextStyle(fontFamily: AppFonts.mono, fontSize: 11, letterSpacing: 1.5, color: AppColors.text)),
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!, style: const TextStyle(color: AppColors.danger)),
        ],
      ],
    );
  }

  Widget _previewView(UnsealedVault unsealed) {
    final vault = unsealed.vault;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Unlocked.', style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, letterSpacing: 1.2, color: AppColors.mutedAt(1))),
        const SizedBox(height: 8),
        Text(vault.name,
            style: const TextStyle(fontFamily: AppFonts.serif, fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.text)),
        const SizedBox(height: 6),
        Text('${vault.entries.length} entries · ${vault.documents.length} documents',
            style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10.5, color: AppColors.mutedAt(1))),
        const SizedBox(height: 26),
        InkWell(
          onTap: _saving ? null : _saveToFolder,
          child: Container(
            width: double.infinity,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: const BoxDecoration(color: AppColors.buttonDark),
            child: _saving
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.text),
                  )
                : Text('SAVE TO FOLDER…',
                    style: TextStyle(fontFamily: AppFonts.mono, fontSize: 11, letterSpacing: 1.5, color: AppColors.text)),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!, style: const TextStyle(color: AppColors.danger)),
        ],
      ],
    );
  }

  Widget _savedView(String folder) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Saved.', style: const TextStyle(fontFamily: AppFonts.serif, fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.text)),
        const SizedBox(height: 10),
        Text(folder, style: TextStyle(fontFamily: AppFonts.mono, fontSize: 11, color: AppColors.mutedAt(1))),
        const SizedBox(height: 26),
        InkWell(
          onTap: () => setState(() {
            _pickedFile = null;
            _pickedFileName = null;
            _pinController.clear();
            _unsealed = null;
            _savedToPath = null;
            _error = null;
          }),
          child: Container(
            width: double.infinity,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(border: Border.all(color: AppColors.borderAt(0.25))),
            child: Text('OPEN ANOTHER SEALED FILE',
                style: TextStyle(fontFamily: AppFonts.mono, fontSize: 11, letterSpacing: 1, color: AppColors.mutedAt(1))),
          ),
        ),
      ],
    );
  }
}
