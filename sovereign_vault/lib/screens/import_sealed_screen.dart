import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:sovereign_core/sovereign_core.dart';

/// Opens a sealed vault file produced by [ExportSealedScreen]. The
/// passphrase never travels with the file — this screen just asks for
/// it, the same way the file's sender agreed to share it separately.
class ImportSealedScreen extends StatefulWidget {
  const ImportSealedScreen({super.key});

  @override
  State<ImportSealedScreen> createState() => _ImportSealedScreenState();
}

class _ImportSealedScreenState extends State<ImportSealedScreen> {
  SealedVaultFile? _pickedFile;
  String? _pickedFileName;
  final _passphraseController = TextEditingController();
  bool _unlocking = false;
  String? _error;
  UnsealedVault? _unsealed;

  @override
  void dispose() {
    _passphraseController.dispose();
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
      });
    } catch (_) {
      setState(() {
        _error = "That file doesn't look like a sealed Sovereign Vault export.";
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
        passphrase: _passphraseController.text,
      );
      if (!mounted) return;
      setState(() {
        _unsealed = unsealed;
        _unlocking = false;
      });
    } on SecretBoxAuthenticationError {
      if (!mounted) return;
      setState(() {
        _error = 'Wrong passphrase.';
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

  Future<void> _addToVault() async {
    final unsealed = _unsealed;
    if (unsealed == null) return;
    final repository = VaultSession.instance.repository!;
    for (final doc in unsealed.vault.documents) {
      final bytes = unsealed.documentBytes[doc.id];
      if (bytes != null) {
        await repository.storeDocumentBytes(doc.id, bytes);
      }
    }
    repository.vaults.add(unsealed.vault);
    await repository.save();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final unsealed = _unsealed;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('IMPORT SEALED FILE',
            style: TextStyle(fontFamily: AppFonts.mono, fontSize: 13, letterSpacing: 1.5, color: AppColors.text)),
      ),
      body: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: unsealed == null ? _pickAndUnlockView() : _previewView(unsealed),
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
          'Someone sent you a sealed vault file. You\'ll need the PIN they shared '
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
            controller: _passphraseController,
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
        Text('${vault.category} · ${vault.entries.length} entries · ${vault.documents.length} documents',
            style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10.5, color: AppColors.mutedAt(1))),
        const SizedBox(height: 26),
        InkWell(
          onTap: _addToVault,
          child: Container(
            width: double.infinity,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: const BoxDecoration(color: AppColors.buttonDark),
            child: Text('ADD TO MY VAULTS',
                style: TextStyle(fontFamily: AppFonts.mono, fontSize: 11, letterSpacing: 1.5, color: AppColors.text)),
          ),
        ),
      ],
    );
  }
}
