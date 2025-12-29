/// Boolean operations for combining vector paths
///
/// Supports:
/// - Union: Combine shapes into one
/// - Subtract: Remove one shape from another
/// - Intersect: Keep only overlapping areas
/// - Exclude: Keep only non-overlapping areas (XOR)
/// - Flatten: Convert to outline paths
/// - Outline Stroke: Convert stroke to fill

import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Types of boolean operations
enum BooleanOperation {
  /// Combine all selected shapes into a single shape
  union,

  /// Subtract the top shapes from the bottom shape
  subtract,

  /// Keep only the overlapping area of shapes
  intersect,

  /// Keep only the non-overlapping areas (XOR)
  exclude,
}

/// Result of a boolean operation
class BooleanResult {
  /// The resulting path after the operation
  final Path resultPath;

  /// The bounding box of the result
  final Rect bounds;

  /// Whether the operation succeeded
  final bool success;

  /// Error message if operation failed
  final String? error;

  /// The operation that was performed
  final BooleanOperation operation;

  const BooleanResult({
    required this.resultPath,
    required this.bounds,
    this.success = true,
    this.error,
    required this.operation,
  });

  /// Create a failed result
  factory BooleanResult.failed(BooleanOperation operation, String error) {
    return BooleanResult(
      resultPath: Path(),
      bounds: Rect.zero,
      success: false,
      error: error,
      operation: operation,
    );
  }
}

/// Engine for performing boolean operations on paths
class BooleanEngine {
  /// Perform a boolean operation on two paths
  static BooleanResult combine(
    Path path1,
    Path path2,
    BooleanOperation operation,
  ) {
    try {
      final ui.PathOperation pathOp = _toPathOperation(operation);
      final resultPath = Path.combine(pathOp, path1, path2);
      final bounds = resultPath.getBounds();

      return BooleanResult(
        resultPath: resultPath,
        bounds: bounds,
        operation: operation,
      );
    } catch (e) {
      return BooleanResult.failed(
        operation,
        'Failed to perform ${operation.name}: $e',
      );
    }
  }

  /// Perform a boolean operation on multiple paths
  /// For union: combines all paths
  /// For subtract: subtracts all paths from the first
  /// For intersect: intersects all paths
  /// For exclude: XORs all paths
  static BooleanResult combineMultiple(
    List<Path> paths,
    BooleanOperation operation,
  ) {
    if (paths.isEmpty) {
      return BooleanResult.failed(operation, 'No paths provided');
    }

    if (paths.length == 1) {
      return BooleanResult(
        resultPath: paths.first,
        bounds: paths.first.getBounds(),
        operation: operation,
      );
    }

    try {
      Path result = paths.first;
      final pathOp = _toPathOperation(operation);

      for (int i = 1; i < paths.length; i++) {
        result = Path.combine(pathOp, result, paths[i]);
      }

      return BooleanResult(
        resultPath: result,
        bounds: result.getBounds(),
        operation: operation,
      );
    } catch (e) {
      return BooleanResult.failed(
        operation,
        'Failed to combine ${paths.length} paths: $e',
      );
    }
  }

  /// Convert BooleanOperation to Flutter's PathOperation
  static ui.PathOperation _toPathOperation(BooleanOperation op) {
    switch (op) {
      case BooleanOperation.union:
        return ui.PathOperation.union;
      case BooleanOperation.subtract:
        return ui.PathOperation.difference;
      case BooleanOperation.intersect:
        return ui.PathOperation.intersect;
      case BooleanOperation.exclude:
        return ui.PathOperation.xor;
    }
  }

  /// Flatten a path (remove all curves, convert to line segments)
  static Path flatten(Path path, {double tolerance = 0.5}) {
    final metrics = path.computeMetrics();
    final flatPath = Path();

    for (final metric in metrics) {
      final length = metric.length;
      final stepCount = (length / tolerance).ceil();
      final step = length / stepCount;

      Offset? firstPoint;
      for (int i = 0; i <= stepCount; i++) {
        final distance = i * step;
        final tangent = metric.getTangentForOffset(distance);
        if (tangent != null) {
          if (firstPoint == null) {
            flatPath.moveTo(tangent.position.dx, tangent.position.dy);
            firstPoint = tangent.position;
          } else {
            flatPath.lineTo(tangent.position.dx, tangent.position.dy);
          }
        }
      }

      if (metric.isClosed) {
        flatPath.close();
      }
    }

    return flatPath;
  }

