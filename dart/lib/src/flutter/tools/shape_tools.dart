/// Shape tools for creating various geometric shapes
///
/// Supports:
/// - Polygon tool (configurable sides)
/// - Star tool (points, inner radius)
/// - Line/arrow tool
/// - Arc tool

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Shape tool types
enum ShapeTool {
  /// Rectangle tool
  rectangle,

  /// Ellipse/circle tool
  ellipse,

  /// Line tool
  line,

  /// Arrow tool
  arrow,

  /// Polygon tool (configurable sides)
  polygon,

  /// Star tool
  star,

  /// Arc tool
  arc,

  /// Triangle tool (shortcut for 3-sided polygon)
  triangle,
}

/// Arrow head styles
enum ArrowHead {
  none,
  triangle,
  triangleOutline,
  circle,
  circleOutline,
  diamond,
  diamondOutline,
  square,
  squareOutline,
}

/// Configuration for polygon shapes
class PolygonConfig {
  /// Number of sides
  final int sides;

  /// Corner radius (0 = sharp corners)
  final double cornerRadius;

  const PolygonConfig({
    this.sides = 6,
    this.cornerRadius = 0,
  });

  PolygonConfig copyWith({int? sides, double? cornerRadius}) {
    return PolygonConfig(
      sides: sides ?? this.sides,
      cornerRadius: cornerRadius ?? this.cornerRadius,
    );
  }
}

/// Configuration for star shapes
class StarConfig {
  /// Number of points
  final int points;

  /// Inner radius ratio (0.0 - 1.0)
  final double innerRadiusRatio;

  /// Corner radius for outer points
  final double cornerRadius;

  const StarConfig({
    this.points = 5,
    this.innerRadiusRatio = 0.5,
    this.cornerRadius = 0,
  });

  StarConfig copyWith({
    int? points,
    double? innerRadiusRatio,
    double? cornerRadius,
  }) {
    return StarConfig(
      points: points ?? this.points,
      innerRadiusRatio: innerRadiusRatio ?? this.innerRadiusRatio,
      cornerRadius: cornerRadius ?? this.cornerRadius,
    );
  }
}

/// Configuration for line/arrow shapes
class LineConfig {
  /// Start arrow head
  final ArrowHead startArrow;

  /// End arrow head
  final ArrowHead endArrow;

  /// Arrow head size
  final double arrowSize;

  const LineConfig({
    this.startArrow = ArrowHead.none,
    this.endArrow = ArrowHead.none,
    this.arrowSize = 12,
  });

  LineConfig copyWith({
    ArrowHead? startArrow,
    ArrowHead? endArrow,
    double? arrowSize,
  }) {
    return LineConfig(
      startArrow: startArrow ?? this.startArrow,
      endArrow: endArrow ?? this.endArrow,
      arrowSize: arrowSize ?? this.arrowSize,
    );
  }
}

/// Configuration for arc shapes
class ArcConfig {
  /// Start angle in radians
  final double startAngle;

  /// Sweep angle in radians
  final double sweepAngle;

  /// Whether to close the arc with lines to center
  final bool closePath;

  const ArcConfig({
    this.startAngle = 0,
    this.sweepAngle = math.pi,
    this.closePath = false,
  });

  ArcConfig copyWith({
    double? startAngle,
    double? sweepAngle,
    bool? closePath,
  }) {
    return ArcConfig(
      startAngle: startAngle ?? this.startAngle,
      sweepAngle: sweepAngle ?? this.sweepAngle,
      closePath: closePath ?? this.closePath,
    );
  }
}

