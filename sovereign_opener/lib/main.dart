import 'package:flutter/material.dart';
import 'package:sovereign_core/sovereign_core.dart';

import 'opener_screen.dart';

void main() {
  runApp(const SovereignOpenerApp());
}

class SovereignOpenerApp extends StatelessWidget {
  const SovereignOpenerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sovereign Vault Opener',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const OpenerScreen(),
    );
  }
}
