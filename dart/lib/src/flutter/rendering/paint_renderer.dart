/// Paint rendering utilities for Figma paints
///
/// Supports all Figma PaintTypes:
/// - SOLID: Solid color fills
/// - GRADIENT_LINEAR: Linear gradients with transform
/// - GRADIENT_RADIAL: Radial gradients with transform
/// - GRADIENT_ANGULAR: Angular/sweep gradients
/// - GRADIENT_DIAMOND: Diamond gradients (approximated)
/// - IMAGE: Image fills with transform and scale modes
/// - VIDEO, EMOJI, PATTERN, NOISE: Placeholders for future support

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Renders Figma paint data to Flutter painting primitives
class PaintRenderer {
  /// Build a Flutter Color from Figma color data
  static Color? buildColor(Map<String, dynamic>? colorData, [double opacity = 1.0]) {
    if (colorData == null) return null;

    final r = (colorData['r'] as num?)?.toDouble() ?? 0;
    final g = (colorData['g'] as num?)?.toDouble() ?? 0;
    final b = (colorData['b'] as num?)?.toDouble() ?? 0;
    final a = (colorData['a'] as num?)?.toDouble() ?? 1.0;

    return Color.fromRGBO(
      (r * 255).round().clamp(0, 255),
      (g * 255).round().clamp(0, 255),
      (b * 255).round().clamp(0, 255),
      a * opacity,
    );
  }

  /// Build a Flutter Gradient from Figma paint data
  static Gradient? buildGradient(Map<String, dynamic> paint, Size size) {
    final type = paint['type']?.toString();
    if (type == null) return null;

    final stops = paint['gradientStops'] as List?;
    if (stops == null || stops.isEmpty) {
      // If no gradientStops, create default 2-color gradient from colors if available
      // Some Figma files might not have explicit stops
      return null;
    }

    final colors = <Color>[];
    final stopPositions = <double>[];

    for (final stop in stops) {
      if (stop is Map) {
        final color = stop['color'];
        final position = (stop['position'] as num?)?.toDouble() ?? 0;

        if (color is Map) {
          colors.add(buildColor(color.cast<String, dynamic>()) ?? Colors.transparent);
        }
        stopPositions.add(position);
      }
    }

    if (colors.length < 2) return null;

    // Parse gradient transform - try multiple formats
    // 1. Check for 'gradientTransform' with handle positions
    // 2. Check for 'transform' with matrix values (m00, m01, etc)
    final gradientTransform = paint['gradientTransform'] as Map<String, dynamic>?;
    final matrixTransform = paint['transform'] as Map<String, dynamic>?;
    final handles = _parseGradientHandles(gradientTransform, matrixTransform, size);

    switch (type) {
      case 'GRADIENT_LINEAR':
        return _buildLinearGradient(colors, stopPositions, handles, size);
      case 'GRADIENT_RADIAL':
        return _buildRadialGradient(colors, stopPositions, handles, size);
      case 'GRADIENT_ANGULAR':
        return _buildAngularGradient(colors, stopPositions, handles, size);
      case 'GRADIENT_DIAMOND':
        return _buildDiamondGradient(colors, stopPositions, handles, size);
      default:
        return null;
    }
  }