  /// Convert a stroked path to a filled path (outline stroke)
  static Path outlineStroke(
    Path path, {
    double strokeWidth = 1.0,
    StrokeCap strokeCap = StrokeCap.butt,
    StrokeJoin strokeJoin = StrokeJoin.miter,
    double miterLimit = 4.0,
  }) {
    // Use path.shift to create parallel paths, then combine
    // This is a simplified implementation - production would use proper offsetting
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = strokeCap
      ..strokeJoin = strokeJoin
      ..strokeMiterLimit = miterLimit;

    // Get the stroked path bounds to create outline
    // For proper outline, we'd need to compute offset curves
    // This uses a workaround by extracting metrics
    final metrics = path.computeMetrics();
    final outlinePath = Path();

    final halfWidth = strokeWidth / 2;

    for (final metric in metrics) {
      final length = metric.length;
      if (length == 0) continue;

      final leftPoints = <Offset>[];
      final rightPoints = <Offset>[];

      // Sample points along the path
      const sampleCount = 100;
      for (int i = 0; i <= sampleCount; i++) {
        final t = i / sampleCount;
        final distance = t * length;
        final tangent = metric.getTangentForOffset(distance);

        if (tangent != null) {
          final pos = tangent.position;
          final angle = tangent.angle;

          // Calculate perpendicular offset
          final perpX = -halfWidth * _sin(angle);
          final perpY = halfWidth * _cos(angle);

          leftPoints.add(Offset(pos.dx + perpX, pos.dy + perpY));
          rightPoints.add(Offset(pos.dx - perpX, pos.dy - perpY));
        }
      }

      // Build the outline path
      if (leftPoints.isNotEmpty) {
        // Left side forward
        outlinePath.moveTo(leftPoints.first.dx, leftPoints.first.dy);
        for (int i = 1; i < leftPoints.length; i++) {
          outlinePath.lineTo(leftPoints[i].dx, leftPoints[i].dy);
        }

        // Add end cap
        if (!metric.isClosed) {
          _addEndCap(outlinePath, leftPoints.last, rightPoints.last, strokeCap);
        }

        // Right side backward
        for (int i = rightPoints.length - 1; i >= 0; i--) {
          outlinePath.lineTo(rightPoints[i].dx, rightPoints[i].dy);
        }

        // Add start cap
        if (!metric.isClosed) {
          _addEndCap(
              outlinePath, rightPoints.first, leftPoints.first, strokeCap);
        }

        outlinePath.close();
      }
    }

    return outlinePath;
  }

  static double _sin(double radians) => _sinTable[(radians * 1000).toInt() % 6283] ?? 0;
  static double _cos(double radians) => _cosTable[(radians * 1000).toInt() % 6283] ?? 1;

  // Precomputed sin/cos for performance (lazy initialization)
  static final Map<int, double> _sinTable = {};
  static final Map<int, double> _cosTable = {};

  static void _initTrigTables() {
    if (_sinTable.isEmpty) {
      for (int i = 0; i < 6283; i++) {
        final angle = i / 1000.0;
        _sinTable[i] = _dartSin(angle);
        _cosTable[i] = _dartCos(angle);
      }
    }
  }

