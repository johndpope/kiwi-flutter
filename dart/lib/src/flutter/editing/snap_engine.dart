/// Snap engine for alignment guides and snapping
///
/// Supports:
/// - Grid snapping
/// - Object edge/center snapping
/// - Smart guides (alignment lines)
/// - Snap threshold based on zoom level

import 'dart:ui';

/// Snap result containing adjusted position and guide lines
class SnapResult {
  /// The snapped position (adjusted from original)
  final Offset position;

  /// Horizontal guide lines to display
  final List<SnapGuide> horizontalGuides;

  /// Vertical guide lines to display
  final List<SnapGuide> verticalGuides;

  /// Whether any snapping occurred
  bool get snapped => horizontalGuides.isNotEmpty || verticalGuides.isNotEmpty;

  const SnapResult({
    required this.position,
    this.horizontalGuides = const [],
    this.verticalGuides = const [],
  });

  /// No snapping result
  static SnapResult none(Offset position) => SnapResult(position: position);
}

/// A single snap guide line
class SnapGuide {
  /// Start point of the guide
  final Offset start;

  /// End point of the guide
  final Offset end;

  /// The snap value (position that was snapped to)
  final double value;

  /// Type of snap (edge, center, grid)
  final SnapType type;

  const SnapGuide({
    required this.start,
    required this.end,
    required this.value,
    required this.type,
  });
}

/// Types of snapping
enum SnapType {
  /// Snapped to grid line
  grid,

  /// Snapped to object edge (left, right, top, bottom)
  edge,

  /// Snapped to object center
  center,

  /// Snapped to parent bounds
  parent,

  /// Snapped to artboard/frame edge
  artboard,
}

/// Snap engine configuration
class SnapConfig {
  /// Enable grid snapping
  final bool snapToGrid;

  /// Enable object snapping
  final bool snapToObjects;

  /// Enable parent bounds snapping
  final bool snapToParent;

  /// Grid size in pixels
  final double gridSize;

  /// Snap threshold in screen pixels (before zoom)
  final double threshold;

  /// Whether to snap to object centers
  final bool snapToCenters;

  /// Whether to snap to object edges
  final bool snapToEdges;

  const SnapConfig({
    this.snapToGrid = true,
    this.snapToObjects = true,
    this.snapToParent = true,
    this.gridSize = 8.0,
    this.threshold = 8.0,
    this.snapToCenters = true,
    this.snapToEdges = true,
  });

  SnapConfig copyWith({
    bool? snapToGrid,
    bool? snapToObjects,
    bool? snapToParent,
    double? gridSize,
    double? threshold,
    bool? snapToCenters,
    bool? snapToEdges,
  }) {
    return SnapConfig(
      snapToGrid: snapToGrid ?? this.snapToGrid,
      snapToObjects: snapToObjects ?? this.snapToObjects,
      snapToParent: snapToParent ?? this.snapToParent,
      gridSize: gridSize ?? this.gridSize,
      threshold: threshold ?? this.threshold,
      snapToCenters: snapToCenters ?? this.snapToCenters,
      snapToEdges: snapToEdges ?? this.snapToEdges,
    );
  }
}

/// Snap engine for calculating snapping positions
class SnapEngine {
  /// Current configuration
  SnapConfig config;

  /// Current zoom level (affects threshold)
  double zoom;

  /// Bounds of other objects to snap to
  List<Rect> objectBounds;

  /// Parent bounds (frame/artboard)
  Rect? parentBounds;

  /// Canvas/viewport bounds
  Rect? viewportBounds;

  SnapEngine({
    this.config = const SnapConfig(),
    this.zoom = 1.0,
    this.objectBounds = const [],
    this.parentBounds,
    this.viewportBounds,
  });

  /// Get the effective snap threshold based on zoom
  double get effectiveThreshold => config.threshold / zoom;

