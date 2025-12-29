/// Vector path editor for direct manipulation of paths
///
/// Supports:
/// - Vertex selection and editing
/// - Bezier handle manipulation
/// - Path point insertion/deletion
/// - Curve type conversion (corner/smooth/symmetric)

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Type of path point
enum PointType {
  /// Corner point with independent handles
  corner,

  /// Smooth point with aligned but different length handles
  smooth,

  /// Symmetric point with aligned and equal length handles
  symmetric,

  /// No handles (straight line)
  straight,
}

/// A point on a vector path
class PathPoint {
  /// Position of the point
  Offset position;

  /// Incoming bezier handle (relative to position)
  Offset? handleIn;

  /// Outgoing bezier handle (relative to position)
  Offset? handleOut;

  /// Point type
  PointType type;

  /// Whether this point is selected
  bool isSelected;

  PathPoint({
    required this.position,
    this.handleIn,
    this.handleOut,
    this.type = PointType.corner,
    this.isSelected = false,
  });

  /// Get absolute position of incoming handle
  Offset? get absoluteHandleIn =>
      handleIn != null ? position + handleIn! : null;

  /// Get absolute position of outgoing handle
  Offset? get absoluteHandleOut =>
      handleOut != null ? position + handleOut! : null;

  /// Set incoming handle from absolute position
  set absoluteHandleIn(Offset? value) {
    handleIn = value != null ? value - position : null;
  }

  /// Set outgoing handle from absolute position
  set absoluteHandleOut(Offset? value) {
    handleOut = value != null ? value - position : null;
  }

  /// Move the point by delta
  void move(Offset delta) {
    position += delta;
  }

  /// Update handle and maintain type constraints
  void updateHandle(bool isIncoming, Offset absolutePosition) {
    final relative = absolutePosition - position;

    if (isIncoming) {
      handleIn = relative;
      if (type == PointType.smooth && handleOut != null) {
        // Align outgoing handle opposite, keeping its length
        final outLength = handleOut!.distance;
        handleOut = Offset.fromDirection(relative.direction + math.pi, outLength);
      } else if (type == PointType.symmetric && handleOut != null) {
        // Mirror the handle
        handleOut = Offset.fromDirection(relative.direction + math.pi, relative.distance);
      }
    } else {
      handleOut = relative;
      if (type == PointType.smooth && handleIn != null) {
        // Align incoming handle opposite, keeping its length
        final inLength = handleIn!.distance;
        handleIn = Offset.fromDirection(relative.direction + math.pi, inLength);
      } else if (type == PointType.symmetric && handleIn != null) {
        // Mirror the handle
        handleIn = Offset.fromDirection(relative.direction + math.pi, relative.distance);
      }
    }
  }

  /// Convert to a different point type
  void convertTo(PointType newType) {
    type = newType;

    switch (newType) {
      case PointType.straight:
        handleIn = null;
        handleOut = null;
        break;
      case PointType.corner:
        // Keep handles as-is
        break;
      case PointType.smooth:
        // Align handles if both exist
        if (handleIn != null && handleOut != null) {
          final avgDirection = (handleIn!.direction - handleOut!.direction) / 2 + handleOut!.direction;
          handleIn = Offset.fromDirection(avgDirection + math.pi, handleIn!.distance);
          handleOut = Offset.fromDirection(avgDirection, handleOut!.distance);
        }
        break;
      case PointType.symmetric:
        // Make handles equal length and opposite
        if (handleIn != null || handleOut != null) {
          final handle = handleOut ?? Offset(-handleIn!.dx, -handleIn!.dy);
          final length = handle.distance;
          handleOut = Offset.fromDirection(handle.direction, length);
          handleIn = Offset.fromDirection(handle.direction + math.pi, length);
        }
        break;
    }
  }

  PathPoint copy() {
    return PathPoint(
      position: position,
      handleIn: handleIn,
      handleOut: handleOut,
      type: type,
      isSelected: isSelected,
    );
  }
}

/// A complete vector path
class VectorPath {
  /// Points on the path
  List<PathPoint> points;

  /// Whether the path is closed
  bool isClosed;