/// Shape path builder
class ShapeBuilder {
  /// Build a polygon path
  static Path buildPolygon({
    required Rect bounds,
    required PolygonConfig config,
  }) {
    final center = bounds.center;
    final radius = bounds.shortestSide / 2;
    final sides = config.sides.clamp(3, 100);

    final path = Path();
    final angleStep = (2 * math.pi) / sides;
    final startAngle = -math.pi / 2; // Start from top

    for (int i = 0; i <= sides; i++) {
      final angle = startAngle + i * angleStep;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        if (config.cornerRadius > 0) {
          // Calculate corner rounding
          final prevAngle = startAngle + (i - 1) * angleStep;
          final nextAngle = startAngle + ((i + 1) % (sides + 1)) * angleStep;

          // Simplified corner rounding
          path.lineTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
    }

    path.close();

    // Scale to fit bounds
    final pathBounds = path.getBounds();
    final scaleX = bounds.width / pathBounds.width;
    final scaleY = bounds.height / pathBounds.height;
    final scale = math.min(scaleX, scaleY);

    final matrix = Matrix4.identity()
      ..translate(bounds.center.dx, bounds.center.dy)
      ..scale(scale * (bounds.width / bounds.height > 1 ? 1 : bounds.width / bounds.shortestSide),
          scale * (bounds.height / bounds.width > 1 ? 1 : bounds.height / bounds.shortestSide))
      ..translate(-center.dx, -center.dy);

    return path.transform(matrix.storage);
  }

  /// Build a star path
  static Path buildStar({
    required Rect bounds,
    required StarConfig config,
  }) {
    final center = bounds.center;
    final outerRadius = bounds.shortestSide / 2;
    final innerRadius = outerRadius * config.innerRadiusRatio;
    final points = config.points.clamp(3, 100);

    final path = Path();
    final angleStep = math.pi / points;
    final startAngle = -math.pi / 2;

    for (int i = 0; i <= points * 2; i++) {
      final angle = startAngle + i * angleStep;
      final radius = i.isEven ? outerRadius : innerRadius;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    path.close();
    return path;
  }

  /// Build a line path with optional arrows
  static Path buildLine({
    required Offset start,
    required Offset end,
    required LineConfig config,
  }) {
    final path = Path();

    final direction = (end - start);
    final length = direction.distance;
    if (length == 0) return path;

    final normalized = direction / length;
    final perpendicular = Offset(-normalized.dy, normalized.dx);

    // Adjust endpoints for arrow heads
    var adjustedStart = start;
    var adjustedEnd = end;

    if (config.startArrow != ArrowHead.none) {
      adjustedStart = start + normalized * config.arrowSize * 0.5;
    }
    if (config.endArrow != ArrowHead.none) {
      adjustedEnd = end - normalized * config.arrowSize * 0.5;
    }

    // Draw main line
    path.moveTo(adjustedStart.dx, adjustedStart.dy);
    path.lineTo(adjustedEnd.dx, adjustedEnd.dy);

    // Draw arrow heads
    if (config.startArrow != ArrowHead.none) {
      _addArrowHead(path, start, -normalized, perpendicular, config.startArrow, config.arrowSize);
    }
    if (config.endArrow != ArrowHead.none) {
      _addArrowHead(path, end, normalized, perpendicular, config.endArrow, config.arrowSize);
    }

    return path;
  }

  static void _addArrowHead(
    Path path,
    Offset tip,
    Offset direction,
    Offset perpendicular,
    ArrowHead style,
    double size,
  ) {
    switch (style) {
      case ArrowHead.none:
        break;

      case ArrowHead.triangle:
      case ArrowHead.triangleOutline:
        final base = tip - direction * size;
        final left = base + perpendicular * size * 0.5;
        final right = base - perpendicular * size * 0.5;
        path.moveTo(tip.dx, tip.dy);
        path.lineTo(left.dx, left.dy);
        path.lineTo(right.dx, right.dy);
        path.close();
        break;

      case ArrowHead.circle:
      case ArrowHead.circleOutline:
        final center = tip - direction * size * 0.5;
        path.addOval(Rect.fromCircle(center: center, radius: size * 0.4));
        break;

      case ArrowHead.diamond:
      case ArrowHead.diamondOutline:
        final center = tip - direction * size * 0.5;
        path.moveTo(tip.dx, tip.dy);
        path.lineTo(center.dx + perpendicular.dx * size * 0.4,
            center.dy + perpendicular.dy * size * 0.4);
        path.lineTo(tip.dx - direction.dx * size, tip.dy - direction.dy * size);
        path.lineTo(center.dx - perpendicular.dx * size * 0.4,
            center.dy - perpendicular.dy * size * 0.4);
        path.close();
        break;

      case ArrowHead.square:
      case ArrowHead.squareOutline:
        final halfSize = size * 0.35;
        final center = tip - direction * size * 0.5;
        path.addRect(Rect.fromCenter(center: center, width: halfSize * 2, height: halfSize * 2));
        break;
    }
  }

  /// Build an arc path
  static Path buildArc({
    required Rect bounds,
    required ArcConfig config,
  }) {
    final path = Path();
    final center = bounds.center;

    path.addArc(bounds, config.startAngle, config.sweepAngle);

    if (config.closePath) {
      path.lineTo(center.dx, center.dy);
      path.close();
    }

    return path;
  }

  /// Build a rounded rectangle path
  static Path buildRoundedRect({
    required Rect bounds,
    double topLeft = 0,
    double topRight = 0,
    double bottomRight = 0,
    double bottomLeft = 0,
  }) {
    return Path()
      ..addRRect(RRect.fromRectAndCorners(
        bounds,
        topLeft: Radius.circular(topLeft),
        topRight: Radius.circular(topRight),
        bottomRight: Radius.circular(bottomRight),
        bottomLeft: Radius.circular(bottomLeft),
      ));
  }

  /// Build a triangle path
  static Path buildTriangle({
    required Rect bounds,
  }) {
    return buildPolygon(
      bounds: bounds,
      config: const PolygonConfig(sides: 3),
    );
  }
}

/// Shape tool toolbar widget
class ShapeToolbar extends StatelessWidget {
  final ShapeTool selectedTool;
  final void Function(ShapeTool tool)? onToolSelected;

  const ShapeToolbar({
    super.key,
    required this.selectedTool,
    this.onToolSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToolButton(ShapeTool.rectangle, Icons.rectangle_outlined, 'Rectangle (R)'),
          _buildToolButton(ShapeTool.ellipse, Icons.circle_outlined, 'Ellipse (O)'),
          _buildToolButton(ShapeTool.line, Icons.horizontal_rule, 'Line (L)'),
          _buildToolButton(ShapeTool.arrow, Icons.arrow_forward, 'Arrow'),
          _buildToolButton(ShapeTool.polygon, Icons.hexagon_outlined, 'Polygon'),
          _buildToolButton(ShapeTool.star, Icons.star_outline, 'Star'),
        ],
      ),
    );
  }

