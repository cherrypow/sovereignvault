import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/core.dart';

import 'home_screen.dart';

/// Shown right after a master-password unlock — the moment someone has
/// just proven ownership without their daily passphrase, which is
/// exactly when they'd want to replace a forgotten one. Skippable: the
/// master password is also just a normal way in, not only a recovery
/// flow.
class RegeneratePassphraseScreen extends StatefulWidget {
  final Uint8List vmk;
  const RegeneratePassphraseScreen({super.key, required this.vmk});

  @override
  State<RegeneratePassphraseScreen> createState() => _RegeneratePassphraseScreenState();
}

class _RegeneratePassphraseScreenState extends State<RegeneratePassphraseScreen> {
  bool _generating = false;
  String? _newPassphrase;
  bool _savedPassphrase = false;
  bool _working = false;
  String? _error;

  Future<void> _continueToVault() async {
    await VaultSession.instance.unlock(widget.vmk);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  void _copyPassphrase() {
    Clipboard.setData(ClipboardData(text: _newPassphrase!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Passphrase copied.'), duration: Duration(seconds: 2)),
    );
  }

  Future<void> _confirmNewPassphrase() async {
    if (!_savedPassphrase) {
      setState(() => _error = 'Confirm you\'ve saved the passphrase before continuing.');
      return;
    }
    setState(() {
      _error = null;
      _working = true;
    });
    await KeyManager.regeneratePassphrase(vmk: widget.vmk, newPassphrase: _newPassphrase!);
    await _continueToVault();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 40),
                  decoration: BoxDecoration(
                    color: AppColors.card.withValues(alpha: 0.02),
                    border: Border.all(color: AppColors.borderAt(0.18)),
                    boxShadow: [
                      BoxShadow(color: AppColors.card.withValues(alpha: 0.06), blurRadius: 32, offset: const Offset(0, 16)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _generating ? _generateStep() : _promptStep(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _promptStep() {
    return [
      const Center(child: AuroraLogo(size: 44, radius: 12)),
      const SizedBox(height: 14),
      Text(
        'UNLOCKED WITH MASTER PASSWORD',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppFonts.serif,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
          letterSpacing: 1,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        'Forgot your daily passphrase? You can generate a new one now — '
        'it replaces the old one, your vault and its data are untouched.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Times New Roman',
          fontSize: 13,
          height: 1.5,
          color: AppColors.textAt(0.8),
        ),
      ),
      const SizedBox(height: 24),
      SizedBox(
        height: 46,
        child: ElevatedButton(
          onPressed: () => setState(() {
            _newPassphrase = VaultPassphrase.generate();
            _generating = true;
          }),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.card,
            foregroundColor: AppColors.background,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: AppColors.borderAt(0.2)),
              borderRadius: BorderRadius.zero,
            ),
          ),
          child: const Text('GENERATE NEW PASSPHRASE', style: TextStyle(letterSpacing: 1.2, fontSize: 12)),
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(
        height: 46,
        child: OutlinedButton(
          onPressed: _continueToVault,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: AppColors.borderAt(0.3)),
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          ),
          child: Text('SKIP, CONTINUE TO VAULT',
              style: TextStyle(letterSpacing: 1.2, fontSize: 12, color: AppColors.textAt(0.8))),
        ),
      ),
    ];
  }

  List<Widget> _generateStep() {
    return [
      const Center(child: AuroraLogo(size: 44, radius: 12)),
      const SizedBox(height: 14),
      Text(
        'YOUR NEW PASSPHRASE',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppFonts.serif,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
          letterSpacing: 1,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        'This replaces your old passphrase. It is shown only once.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppFonts.mono,
          fontSize: 10,
          letterSpacing: 1.5,
          color: AppColors.textAt(0.45),
        ),
      ),
      const SizedBox(height: 22),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.card.withValues(alpha: 0.035),
          border: Border.all(color: AppColors.borderAt(0.22)),
        ),
        child: Row(
          children: [
            Expanded(
              child: SelectableText(
                _newPassphrase!,
                style: TextStyle(
                  fontFamily: AppFonts.mono,
                  color: AppColors.text,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.copy_outlined, size: 17, color: AppColors.mutedAt(1)),
              tooltip: 'Copy passphrase',
              onPressed: _copyPassphrase,
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      InkWell(
        onTap: () => setState(() => _savedPassphrase = !_savedPassphrase),
        child: Row(
          children: [
            Checkbox(
              value: _savedPassphrase,
              onChanged: (v) => setState(() => _savedPassphrase = v ?? false),
            ),
            Expanded(
              child: Text(
                'I\'ve written this passphrase down somewhere safe.',
                style: TextStyle(fontFamily: AppFonts.mono, fontSize: 11, color: AppColors.textAt(0.7)),
              ),
            ),
          ],
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: 10),
        Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
      ],
      const SizedBox(height: 18),
      SizedBox(
        height: 46,
        child: ElevatedButton(
          onPressed: _working ? null : _confirmNewPassphrase,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.card,
            foregroundColor: AppColors.background,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: AppColors.borderAt(0.2)),
              borderRadius: BorderRadius.zero,
            ),
          ),
          child: _working
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('CONTINUE', style: TextStyle(letterSpacing: 1.5, fontSize: 12)),
        ),
      ),
    ];
  }
}
