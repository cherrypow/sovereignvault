import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sovereign_core/sovereign_core.dart';

/// Packages a single [Vault] into a PIN-protected file that can travel
/// through any channel — email, cloud storage, a USB stick — without
/// that channel ever seeing anything but ciphertext. The PIN is
/// generated here, shown exactly once, and never stored; it's the
/// caller's job to get it to the recipient a different way than the
/// file itself (a phone call, a separate text). The suggested filename
/// is a random codename, not the vault's real name — the only place
/// that name should be visible is inside the decrypted contents.
class ExportSealedScreen extends StatefulWidget {
  final Vault vault;
  const ExportSealedScreen({super.key, required this.vault});

  @override
  State<ExportSealedScreen> createState() => _ExportSealedScreenState();
}

class _ExportSealedScreenState extends State<ExportSealedScreen> {
  String? _pin;
  String? _codename;
  SealedVaultFile? _sealedFile;
  bool _preparing = true;
  String? _error;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      final pin = PassphraseGenerator.generatePin();
      final codename = PassphraseGenerator.generateCodename();
      final sealed = await SealedExportService.export(
        vault: widget.vault,
        repository: VaultSession.instance.repository!,
        passphrase: pin,
      );
      if (!mounted) return;
      setState(() {
        _pin = pin;
        _codename = codename;
        _sealedFile = sealed;
        _preparing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not prepare the sealed file: $e';
        _preparing = false;
      });
    }
  }

  Future<void> _saveFile() async {
    final sealedFile = _sealedFile;
    if (sealedFile == null) return;
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save sealed vault file',
      fileName: '${_codename ?? 'sealed'}.svlt',
    );
    if (savePath == null) return;
    await File(savePath).writeAsString(jsonEncode(sealedFile.toJson()));
    if (!mounted) return;
    setState(() => _saved = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved to $savePath'), duration: const Duration(seconds: 4)),
    );
  }

  void _copyPin() {
    final pin = _pin;
    if (pin == null) return;
    Clipboard.setData(ClipboardData(text: pin));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PIN copied.'), duration: Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('EXPORT SEALED FILE',
            style: TextStyle(fontFamily: AppFonts.mono, fontSize: 13, letterSpacing: 1.5, color: AppColors.text)),
      ),
      body: _preparing
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(32), child: Text(_error!, style: const TextStyle(color: AppColors.danger))))
              : Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('"${widget.vault.name}" is sealed and ready.',
                              style: const TextStyle(
                                  fontFamily: AppFonts.serif, fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.text)),
                          const SizedBox(height: 10),
                          Text(
                            'It will save as "${_codename ?? '…'}.svlt" — a random name that has nothing to do '
                            'with this vault, so the file itself never gives it away. Send it through any '
                            'channel you like — email, cloud storage, a USB stick. It is meaningless without '
                            'the PIN. Share that PIN a different way: read it aloud on a call, or send it as '
                            'a separate text.',
                            style: TextStyle(fontFamily: AppFonts.mono, fontSize: 11, height: 1.6, color: AppColors.mutedAt(1)),
                          ),
                          const SizedBox(height: 26),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.borderAt(0.3)),
                              color: AppColors.card.withValues(alpha: 0.05),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('ONE-TIME PIN — SHOWN ONLY NOW',
                                    style: TextStyle(
                                        fontFamily: AppFonts.mono, fontSize: 9, letterSpacing: 1.2, color: AppColors.mutedAt(1))),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: SelectableText(_pin ?? '',
                                          style: TextStyle(
                                              fontFamily: AppFonts.mono,
                                              fontSize: 26,
                                              letterSpacing: 6,
                                              color: AppColors.card,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.copy, size: 16, color: AppColors.mutedAt(1)),
                                      tooltip: 'Copy PIN',
                                      onPressed: _copyPin,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 26),
                          InkWell(
                            onTap: _saveFile,
                            child: Container(
                              width: double.infinity,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: const BoxDecoration(color: AppColors.buttonDark),
                              child: Text(_saved ? 'SAVED — SAVE AGAIN' : 'SAVE SEALED FILE…',
                                  style: TextStyle(fontFamily: AppFonts.mono, fontSize: 11, letterSpacing: 1.5, color: AppColors.text)),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'A 6-digit PIN is easy to read over a call, but far easier to guess than a full '
                            'passphrase if the file itself ever leaks — there is no lockout protecting it '
                            'once it has left the vault. Use this for a quick, trusted handoff, not for '
                            'something that must stay safe indefinitely. This PIN will not be shown again '
                            'after you leave this screen; if you lose it, export a new sealed file.',
                            style: TextStyle(fontFamily: AppFonts.mono, fontSize: 9.5, height: 1.5, color: AppColors.mutedAt(0.85)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }
}
