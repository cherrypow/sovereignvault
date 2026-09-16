import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sovereign_core/sovereign_core.dart';

import 'unlock_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _pinController = TextEditingController();
  final _pinConfirmController = TextEditingController();
  final _masterController = TextEditingController();
  final _masterConfirmController = TextEditingController();
  String? _error;
  bool _working = false;
  bool _obscureMaster = true;
  bool _obscureMasterConfirm = true;

  Future<void> _createVault() async {
    setState(() => _error = null);

    if (_pinController.text.length != 6 || int.tryParse(_pinController.text) == null) {
      setState(() => _error = 'PIN must be exactly 6 digits.');
      return;
    }
    if (_pinController.text != _pinConfirmController.text) {
      setState(() => _error = 'PINs do not match.');
      return;
    }
    if (_masterController.text.length < 12) {
      setState(() => _error = 'Master password must be at least 12 characters.');
      return;
    }
    if (_masterController.text != _masterConfirmController.text) {
      setState(() => _error = 'Master passwords do not match.');
      return;
    }

    setState(() => _working = true);
    await KeyManager.setUp(pin: _pinController.text, masterPassword: _masterController.text);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const UnlockScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
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
              children: [
                const Center(child: AuroraLogo(size: 44, radius: 12)),
                const SizedBox(height: 14),
                Text(
                  'CREATE YOUR VAULT',
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
                const SizedBox(height: 18),
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
                        'Nothing about the PIN or master password you set below is stored '
                        'anywhere but this device — that is what keeps this vault safe from '
                        'a remote attacker, but it also means no one can recover it for you. '
                        'Before you continue, have paper ready to write both of them down and '
                        'store somewhere safe. If you lose both, everything in this vault is '
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
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('6-DIGIT PIN — daily unlock'),
                          _pinField(_pinController),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('CONFIRM PIN'),
                          _pinField(_pinConfirmController),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
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
                        ? const SizedBox(
                            width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('SEAL THE VAULT', style: TextStyle(letterSpacing: 1.5, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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

  Widget _pinField(TextEditingController controller) => _textField(
        controller,
        obscure: true,
        keyboardType: TextInputType.number,
        maxLength: 6,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      );

  Widget _textField(
    TextEditingController controller, {
    bool obscure = false,
    TextInputType? keyboardType,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    VoidCallback? onToggleObscure,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
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
