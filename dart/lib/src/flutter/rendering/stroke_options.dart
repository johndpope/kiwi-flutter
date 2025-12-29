/// Advanced stroke options for shapes
///
/// Supports:
/// - Stroke caps (round, square, butt)
/// - Stroke joins (miter, round, bevel)
/// - Dash patterns (gap, dash, custom)
/// - Stroke position (inside, center, outside)
/// - Individual stroke sides

import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Stroke position relative to the path
enum StrokePosition {
  /// Stroke centered on the path (default)
  center,

  /// Stroke inside the shape
  inside,

  /// Stroke outside the shape
  outside,
}

/// Preset dash patterns
enum DashPreset {
  /// No dashing (solid line)
  solid,

  /// Short dashes
  dashed,

  /// Dots
  dotted,

  /// Dash-dot pattern
  dashDot,

  /// Dash-dot-dot pattern
  dashDotDot,

  /// Custom pattern
  custom,
}

/// Individual stroke sides (for rectangles)
class StrokeSides {
  final bool top;
  final bool right;
  final bool bottom;
  final bool left;

  const StrokeSides({
    this.top = true,
    this.right = true,
    this.bottom = true,
    this.left = true,
  });

  /// All sides enabled
  static const StrokeSides all = StrokeSides();

  /// No sides enabled
  static const StrokeSides none = StrokeSides(
    top: false,
    right: false,
    bottom: false,
    left: false,
  );

  /// Only horizontal sides
  static const StrokeSides horizontal = StrokeSides(
    top: true,
    bottom: true,
    right: false,
    left: false,
  );

  /// Only vertical sides
  static const StrokeSides vertical = StrokeSides(
    top: false,
    bottom: false,
    right: true,
    left: true,
  );

  bool get hasAny => top || right || bottom || left;
  bool get hasAll => top && right && bottom && left;

  int get enabledCount => [top, right, bottom, left].where((e) => e).length;