  /// Snap a point to the nearest snap target
  SnapResult snapPoint(Offset point) {
    double x = point.dx;
    double y = point.dy;
    final horizontalGuides = <SnapGuide>[];
    final verticalGuides = <SnapGuide>[];

    // Grid snapping
    if (config.snapToGrid) {
      final gridSnapX = _snapToGrid(x);
      final gridSnapY = _snapToGrid(y);

      if (gridSnapX != null) {
        x = gridSnapX;
      }
      if (gridSnapY != null) {
        y = gridSnapY;
      }
    }

    // Object snapping (has priority over grid)
    if (config.snapToObjects && objectBounds.isNotEmpty) {
      final objectSnapResult = _snapToObjects(Offset(x, y));
      if (objectSnapResult.horizontalGuides.isNotEmpty) {
        y = objectSnapResult.position.dy;
        horizontalGuides.addAll(objectSnapResult.horizontalGuides);
      }
      if (objectSnapResult.verticalGuides.isNotEmpty) {
        x = objectSnapResult.position.dx;
        verticalGuides.addAll(objectSnapResult.verticalGuides);
      }
    }

    // Parent bounds snapping
    if (config.snapToParent && parentBounds != null) {
      final parentSnapResult = _snapToParent(Offset(x, y));
      if (parentSnapResult.horizontalGuides.isNotEmpty) {
        y = parentSnapResult.position.dy;
        horizontalGuides.addAll(parentSnapResult.horizontalGuides);
      }
      if (parentSnapResult.verticalGuides.isNotEmpty) {
        x = parentSnapResult.position.dx;
        verticalGuides.addAll(parentSnapResult.verticalGuides);
      }
    }

    return SnapResult(
      position: Offset(x, y),
      horizontalGuides: horizontalGuides,
      verticalGuides: verticalGuides,
    );
  }

  /// Snap a rect (for moving/resizing)
  SnapResult snapRect(Rect rect, {bool snapCenter = true}) {
    double dx = 0;
    double dy = 0;
    final horizontalGuides = <SnapGuide>[];
    final verticalGuides = <SnapGuide>[];

    // Collect all x and y values to check
    final xValues = <double>[rect.left, rect.right];
    final yValues = <double>[rect.top, rect.bottom];

    if (snapCenter) {
      xValues.add(rect.center.dx);
      yValues.add(rect.center.dy);
    }

    // Grid snapping for edges and center
    if (config.snapToGrid) {
      for (final x in xValues) {
        final snapped = _snapToGrid(x);
        if (snapped != null && dx == 0) {
          dx = snapped - x;
        }
      }
      for (final y in yValues) {
        final snapped = _snapToGrid(y);
        if (snapped != null && dy == 0) {
          dy = snapped - y;
        }
      }
    }

    // Object snapping
    if (config.snapToObjects && objectBounds.isNotEmpty) {
      final objResult = _snapRectToObjects(rect);
      if (objResult.dx != 0) {
        dx = objResult.dx;
        verticalGuides.addAll(objResult.verticalGuides);
      }
      if (objResult.dy != 0) {
        dy = objResult.dy;
        horizontalGuides.addAll(objResult.horizontalGuides);
      }
    }

    // Parent snapping
    if (config.snapToParent && parentBounds != null) {
      final parentResult = _snapRectToParent(rect);
      if (parentResult.dx != 0 && dx == 0) {
        dx = parentResult.dx;
        verticalGuides.addAll(parentResult.verticalGuides);
      }
      if (parentResult.dy != 0 && dy == 0) {
        dy = parentResult.dy;
        horizontalGuides.addAll(parentResult.horizontalGuides);
      }
    }

    return SnapResult(
      position: Offset(rect.left + dx, rect.top + dy),
      horizontalGuides: horizontalGuides,
      verticalGuides: verticalGuides,
    );
  }

  /// Snap to grid
  double? _snapToGrid(double value) {
    final gridValue = (value / config.gridSize).round() * config.gridSize;
    if ((gridValue - value).abs() <= effectiveThreshold) {
      return gridValue;
    }
    return null;
  }