  static double _dartSin(double x) {
    // Taylor series approximation
    x = x % (2 * 3.14159265359);
    if (x > 3.14159265359) x -= 2 * 3.14159265359;
    double result = x;
    double term = x;
    for (int i = 1; i < 10; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }

  static double _dartCos(double x) {
    return _dartSin(x + 3.14159265359 / 2);
  }

  static void _addEndCap(Path path, Offset p1, Offset p2, StrokeCap cap) {
    switch (cap) {
      case StrokeCap.butt:
        path.lineTo(p2.dx, p2.dy);
        break;
      case StrokeCap.round:
        // Add semicircle
        final center = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
        final radius = (p1 - p2).distance / 2;
        path.arcToPoint(p2, radius: Radius.circular(radius));
        break;
      case StrokeCap.square:
        // Extend by half stroke width
        final dir = (p2 - p1).direction;
        final ext = Offset.fromDirection(dir + 3.14159265359 / 2, (p2 - p1).distance / 2);
        path.lineTo(p1.dx + ext.dx, p1.dy + ext.dy);
        path.lineTo(p2.dx + ext.dx, p2.dy + ext.dy);
        path.lineTo(p2.dx, p2.dy);
        break;
    }
  }

  /// Create a path from node bounds (for shapes that don't have explicit paths)
  static Path pathFromRect(Rect rect, {List<double>? cornerRadii}) {
    if (cornerRadii != null && cornerRadii.length == 4) {
      return Path()
        ..addRRect(RRect.fromRectAndCorners(
          rect,
          topLeft: Radius.circular(cornerRadii[0]),
          topRight: Radius.circular(cornerRadii[1]),
          bottomRight: Radius.circular(cornerRadii[2]),
          bottomLeft: Radius.circular(cornerRadii[3]),
        ));
    }
    return Path()..addRect(rect);
  }

  /// Create a path from an ellipse
  static Path pathFromEllipse(Rect bounds) {
    return Path()..addOval(bounds);
  }

  /// Create a path from a polygon
  static Path pathFromPolygon(Offset center, double radius, int sides) {
    if (sides < 3) sides = 3;

    final path = Path();
    final angleStep = (2 * 3.14159265359) / sides;
    final startAngle = -3.14159265359 / 2; // Start from top

    for (int i = 0; i <= sides; i++) {
      final angle = startAngle + i * angleStep;
      final x = center.dx + radius * _dartCos(angle);
      final y = center.dy + radius * _dartSin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    path.close();
    return path;
  }

  /// Create a star path
  static Path pathFromStar(
    Offset center,
    double outerRadius,
    double innerRadius,
    int points,
  ) {
    if (points < 3) points = 3;

    final path = Path();
    final angleStep = 3.14159265359 / points;
    final startAngle = -3.14159265359 / 2;

    for (int i = 0; i <= points * 2; i++) {
      final angle = startAngle + i * angleStep;
      final radius = i.isEven ? outerRadius : innerRadius;
      final x = center.dx + radius * _dartCos(angle);
      final y = center.dy + radius * _dartSin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    path.close();
    return path;
  }
}

/// Widget for displaying boolean operation buttons
class BooleanOperationsToolbar extends StatelessWidget {
  /// Callback when an operation is selected
  final void Function(BooleanOperation operation)? onOperationSelected;

  /// Whether operations are enabled (need 2+ shapes selected)
  final bool enabled;

  /// Currently selected shapes count
  final int selectedCount;

  const BooleanOperationsToolbar({
    super.key,
    this.onOperationSelected,
    this.enabled = true,
    this.selectedCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = enabled && selectedCount >= 2;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildButton(
            icon: Icons.add_box_outlined,
            tooltip: 'Union (Ctrl+Alt+U)',
            operation: BooleanOperation.union,
            enabled: isEnabled,
          ),
          _buildButton(
            icon: Icons.indeterminate_check_box_outlined,
            tooltip: 'Subtract (Ctrl+Alt+S)',
            operation: BooleanOperation.subtract,
            enabled: isEnabled,
          ),
          _buildButton(
            icon: Icons.filter_none,
            tooltip: 'Intersect (Ctrl+Alt+I)',
            operation: BooleanOperation.intersect,
            enabled: isEnabled,
          ),
          _buildButton(
            icon: Icons.flip_to_front,
            tooltip: 'Exclude (Ctrl+Alt+X)',
            operation: BooleanOperation.exclude,
            enabled: isEnabled,
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required IconData icon,
    required String tooltip,
    required BooleanOperation operation,
    required bool enabled,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: 20),
        onPressed: enabled ? () => onOperationSelected?.call(operation) : null,
        color: enabled ? Colors.white : Colors.grey[600],
        splashRadius: 18,
      ),
    );
  }
}

/// Panel for boolean operations with preview
class BooleanOperationsPanel extends StatefulWidget {
  /// Paths to operate on
  final List<Path> paths;

  /// Callback when operation is applied
  final void Function(BooleanResult result)? onApply;

  /// Callback to cancel
  final VoidCallback? onCancel;

  const BooleanOperationsPanel({
    super.key,
    required this.paths,
    this.onApply,
    this.onCancel,
  });

  @override
  State<BooleanOperationsPanel> createState() => _BooleanOperationsPanelState();
}

class _BooleanOperationsPanelState extends State<BooleanOperationsPanel> {
  BooleanOperation _selectedOperation = BooleanOperation.union;
  BooleanResult? _preview;

  @override
  void initState() {
    super.initState();
    _updatePreview();
  }

  void _updatePreview() {
    if (widget.paths.length >= 2) {
      _preview = BooleanEngine.combineMultiple(widget.paths, _selectedOperation);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.auto_fix_high, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Boolean Operations',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: widget.onCancel,
                color: Colors.grey[400],
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Operation selector
          _buildOperationOption(BooleanOperation.union, 'Union', Icons.add_box),
          _buildOperationOption(
              BooleanOperation.subtract, 'Subtract', Icons.indeterminate_check_box),
          _buildOperationOption(
              BooleanOperation.intersect, 'Intersect', Icons.filter_none),
          _buildOperationOption(
              BooleanOperation.exclude, 'Exclude', Icons.flip_to_front),

          const SizedBox(height: 16),

          // Preview
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[700]!),
            ),
            child: Center(
              child: _preview != null && _preview!.success
                  ? CustomPaint(
                      size: const Size(100, 100),
                      painter: _PreviewPainter(_preview!.resultPath),
                    )
                  : Text(
                      _preview?.error ?? 'Select shapes to preview',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
            ),
          ),

          const SizedBox(height: 16),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[400],
                    side: BorderSide(color: Colors.grey[600]!),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _preview?.success == true
                      ? () => widget.onApply?.call(_preview!)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOperationOption(
    BooleanOperation operation,
    String label,
    IconData icon,
  ) {
    final isSelected = _selectedOperation == operation;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedOperation = operation;
          _updatePreview();
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.blue : Colors.grey[400],
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[400],
                fontSize: 13,
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check, size: 16, color: Colors.blue),
          ],
        ),
      ),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  final Path path;

  _PreviewPainter(this.path);

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = path.getBounds();
    if (bounds.isEmpty) return;

    // Scale path to fit preview area
    final scale = (size.shortestSide - 20) /
        (bounds.width > bounds.height ? bounds.width : bounds.height);

    canvas.save();
    canvas.translate(
      (size.width - bounds.width * scale) / 2 - bounds.left * scale,
      (size.height - bounds.height * scale) / 2 - bounds.top * scale,
    );
    canvas.scale(scale);

    // Draw fill
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.blue.withOpacity(0.3)
        ..style = PaintingStyle.fill,
    );

    // Draw stroke
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 / scale,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PreviewPainter oldDelegate) {
    return path != oldDelegate.path;
  }
}

/// Command for executing boolean operations (for undo/redo)
class BooleanOperationCommand {
  final String id;
  final BooleanOperation operation;
  final List<String> sourceNodeIds;
  final String resultNodeId;
  final BooleanResult result;

  const BooleanOperationCommand({
    required this.id,
    required this.operation,
    required this.sourceNodeIds,
    required this.resultNodeId,
    required this.result,
  });

  String get description {
    switch (operation) {
      case BooleanOperation.union:
        return 'Union ${sourceNodeIds.length} shapes';
      case BooleanOperation.subtract:
        return 'Subtract shapes';
      case BooleanOperation.intersect:
        return 'Intersect ${sourceNodeIds.length} shapes';
      case BooleanOperation.exclude:
        return 'Exclude ${sourceNodeIds.length} shapes';
    }
  }
}
