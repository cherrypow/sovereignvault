import 'package:flutter/material.dart';
import 'package:sovereign_core/sovereign_core.dart';

/// Shown when encrypted vault data exists at this location (e.g. a
/// USB drive plugged into a different computer) but this machine's
/// SecureStore has no matching keys. This is a dead end by design:
/// there is no "create a new vault here anyway" button, because doing
/// so next to someone else's — or your own, from another machine's —
/// encrypted data is exactly the kind of silent-overwrite risk that
/// would undermine trust in the whole system.
class ForeignVaultScreen extends StatelessWidget {
  const ForeignVaultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.lock_clock_outlined, color: AppColors.card, size: 32),
                const SizedBox(height: 16),
                Text(
                  'VAULT LOCKED TO ANOTHER DEVICE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.serif,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.card,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Encrypted license data was found at this location, but this computer '
                  'does not hold the keys for it. That\'s expected if this data was '
                  'copied from a USB drive or another machine — by design, both the PIN '
                  'and the master password only unlock a vault on the computer it was '
                  'created on.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Times New Roman', fontSize: 13.5, height: 1.6, color: AppColors.textAt(0.8)),
                ),
                const SizedBox(height: 14),
                Text(
                  'Reconnect this drive to the original computer to open it. Nothing on '
                  'this screen will modify or delete the data that\'s here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Times New Roman', fontSize: 13.5, height: 1.6, color: AppColors.textAt(0.8)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