  /// Snap point to objects
  SnapResult _snapToObjects(Offset point) {
    double? snappedX;
    double? snappedY;
    final horizontalGuides = <SnapGuide>[];
    final verticalGuides = <SnapGuide>[];

    for (final bounds in objectBounds) {
      // Check edges
      if (config.snapToEdges) {
        // Left edge
        if ((bounds.left - point.dx).abs() <= effectiveThreshold) {
          snappedX = bounds.left;
          verticalGuides.add(SnapGuide(
            start: Offset(bounds.left, bounds.top - 20),
            end: Offset(bounds.left, bounds.bottom + 20),
            value: bounds.left,
            type: SnapType.edge,
          ));
        }
        // Right edge
        if ((bounds.right - point.dx).abs() <= effectiveThreshold) {
          snappedX = bounds.right;
          verticalGuides.add(SnapGuide(
            start: Offset(bounds.right, bounds.top - 20),
            end: Offset(bounds.right, bounds.bottom + 20),
            value: bounds.right,
            type: SnapType.edge,
          ));
        }
        // Top edge
        if ((bounds.top - point.dy).abs() <= effectiveThreshold) {
          snappedY = bounds.top;
          horizontalGuides.add(SnapGuide(
            start: Offset(bounds.left - 20, bounds.top),
            end: Offset(bounds.right + 20, bounds.top),
            value: bounds.top,
            type: SnapType.edge,
          ));
        }
        // Bottom edge
        if ((bounds.bottom - point.dy).abs() <= effectiveThreshold) {
          snappedY = bounds.bottom;
          horizontalGuides.add(SnapGuide(
            start: Offset(bounds.left - 20, bounds.bottom),
            end: Offset(bounds.right + 20, bounds.bottom),
            value: bounds.bottom,
            type: SnapType.edge,
          ));
        }
      }

      // Check centers
      if (config.snapToCenters) {
        if ((bounds.center.dx - point.dx).abs() <= effectiveThreshold) {
          snappedX = bounds.center.dx;
          verticalGuides.add(SnapGuide(
            start: Offset(bounds.center.dx, bounds.top - 20),
            end: Offset(bounds.center.dx, bounds.bottom + 20),
            value: bounds.center.dx,
            type: SnapType.center,
          ));
        }
        if ((bounds.center.dy - point.dy).abs() <= effectiveThreshold) {
          snappedY = bounds.center.dy;
          horizontalGuides.add(SnapGuide(
            start: Offset(bounds.left - 20, bounds.center.dy),
            end: Offset(bounds.right + 20, bounds.center.dy),
            value: bounds.center.dy,
            type: SnapType.center,
          ));
        }
      }
    }

    return SnapResult(
      position: Offset(snappedX ?? point.dx, snappedY ?? point.dy),
      horizontalGuides: horizontalGuides,
      verticalGuides: verticalGuides,
    );
  }

  /// Snap point to parent bounds
  SnapResult _snapToParent(Offset point) {
    if (parentBounds == null) return SnapResult.none(point);

    double? snappedX;
    double? snappedY;
    final horizontalGuides = <SnapGuide>[];
    final verticalGuides = <SnapGuide>[];
    final bounds = parentBounds!;

    // Check edges
    if ((bounds.left - point.dx).abs() <= effectiveThreshold) {
      snappedX = bounds.left;
      verticalGuides.add(SnapGuide(
        start: Offset(bounds.left, bounds.top),
        end: Offset(bounds.left, bounds.bottom),
        value: bounds.left,
        type: SnapType.parent,
      ));
    }
    if ((bounds.right - point.dx).abs() <= effectiveThreshold) {
      snappedX = bounds.right;
      verticalGuides.add(SnapGuide(
        start: Offset(bounds.right, bounds.top),
        end: Offset(bounds.right, bounds.bottom),
        value: bounds.right,
        type: SnapType.parent,
      ));
    }
    if ((bounds.top - point.dy).abs() <= effectiveThreshold) {
      snappedY = bounds.top;
      horizontalGuides.add(SnapGuide(
        start: Offset(bounds.left, bounds.top),
        end: Offset(bounds.right, bounds.top),
        value: bounds.top,
        type: SnapType.parent,
      ));
    }
    if ((bounds.bottom - point.dy).abs() <= effectiveThreshold) {
      snappedY = bounds.bottom;
      horizontalGuides.add(SnapGuide(
        start: Offset(bounds.left, bounds.bottom),
        end: Offset(bounds.right, bounds.bottom),
        value: bounds.bottom,
        type: SnapType.parent,
      ));
    }

    // Check center
    if ((bounds.center.dx - point.dx).abs() <= effectiveThreshold) {
      snappedX = bounds.center.dx;
      verticalGuides.add(SnapGuide(
        start: Offset(bounds.center.dx, bounds.top),
        end: Offset(bounds.center.dx, bounds.bottom),
        value: bounds.center.dx,
        type: SnapType.center,
      ));
    }
    if ((bounds.center.dy - point.dy).abs() <= effectiveThreshold) {
      snappedY = bounds.center.dy;
      horizontalGuides.add(SnapGuide(
        start: Offset(bounds.left, bounds.center.dy),
        end: Offset(bounds.right, bounds.center.dy),
        value: bounds.center.dy,
        type: SnapType.center,
      ));
    }

    return SnapResult(
      position: Offset(snappedX ?? point.dx, snappedY ?? point.dy),
      horizontalGuides: horizontalGuides,
      verticalGuides: verticalGuides,
    );
  }

