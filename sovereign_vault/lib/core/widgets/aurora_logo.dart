import 'package:flutter/material.dart';

/// The real Aurora brand mark, desaturated to grayscale: the source
/// file is a vivid teal/blue/purple gradient, which read as visually
/// off against this app's flat navy/cream palette. Grayscale keeps the
/// actual mark (not a redrawn substitute) while letting it sit quietly
/// in a UI that otherwise uses no color beyond navy and cream.
class AuroraLogo extends StatelessWidget {
  final double size;
  final double radius;
  const AuroraLogo({super.key, this.size = 40, this.radius = 10});

  static const _grayscale = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: ColorFiltered(
        colorFilter: _grayscale,
        child: Image.asset(
          'assets/aurora_logo.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
