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
  bool _isResizing = false;
  _ResizeHandle? _activeHandle;

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
      _size.width.clamp(widget.minSize.width, widget.maxSize?.width ?? double.infinity),
      _size.height.clamp(widget.minSize.height, widget.maxSize?.height ?? double.infinity),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: Container(
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

enum _ResizeHandle {
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
