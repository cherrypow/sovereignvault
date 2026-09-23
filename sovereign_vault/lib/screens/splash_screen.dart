import 'package:flutter/material.dart';
import '../core/core.dart';

/// Shown for the brief moment while _StartupGate checks whether keys
/// and/or data exist. Replaces a bare spinner — the app should never
/// show an unbranded blank screen, even for a fraction of a second.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AuroraLogo(size: 56, radius: 14),
            const SizedBox(height: 20),
            Text('SOVEREIGN VAULT',
                style: TextStyle(fontFamily: AppFonts.mono, fontSize: 11, letterSpacing: 3, color: AppColors.mutedAt(1))),
            const SizedBox(height: 24),
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.card),
            ),
          ],
        ),
      ),
    );
  }
}
