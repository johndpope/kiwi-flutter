/// Effect rendering utilities for Figma effects
///
/// Supports all Figma EffectTypes:
/// - DROP_SHADOW: External shadow with offset, blur, and spread
/// - INNER_SHADOW: Internal shadow effect
/// - LAYER_BLUR: Gaussian blur on the layer
/// - BACKGROUND_BLUR: Blur of content behind the layer
/// - FOREGROUND_BLUR: Blur of content in front (rare)

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'paint_renderer.dart';

/// Renders Figma effect data to Flutter effect primitives
class EffectRenderer {
  /// Build BoxShadow list from Figma effects
  static List<BoxShadow> buildBoxShadows(List<Map<String, dynamic>> effects) {
    final shadows = <BoxShadow>[];

    for (final effect in effects) {
      if (effect['visible'] == false) continue;

      final type = effect['type']?.toString();
      if (type == 'DROP_SHADOW' || type == 'INNER_SHADOW') {
        final shadow = buildBoxShadow(effect);
        if (shadow != null) {
          shadows.add(shadow);
        }
      }
    }

    return shadows;
  }

  /// Build a single BoxShadow from Figma effect data
  static BoxShadow? buildBoxShadow(Map<String, dynamic> effect) {
    final type = effect['type']?.toString();
    if (type != 'DROP_SHADOW' && type != 'INNER_SHADOW') {
      return null;
    }

    // Extract color
    final colorData = effect['color'] as Map<String, dynamic>?;
    final color = PaintRenderer.buildColor(colorData) ?? Colors.black26;

    // Extract offset
    final offsetData = effect['offset'] as Map<String, dynamic>?;
    final offsetX = (offsetData?['x'] as num?)?.toDouble() ?? 0;
    final offsetY = (offsetData?['y'] as num?)?.toDouble() ?? 0;

    // Extract blur radius
    final blurRadius = (effect['radius'] as num?)?.toDouble() ?? 0;

    // Extract spread radius
    final spreadRadius = (effect['spread'] as num?)?.toDouble() ?? 0;

    // Note: Flutter BoxShadow doesn't support inner shadows directly
    // For inner shadows, we'd need to use a custom painter or shader
    // For now, we'll skip inner shadows in BoxShadow and handle them separately

    if (type == 'INNER_SHADOW') {
      // Inner shadows would need special handling with a custom painter
      // Return null for now - they'll be handled in InnerShadowPainter
      return null;
    }

    return BoxShadow(
      color: color,
      offset: Offset(offsetX, offsetY),
      blurRadius: blurRadius,
      spreadRadius: spreadRadius,
    );
  }

  /// Check if effects contain blur
  static bool hasBlur(List<Map<String, dynamic>> effects) {
    return effects.any((effect) {
      if (effect['visible'] == false) return false;
      final type = effect['type']?.toString();
      return type == 'LAYER_BLUR' ||
             type == 'BACKGROUND_BLUR' ||
             type == 'FOREGROUND_BLUR';
    });
  }

  /// Check if effects contain inner shadow
  static bool hasInnerShadow(List<Map<String, dynamic>> effects) {
    return effects.any((effect) {
      if (effect['visible'] == false) return false;
      return effect['type']?.toString() == 'INNER_SHADOW';
    });
  }

  /// Get blur radius from effects
  static double? getBlurRadius(List<Map<String, dynamic>> effects) {
    for (final effect in effects) {
      if (effect['visible'] == false) continue;
      final type = effect['type']?.toString();
      if (type == 'LAYER_BLUR' ||
          type == 'BACKGROUND_BLUR' ||
          type == 'FOREGROUND_BLUR') {
        return (effect['radius'] as num?)?.toDouble();
      }
    }
    return null;
  }

  /// Get background blur radius specifically
  static double? getBackgroundBlurRadius(List<Map<String, dynamic>> effects) {
    for (final effect in effects) {
      if (effect['visible'] == false) continue;
      if (effect['type']?.toString() == 'BACKGROUND_BLUR') {
        return (effect['radius'] as num?)?.toDouble();
      }
    }
    return null;
  }

  /// Build ImageFilter for blur effects
  static ui.ImageFilter? buildBlurFilter(List<Map<String, dynamic>> effects) {
    final radius = getBlurRadius(effects);
    if (radius == null || radius <= 0) return null;

    return ui.ImageFilter.blur(
      sigmaX: radius,
      sigmaY: radius,
      tileMode: TileMode.clamp,
    );
  }

