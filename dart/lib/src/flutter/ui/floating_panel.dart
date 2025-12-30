/// Floating Panel Component
///
/// A draggable, resizable floating panel like Figma's design.

import 'package:flutter/material.dart';

/// A floating panel that can be dragged and resized
class FloatingPanel extends StatefulWidget {
  final Widget child;
  final String? title;
  final Offset initialPosition;
  final Size initialSize;
  final Size minSize;
  final Size? maxSize;
  final VoidCallback? onClose;
  final bool showHeader;
  final bool resizable;

  const FloatingPanel({
    super.key,
    required this.child,
    this.title,
    this.initialPosition = const Offset(100, 100),
    this.initialSize = const Size(600, 500),
    this.minSize = const Size(300, 200),
    this.maxSize,
    this.onClose,
    this.showHeader = true,
    this.resizable = true,
  });

  @override
  State<FloatingPanel> createState() => _FloatingPanelState();
}

class _FloatingPanelState extends State<FloatingPanel> {
  late Offset _position;
  late Size _size;
  bool _isDragging = false;
  _ResizeEdge? _activeEdge;

  static const double _resizeHandleSize = 8.0;
  static const double _cornerHandleSize = 12.0;

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition;
    _size = widget.initialSize;
  }

  void _clampPosition() {
    final screenSize = MediaQuery.of(context).size;
    _position = Offset(
      _position.dx.clamp(0, screenSize.width - 100),
      _position.dy.clamp(0, screenSize.height - 50),
    );
  }

  void _clampSize() {
    _size = Size(
      _size.width.clamp(widget.minSize.width, widget.maxSize?.width ?? 2000),
      _size.height.clamp(widget.minSize.height, widget.maxSize?.height ?? 2000),
    );
  }

  void _handleResize(_ResizeEdge edge, Offset delta) {
    setState(() {
      double newWidth = _size.width;
      double newHeight = _size.height;
      double newX = _position.dx;
      double newY = _position.dy;

      switch (edge) {
        case _ResizeEdge.right:
          newWidth += delta.dx;
          break;
        case _ResizeEdge.bottom:
          newHeight += delta.dy;
          break;
        case _ResizeEdge.left:
          newWidth -= delta.dx;
          newX += delta.dx;
          break;
        case _ResizeEdge.top:
          newHeight -= delta.dy;
          newY += delta.dy;
          break;
        case _ResizeEdge.topLeft:
          newWidth -= delta.dx;
          newHeight -= delta.dy;
          newX += delta.dx;
          newY += delta.dy;
          break;
        case _ResizeEdge.topRight:
          newWidth += delta.dx;
          newHeight -= delta.dy;
          newY += delta.dy;
          break;
        case _ResizeEdge.bottomLeft:
          newWidth -= delta.dx;
          newHeight += delta.dy;
          newX += delta.dx;
          break;
        case _ResizeEdge.bottomRight:
          newWidth += delta.dx;
          newHeight += delta.dy;
          break;
      }

      // Apply min/max constraints
      final clampedWidth = newWidth.clamp(widget.minSize.width, widget.maxSize?.width ?? 2000.0).toDouble();
      final clampedHeight = newHeight.clamp(widget.minSize.height, widget.maxSize?.height ?? 2000.0).toDouble();

      // Adjust position if size was clamped on left/top edges
      if (edge == _ResizeEdge.left || edge == _ResizeEdge.topLeft || edge == _ResizeEdge.bottomLeft) {
        if (clampedWidth != newWidth) {
          newX = _position.dx + (_size.width - clampedWidth);
        }
      }
      if (edge == _ResizeEdge.top || edge == _ResizeEdge.topLeft || edge == _ResizeEdge.topRight) {
        if (clampedHeight != newHeight) {
          newY = _position.dy + (_size.height - clampedHeight);
        }
      }

      _size = Size(clampedWidth.toDouble(), clampedHeight.toDouble());
      _position = Offset(newX, newY);
      _clampPosition();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: Stack(
        children: [
          // Main panel
          Container(
            width: _size.width,
            height: _size.height,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(
                color: const Color(0xFF3C3C3C),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Column(
                children: [
                  if (widget.showHeader) _buildHeader(),
                  Expanded(child: widget.child),
                ],
              ),
            ),
          ),
          // Resize handles
          if (widget.resizable) ..._buildResizeHandles(),
        ],
      ),
    );
  }

  List<Widget> _buildResizeHandles() {
    return [
      // Edge handles
      _buildEdgeHandle(_ResizeEdge.top,
        Alignment.topCenter,
        Size(_size.width - _cornerHandleSize * 2, _resizeHandleSize),
        SystemMouseCursors.resizeUpDown,
      ),
      _buildEdgeHandle(_ResizeEdge.bottom,
        Alignment.bottomCenter,
        Size(_size.width - _cornerHandleSize * 2, _resizeHandleSize),
        SystemMouseCursors.resizeUpDown,
      ),
      _buildEdgeHandle(_ResizeEdge.left,
        Alignment.centerLeft,
        Size(_resizeHandleSize, _size.height - _cornerHandleSize * 2),
        SystemMouseCursors.resizeLeftRight,
      ),
      _buildEdgeHandle(_ResizeEdge.right,
        Alignment.centerRight,
        Size(_resizeHandleSize, _size.height - _cornerHandleSize * 2),
        SystemMouseCursors.resizeLeftRight,
      ),
      // Corner handles
      _buildCornerHandle(_ResizeEdge.topLeft, Alignment.topLeft, SystemMouseCursors.resizeUpLeftDownRight),
      _buildCornerHandle(_ResizeEdge.topRight, Alignment.topRight, SystemMouseCursors.resizeUpRightDownLeft),
      _buildCornerHandle(_ResizeEdge.bottomLeft, Alignment.bottomLeft, SystemMouseCursors.resizeUpRightDownLeft),
      _buildCornerHandle(_ResizeEdge.bottomRight, Alignment.bottomRight, SystemMouseCursors.resizeUpLeftDownRight),
    ];
  }

  Widget _buildEdgeHandle(_ResizeEdge edge, Alignment alignment, Size size, MouseCursor cursor) {
    return Positioned.fill(
      child: Align(
        alignment: alignment,
        child: MouseRegion(
          cursor: cursor,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (details) => _handleResize(edge, details.delta),
            child: Container(
              width: size.width,
              height: size.height,
              color: Colors.transparent,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCornerHandle(_ResizeEdge edge, Alignment alignment, MouseCursor cursor) {
    return Positioned.fill(
      child: Align(
        alignment: alignment,
        child: MouseRegion(
          cursor: cursor,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (details) => _handleResize(edge, details.delta),
            child: Container(
              width: _cornerHandleSize,
              height: _cornerHandleSize,
              color: Colors.transparent,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return GestureDetector(
      onPanStart: (_) => setState(() => _isDragging = true),
      onPanUpdate: (details) {
        setState(() {
          _position += details.delta;
          _clampPosition();
        });
      },
      onPanEnd: (_) => setState(() => _isDragging = false),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: _isDragging
              ? const Color(0xFF3C3C3C)
              : const Color(0xFF252525),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        ),
        child: Row(
          children: [
            // Drag handle indicator
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (widget.title != null)
              Expanded(
                child: Text(
                  widget.title!,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            else
              const Spacer(),
            // Close button
            if (widget.onClose != null)
              IconButton(
                icon: const Icon(Icons.close, size: 14),
                color: Colors.white54,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                hoverColor: Colors.white12,
                onPressed: widget.onClose,
                tooltip: 'Close',
              ),
          ],
        ),
      ),
    );
  }
}

enum _ResizeEdge {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  left,
  right,
  top,
  bottom,
}

/// A container that can hold multiple floating panels
class FloatingPanelContainer extends StatelessWidget {
  final Widget background;
  final List<Widget> panels;

  const FloatingPanelContainer({
    super.key,
    required this.background,
    this.panels = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        background,
        ...panels,
      ],
    );
  }
}