  /// Parse gradient handle positions from transform data
  /// Supports two formats:
  /// 1. Handle positions (handlePositionA/B/C)
  /// 2. Transform matrix (m00, m01, m02, m10, m11, m12)
  static _GradientHandles _parseGradientHandles(
    Map<String, dynamic>? gradientTransform,
    Map<String, dynamic>? matrixTransform,
    Size size,
  ) {
    // Try handle positions format first
    if (gradientTransform != null) {
      final handleA = gradientTransform['handlePositionA'] as Map<String, dynamic>?;
      final handleB = gradientTransform['handlePositionB'] as Map<String, dynamic>?;
      final handleC = gradientTransform['handlePositionC'] as Map<String, dynamic>?;

      if (handleA != null || handleB != null) {
        return _GradientHandles(
          a: _parseVector(handleA) ?? const Offset(0.5, 0),
          b: _parseVector(handleB) ?? const Offset(0.5, 1),
          c: _parseVector(handleC) ?? const Offset(0, 0.5),
        );
      }
    }

    // Try transform matrix format
    if (matrixTransform != null) {
      final m00 = (matrixTransform['m00'] as num?)?.toDouble() ?? 1.0;
      final m01 = (matrixTransform['m01'] as num?)?.toDouble() ?? 0.0;
      final m02 = (matrixTransform['m02'] as num?)?.toDouble() ?? 0.0;
      final m10 = (matrixTransform['m10'] as num?)?.toDouble() ?? 0.0;
      final m11 = (matrixTransform['m11'] as num?)?.toDouble() ?? 1.0;
      final m12 = (matrixTransform['m12'] as num?)?.toDouble() ?? 0.0;

      // The transform matrix maps from gradient space to node space
      // Gradient space: x=0 to 1 (along gradient), y=0.5 (center)
      // Apply transform to get start and end points in normalized coordinates

      // Start point (gradient position 0, center)
      final startX = m00 * 0.0 + m01 * 0.5 + m02;
      final startY = m10 * 0.0 + m11 * 0.5 + m12;

      // End point (gradient position 1, center)
      final endX = m00 * 1.0 + m01 * 0.5 + m02;
      final endY = m10 * 1.0 + m11 * 0.5 + m12;

      // Control point for radial gradient (perpendicular direction)
      final ctrlX = m00 * 0.5 + m01 * 0.0 + m02;
      final ctrlY = m10 * 0.5 + m11 * 0.0 + m12;

      return _GradientHandles(
        a: Offset(startX, startY),
        b: Offset(endX, endY),
        c: Offset(ctrlX, ctrlY),
      );
    }

    // Default: vertical gradient from top to bottom
    return _GradientHandles(
      a: const Offset(0.5, 0), // Start at top center
      b: const Offset(0.5, 1), // End at bottom center
      c: const Offset(0, 0.5), // Control point
    );
  }

  static Offset? _parseVector(Map<String, dynamic>? vector) {
    if (vector == null) return null;
    final x = (vector['x'] as num?)?.toDouble() ?? 0;
    final y = (vector['y'] as num?)?.toDouble() ?? 0;
    return Offset(x, y);
  }

  /// Build a linear gradient with proper transform
  static LinearGradient _buildLinearGradient(
    List<Color> colors,
    List<double> stops,
    _GradientHandles handles,
    Size size,
  ) {
    // Convert normalized coordinates to alignment
    // Figma uses 0-1 coordinates, Flutter uses -1 to 1
    final beginAlign = Alignment(
      (handles.a.dx * 2) - 1,
      (handles.a.dy * 2) - 1,
    );
    final endAlign = Alignment(
      (handles.b.dx * 2) - 1,
      (handles.b.dy * 2) - 1,
    );

    return LinearGradient(
      colors: colors,
      stops: stops,
      begin: beginAlign,
      end: endAlign,
    );
  }

  /// Build a radial gradient with proper transform
  static RadialGradient _buildRadialGradient(
    List<Color> colors,
    List<double> stops,
    _GradientHandles handles,
    Size size,
  ) {
    // Center is handle A, radius determined by distance to B
    final centerAlign = Alignment(
      (handles.a.dx * 2) - 1,
      (handles.a.dy * 2) - 1,
    );

    // Calculate radius from handles
    final radius = (handles.b - handles.a).distance;

    return RadialGradient(
      colors: colors,
      stops: stops,
      center: centerAlign,
      radius: radius > 0 ? radius : 0.5,
    );
  }

  /// Build an angular/sweep gradient
  static SweepGradient _buildAngularGradient(
    List<Color> colors,
    List<double> stops,
    _GradientHandles handles,
    Size size,
  ) {
    final centerAlign = Alignment(
      (handles.a.dx * 2) - 1,
      (handles.a.dy * 2) - 1,
    );

    // Calculate start angle from handle positions
    final direction = handles.b - handles.a;
    final startAngle = math.atan2(direction.dy, direction.dx);

    return SweepGradient(
      colors: colors,
      stops: stops,
      center: centerAlign,
      startAngle: startAngle,
      endAngle: startAngle + 2 * math.pi,
    );
  }

  /// Build a diamond gradient (approximated as radial with focal point)
  /// Note: Flutter doesn't have a native diamond gradient, so we approximate
  static RadialGradient _buildDiamondGradient(
    List<Color> colors,
    List<double> stops,
    _GradientHandles handles,
    Size size,
  ) {
    // For now, approximate as radial gradient
    // A true diamond gradient would require a custom shader
    final centerAlign = Alignment(
      (handles.a.dx * 2) - 1,
      (handles.a.dy * 2) - 1,
    );

    final radius = (handles.b - handles.a).distance;

    return RadialGradient(
      colors: colors,
      stops: stops,
      center: centerAlign,
      radius: radius > 0 ? radius : 0.5,
      focal: centerAlign,
      focalRadius: 0,
    );
  }

