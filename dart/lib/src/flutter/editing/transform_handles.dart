/// Transform handles for node manipulation
///
/// Provides:
/// - 8 resize handles (corners + edges)
/// - Rotation handle
/// - Visual feedback during drag
/// - Shift for proportional scaling
/// - Alt for center-based scaling

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Handle position enum
enum HandlePosition {
  topLeft,
  topCenter,
  topRight,
  centerLeft,
  centerRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
  rotation,
}

/// Transform operation types
enum TransformType {
  none,
  move,
  resize,
  rotate,
}

/// Data class for transform state
class TransformState {
  final Rect originalBounds;
  final double originalRotation;
  final Offset dragStart;
  final HandlePosition? activeHandle;
  final TransformType type;
  final bool proportional;
  final bool centerBased;

  const TransformState({
    required this.originalBounds,
    this.originalRotation = 0,
    required this.dragStart,
    this.activeHandle,
    this.type = TransformType.none,
    this.proportional = false,
    this.centerBased = false,
  });

  TransformState copyWith({
    Rect? originalBounds,
    double? originalRotation,
    Offset? dragStart,
    HandlePosition? activeHandle,
    TransformType? type,
    bool? proportional,
    bool? centerBased,
  }) {
    return TransformState(
      originalBounds: originalBounds ?? this.originalBounds,
      originalRotation: originalRotation ?? this.originalRotation,
      dragStart: dragStart ?? this.dragStart,
      activeHandle: activeHandle ?? this.activeHandle,
      type: type ?? this.type,
      proportional: proportional ?? this.proportional,
      centerBased: centerBased ?? this.centerBased,
    );
  }
}

/// Transform handles widget
class TransformHandles extends StatefulWidget {
  /// Bounds of the selection
  final Rect bounds;

  /// Current rotation in radians
  final double rotation;

  /// Zoom level for scaling handle sizes
  final double zoom;

  /// Called when transform starts
  final void Function(TransformState state)? onTransformStart;

  /// Called during transform with new bounds
  final void Function(Rect newBounds, double newRotation)? onTransformUpdate;

  /// Called when transform ends
  final void Function(Rect finalBounds, double finalRotation)? onTransformEnd;

  /// Called when move starts
  final void Function(Offset position)? onMoveStart;

  /// Called during move
  final void Function(Offset delta)? onMoveUpdate;

  /// Called when move ends
  final void Function()? onMoveEnd;

  /// Whether to show rotation handle
  final bool showRotation;

  /// Handle color
  final Color handleColor;

  /// Handle fill color
  final Color handleFillColor;

  /// Selection border color
  final Color borderColor;

  const TransformHandles({
    super.key,
    required this.bounds,
    this.rotation = 0,
    this.zoom = 1.0,
    this.onTransformStart,
    this.onTransformUpdate,
    this.onTransformEnd,
    this.onMoveStart,
    this.onMoveUpdate,
    this.onMoveEnd,
    this.showRotation = true,
    this.handleColor = const Color(0xFF0D99FF),
    this.handleFillColor = Colors.white,
    this.borderColor = const Color(0xFF0D99FF),
  });

  @override
  State<TransformHandles> createState() => _TransformHandlesState();
}

class _TransformHandlesState extends State<TransformHandles> {
  TransformState? _transformState;
  bool _isShiftPressed = false;
  bool _isAltPressed = false;

  // Handle sizes
  double get _handleSize => 8.0 / widget.zoom;
  double get _rotationHandleOffset => 24.0 / widget.zoom;
  double get _borderWidth => 1.0 / widget.zoom;

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: _handleKeyEvent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Selection border
          Positioned.fromRect(
            rect: widget.bounds,
            child: IgnorePointer(
              child: CustomPaint(
                painter: _SelectionBorderPainter(
                  color: widget.borderColor,
                  strokeWidth: _borderWidth,
                  rotation: widget.rotation,
                ),
              ),
            ),
          ),