  VectorPath({
    required this.points,
    this.isClosed = false,
  });

  /// Get selected points
  List<PathPoint> get selectedPoints =>
      points.where((p) => p.isSelected).toList();

  /// Select all points
  void selectAll() {
    for (final point in points) {
      point.isSelected = true;
    }
  }

  /// Deselect all points
  void deselectAll() {
    for (final point in points) {
      point.isSelected = false;
    }
  }

  /// Insert a point at parameter t between index and index+1
  void insertPoint(int index, double t) {
    if (index < 0 || index >= points.length - 1) return;

    final p0 = points[index];
    final p1 = points[index + 1];

    // Calculate position on bezier curve at t
    final newPosition = _bezierPoint(
      p0.position,
      p0.absoluteHandleOut ?? p0.position,
      p1.absoluteHandleIn ?? p1.position,
      p1.position,
      t,
    );

    // Split bezier handles
    final newPoint = PathPoint(
      position: newPosition,
      type: PointType.smooth,
    );

    // Calculate new handles using de Casteljau's algorithm
    final h1 = _lerp(p0.position, p0.absoluteHandleOut ?? p0.position, t);
    final h2 = _lerp(p0.absoluteHandleOut ?? p0.position, p1.absoluteHandleIn ?? p1.position, t);
    final h3 = _lerp(p1.absoluteHandleIn ?? p1.position, p1.position, t);

    final h12 = _lerp(h1, h2, t);
    final h23 = _lerp(h2, h3, t);

    p0.absoluteHandleOut = h1;
    newPoint.handleIn = h12 - newPosition;
    newPoint.handleOut = h23 - newPosition;
    p1.absoluteHandleIn = h3;

    points.insert(index + 1, newPoint);
  }

  /// Delete selected points
  void deleteSelectedPoints() {
    points.removeWhere((p) => p.isSelected);
  }

  /// Move selected points by delta
  void moveSelectedPoints(Offset delta) {
    for (final point in points) {
      if (point.isSelected) {
        point.move(delta);
      }
    }
  }

  /// Convert to Flutter Path
  Path toPath() {
    if (points.isEmpty) return Path();

    final path = Path();
    path.moveTo(points.first.position.dx, points.first.position.dy);

    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];

      if (prev.handleOut != null || curr.handleIn != null) {
        // Cubic bezier
        final cp1 = prev.absoluteHandleOut ?? prev.position;
        final cp2 = curr.absoluteHandleIn ?? curr.position;
        path.cubicTo(
          cp1.dx, cp1.dy,
          cp2.dx, cp2.dy,
          curr.position.dx, curr.position.dy,
        );
      } else {
        // Straight line
        path.lineTo(curr.position.dx, curr.position.dy);
      }
    }

    if (isClosed && points.length > 1) {
      final last = points.last;
      final first = points.first;

      if (last.handleOut != null || first.handleIn != null) {
        final cp1 = last.absoluteHandleOut ?? last.position;
        final cp2 = first.absoluteHandleIn ?? first.position;
        path.cubicTo(
          cp1.dx, cp1.dy,
          cp2.dx, cp2.dy,
          first.position.dx, first.position.dy,
        );
      }
      path.close();
    }

    return path;
  }

  /// Parse from SVG path data
  static VectorPath fromSvgPath(String pathData) {
    final points = <PathPoint>[];
    // Simplified SVG path parsing - handle M, L, C, Q, Z commands
    // This is a basic implementation; a full parser would be more complex

    final commands = RegExp(r'([MLCQZ])\s*([-\d.,\s]*)').allMatches(pathData.toUpperCase());
    Offset current = Offset.zero;
    bool closed = false;

    for (final match in commands) {
      final cmd = match.group(1)!;
      final argsStr = match.group(2) ?? '';
      final args = argsStr.split(RegExp(r'[\s,]+')).where((s) => s.isNotEmpty).map(double.parse).toList();

      switch (cmd) {
        case 'M':
          if (args.length >= 2) {
            current = Offset(args[0], args[1]);
            points.add(PathPoint(position: current));
          }
          break;
        case 'L':
          if (args.length >= 2) {
            current = Offset(args[0], args[1]);
            points.add(PathPoint(position: current, type: PointType.straight));
          }
          break;
        case 'C':
          if (args.length >= 6) {
            final cp1 = Offset(args[0], args[1]);
            final cp2 = Offset(args[2], args[3]);
            final end = Offset(args[4], args[5]);

            if (points.isNotEmpty) {
              points.last.absoluteHandleOut = cp1;
            }
            points.add(PathPoint(
              position: end,
              handleIn: cp2 - end,
            ));
            current = end;
          }
          break;
        case 'Q':
          if (args.length >= 4) {
            final cp = Offset(args[0], args[1]);
            final end = Offset(args[2], args[3]);

            // Convert quadratic to cubic
            if (points.isNotEmpty) {
              final start = points.last.position;
              points.last.absoluteHandleOut = start + (cp - start) * (2 / 3);
              points.add(PathPoint(
                position: end,
                handleIn: (cp - end) * (2 / 3),
              ));
            }
            current = end;
          }
          break;
        case 'Z':
          closed = true;
          break;
      }
    }

    return VectorPath(points: points, isClosed: closed);
  }

  VectorPath copy() {
    return VectorPath(
      points: points.map((p) => p.copy()).toList(),
      isClosed: isClosed,
    );
  }
}

