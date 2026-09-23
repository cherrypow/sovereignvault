import 'dart:io';

import 'package:flutter/material.dart';
import 'core/core.dart';

import 'screens/foreign_vault_screen.dart';
import 'screens/setup_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/unlock_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

// A fixed loopback port used purely as a single-instance mutex on
// platforms with no OS-native equivalent: only one process can ever
// bind it, so a second launch can detect the first one is already
// running instead of risking two processes writing to the same local
// storage files at once.
//
// macOS is deliberately excluded — LSMultipleInstancesProhibited in
// Info.plist handles this natively there. Binding even a loopback-only
// socket under App Sandbox generally requires a network-server
// entitlement, which would undermine the "this app makes zero network
// calls" claim for no benefit, since the OS already solves this.
const _singleInstancePort = 47821;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!Platform.isMacOS) {
    ServerSocket? lock;
    try {
      lock = await ServerSocket.bind(InternetAddress.loopbackIPv4, _singleInstancePort);
    } on SocketException {
      runApp(const _AlreadyRunningApp());
      return;
    }
    // Deliberately never closed — the OS releases the port
    // automatically when this process exits, even on a crash, which
    // is more reliable than a lock file that could be left behind stale.
    lock.listen((_) {});
  }

  IdleTimer.instance.onTimeout = () {
    if (!VaultSession.instance.isUnlocked) return;
    VaultSession.instance.lock();
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const UnlockScreen()),
      (route) => false,
    );
  };
  runApp(const SovereignVaultApp());
}

class _AlreadyRunningApp extends StatelessWidget {
  const _AlreadyRunningApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sovereign Vault',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, color: AppColors.card, size: 28),
                const SizedBox(height: 14),
                Text('Sovereign Vault is already running',
                    style: TextStyle(fontFamily: AppFonts.serif, fontSize: 18, color: AppColors.card)),
                const SizedBox(height: 8),
                Text('Only one copy can run at a time, to avoid two processes writing to the same vault at once.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: AppFonts.mono, fontSize: 11.5, color: AppColors.mutedAt(1))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SovereignVaultApp extends StatelessWidget {
  const SovereignVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Sovereign Vault',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      builder: (context, child) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => IdleTimer.instance.reset(),
        onPointerMove: (_) => IdleTimer.instance.reset(),
        onPointerSignal: (_) => IdleTimer.instance.reset(),
        child: Container(
          decoration: const BoxDecoration(border: Border.fromBorderSide(BorderSide(color: Colors.black, width: 1))),
          child: child,
        ),
      ),
      home: const _StartupGate(),
    );
  }
}

/// Decides which of three states the app is in at launch:
///   - keys present here -> UnlockScreen (normal case)
///   - no keys, no existing encrypted data -> SetupScreen (first run)
///   - no keys, but encrypted data already exists at this location ->
///     ForeignVaultScreen (this data belongs to a different machine —
///     see the note on ForeignVaultScreen for why this is a dead end,
///     not a "create new vault here" prompt).
class _StartupGate extends StatelessWidget {
  const _StartupGate();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(bool, bool)>(
      future: () async {
        final keysExist = await KeyManager.vaultExists();
        final dataExists = await VaultRepository.indexFileExists();
        return (keysExist, dataExists);
      }(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SplashScreen();
        }
        final (keysExist, dataExists) = snapshot.data!;
        if (keysExist) return const UnlockScreen();
        if (dataExists) return const ForeignVaultScreen();
        return const SetupScreen();
      },
    );
  }
}