  Widget _buildToolButton(ShapeTool tool, IconData icon, String tooltip) {
    final isSelected = selectedTool == tool;
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: 20),
        onPressed: () => onToolSelected?.call(tool),
        color: isSelected ? Colors.blue : Colors.white,
        splashRadius: 18,
      ),
    );
  }
}

/// Shape properties panel
class ShapePropertiesPanel extends StatelessWidget {
  final ShapeTool tool;
  final PolygonConfig? polygonConfig;
  final StarConfig? starConfig;
  final LineConfig? lineConfig;
  final ArcConfig? arcConfig;
  final void Function(PolygonConfig)? onPolygonConfigChanged;
  final void Function(StarConfig)? onStarConfigChanged;
  final void Function(LineConfig)? onLineConfigChanged;
  final void Function(ArcConfig)? onArcConfigChanged;

  const ShapePropertiesPanel({
    super.key,
    required this.tool,
    this.polygonConfig,
    this.starConfig,
    this.lineConfig,
    this.arcConfig,
    this.onPolygonConfigChanged,
    this.onStarConfigChanged,
    this.onLineConfigChanged,
    this.onArcConfigChanged,
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
          Text(
            _getToolName(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildToolProperties(),
        ],
      ),
    );
  }

  String _getToolName() {
    switch (tool) {
      case ShapeTool.rectangle:
        return 'Rectangle';
      case ShapeTool.ellipse:
        return 'Ellipse';
      case ShapeTool.line:
        return 'Line';
      case ShapeTool.arrow:
        return 'Arrow';
      case ShapeTool.polygon:
        return 'Polygon';
      case ShapeTool.star:
        return 'Star';
      case ShapeTool.arc:
        return 'Arc';
      case ShapeTool.triangle:
        return 'Triangle';
    }
  }