// Helper functions
Offset _lerp(Offset a, Offset b, double t) {
  return Offset(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t);
}

Offset _bezierPoint(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
  final t2 = t * t;
  final t3 = t2 * t;
  final mt = 1 - t;
  final mt2 = mt * mt;
  final mt3 = mt2 * mt;

  return Offset(
    mt3 * p0.dx + 3 * mt2 * t * p1.dx + 3 * mt * t2 * p2.dx + t3 * p3.dx,
    mt3 * p0.dy + 3 * mt2 * t * p1.dy + 3 * mt * t2 * p2.dy + t3 * p3.dy,
  );
}

/// Widget for editing vector paths
class VectorEditorWidget extends StatefulWidget {
  /// The path being edited
  final VectorPath path;

  /// Zoom level
  final double zoom;

  /// Called when path changes
  final void Function(VectorPath path)? onPathChanged;

  /// Colors
  final Color pathColor;
  final Color handleColor;
  final Color selectedColor;

  const VectorEditorWidget({
    super.key,
    required this.path,
    this.zoom = 1.0,
    this.onPathChanged,
    this.pathColor = const Color(0xFF0D99FF),
    this.handleColor = const Color(0xFFFF6B6B),
    this.selectedColor = const Color(0xFF0D99FF),
  });

  @override
  State<VectorEditorWidget> createState() => _VectorEditorWidgetState();
}

class _VectorEditorWidgetState extends State<VectorEditorWidget> {
  int? _draggingPointIndex;
  bool _draggingHandleIn = false;
  bool _draggingHandleOut = false;

