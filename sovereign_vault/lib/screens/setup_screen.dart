import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/core.dart';

import 'unlock_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

/// Setup is a 3-step wizard, not one dense form: a new user sees a
/// welcome + the "no password reset" warning first, then the generated
/// passphrase on its own, then the master password fields — instead of
/// all of it landing at once on first launch.
enum _SetupStep { welcome, passphrase, masterPassword }

class _SetupScreenState extends State<SetupScreen> {
  _SetupStep _step = _SetupStep.welcome;
  bool _acceptedRisk = false;
  late final _passphrase = VaultPassphrase.generate();
  bool _savedPassphrase = false;
  final _masterController = TextEditingController();
  final _masterConfirmController = TextEditingController();
  String? _error;
  bool _working = false;
  bool _obscureMaster = true;
  bool _obscureMasterConfirm = true;

  void _copyPassphrase() {
    Clipboard.setData(ClipboardData(text: _passphrase));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Passphrase copied.'), duration: Duration(seconds: 2)),
    );
  }

  void _continueFromWelcome() {
    if (!_acceptedRisk) {
      setState(() => _error = 'You must confirm you understand before continuing.');
      return;
    }
    setState(() {
      _error = null;
      _step = _SetupStep.passphrase;
    });
  }

  void _continueFromPassphrase() {
    if (!_savedPassphrase) {
      setState(() => _error = 'Confirm you\'ve saved the passphrase before continuing.');
      return;
    }
    setState(() {
      _error = null;
      _step = _SetupStep.masterPassword;
    });
  }

  Future<void> _createVault() async {
    setState(() => _error = null);

    if (_masterController.text.length < 10) {
      setState(() => _error = 'Master password must be at least 10 characters.');
      return;
    }
    final symbolCount = RegExp(r'[^a-zA-Z0-9]').allMatches(_masterController.text).length;
    if (symbolCount < 2) {
      setState(() => _error = 'Master password must include at least 2 symbols.');
      return;
    }
    if (_masterController.text != _masterConfirmController.text) {
      setState(() => _error = 'Master passwords do not match.');
      return;
    }

    setState(() => _working = true);
    await KeyManager.setUp(passphrase: _passphrase, masterPassword: _masterController.text);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const UnlockScreen()),
    );
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
              children: switch (_step) {
                _SetupStep.welcome => _welcomeStep(),
                _SetupStep.passphrase => _passphraseStep(),
                _SetupStep.masterPassword => _masterPasswordStep(),
              },
            ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _welcomeStep() {
    return [
      const Center(child: AuroraLogo(size: 44, radius: 12)),
      const SizedBox(height: 14),
      Text(
        'WELCOME TO SOVEREIGN VAULT',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppFonts.serif,
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
          letterSpacing: 1,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        'Sovereign Key Protocol — dual-custody encryption',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppFonts.mono,
          fontSize: 10,
          letterSpacing: 1.5,
          color: AppColors.textAt(0.45),
        ),
      ),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card.withValues(alpha: 0.05),
          border: Border.all(color: AppColors.borderAt(0.22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.textAt(0.8), size: 15),
                const SizedBox(width: 8),
                Text(
                  'THERE IS NO PASSWORD RESET',
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 10,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Nothing about the passphrase or master password you\'re about to set '
              'is stored anywhere but this device — that is what keeps this vault '
              'safe from a remote attacker, but it also means no one can recover it '
              'for you. Have paper ready to write both of them down and store '
              'somewhere safe. If you lose both, everything in this vault is '
              'permanently unrecoverable.',
              style: TextStyle(
                fontFamily: 'Times New Roman',
                fontSize: 12.5,
                height: 1.5,
                color: AppColors.textAt(0.8),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      InkWell(
        onTap: () => setState(() => _acceptedRisk = !_acceptedRisk),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: _acceptedRisk,
              onChanged: (v) => setState(() => _acceptedRisk = v ?? false),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Do you understand? I accept that I am solely responsible for my '
                  'passphrase and master password, and that lost data cannot be '
                  'recovered by anyone.',
                  style: TextStyle(fontFamily: AppFonts.mono, fontSize: 11, color: AppColors.textAt(0.7)),
                ),
              ),
            ),
          ],
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: 10),
        Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
      ],
      const SizedBox(height: 16),
      SizedBox(
        height: 46,
        child: ElevatedButton(
          onPressed: _continueFromWelcome,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.card,
            foregroundColor: AppColors.background,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: AppColors.borderAt(0.2)),
              borderRadius: BorderRadius.zero,
            ),
          ),
          child: const Text('CONTINUE', style: TextStyle(letterSpacing: 1.5, fontSize: 12)),
        ),
      ),
    ];
  }

  List<Widget> _passphraseStep() {
    return [
      const Center(child: AuroraLogo(size: 44, radius: 12)),
      const SizedBox(height: 14),
      Text(
        'REMEMBER YOUR PASSPHRASE',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppFonts.serif,
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
          letterSpacing: 1,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        'This unlocks your vault every day. It is shown only once.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppFonts.mono,
          fontSize: 10,
          letterSpacing: 1.5,
          color: AppColors.textAt(0.45),
        ),
      ),
      const SizedBox(height: 24),
      _label('PASSPHRASE — daily unlock'),
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
                _passphrase,
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
          onPressed: _continueFromPassphrase,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.card,
            foregroundColor: AppColors.background,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: AppColors.borderAt(0.2)),
              borderRadius: BorderRadius.zero,
            ),
          ),
          child: const Text('CONTINUE', style: TextStyle(letterSpacing: 1.5, fontSize: 12)),
        ),
      ),
      const SizedBox(height: 10),
      Center(
        child: TextButton(
          onPressed: () => setState(() {
            _error = null;
            _step = _SetupStep.welcome;
          }),
          child: Text('Back', style: TextStyle(fontFamily: AppFonts.mono, fontSize: 11, color: AppColors.textAt(0.55))),
        ),
      ),
    ];
  }

  List<Widget> _masterPasswordStep() {
    return [
      const Center(child: AuroraLogo(size: 44, radius: 12)),
      const SizedBox(height: 14),
      Text(
        'CREATE A MASTER PASSWORD',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppFonts.serif,
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
          letterSpacing: 1,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        'A second, independent way in — for recovery, not daily use.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppFonts.mono,
          fontSize: 10,
          letterSpacing: 1.5,
          color: AppColors.textAt(0.45),
        ),
      ),
      const SizedBox(height: 6),
      Text(
        'At least 10 characters, including at least 2 symbols.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppFonts.mono,
          fontSize: 9.5,
          color: AppColors.textAt(0.4),
        ),
      ),
      const SizedBox(height: 24),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label('MASTER PASSWORD — recovery & wipe'),
                _textField(
                  _masterController,
                  obscure: _obscureMaster,
                  onToggleObscure: () => setState(() => _obscureMaster = !_obscureMaster),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label('CONFIRM MASTER PASSWORD'),
                _textField(
                  _masterConfirmController,
                  obscure: _obscureMasterConfirm,
                  onToggleObscure: () => setState(() => _obscureMasterConfirm = !_obscureMasterConfirm),
                ),
              ],
            ),
          ),
        ],
      ),
      if (_error != null) ...[
        const SizedBox(height: 14),
        Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
      ],
      const SizedBox(height: 22),
      SizedBox(
        height: 46,
        child: ElevatedButton(
          onPressed: _working ? null : _createVault,
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
              : const Text('SEAL THE VAULT', style: TextStyle(letterSpacing: 1.5, fontSize: 12)),
        ),
      ),
      const SizedBox(height: 10),
      Center(
        child: TextButton(
          onPressed: _working
              ? null
              : () => setState(() {
                    _error = null;
                    _step = _SetupStep.passphrase;
                  }),
          child: Text('Back', style: TextStyle(fontFamily: AppFonts.mono, fontSize: 11, color: AppColors.textAt(0.55))),
        ),
      ),
    ];
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 9,
            letterSpacing: 1,
            color: AppColors.textAt(0.5),
          ),
        ),
      );

  Widget _textField(
    TextEditingController controller, {
    bool obscure = false,
    VoidCallback? onToggleObscure,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(fontFamily: AppFonts.mono, color: AppColors.text, fontSize: 14),
      decoration: InputDecoration(
        counterText: '',
        isDense: true,
        filled: true,
        suffixIcon: onToggleObscure == null
            ? null
            : IconButton(
                icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 17, color: AppColors.mutedAt(1)),
                onPressed: onToggleObscure,
              ),
        fillColor: AppColors.card.withValues(alpha: 0.035),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.borderAt(0.22)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.borderAt(0.22)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.borderAt(0.6)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}
