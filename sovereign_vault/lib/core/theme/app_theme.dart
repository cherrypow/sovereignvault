import 'dart:io';

import 'package:flutter/material.dart';

/// "The Hidden System" — dark, deliberately vault-like: near-black
/// ground, a cold periwinkle accent, no card fills or shadows.
/// Hierarchy still comes from hairline dividers, spacing and type, not
/// containers — only the palette inverted from the original light
/// "Private Ledger" direction to read as a system you've been let
/// inside of, not a bright productivity app.
class AppColors {
  AppColors._();

  static const background = Color(0xFF0A0A0E);
  static const card = Color(0xFF9EA0F2); // periwinkle — accents, headings, hairlines
  static const text = Color(0xFFEDEAE2); // warm off-white ink
  static const buttonDark = Color(0xFF4B4B54); // slate grey — primary action buttons
  static const danger = Color(0xFFFF7A6E); // delete/error, tuned for contrast on dark

  static Color textAt(double opacity) => text.withValues(alpha: opacity);
  static Color mutedAt(double opacity) => const Color(0xFFA79E90).withValues(alpha: opacity);

  // Hairline dividers/borders. Nudged a touch stronger than a literal
  // opacity read of the design would give, so rules read as
  // deliberate lines rather than disappearing against the dark
  // background.
  static Color borderAt(double opacity) => card.withValues(alpha: (opacity + 0.05).clamp(0.0, 1.0));
}

/// Placeholder system fonts standing in for the brand pairing
/// (Playfair Display / IBM Plex Mono) used in the approved mockup.
/// Swap these for bundled font assets once branding fonts are final —
/// kept as system fonts for now so the app has no network dependency.
class AppFonts {
  AppFonts._();
  static const serif = 'Georgia'; // ships on both Windows and macOS

  /// Consolas (the previous hardcoded choice) is Windows-only and
  /// doesn't exist on macOS — every mono text style silently fell back
  /// to a generic system font there. Menlo is macOS's built-in
  /// equivalent; Courier New is the safe cross-platform fallback.
  static String get mono => Platform.isMacOS ? 'Menlo' : 'Consolas';
  static const monoFallback = ['Menlo', 'Consolas', 'Courier New', 'monospace'];
}

ThemeData buildAppTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      surface: AppColors.background,
      primary: AppColors.card,
      secondary: AppColors.card,
      error: AppColors.danger,
    ),
    fontFamily: AppFonts.mono,
    fontFamilyFallback: AppFonts.monoFallback,
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: AppColors.text),
    ),
    dividerColor: AppColors.borderAt(0.14),
    useMaterial3: true,
  );
}