  double get _pointSize => 8.0 / widget.zoom;
  double get _handleSize => 6.0 / widget.zoom;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapUp: _onTap,
      child: CustomPaint(
        painter: _VectorPathPainter(
          path: widget.path,
          zoom: widget.zoom,
          pathColor: widget.pathColor,
          handleColor: widget.handleColor,
          selectedColor: widget.selectedColor,
        ),
        child: Stack(
          children: [
            // Point handles
            for (int i = 0; i < widget.path.points.length; i++) ...[
              _buildPointHandle(i),
              if (widget.path.points[i].isSelected) ...[
                if (widget.path.points[i].absoluteHandleIn != null)
                  _buildBezierHandle(i, true),
                if (widget.path.points[i].absoluteHandleOut != null)
                  _buildBezierHandle(i, false),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPointHandle(int index) {
    final point = widget.path.points[index];

    return Positioned(
      left: point.position.dx - _pointSize / 2,
      top: point.position.dy - _pointSize / 2,
      child: GestureDetector(
        onPanStart: (_) => _startDraggingPoint(index),
        onPanUpdate: (details) => _updatePoint(details.delta),
        onPanEnd: (_) => _stopDragging(),
        onTap: () => _selectPoint(index),
        child: MouseRegion(
          cursor: SystemMouseCursors.move,
          child: Container(
            width: _pointSize,
            height: _pointSize,
            decoration: BoxDecoration(
              color: point.isSelected ? widget.selectedColor : Colors.white,
              border: Border.all(
                color: widget.pathColor,
                width: 1.5 / widget.zoom,
              ),
              shape: point.type == PointType.smooth || point.type == PointType.symmetric
                  ? BoxShape.circle
                  : BoxShape.rectangle,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBezierHandle(int index, bool isIncoming) {
    final point = widget.path.points[index];
    final handlePos = isIncoming ? point.absoluteHandleIn! : point.absoluteHandleOut!;

    return Positioned(
      left: handlePos.dx - _handleSize / 2,
      top: handlePos.dy - _handleSize / 2,
      child: GestureDetector(
        onPanStart: (_) => _startDraggingHandle(index, isIncoming),
        onPanUpdate: (details) => _updateHandle(details.delta),
        onPanEnd: (_) => _stopDragging(),
        child: MouseRegion(
          cursor: SystemMouseCursors.move,
          child: Container(
            width: _handleSize,
            height: _handleSize,
            decoration: BoxDecoration(
              color: widget.handleColor,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  void _onTap(TapUpDetails details) {
    // Deselect all if tapping on empty space
    setState(() {
      widget.path.deselectAll();
    });
    widget.onPathChanged?.call(widget.path);
  }

  void _selectPoint(int index) {
    setState(() {
      if (!HardwareKeyboard.instance.isShiftPressed) {
        widget.path.deselectAll();
      }
      widget.path.points[index].isSelected = !widget.path.points[index].isSelected;
    });
    widget.onPathChanged?.call(widget.path);
  }

  void _startDraggingPoint(int index) {
    _draggingPointIndex = index;
    if (!widget.path.points[index].isSelected) {
      widget.path.deselectAll();
      widget.path.points[index].isSelected = true;
    }
  }

  void _startDraggingHandle(int index, bool isIncoming) {
    _draggingPointIndex = index;
    _draggingHandleIn = isIncoming;
    _draggingHandleOut = !isIncoming;
  }

  void _updatePoint(Offset delta) {
    if (_draggingPointIndex == null) return;

    setState(() {
      widget.path.moveSelectedPoints(delta);
    });
    widget.onPathChanged?.call(widget.path);
  }

  void _updateHandle(Offset delta) {
    if (_draggingPointIndex == null) return;

    setState(() {
      final point = widget.path.points[_draggingPointIndex!];
      if (_draggingHandleIn && point.absoluteHandleIn != null) {
        point.updateHandle(true, point.absoluteHandleIn! + delta);
      } else if (_draggingHandleOut && point.absoluteHandleOut != null) {
        point.updateHandle(false, point.absoluteHandleOut! + delta);
      }
    });
    widget.onPathChanged?.call(widget.path);
  }

  void _stopDragging() {
    _draggingPointIndex = null;
    _draggingHandleIn = false;
    _draggingHandleOut = false;
  }
}

/// Custom painter for vector paths
class _VectorPathPainter extends CustomPainter {
  final VectorPath path;
  final double zoom;
  final Color pathColor;
  final Color handleColor;
  final Color selectedColor;

  _VectorPathPainter({
    required this.path,
    required this.zoom,
    required this.pathColor,
    required this.handleColor,
    required this.selectedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final pathPaint = Paint()
      ..color = pathColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 / zoom;

    // Draw the path
    canvas.drawPath(path.toPath(), pathPaint);

    // Draw handle lines for selected points
    final handleLinePaint = Paint()
      ..color = handleColor.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 / zoom;

    for (final point in path.points) {
      if (point.isSelected) {
        if (point.absoluteHandleIn != null) {
          canvas.drawLine(point.position, point.absoluteHandleIn!, handleLinePaint);
        }
        if (point.absoluteHandleOut != null) {
          canvas.drawLine(point.position, point.absoluteHandleOut!, handleLinePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_VectorPathPainter oldDelegate) {
    return path != oldDelegate.path ||
        zoom != oldDelegate.zoom ||
        pathColor != oldDelegate.pathColor;
  }
}
