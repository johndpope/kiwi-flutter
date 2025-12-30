/// Selection and hover overlay for Figma-style canvas interactions
///
/// Provides:
/// - Hover highlighting with blue border
/// - Selection highlighting with blue border and resize handles
/// - Ctrl/Cmd + click for multi-selection
/// - Marquee selection rectangle

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'state/selection.dart';
import 'figma_canvas.dart';

/// Colors for selection and hover states (matching Figma)
class SelectionColors {
  static const hoverBorder = Color(0xFF0D99FF); // Blue
  static const selectionBorder = Color(0xFF0D99FF); // Blue
  static const selectionFill = Color(0x110D99FF); // Light blue fill
  static const marqueeBorder = Color(0xFF0D99FF);
  static const marqueeFill = Color(0x220D99FF);
  static const handleFill = Colors.white;
  static const handleBorder = Color(0xFF0D99FF);
}

/// Overlay that draws selection/hover indicators and handles interactions
class SelectionOverlay extends StatefulWidget {
  final Widget child;
  final Selection selection;
  final Map<String, Map<String, dynamic>> nodeMap;
  final double scale;
  final Matrix4? transform;
  final void Function(String nodeId, {bool additive})? onNodeTap;
  final void Function(String nodeId)? onNodeDoubleTap;
  final VoidCallback? onCanvasTap;

  const SelectionOverlay({
    super.key,
    required this.child,
    required this.selection,
    required this.nodeMap,
    this.scale = 1.0,
    this.transform,
    this.onNodeTap,
    this.onNodeDoubleTap,
    this.onCanvasTap,
  });

  @override
  State<SelectionOverlay> createState() => _SelectionOverlayState();
}