  /// Snap rect to objects (returns delta)
  _RectSnapResult _snapRectToObjects(Rect rect) {
    double dx = 0;
    double dy = 0;
    final horizontalGuides = <SnapGuide>[];
    final verticalGuides = <SnapGuide>[];

    final rectEdgesX = [rect.left, rect.center.dx, rect.right];
    final rectEdgesY = [rect.top, rect.center.dy, rect.bottom];

    for (final bounds in objectBounds) {
      final objEdgesX = [bounds.left, bounds.center.dx, bounds.right];
      final objEdgesY = [bounds.top, bounds.center.dy, bounds.bottom];

      // Check X alignment
      for (final rx in rectEdgesX) {
        for (final ox in objEdgesX) {
          if ((ox - rx).abs() <= effectiveThreshold && dx == 0) {
            dx = ox - rx;
            verticalGuides.add(SnapGuide(
              start: Offset(ox, bounds.top.clamp(-10000, rect.top) - 20),
              end: Offset(ox, bounds.bottom.clamp(rect.bottom, 10000) + 20),
              value: ox,
              type: rx == rect.center.dx ? SnapType.center : SnapType.edge,
            ));
          }
        }
      }

      // Check Y alignment
      for (final ry in rectEdgesY) {
        for (final oy in objEdgesY) {
          if ((oy - ry).abs() <= effectiveThreshold && dy == 0) {
            dy = oy - ry;
            horizontalGuides.add(SnapGuide(
              start: Offset(bounds.left.clamp(-10000, rect.left) - 20, oy),
              end: Offset(bounds.right.clamp(rect.right, 10000) + 20, oy),
              value: oy,
              type: ry == rect.center.dy ? SnapType.center : SnapType.edge,
            ));
          }
        }
      }
    }

    return _RectSnapResult(
      dx: dx,
      dy: dy,
      horizontalGuides: horizontalGuides,
      verticalGuides: verticalGuides,
    );
  }

  /// Snap rect to parent (returns delta)
  _RectSnapResult _snapRectToParent(Rect rect) {
    if (parentBounds == null) {
      return _RectSnapResult(dx: 0, dy: 0);
    }

    double dx = 0;
    double dy = 0;
    final horizontalGuides = <SnapGuide>[];
    final verticalGuides = <SnapGuide>[];
    final bounds = parentBounds!;

    final rectEdgesX = [rect.left, rect.center.dx, rect.right];
    final rectEdgesY = [rect.top, rect.center.dy, rect.bottom];
    final parentEdgesX = [bounds.left, bounds.center.dx, bounds.right];
    final parentEdgesY = [bounds.top, bounds.center.dy, bounds.bottom];

    // Check X alignment
    for (final rx in rectEdgesX) {
      for (final px in parentEdgesX) {
        if ((px - rx).abs() <= effectiveThreshold && dx == 0) {
          dx = px - rx;
          verticalGuides.add(SnapGuide(
            start: Offset(px, bounds.top),
            end: Offset(px, bounds.bottom),
            value: px,
            type: SnapType.parent,
          ));
        }
      }
    }

    // Check Y alignment
    for (final ry in rectEdgesY) {
      for (final py in parentEdgesY) {
        if ((py - ry).abs() <= effectiveThreshold && dy == 0) {
          dy = py - ry;
          horizontalGuides.add(SnapGuide(
            start: Offset(bounds.left, py),
            end: Offset(bounds.right, py),
            value: py,
            type: SnapType.parent,
          ));
        }
      }
    }

    return _RectSnapResult(
      dx: dx,
      dy: dy,
      horizontalGuides: horizontalGuides,
      verticalGuides: verticalGuides,
    );
  }
}

/// Internal result for rect snapping
class _RectSnapResult {
  final double dx;
  final double dy;
  final List<SnapGuide> horizontalGuides;
  final List<SnapGuide> verticalGuides;

  _RectSnapResult({
    required this.dx,
    required this.dy,
    this.horizontalGuides = const [],
    this.verticalGuides = const [],
  });
}