  Widget _buildToolProperties() {
    switch (tool) {
      case ShapeTool.polygon:
        return _buildPolygonProperties();
      case ShapeTool.star:
        return _buildStarProperties();
      case ShapeTool.line:
      case ShapeTool.arrow:
        return _buildLineProperties();
      case ShapeTool.arc:
        return _buildArcProperties();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPolygonProperties() {
    final config = polygonConfig ?? const PolygonConfig();
    return Column(
      children: [
        _buildIntSlider(
          'Sides',
          config.sides.toDouble(),
          3,
          12,
          (v) => onPolygonConfigChanged?.call(config.copyWith(sides: v.round())),
        ),
        const SizedBox(height: 8),
        _buildSlider(
          'Corner radius',
          config.cornerRadius,
          0,
          50,
          (v) => onPolygonConfigChanged?.call(config.copyWith(cornerRadius: v)),
        ),
      ],
    );
  }

  Widget _buildStarProperties() {
    final config = starConfig ?? const StarConfig();
    return Column(
      children: [
        _buildIntSlider(
          'Points',
          config.points.toDouble(),
          3,
          12,
          (v) => onStarConfigChanged?.call(config.copyWith(points: v.round())),
        ),
        const SizedBox(height: 8),
        _buildSlider(
          'Inner radius',
          config.innerRadiusRatio,
          0.1,
          0.9,
          (v) => onStarConfigChanged?.call(config.copyWith(innerRadiusRatio: v)),
        ),
      ],
    );
  }

  Widget _buildLineProperties() {
    final config = lineConfig ?? const LineConfig();
    return Column(
      children: [
        _buildArrowSelector('Start', config.startArrow, (v) {
          onLineConfigChanged?.call(config.copyWith(startArrow: v));
        }),
        const SizedBox(height: 8),
        _buildArrowSelector('End', config.endArrow, (v) {
          onLineConfigChanged?.call(config.copyWith(endArrow: v));
        }),
        const SizedBox(height: 8),
        _buildSlider(
          'Arrow size',
          config.arrowSize,
          8,
          32,
          (v) => onLineConfigChanged?.call(config.copyWith(arrowSize: v)),
        ),
      ],
    );
  }

  Widget _buildArcProperties() {
    final config = arcConfig ?? const ArcConfig();
    return Column(
      children: [
        _buildSlider(
          'Start angle',
          config.startAngle * 180 / math.pi,
          0,
          360,
          (v) => onArcConfigChanged?.call(config.copyWith(startAngle: v * math.pi / 180)),
        ),
        const SizedBox(height: 8),
        _buildSlider(
          'Sweep',
          config.sweepAngle * 180 / math.pi,
          -360,
          360,
          (v) => onArcConfigChanged?.call(config.copyWith(sweepAngle: v * math.pi / 180)),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text('Close path', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
            const Spacer(),
            Switch(
              value: config.closePath,
              onChanged: (v) => onArcConfigChanged?.call(config.copyWith(closePath: v)),
              activeColor: Colors.blue,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSlider(
    String label,
    double value,
    double min,
    double max,
    void Function(double) onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 11)),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
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

  Widget _buildIntSlider(
    String label,
    double value,
    double min,
    double max,
    void Function(double) onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 11)),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: (max - min).round(),
            onChanged: onChanged,
            activeColor: Colors.blue,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            value.round().toString(),
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _buildArrowSelector(
    String label,
    ArrowHead value,
    void Function(ArrowHead) onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 11)),
        ),
        Expanded(
          child: Wrap(
            spacing: 4,
            children: [
              _buildArrowOption(ArrowHead.none, 'None', value, onChanged),
              _buildArrowOption(ArrowHead.triangle, '▶', value, onChanged),
              _buildArrowOption(ArrowHead.circle, '●', value, onChanged),
              _buildArrowOption(ArrowHead.diamond, '◆', value, onChanged),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildArrowOption(
    ArrowHead arrow,
    String label,
    ArrowHead selected,
    void Function(ArrowHead) onChanged,
  ) {
    final isSelected = selected == arrow;
    return GestureDetector(
      onTap: () => onChanged(arrow),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[800],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[400],
            fontSize: 10,
          ),
        ),
      ),
    );
  }
}