  StrokeSides copyWith({
    bool? top,
    bool? right,
    bool? bottom,
    bool? left,
  }) {
    return StrokeSides(
      top: top ?? this.top,
      right: right ?? this.right,
      bottom: bottom ?? this.bottom,
      left: left ?? this.left,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StrokeSides &&
          top == other.top &&
          right == other.right &&
          bottom == other.bottom &&
          left == other.left;

  @override
  int get hashCode => Object.hash(top, right, bottom, left);
}

/// Complete stroke configuration
class StrokeConfig {
  /// Stroke color
  final Color color;

  /// Stroke width
  final double width;

  /// Stroke opacity (0.0 - 1.0)
  final double opacity;

  /// Stroke cap style
  final StrokeCap cap;

  /// Stroke join style
  final StrokeJoin join;

  /// Miter limit for miter joins
  final double miterLimit;

  /// Stroke position
  final StrokePosition position;

  /// Dash pattern (alternating dash/gap lengths)
  final List<double>? dashPattern;

  /// Dash offset for animation
  final double dashOffset;

  /// Individual stroke sides (for rectangles)
  final StrokeSides sides;

  /// Whether stroke is enabled
  final bool enabled;

  const StrokeConfig({
    this.color = Colors.black,
    this.width = 1.0,
    this.opacity = 1.0,
    this.cap = StrokeCap.butt,
    this.join = StrokeJoin.miter,
    this.miterLimit = 4.0,
    this.position = StrokePosition.center,
    this.dashPattern,
    this.dashOffset = 0.0,
    this.sides = const StrokeSides(),
    this.enabled = true,
  });

  /// Create a solid stroke
  factory StrokeConfig.solid({
    Color color = Colors.black,
    double width = 1.0,
    StrokeCap cap = StrokeCap.butt,
    StrokeJoin join = StrokeJoin.miter,
  }) {
    return StrokeConfig(
      color: color,
      width: width,
      cap: cap,
      join: join,
    );
  }

  /// Create a dashed stroke
  factory StrokeConfig.dashed({
    Color color = Colors.black,
    double width = 1.0,
    double dashLength = 8.0,
    double gapLength = 4.0,
    StrokeCap cap = StrokeCap.butt,
  }) {
    return StrokeConfig(
      color: color,
      width: width,
      dashPattern: [dashLength, gapLength],
      cap: cap,
    );
  }

  /// Create a dotted stroke
  factory StrokeConfig.dotted({
    Color color = Colors.black,
    double width = 1.0,
    double spacing = 4.0,
  }) {
    return StrokeConfig(
      color: color,
      width: width,
      dashPattern: [1.0, spacing],
      cap: StrokeCap.round,
    );
  }

  /// Create from dash preset
  factory StrokeConfig.fromPreset(
    DashPreset preset, {
    Color color = Colors.black,
    double width = 1.0,
    List<double>? customPattern,
  }) {
    List<double>? pattern;
    StrokeCap cap = StrokeCap.butt;

    switch (preset) {
      case DashPreset.solid:
        pattern = null;
        break;
      case DashPreset.dashed:
        pattern = [width * 4, width * 2];
        break;
      case DashPreset.dotted:
        pattern = [width, width * 2];
        cap = StrokeCap.round;
        break;
      case DashPreset.dashDot:
        pattern = [width * 4, width * 2, width, width * 2];
        break;
      case DashPreset.dashDotDot:
        pattern = [width * 4, width * 2, width, width * 2, width, width * 2];
        break;
      case DashPreset.custom:
        pattern = customPattern;
        break;
    }

    return StrokeConfig(
      color: color,
      width: width,
      dashPattern: pattern,
      cap: cap,
    );
  }

  /// Get effective color with opacity
  Color get effectiveColor => color.withOpacity(opacity);

  /// Whether stroke has a dash pattern
  bool get isDashed => dashPattern != null && dashPattern!.isNotEmpty;

  /// Convert to Paint object
  Paint toPaint() {
    return Paint()
      ..color = effectiveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = cap
      ..strokeJoin = join
      ..strokeMiterLimit = miterLimit;
  }

  StrokeConfig copyWith({
    Color? color,
    double? width,
    double? opacity,
    StrokeCap? cap,
    StrokeJoin? join,
    double? miterLimit,
    StrokePosition? position,
    List<double>? dashPattern,
    double? dashOffset,
    StrokeSides? sides,
    bool? enabled,
  }) {
    return StrokeConfig(
      color: color ?? this.color,
      width: width ?? this.width,
      opacity: opacity ?? this.opacity,
      cap: cap ?? this.cap,
      join: join ?? this.join,
      miterLimit: miterLimit ?? this.miterLimit,
      position: position ?? this.position,
      dashPattern: dashPattern ?? this.dashPattern,
      dashOffset: dashOffset ?? this.dashOffset,
      sides: sides ?? this.sides,
      enabled: enabled ?? this.enabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StrokeConfig &&
          color == other.color &&
          width == other.width &&
          opacity == other.opacity &&
          cap == other.cap &&
          join == other.join &&
          position == other.position &&
          _listEquals(dashPattern, other.dashPattern) &&
          sides == other.sides &&
          enabled == other.enabled;

  @override
  int get hashCode => Object.hash(
        color,
        width,
        opacity,
        cap,
        join,
        position,
        dashPattern?.hashCode,
        sides,
        enabled,
      );

  static bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Painter for strokes with advanced options
class StrokePainter {
  /// Draw a stroked path with the given config
  static void drawPath(
    Canvas canvas,
    Path path,
    StrokeConfig config,
  ) {
    if (!config.enabled) return;

    final paint = config.toPaint();

    if (config.isDashed) {
      _drawDashedPath(canvas, path, paint, config.dashPattern!, config.dashOffset);
    } else {
      canvas.drawPath(path, paint);
    }
  }

  /// Draw a stroked rect with position adjustment
  static void drawRect(
    Canvas canvas,
    Rect rect,
    StrokeConfig config,
  ) {
    if (!config.enabled) return;

    // Adjust rect for stroke position
    final adjustedRect = _adjustRectForPosition(rect, config);

    if (config.sides.hasAll) {
      // Draw all sides as a single path
      final path = Path()..addRect(adjustedRect);
      drawPath(canvas, path, config);
    } else {
      // Draw individual sides
      _drawIndividualSides(canvas, adjustedRect, config);
    }
  }

  /// Draw a stroked rounded rect with position adjustment
  static void drawRRect(
    Canvas canvas,
    RRect rrect,
    StrokeConfig config,
  ) {
    if (!config.enabled) return;

    final adjustedRRect = _adjustRRectForPosition(rrect, config);
    final path = Path()..addRRect(adjustedRRect);
    drawPath(canvas, path, config);
  }

  /// Draw a stroked ellipse with position adjustment
  static void drawOval(
    Canvas canvas,
    Rect bounds,
    StrokeConfig config,
  ) {
    if (!config.enabled) return;

    final adjustedBounds = _adjustRectForPosition(bounds, config);
    final path = Path()..addOval(adjustedBounds);
    drawPath(canvas, path, config);
  }

  static Rect _adjustRectForPosition(Rect rect, StrokeConfig config) {
    switch (config.position) {
      case StrokePosition.center:
        return rect;
      case StrokePosition.inside:
        final inset = config.width / 2;
        return rect.deflate(inset);
      case StrokePosition.outside:
        final outset = config.width / 2;
        return rect.inflate(outset);
    }
  }

  static RRect _adjustRRectForPosition(RRect rrect, StrokeConfig config) {
    switch (config.position) {
      case StrokePosition.center:
        return rrect;
      case StrokePosition.inside:
        final inset = config.width / 2;
        return rrect.deflate(inset);
      case StrokePosition.outside:
        final outset = config.width / 2;
        return rrect.inflate(outset);
    }
  }

  static void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint,
    List<double> pattern,
    double offset,
  ) {
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = -offset;
      int patternIndex = 0;
      bool draw = true;

      while (distance < metric.length) {
        final segmentLength = pattern[patternIndex % pattern.length];
        final start = distance.clamp(0.0, metric.length);
        final end = (distance + segmentLength).clamp(0.0, metric.length);

        if (draw && end > start) {
          final segment = metric.extractPath(start, end);
          canvas.drawPath(segment, paint);
        }

        distance += segmentLength;
        patternIndex++;
        draw = !draw;
      }
    }
  }

  static void _drawIndividualSides(
    Canvas canvas,
    Rect rect,
    StrokeConfig config,
  ) {
    final paint = config.toPaint();

    if (config.sides.top) {
      final path = Path()
        ..moveTo(rect.left, rect.top)
        ..lineTo(rect.right, rect.top);
      if (config.isDashed) {
        _drawDashedPath(canvas, path, paint, config.dashPattern!, config.dashOffset);
      } else {
        canvas.drawPath(path, paint);
      }
    }

    if (config.sides.right) {
      final path = Path()
        ..moveTo(rect.right, rect.top)
        ..lineTo(rect.right, rect.bottom);
      if (config.isDashed) {
        _drawDashedPath(canvas, path, paint, config.dashPattern!, config.dashOffset);
      } else {
        canvas.drawPath(path, paint);
      }
    }

    if (config.sides.bottom) {
      final path = Path()
        ..moveTo(rect.right, rect.bottom)
        ..lineTo(rect.left, rect.bottom);
      if (config.isDashed) {
        _drawDashedPath(canvas, path, paint, config.dashPattern!, config.dashOffset);
      } else {
        canvas.drawPath(path, paint);
      }
    }

    if (config.sides.left) {
      final path = Path()
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.top);
      if (config.isDashed) {
        _drawDashedPath(canvas, path, paint, config.dashPattern!, config.dashOffset);
      } else {
        canvas.drawPath(path, paint);
      }
    }
  }
}

/// Stroke options panel widget
class StrokeOptionsPanel extends StatelessWidget {
  final StrokeConfig config;
  final void Function(StrokeConfig)? onConfigChanged;

  const StrokeOptionsPanel({
    super.key,
    required this.config,
    this.onConfigChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Width
          _buildSliderRow('Width', config.width, 0.5, 20, (v) {
            onConfigChanged?.call(config.copyWith(width: v));
          }),
          const SizedBox(height: 12),

          // Cap
          _buildCapSelector(),
          const SizedBox(height: 12),

          // Join
          _buildJoinSelector(),
          const SizedBox(height: 12),

          // Position
          _buildPositionSelector(),
          const SizedBox(height: 12),

          // Dash pattern
          _buildDashSelector(),
          const SizedBox(height: 12),

          // Sides (for rectangles)
          _buildSidesSelector(),
        ],
      ),
    );
  }