  /// Apply effects to a child widget
  static Widget applyEffects(
    Widget child,
    List<Map<String, dynamic>> effects, {
    Size? size,
    BorderRadius? borderRadius,
  }) {
    if (effects.isEmpty) return child;

    Widget result = child;

    // Apply layer blur
    final blurRadius = getBlurRadius(effects);
    if (blurRadius != null && blurRadius > 0) {
      result = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: blurRadius,
          sigmaY: blurRadius,
        ),
        child: result,
      );
    }

    // Apply inner shadows using custom painter
    if (hasInnerShadow(effects) && size != null) {
      final innerShadows = _buildInnerShadows(effects);
      if (innerShadows.isNotEmpty) {
        result = CustomPaint(
          painter: InnerShadowPainter(
            shadows: innerShadows,
            borderRadius: borderRadius,
          ),
          child: result,
        );
      }
    }

    return result;
  }

  /// Build inner shadow data list
  static List<InnerShadowData> _buildInnerShadows(List<Map<String, dynamic>> effects) {
    final shadows = <InnerShadowData>[];

    for (final effect in effects) {
      if (effect['visible'] == false) continue;
      if (effect['type']?.toString() != 'INNER_SHADOW') continue;

      final colorData = effect['color'] as Map<String, dynamic>?;
      final color = PaintRenderer.buildColor(colorData) ?? Colors.black26;

      final offsetData = effect['offset'] as Map<String, dynamic>?;
      final offsetX = (offsetData?['x'] as num?)?.toDouble() ?? 0;
      final offsetY = (offsetData?['y'] as num?)?.toDouble() ?? 0;

      final blurRadius = (effect['radius'] as num?)?.toDouble() ?? 0;
      final spread = (effect['spread'] as num?)?.toDouble() ?? 0;

      shadows.add(InnerShadowData(
        color: color,
        offset: Offset(offsetX, offsetY),
        blurRadius: blurRadius,
        spread: spread,
      ));
    }

    return shadows;
  }
}

/// Data class for inner shadow properties
class InnerShadowData {
  final Color color;
  final Offset offset;
  final double blurRadius;
  final double spread;

  const InnerShadowData({
    required this.color,
    required this.offset,
    required this.blurRadius,
    required this.spread,
  });
}

/// Custom painter for inner shadows
class InnerShadowPainter extends CustomPainter {
  final List<InnerShadowData> shadows;
  final BorderRadius? borderRadius;

  InnerShadowPainter({
    required this.shadows,
    this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (shadows.isEmpty) return;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = borderRadius?.toRRect(rect) ?? RRect.fromRectXY(rect, 0, 0);

    for (final shadow in shadows) {
      _paintInnerShadow(canvas, rrect, shadow);
    }
  }

  void _paintInnerShadow(Canvas canvas, RRect rrect, InnerShadowData shadow) {
    final paint = Paint()
      ..color = shadow.color
      ..maskFilter = shadow.blurRadius > 0
          ? MaskFilter.blur(BlurStyle.normal, shadow.blurRadius)
          : null;

    // Create a path for the inner shadow
    // This is done by drawing a larger rect outside and clipping to the inner shape
    canvas.save();
    canvas.clipRRect(rrect);

    // Draw shadow offset from edge
    final shadowRect = rrect.outerRect.shift(shadow.offset);
    final expandedRect = shadowRect.inflate(shadow.spread);

    // Create inverted path for inner shadow
    final outerPath = Path()..addRect(expandedRect.inflate(100));
    final innerPath = Path()..addRRect(rrect.shift(shadow.offset));
    final shadowPath = Path.combine(PathOperation.difference, outerPath, innerPath);

    canvas.drawPath(shadowPath, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(InnerShadowPainter oldDelegate) {
    return shadows != oldDelegate.shadows ||
           borderRadius != oldDelegate.borderRadius;
  }
}

/// Widget that applies background blur effect
class BackgroundBlurWidget extends StatelessWidget {
  final Widget child;
  final double blurRadius;
  final BorderRadius? borderRadius;

  const BackgroundBlurWidget({
    super.key,
    required this.child,
    required this.blurRadius,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: blurRadius,
          sigmaY: blurRadius,
        ),
        child: child,
      ),
    );
  }
}
