import 'package:flutter/material.dart';
import 'package:sovereign_core/sovereign_core.dart';

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
            Text('SOVEREIGN VAULT X',
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
