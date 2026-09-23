import 'dart:async';

import 'package:flutter/material.dart';
import '../core/core.dart';

import 'home_screen.dart';
import 'regenerate_passphrase_screen.dart';

class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final _passphraseController = TextEditingController();
  final _masterController = TextEditingController();
  bool _useMasterPassword = false;
  bool _obscureMaster = true;
  String? _status;
  bool _working = false;

  Future<void> _submit() async {
    setState(() {
      _status = null;
      _working = true;
    });
    try {
      if (_useMasterPassword) {
        final vmk = await KeyManager.unlockWithMasterPassword(_masterController.text);
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => RegeneratePassphraseScreen(vmk: vmk)),
        );
        return;
      }
      final vmk = await KeyManager.unlockWithPassphrase(_passphraseController.text);
      await VaultSession.instance.unlock(vmk);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on UnlockFailure catch (e) {
      setState(() => _status = 'Incorrect passphrase — ${e.attemptsRemaining} attempt(s) remaining before lockout.');
    } on VaultLockedException catch (e) {
      final remaining = e.until.difference(DateTime.now());
      setState(() => _status = 'Vault locked. Try again in ${_formatDuration(remaining)}.');
    } on VaultWipedException {
      setState(() => _status = 'Vault key material has been destroyed after repeated failed attempts.');
    } catch (e) {
      setState(() => _status = _useMasterPassword
          ? 'Incorrect master password.'
          : 'Could not unlock with this passphrase ($e).');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  String _formatDuration(Duration d) {
    if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inMinutes}m';
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
                constraints: const BoxConstraints(maxWidth: 400),
                child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
            decoration: BoxDecoration(
              color: AppColors.card.withValues(alpha: 0.02),
              border: Border.all(color: AppColors.borderAt(0.18)),
              boxShadow: [
                BoxShadow(color: AppColors.card.withValues(alpha: 0.06), blurRadius: 32, offset: const Offset(0, 16)),
              ],
            ),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AuroraLogo(size: 44, radius: 12),
              const SizedBox(height: 16),
              Text(
                'Sovereign Vault',
                style: TextStyle(
                  fontFamily: AppFonts.serif,
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'SOVEREIGN KEY PROTOCOL',
                style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontSize: 9.5,
                  letterSpacing: 2,
                  color: AppColors.textAt(0.4),
                ),
              ),
              const SizedBox(height: 40),
              if (!_useMasterPassword) ...[
                TextField(
                  key: const ValueKey('passphrase_field'),
                  controller: _passphraseController,
                  obscureText: true,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    color: AppColors.text,
                    fontSize: 18,
                    letterSpacing: 1,
                  ),
                  decoration: InputDecoration(
                    hintText: 'word-word-word-word',
                    hintStyle: TextStyle(color: AppColors.mutedAt(0.8)),
                    filled: true,
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
                  ),
                  onSubmitted: (_) => _submit(),
                ),
              ] else ...[
                TextField(
                  key: const ValueKey('master_field'),
                  controller: _masterController,
                  obscureText: _obscureMaster,
                  style: TextStyle(fontFamily: AppFonts.mono, color: AppColors.text),
                  decoration: InputDecoration(
                    hintText: 'Master password',
                    hintStyle: TextStyle(color: AppColors.mutedAt(0.8)),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureMaster ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          size: 18, color: AppColors.mutedAt(1)),
                      onPressed: () => setState(() => _obscureMaster = !_obscureMaster),
                    ),
                    filled: true,
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
                  ),
                  onSubmitted: (_) => _submit(),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: _working ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.buttonDark,
                    foregroundColor: AppColors.background,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: AppColors.borderAt(0.2)),
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  child: _working
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('UNLOCK', style: TextStyle(letterSpacing: 1.5, fontSize: 12)),
                ),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: () => setState(() {
                  _useMasterPassword = !_useMasterPassword;
                  _status = null;
                  _passphraseController.clear();
                  _masterController.clear();
                }),
                child: Text(
                  _useMasterPassword ? 'Use passphrase instead' : 'Use master password instead',
                  style: TextStyle(fontFamily: AppFonts.mono, fontSize: 11, color: AppColors.textAt(0.55)),
                ),
              ),
              if (_status != null) ...[
                const SizedBox(height: 12),
                Text(
                  _status!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.danger, fontSize: 12),
                ),
              ],
            ],
          ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