  /// Build a BoxDecoration from Figma fills
  static BoxDecoration buildDecoration({
    required List<Map<String, dynamic>> fills,
    required Size size,
    List<Map<String, dynamic>>? strokes,
    double strokeWeight = 0,
    BorderRadius? borderRadius,
    List<BoxShadow>? shadows,
  }) {
    Color? backgroundColor;
    Gradient? gradient;
    DecorationImage? image;

    for (final fill in fills) {
      if (fill['visible'] == false) continue;

      final type = fill['type']?.toString();

      if (type == 'SOLID') {
        final color = fill['color'];
        final opacity = (fill['opacity'] as num?)?.toDouble() ?? 1.0;
        if (color is Map) {
          backgroundColor = buildColor(color.cast<String, dynamic>(), opacity);
        }
      } else if (type?.startsWith('GRADIENT_') == true) {
        gradient = buildGradient(fill, size);
      }
      // IMAGE handled separately via buildImageProvider
    }

    // Build border from strokes
    Border? border;
    if (strokes != null && strokes.isNotEmpty && strokeWeight > 0) {
      for (final stroke in strokes) {
        if (stroke['visible'] == false) continue;
        final type = stroke['type']?.toString();
        if (type == 'SOLID') {
          final color = stroke['color'];
          final opacity = (stroke['opacity'] as num?)?.toDouble() ?? 1.0;
          if (color is Map) {
            final strokeColor = buildColor(color.cast<String, dynamic>(), opacity);
            if (strokeColor != null) {
              border = Border.all(color: strokeColor, width: strokeWeight);
            }
          }
        }
      }
    }

    return BoxDecoration(
      color: gradient == null ? backgroundColor : null,
      gradient: gradient,
      image: image,
      border: border,
      borderRadius: borderRadius,
      boxShadow: shadows,
    );
  }

  /// Check if fills contain an image
  static bool hasImageFill(List<Map<String, dynamic>> fills) {
    return fills.any((fill) =>
      fill['visible'] != false && fill['type'] == 'IMAGE'
    );
  }

  /// Get image data from fills
  static Map<String, dynamic>? getImageFill(List<Map<String, dynamic>> fills) {
    for (final fill in fills) {
      if (fill['visible'] == false) continue;
      if (fill['type'] == 'IMAGE') {
        return fill;
      }
    }
    return null;
  }

  /// Build image scale mode (BoxFit)
  static BoxFit getImageBoxFit(String? scaleMode) {
    switch (scaleMode) {
      case 'STRETCH':
        return BoxFit.fill;
      case 'FIT':
        return BoxFit.contain;
      case 'FILL':
        return BoxFit.cover;
      case 'TILE':
        return BoxFit.none; // Tiling handled separately
      default:
        return BoxFit.cover;
    }
  }
}

/// Helper class to hold gradient handle positions
class _GradientHandles {
  final Offset a; // Start/center point
  final Offset b; // End point
  final Offset c; // Control/width point

  const _GradientHandles({
    required this.a,
    required this.b,
    required this.c,
  });
}

/// Custom painter for gradients that need special handling
class GradientPainter extends CustomPainter {
  final Gradient gradient;
  final Rect? rect;

  GradientPainter({
    required this.gradient,
    this.rect,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintRect = rect ?? Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..shader = gradient.createShader(paintRect);

    canvas.drawRect(paintRect, paint);
  }

  @override
  bool shouldRepaint(GradientPainter oldDelegate) {
    return gradient != oldDelegate.gradient || rect != oldDelegate.rect;
  }
}

/// Custom painter for diamond gradient using a shader
class DiamondGradientPainter extends CustomPainter {
  final List<Color> colors;
  final List<double> stops;
  final Offset center;
  final double radius;

  DiamondGradientPainter({
    required this.colors,
    required this.stops,
    required this.center,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // For a true diamond gradient, we'd need a custom fragment shader
    // For now, use a radial gradient as approximation
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final centerPoint = Offset(
      center.dx * size.width,
      center.dy * size.height,
    );

    final gradient = RadialGradient(
      colors: colors,
      stops: stops,
      center: Alignment(
        (center.dx * 2) - 1,
        (center.dy * 2) - 1,
      ),
      radius: radius,
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect);

    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(DiamondGradientPainter oldDelegate) {
    return colors != oldDelegate.colors ||
           stops != oldDelegate.stops ||
           center != oldDelegate.center ||
           radius != oldDelegate.radius;
  }
}