class _SelectionOverlayState extends State<SelectionOverlay> {
  Offset? _lastPointerPosition;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    widget.selection.addListener(_onSelectionChanged);
  }

  @override
  void dispose() {
    widget.selection.removeListener(_onSelectionChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(SelectionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selection != widget.selection) {
      oldWidget.selection.removeListener(_onSelectionChanged);
      widget.selection.addListener(_onSelectionChanged);
    }
  }

  void _onSelectionChanged() {
    setState(() {});
  }

  /// Convert screen position to canvas position
  Offset _screenToCanvas(Offset screenPos) {
    // Invert transform to get canvas coordinates
    final transform = widget.transform ?? Matrix4.identity();
    final inverted = Matrix4.inverted(transform);
    final point = inverted.transform3(Vector3(screenPos.dx, screenPos.dy, 0));
    return Offset(point.x, point.y);
  }

  /// Hit test to find node at position
  String? _hitTestNode(Offset canvasPos) {
    // Iterate through nodes in reverse order (top to bottom visually)
    // This is a simplified hit test - real implementation would need proper z-ordering
    String? hitNodeId;

    for (final entry in widget.nodeMap.entries) {
      final node = entry.value;
      final bounds = _getNodeBounds(node);
      if (bounds != null && bounds.contains(canvasPos)) {
        // Check if this node is selectable (not a page/canvas)
        final type = node['type']?.toString();
        if (type != 'DOCUMENT' && type != 'CANVAS') {
          hitNodeId = entry.key;
          // Don't break - we want the topmost (last) node
        }
      }
    }

    return hitNodeId;
  }

  /// Get bounds of a node
  Rect? _getNodeBounds(Map<String, dynamic> node) {
    // Try transform first
    final transform = node['transform'] as Map?;
    final size = node['size'] as Map?;

    if (transform != null && size != null) {
      final x = (transform['m02'] as num?)?.toDouble() ?? 0;
      final y = (transform['m12'] as num?)?.toDouble() ?? 0;
      final w = (size['x'] as num?)?.toDouble() ?? 0;
      final h = (size['y'] as num?)?.toDouble() ?? 0;
      return Rect.fromLTWH(x, y, w, h);
    }

    // Try bounding box
    final bbox = node['boundingBox'] as Map?;
    if (bbox != null) {
      return Rect.fromLTWH(
        (bbox['x'] as num?)?.toDouble() ?? 0,
        (bbox['y'] as num?)?.toDouble() ?? 0,
        (bbox['width'] as num?)?.toDouble() ?? 0,
        (bbox['height'] as num?)?.toDouble() ?? 0,
      );
    }

    return null;
  }

  void _handlePointerHover(PointerHoverEvent event) {
    _lastPointerPosition = event.localPosition;
    final canvasPos = _screenToCanvas(event.localPosition);
    final hitNodeId = _hitTestNode(canvasPos);
    widget.selection.setHoveredNode(hitNodeId);
  }

  void _handlePointerExit(PointerExitEvent event) {
    widget.selection.clearHover();
  }

  void _handleTapDown(TapDownDetails details) {
    final canvasPos = _screenToCanvas(details.localPosition);
    final hitNodeId = _hitTestNode(canvasPos);

    if (hitNodeId != null) {
      // Check if Ctrl/Cmd is pressed for multi-selection
      final isMultiSelect = HardwareKeyboard.instance.isControlPressed ||
                            HardwareKeyboard.instance.isMetaPressed;

      if (isMultiSelect) {
        // Toggle selection
        widget.selection.toggle(hitNodeId);
      } else {
        // Single select
        widget.onNodeTap?.call(hitNodeId, additive: false);
        widget.selection.select(hitNodeId);
      }
    } else {
      // Clicked on empty canvas
      widget.onCanvasTap?.call();
      widget.selection.deselectAll();
    }
  }

  void _handleDoubleTap() {
    if (_lastPointerPosition != null) {
      final canvasPos = _screenToCanvas(_lastPointerPosition!);
      final hitNodeId = _hitTestNode(canvasPos);
      if (hitNodeId != null) {
        widget.onNodeDoubleTap?.call(hitNodeId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: _handlePointerHover,
      onExit: _handlePointerExit,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onDoubleTap: _handleDoubleTap,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            widget.child,
            // Selection/hover overlay
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _SelectionPainter(
                    selection: widget.selection,
                    nodeMap: widget.nodeMap,
                    scale: widget.scale,
                    transform: widget.transform ?? Matrix4.identity(),
                    getNodeBounds: _getNodeBounds,
                  ),
                ),
              ),
            ),
            // Marquee selection rectangle
            if (widget.selection.marqueeRect != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _MarqueePainter(
                      rect: widget.selection.marqueeRect!,
                      transform: widget.transform ?? Matrix4.identity(),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for selection/hover borders
class _SelectionPainter extends CustomPainter {
  final Selection selection;
  final Map<String, Map<String, dynamic>> nodeMap;
  final double scale;
  final Matrix4 transform;
  final Rect? Function(Map<String, dynamic>) getNodeBounds;

  _SelectionPainter({
    required this.selection,
    required this.nodeMap,
    required this.scale,
    required this.transform,
    required this.getNodeBounds,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final hoverPaint = Paint()
      ..color = SelectionColors.hoverBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 / scale;

    final selectionPaint = Paint()
      ..color = SelectionColors.selectionBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 / scale;

    final selectionFillPaint = Paint()
      ..color = SelectionColors.selectionFill
      ..style = PaintingStyle.fill;

    // Apply transform
    canvas.save();
    canvas.transform(transform.storage);

    // Draw hover highlight (only if not selected)
    final hoveredId = selection.hoveredNodeId;
    if (hoveredId != null && !selection.isSelected(hoveredId)) {
      final node = nodeMap[hoveredId];
      if (node != null) {
        final bounds = getNodeBounds(node);
        if (bounds != null) {
          canvas.drawRect(bounds, hoverPaint);
        }
      }
    }

    // Draw selection highlights
    for (final nodeId in selection.selectedNodeIds) {
      final node = nodeMap[nodeId];
      if (node != null) {
        final bounds = getNodeBounds(node);
        if (bounds != null) {
          // Draw fill
          canvas.drawRect(bounds, selectionFillPaint);
          // Draw border
          canvas.drawRect(bounds, selectionPaint);
          // Draw resize handles
          _drawResizeHandles(canvas, bounds, scale);
        }
      }
    }

    canvas.restore();
  }

  void _drawResizeHandles(Canvas canvas, Rect bounds, double scale) {
    final handleSize = 8.0 / scale;
    final handleRadius = handleSize / 2;

    final handleFillPaint = Paint()
      ..color = SelectionColors.handleFill
      ..style = PaintingStyle.fill;

    final handleBorderPaint = Paint()
      ..color = SelectionColors.handleBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 / scale;

    // Corner handles
    final corners = [
      bounds.topLeft,
      bounds.topRight,
      bounds.bottomLeft,
      bounds.bottomRight,
    ];

    // Edge center handles
    final edges = [
      Offset(bounds.center.dx, bounds.top), // top center
      Offset(bounds.center.dx, bounds.bottom), // bottom center
      Offset(bounds.left, bounds.center.dy), // left center
      Offset(bounds.right, bounds.center.dy), // right center
    ];

    for (final corner in corners) {
      final rect = Rect.fromCenter(center: corner, width: handleSize, height: handleSize);
      canvas.drawRect(rect, handleFillPaint);
      canvas.drawRect(rect, handleBorderPaint);
    }

    for (final edge in edges) {
      final rect = Rect.fromCenter(center: edge, width: handleSize, height: handleSize);
      canvas.drawRect(rect, handleFillPaint);
      canvas.drawRect(rect, handleBorderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SelectionPainter oldDelegate) {
    return selection.hoveredNodeId != oldDelegate.selection.hoveredNodeId ||
           selection.selectedNodeIds != oldDelegate.selection.selectedNodeIds ||
           scale != oldDelegate.scale;
  }
}

/// Custom painter for marquee selection rectangle
class _MarqueePainter extends CustomPainter {
  final Rect rect;
  final Matrix4 transform;

  _MarqueePainter({
    required this.rect,
    required this.transform,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = SelectionColors.marqueeBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final fillPaint = Paint()
      ..color = SelectionColors.marqueeFill
      ..style = PaintingStyle.fill;

    canvas.drawRect(rect, fillPaint);
    canvas.drawRect(rect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _MarqueePainter oldDelegate) {
    return rect != oldDelegate.rect;
  }
}

/// Wrapper widget that makes a node hoverable and selectable
class SelectableNode extends StatelessWidget {
  final String nodeId;
  final Widget child;
  final Selection selection;
  final void Function(String nodeId, {bool additive})? onTap;
  final void Function(String nodeId)? onDoubleTap;

  const SelectableNode({
    super.key,
    required this.nodeId,
    required this.child,
    required this.selection,
    this.onTap,
    this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => selection.setHoveredNode(nodeId),
      onExit: (_) {
        if (selection.hoveredNodeId == nodeId) {
          selection.clearHover();
        }
      },
      child: GestureDetector(
        onTap: () {
          final isMultiSelect = HardwareKeyboard.instance.isControlPressed ||
                                HardwareKeyboard.instance.isMetaPressed;
          if (isMultiSelect) {
            selection.toggle(nodeId);
          } else {
            onTap?.call(nodeId, additive: false);
            selection.select(nodeId);
          }
        },
        onDoubleTap: () => onDoubleTap?.call(nodeId),
        child: ListenableBuilder(
          listenable: selection,
          builder: (context, _) {
            final isHovered = selection.isHovered(nodeId);
            final isSelected = selection.isSelected(nodeId);

            if (!isHovered && !isSelected) {
              return child;
            }

            return Stack(
              children: [
                child,
                // Hover/selection border overlay
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: SelectionColors.selectionBorder,
                          width: isSelected ? 2.0 : 1.5,
                        ),
                        color: isSelected ? SelectionColors.selectionFill : null,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