  Widget _buildSliderRow(
    String label,
    double value,
    double min,
    double max,
    void Function(double) onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: TextStyle(color: Colors.grey[400], fontSize: 11),
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
            activeColor: Colors.blue,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            value.toStringAsFixed(1),
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _buildCapSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cap', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
        const SizedBox(height: 4),
        Row(
          children: [
            _buildCapOption(StrokeCap.butt, 'Butt'),
            _buildCapOption(StrokeCap.round, 'Round'),
            _buildCapOption(StrokeCap.square, 'Square'),
          ],
        ),
      ],
    );
  }

  Widget _buildCapOption(StrokeCap cap, String label) {
    final isSelected = config.cap == cap;
    return GestureDetector(
      onTap: () => onConfigChanged?.call(config.copyWith(cap: cap)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[800],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[400],
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildJoinSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Join', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
        const SizedBox(height: 4),
        Row(
          children: [
            _buildJoinOption(StrokeJoin.miter, 'Miter'),
            _buildJoinOption(StrokeJoin.round, 'Round'),
            _buildJoinOption(StrokeJoin.bevel, 'Bevel'),
          ],
        ),
      ],
    );
  }

  Widget _buildJoinOption(StrokeJoin join, String label) {
    final isSelected = config.join == join;
    return GestureDetector(
      onTap: () => onConfigChanged?.call(config.copyWith(join: join)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[800],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[400],
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildPositionSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Position', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
        const SizedBox(height: 4),
        Row(
          children: [
            _buildPositionOption(StrokePosition.inside, 'Inside'),
            _buildPositionOption(StrokePosition.center, 'Center'),
            _buildPositionOption(StrokePosition.outside, 'Outside'),
          ],
        ),
      ],
    );
  }

  Widget _buildPositionOption(StrokePosition position, String label) {
    final isSelected = config.position == position;
    return GestureDetector(
      onTap: () => onConfigChanged?.call(config.copyWith(position: position)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[800],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[400],
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildDashSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Dash', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
        const SizedBox(height: 4),
        Row(
          children: [
            _buildDashOption(DashPreset.solid, '—'),
            _buildDashOption(DashPreset.dashed, '- -'),
            _buildDashOption(DashPreset.dotted, '···'),
            _buildDashOption(DashPreset.dashDot, '-·-'),
          ],
        ),
      ],
    );
  }

  Widget _buildDashOption(DashPreset preset, String label) {
    final currentPreset = _getCurrentPreset();
    final isSelected = currentPreset == preset;
    return GestureDetector(
      onTap: () {
        final newConfig = StrokeConfig.fromPreset(
          preset,
          color: config.color,
          width: config.width,
        );
        onConfigChanged?.call(config.copyWith(
          dashPattern: newConfig.dashPattern,
          cap: newConfig.cap,
        ));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[800],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[400],
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  DashPreset _getCurrentPreset() {
    if (config.dashPattern == null) return DashPreset.solid;
    // Simple heuristic for preset detection
    final pattern = config.dashPattern!;
    if (pattern.length == 2) {
      if (pattern[0] <= config.width * 1.5) return DashPreset.dotted;
      return DashPreset.dashed;
    }
    if (pattern.length == 4) return DashPreset.dashDot;
    if (pattern.length == 6) return DashPreset.dashDotDot;
    return DashPreset.custom;
  }

  Widget _buildSidesSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sides', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
        const SizedBox(height: 4),
        Row(
          children: [
            _buildSideToggle('T', config.sides.top, (v) {
              onConfigChanged?.call(config.copyWith(
                sides: config.sides.copyWith(top: v),
              ));
            }),
            _buildSideToggle('R', config.sides.right, (v) {
              onConfigChanged?.call(config.copyWith(
                sides: config.sides.copyWith(right: v),
              ));
            }),
            _buildSideToggle('B', config.sides.bottom, (v) {
              onConfigChanged?.call(config.copyWith(
                sides: config.sides.copyWith(bottom: v),
              ));
            }),
            _buildSideToggle('L', config.sides.left, (v) {
              onConfigChanged?.call(config.copyWith(
                sides: config.sides.copyWith(left: v),
              ));
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildSideToggle(String label, bool enabled, void Function(bool) onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!enabled),
      child: Container(
        width: 28,
        height: 28,
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: enabled ? Colors.blue : Colors.grey[800],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: enabled ? Colors.white : Colors.grey[500],
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
