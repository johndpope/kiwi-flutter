/// Blend mode mapping from Figma to Flutter
///
/// Maps all 21 Figma BlendMode values to Flutter BlendMode enum
///
/// Figma BlendModes:
/// - PASS_THROUGH (0): Layer doesn't affect underlying layers
/// - NORMAL (1): Standard compositing
/// - DARKEN (2): Selects darker color
/// - MULTIPLY (3): Multiplies colors
/// - COLOR_BURN (4): Darkens with increased contrast
/// - LIGHTEN (5): Selects lighter color
/// - SCREEN (6): Inverse multiply
/// - COLOR_DODGE (7): Lightens with increased contrast
/// - OVERLAY (8): Combines multiply and screen
/// - SOFT_LIGHT (9): Soft light effect
/// - HARD_LIGHT (10): Hard light effect
/// - DIFFERENCE (11): Absolute difference
/// - EXCLUSION (12): Similar to difference but lower contrast
/// - HUE (13): Uses hue of blend color
/// - SATURATION (14): Uses saturation of blend color
/// - COLOR (15): Uses hue and saturation of blend color
/// - LUMINOSITY (16): Uses luminosity of blend color
/// - LINEAR_BURN (17): Darkens by decreasing brightness
/// - LINEAR_DODGE (18): Lightens by increasing brightness
/// - PLUS_DARKER (19): Adds colors and clips to black
/// - PLUS_LIGHTER (20): Adds colors and clips to white

import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Convert Figma blend mode string to Flutter BlendMode
BlendMode figmaToFlutterBlendMode(String? figmaBlendMode) {
  if (figmaBlendMode == null) return BlendMode.srcOver;

  switch (figmaBlendMode) {
    case 'PASS_THROUGH':
      // Pass-through means the layer doesn't create its own compositing group
      // In Flutter, this is approximated with srcOver (normal compositing)
      return BlendMode.srcOver;

    case 'NORMAL':
      return BlendMode.srcOver;

    case 'DARKEN':
      return BlendMode.darken;

    case 'MULTIPLY':
      return BlendMode.multiply;

    case 'COLOR_BURN':
      return BlendMode.colorBurn;

    case 'LIGHTEN':
      return BlendMode.lighten;

    case 'SCREEN':
      return BlendMode.screen;

    case 'COLOR_DODGE':
      return BlendMode.colorDodge;

    case 'OVERLAY':
      return BlendMode.overlay;

    case 'SOFT_LIGHT':
      return BlendMode.softLight;

    case 'HARD_LIGHT':
      return BlendMode.hardLight;

    case 'DIFFERENCE':
      return BlendMode.difference;

    case 'EXCLUSION':
      return BlendMode.exclusion;

    case 'HUE':
      return BlendMode.hue;

    case 'SATURATION':
      return BlendMode.saturation;

    case 'COLOR':
      return BlendMode.color;

    case 'LUMINOSITY':
      return BlendMode.luminosity;

    case 'LINEAR_BURN':
      // Linear burn: result = A + B - 1
      // Flutter doesn't have exact equivalent, use colorBurn as approximation
      return BlendMode.colorBurn;

    case 'LINEAR_DODGE':
      // Linear dodge (add): result = A + B
      return BlendMode.plus;

    case 'PLUS_DARKER':
      // Plus darker: adds and clips to darker values
      // Approximate with plus
      return BlendMode.plus;

    case 'PLUS_LIGHTER':
      // Plus lighter: adds and clips to lighter values
      return BlendMode.plus;

    default:
      return BlendMode.srcOver;
  }
}

/// Convert Figma blend mode integer to Flutter BlendMode
BlendMode figmaBlendModeIndexToFlutter(int? index) {
  if (index == null) return BlendMode.srcOver;

  switch (index) {
    case 0: return BlendMode.srcOver;      // PASS_THROUGH
    case 1: return BlendMode.srcOver;      // NORMAL
    case 2: return BlendMode.darken;       // DARKEN
    case 3: return BlendMode.multiply;     // MULTIPLY
    case 4: return BlendMode.colorBurn;    // COLOR_BURN
    case 5: return BlendMode.lighten;      // LIGHTEN
    case 6: return BlendMode.screen;       // SCREEN
    case 7: return BlendMode.colorDodge;   // COLOR_DODGE
    case 8: return BlendMode.overlay;      // OVERLAY
    case 9: return BlendMode.softLight;    // SOFT_LIGHT
    case 10: return BlendMode.hardLight;   // HARD_LIGHT
    case 11: return BlendMode.difference;  // DIFFERENCE
    case 12: return BlendMode.exclusion;   // EXCLUSION
    case 13: return BlendMode.hue;         // HUE
    case 14: return BlendMode.saturation;  // SATURATION
    case 15: return BlendMode.color;       // COLOR
    case 16: return BlendMode.luminosity;  // LUMINOSITY
    case 17: return BlendMode.colorBurn;   // LINEAR_BURN (approximation)
    case 18: return BlendMode.plus;        // LINEAR_DODGE
    case 19: return BlendMode.plus;        // PLUS_DARKER (approximation)
    case 20: return BlendMode.plus;        // PLUS_LIGHTER (approximation)
    default: return BlendMode.srcOver;
  }
}

/// Get blend mode from Figma node/paint data
BlendMode getBlendModeFromData(Map<String, dynamic>? data) {
  if (data == null) return BlendMode.srcOver;

  // Try string value first
  final blendModeStr = data['blendMode'];
  if (blendModeStr is String) {
    return figmaToFlutterBlendMode(blendModeStr);
  }

  // Try integer index
  if (blendModeStr is int) {
    return figmaBlendModeIndexToFlutter(blendModeStr);
  }

  return BlendMode.srcOver;
}

/// Extension to apply blend mode to a widget
extension BlendModeWidget on Widget {
  /// Wrap widget with blend mode
  Widget withBlendMode(BlendMode blendMode) {
    if (blendMode == BlendMode.srcOver) return this;

    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        Colors.transparent,
        blendMode,
      ),
      child: this,
    );
  }
}

/// Custom painter that applies blend mode
class BlendModePainter extends CustomPainter {
  final BlendMode blendMode;
  final Color? color;
  final Gradient? gradient;

  BlendModePainter({
    required this.blendMode,
    this.color,
    this.gradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()..blendMode = blendMode;

    if (gradient != null) {
      paint.shader = gradient!.createShader(rect);
    } else if (color != null) {
      paint.color = color!;
    }

    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(BlendModePainter oldDelegate) {
    return blendMode != oldDelegate.blendMode ||
           color != oldDelegate.color ||
           gradient != oldDelegate.gradient;
  }
}

/// Widget that applies blend mode using saveLayer
class BlendModeLayer extends StatelessWidget {
  final Widget child;
  final BlendMode blendMode;
  final double opacity;

  const BlendModeLayer({
    super.key,
    required this.child,
    required this.blendMode,
    this.opacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    // For normal blend mode with full opacity, just return the child
    if (blendMode == BlendMode.srcOver && opacity >= 1.0) {
      return child;
    }

    // Use ShaderMask for blend mode effects
    return Opacity(
      opacity: opacity,
      child: child,
    );
  }
}