          // Move area (the entire bounds)
          Positioned.fromRect(
            rect: widget.bounds,
            child: GestureDetector(
              onPanStart: _onMoveStart,
              onPanUpdate: _onMoveUpdate,
              onPanEnd: _onMoveEnd,
              child: MouseRegion(
                cursor: SystemMouseCursors.move,
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          // Resize handles
          ..._buildResizeHandles(),

          // Rotation handle
          if (widget.showRotation) _buildRotationHandle(),
        ],
      ),
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    setState(() {
      _isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
      _isAltPressed = HardwareKeyboard.instance.isAltPressed;
    });

    if (_transformState != null) {
      _transformState = _transformState!.copyWith(
        proportional: _isShiftPressed,
        centerBased: _isAltPressed,
      );
    }
  }

  List<Widget> _buildResizeHandles() {
    final handles = <Widget>[];
    final positions = [
      HandlePosition.topLeft,
      HandlePosition.topCenter,
      HandlePosition.topRight,
      HandlePosition.centerLeft,
      HandlePosition.centerRight,
      HandlePosition.bottomLeft,
      HandlePosition.bottomCenter,
      HandlePosition.bottomRight,
    ];

    for (final position in positions) {
      handles.add(_buildHandle(position));
    }

    return handles;
  }

  Widget _buildHandle(HandlePosition position) {
    final offset = _getHandleOffset(position);
    final cursor = _getCursorForHandle(position);

    return Positioned(
      left: offset.dx - _handleSize / 2,
      top: offset.dy - _handleSize / 2,
      child: GestureDetector(
        onPanStart: (details) => _onResizeStart(details, position),
        onPanUpdate: _onResizeUpdate,
        onPanEnd: _onResizeEnd,
        child: MouseRegion(
          cursor: cursor,
          child: Container(
            width: _handleSize,
            height: _handleSize,
            decoration: BoxDecoration(
              color: widget.handleFillColor,
              border: Border.all(
                color: widget.handleColor,
                width: _borderWidth,
              ),
              borderRadius: BorderRadius.circular(_handleSize / 4),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRotationHandle() {
    final center = widget.bounds.topCenter;
    final offset = Offset(center.dx, center.dy - _rotationHandleOffset);

    return Positioned(
      left: offset.dx - _handleSize / 2,
      top: offset.dy - _handleSize / 2,
      child: GestureDetector(
        onPanStart: _onRotateStart,
        onPanUpdate: _onRotateUpdate,
        onPanEnd: _onRotateEnd,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            width: _handleSize,
            height: _handleSize,
            decoration: BoxDecoration(
              color: widget.handleFillColor,
              border: Border.all(
                color: widget.handleColor,
                width: _borderWidth,
              ),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  Offset _getHandleOffset(HandlePosition position) {
    final rect = widget.bounds;

    switch (position) {
      case HandlePosition.topLeft:
        return rect.topLeft;
      case HandlePosition.topCenter:
        return rect.topCenter;
      case HandlePosition.topRight:
        return rect.topRight;
      case HandlePosition.centerLeft:
        return rect.centerLeft;
      case HandlePosition.centerRight:
        return rect.centerRight;
      case HandlePosition.bottomLeft:
        return rect.bottomLeft;
      case HandlePosition.bottomCenter:
        return rect.bottomCenter;
      case HandlePosition.bottomRight:
        return rect.bottomRight;
      case HandlePosition.rotation:
        return Offset(rect.center.dx, rect.top - _rotationHandleOffset);
    }
  }

  SystemMouseCursor _getCursorForHandle(HandlePosition position) {
    switch (position) {
      case HandlePosition.topLeft:
      case HandlePosition.bottomRight:
        return SystemMouseCursors.resizeUpLeftDownRight;
      case HandlePosition.topRight:
      case HandlePosition.bottomLeft:
        return SystemMouseCursors.resizeUpRightDownLeft;
      case HandlePosition.topCenter:
      case HandlePosition.bottomCenter:
        return SystemMouseCursors.resizeUpDown;
      case HandlePosition.centerLeft:
      case HandlePosition.centerRight:
        return SystemMouseCursors.resizeLeftRight;
      case HandlePosition.rotation:
        return SystemMouseCursors.click;
    }
  }

  // Move handlers
  void _onMoveStart(DragStartDetails details) {
    _transformState = TransformState(
      originalBounds: widget.bounds,
      originalRotation: widget.rotation,
      dragStart: details.globalPosition,
      type: TransformType.move,
      proportional: _isShiftPressed,
      centerBased: _isAltPressed,
    );
    widget.onMoveStart?.call(details.globalPosition);
  }

  void _onMoveUpdate(DragUpdateDetails details) {
    widget.onMoveUpdate?.call(details.delta);
  }

  void _onMoveEnd(DragEndDetails details) {
    _transformState = null;
    widget.onMoveEnd?.call();
  }

  // Resize handlers
  void _onResizeStart(DragStartDetails details, HandlePosition handle) {
    _transformState = TransformState(
      originalBounds: widget.bounds,
      originalRotation: widget.rotation,
      dragStart: details.globalPosition,
      activeHandle: handle,
      type: TransformType.resize,
      proportional: _isShiftPressed,
      centerBased: _isAltPressed,
    );
    widget.onTransformStart?.call(_transformState!);
  }

  void _onResizeUpdate(DragUpdateDetails details) {
    if (_transformState == null || _transformState!.activeHandle == null) return;

    final delta = details.globalPosition - _transformState!.dragStart;
    final newBounds = _calculateNewBounds(
      _transformState!.originalBounds,
      _transformState!.activeHandle!,
      delta,
      proportional: _isShiftPressed,
      centerBased: _isAltPressed,
    );

    widget.onTransformUpdate?.call(newBounds, widget.rotation);
  }

  void _onResizeEnd(DragEndDetails details) {
    if (_transformState != null) {
      widget.onTransformEnd?.call(widget.bounds, widget.rotation);
    }
    _transformState = null;
  }

  // Rotation handlers
  void _onRotateStart(DragStartDetails details) {
    _transformState = TransformState(
      originalBounds: widget.bounds,
      originalRotation: widget.rotation,
      dragStart: details.globalPosition,
      activeHandle: HandlePosition.rotation,
      type: TransformType.rotate,
    );
    widget.onTransformStart?.call(_transformState!);
  }

  void _onRotateUpdate(DragUpdateDetails details) {
    if (_transformState == null) return;

    final center = widget.bounds.center;
    final startAngle = math.atan2(
      _transformState!.dragStart.dy - center.dy,
      _transformState!.dragStart.dx - center.dx,
    );
    final currentAngle = math.atan2(
      details.globalPosition.dy - center.dy,
      details.globalPosition.dx - center.dx,
    );

    var newRotation = _transformState!.originalRotation + (currentAngle - startAngle);

    // Snap to 15 degree increments when shift is pressed
    if (_isShiftPressed) {
      const snapAngle = math.pi / 12; // 15 degrees
      newRotation = (newRotation / snapAngle).round() * snapAngle;
    }

    widget.onTransformUpdate?.call(widget.bounds, newRotation);
  }

  void _onRotateEnd(DragEndDetails details) {
    if (_transformState != null) {
      widget.onTransformEnd?.call(widget.bounds, widget.rotation);
    }
    _transformState = null;
  }

  Rect _calculateNewBounds(
    Rect original,
    HandlePosition handle,
    Offset delta, {
    bool proportional = false,
    bool centerBased = false,
  }) {
    double left = original.left;
    double top = original.top;
    double right = original.right;
    double bottom = original.bottom;

    // Apply delta based on handle position
    switch (handle) {
      case HandlePosition.topLeft:
        left += delta.dx;
        top += delta.dy;
        break;
      case HandlePosition.topCenter:
        top += delta.dy;
        break;
      case HandlePosition.topRight:
        right += delta.dx;
        top += delta.dy;
        break;
      case HandlePosition.centerLeft:
        left += delta.dx;
        break;
      case HandlePosition.centerRight:
        right += delta.dx;
        break;
      case HandlePosition.bottomLeft:
        left += delta.dx;
        bottom += delta.dy;
        break;
      case HandlePosition.bottomCenter:
        bottom += delta.dy;
        break;
      case HandlePosition.bottomRight:
        right += delta.dx;
        bottom += delta.dy;
        break;
      case HandlePosition.rotation:
        break;
    }

    // Ensure minimum size
    const minSize = 1.0;
    if (right - left < minSize) {
      if (handle == HandlePosition.topLeft ||
          handle == HandlePosition.centerLeft ||
          handle == HandlePosition.bottomLeft) {
        left = right - minSize;
      } else {
        right = left + minSize;
      }
    }
    if (bottom - top < minSize) {
      if (handle == HandlePosition.topLeft ||
          handle == HandlePosition.topCenter ||
          handle == HandlePosition.topRight) {
        top = bottom - minSize;
      } else {
        bottom = top + minSize;
      }
    }

    // Proportional scaling
    if (proportional && _isCornerHandle(handle)) {
      final originalAspect = original.width / original.height;
      final newWidth = right - left;
      final newHeight = bottom - top;
      final newAspect = newWidth / newHeight;

      if (newAspect > originalAspect) {
        // Width is larger, adjust height
        final adjustedHeight = newWidth / originalAspect;
        if (handle == HandlePosition.topLeft || handle == HandlePosition.topRight) {
          top = bottom - adjustedHeight;
        } else {
          bottom = top + adjustedHeight;
        }
      } else {
        // Height is larger, adjust width
        final adjustedWidth = newHeight * originalAspect;
        if (handle == HandlePosition.topLeft || handle == HandlePosition.bottomLeft) {
          left = right - adjustedWidth;
        } else {
          right = left + adjustedWidth;
        }
      }
    }

    // Center-based scaling
    if (centerBased) {
      final center = original.center;
      final halfWidth = (right - left) / 2;
      final halfHeight = (bottom - top) / 2;
      left = center.dx - halfWidth;
      right = center.dx + halfWidth;
      top = center.dy - halfHeight;
      bottom = center.dy + halfHeight;
    }

    return Rect.fromLTRB(left, top, right, bottom);
  }

  bool _isCornerHandle(HandlePosition handle) {
    return handle == HandlePosition.topLeft ||
        handle == HandlePosition.topRight ||
        handle == HandlePosition.bottomLeft ||
        handle == HandlePosition.bottomRight;
  }
}

/// Painter for selection border
class _SelectionBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double rotation;

  _SelectionBorderPainter({
    required this.color,
    required this.strokeWidth,
    this.rotation = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    if (rotation != 0) {
      canvas.save();
      canvas.translate(size.width / 2, size.height / 2);
      canvas.rotate(rotation);
      canvas.translate(-size.width / 2, -size.height / 2);
      canvas.drawRect(rect, paint);
      canvas.restore();
    } else {
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(_SelectionBorderPainter oldDelegate) {
    return color != oldDelegate.color ||
        strokeWidth != oldDelegate.strokeWidth ||
        rotation != oldDelegate.rotation;
  }
}

/// Multi-selection bounds indicator
class MultiSelectionBounds extends StatelessWidget {
  final List<Rect> selectedBounds;
  final double zoom;
  final Color color;

  const MultiSelectionBounds({
    super.key,
    required this.selectedBounds,
    this.zoom = 1.0,
    this.color = const Color(0xFF0D99FF),
  });

  @override
  Widget build(BuildContext context) {
    if (selectedBounds.isEmpty) return const SizedBox.shrink();

    // Calculate combined bounds
    Rect combined = selectedBounds.first;
    for (final bounds in selectedBounds.skip(1)) {
      combined = combined.expandToInclude(bounds);
    }

    return Stack(
      children: [
        // Individual selection indicators
        for (final bounds in selectedBounds)
          Positioned.fromRect(
            rect: bounds,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: color.withOpacity(0.5),
                    width: 1.0 / zoom,
                  ),
                ),
              ),
            ),
          ),

        // Combined bounds with handles
        TransformHandles(
          bounds: combined,
          zoom: zoom,
        ),
      ],
    );
  }
}
