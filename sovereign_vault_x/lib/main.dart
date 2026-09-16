import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sovereign_core/sovereign_core.dart';

import 'screens/foreign_vault_screen.dart';
import 'screens/setup_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/unlock_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

// Distinct from Sovereign Vault's port (47821) so the two apps can run
// side by side without one mistaking the other for a second instance
// of itself.
const _singleInstancePort = 47822;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Namespace this app's storage and secure-storage keys distinctly
  // from the base Sovereign Vault app — both are built on the same
  // sovereign_core engine, but must never read or write each other's
  // data. See StoragePaths and SecureStore in sovereign_core for why
  // these defaults are unsafe to share.
  StoragePaths.appSupportFolderName = 'sovereign_vault_x';
  StoragePaths.portableFolderName = 'SovereignVaultXData';
  SecureStore.keyPrefix = 'x_';

  if (!Platform.isMacOS) {
    ServerSocket? lock;
    try {
      lock = await ServerSocket.bind(InternetAddress.loopbackIPv4, _singleInstancePort);
    } on SocketException {
      runApp(const _AlreadyRunningApp());
      return;
    }
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
  runApp(const SovereignVaultXApp());
}

class _AlreadyRunningApp extends StatelessWidget {
  const _AlreadyRunningApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sovereign Vault X',
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
                Text('Sovereign Vault X is already running',
                    style: TextStyle(fontFamily: AppFonts.serif, fontSize: 18, color: AppColors.card)),
                const SizedBox(height: 8),
                Text('Only one copy can run at a time, to avoid two processes writing to the same data at once.',
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

class SovereignVaultXApp extends StatelessWidget {
  const SovereignVaultXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Sovereign Vault X',
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
