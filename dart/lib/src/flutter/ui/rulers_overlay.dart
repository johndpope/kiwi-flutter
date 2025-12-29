/// Rulers and guides overlay for the canvas
///
/// Features:
/// - Horizontal and vertical rulers with units
/// - Draggable guides
/// - Guide snapping
/// - Cursor position indicator

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Guide orientation
enum GuideOrientation {
  horizontal,
  vertical,
}

/// Guide data
class Guide {
  /// Unique ID
  final String id;

  /// Orientation
  final GuideOrientation orientation;

  /// Position (in canvas coordinates)
  double position;

  /// Whether this guide is locked
  bool locked;

  /// Guide color
  Color color;

  Guide({
    required this.id,
    required this.orientation,
    required this.position,
    this.locked = false,
    this.color = const Color(0xFFFF4081),
  });

  /// Create a horizontal guide
  factory Guide.horizontal(double y, {String? id}) {
    return Guide(
      id: id ?? 'h_${DateTime.now().millisecondsSinceEpoch}',
      orientation: GuideOrientation.horizontal,
      position: y,
    );
  }

  /// Create a vertical guide
  factory Guide.vertical(double x, {String? id}) {
    return Guide(
      id: id ?? 'v_${DateTime.now().millisecondsSinceEpoch}',
      orientation: GuideOrientation.vertical,
      position: x,
    );
  }
}

/// Ruler unit type
enum RulerUnit {
  pixels,
  points,
  inches,
  centimeters,
}

/// Ruler configuration
class RulerConfig {
  /// Ruler unit
  final RulerUnit unit;

  /// Major tick interval (in pixels at 100% zoom)
  final double majorInterval;

  /// Number of minor ticks between major ticks
  final int minorTicks;

  /// Ruler thickness
  final double thickness;

  /// Background color
  final Color backgroundColor;

  /// Tick color
  final Color tickColor;

  /// Text color
  final Color textColor;

  /// Font size for labels
  final double fontSize;

  const RulerConfig({
    this.unit = RulerUnit.pixels,
    this.majorInterval = 100,
    this.minorTicks = 10,
    this.thickness = 20,
    this.backgroundColor = const Color(0xFF3C3C3C),
    this.tickColor = const Color(0xFF666666),
    this.textColor = const Color(0xFF999999),
    this.fontSize = 9,
  });

  /// Get display text for the unit
  String get unitLabel {
    switch (unit) {
      case RulerUnit.pixels:
        return 'px';
      case RulerUnit.points:
        return 'pt';
      case RulerUnit.inches:
        return 'in';
      case RulerUnit.centimeters:
        return 'cm';
    }
  }

  /// Convert canvas value to display value based on unit
  double toDisplayValue(double canvasValue) {
    switch (unit) {
      case RulerUnit.pixels:
        return canvasValue;
      case RulerUnit.points:
        return canvasValue * 0.75; // 1pt = 1.333px at 96 DPI
      case RulerUnit.inches:
        return canvasValue / 96;
      case RulerUnit.centimeters:
        return canvasValue / 37.795275591;
    }
  }
}

/// Rulers and guides overlay widget
class RulersOverlay extends StatefulWidget {
  /// Canvas transform (pan/zoom)
  final Matrix4 transform;

  /// Viewport size
  final Size viewportSize;

  /// Guides list
  final List<Guide> guides;

  /// Ruler configuration
  final RulerConfig config;

  /// Whether rulers are visible
  final bool showRulers;

  /// Whether guides are visible
  final bool showGuides;

  /// Cursor position (in canvas coordinates)
  final Offset? cursorPosition;

  /// Callback when a guide is added
  final ValueChanged<Guide>? onGuideAdded;

  /// Callback when a guide position changes
  final void Function(String id, double position)? onGuidePositionChanged;

  /// Callback when a guide is removed
  final ValueChanged<String>? onGuideRemoved;

  const RulersOverlay({
    super.key,
    required this.transform,
    required this.viewportSize,
    this.guides = const [],
    this.config = const RulerConfig(),
    this.showRulers = true,
    this.showGuides = true,
    this.cursorPosition,
    this.onGuideAdded,
    this.onGuidePositionChanged,
    this.onGuideRemoved,
  });

  @override
  State<RulersOverlay> createState() => _RulersOverlayState();
}

class _RulersOverlayState extends State<RulersOverlay> {
  String? _draggingGuideId;
  bool _isDraggingFromRuler = false;
  GuideOrientation? _draggingOrientation;

  double get _scale => widget.transform.getMaxScaleOnAxis();
  Offset get _translation {
    final t = widget.transform.getTranslation();
    return Offset(t.x, t.y);
  }

  /// Convert screen position to canvas position
  Offset _screenToCanvas(Offset screen) {
    return (screen - _translation) / _scale;
  }

  /// Convert canvas position to screen position
  Offset _canvasToScreen(Offset canvas) {
    return canvas * _scale + _translation;
  }

  void _handleRulerDragStart(GuideOrientation orientation, Offset position) {
    setState(() {
      _isDraggingFromRuler = true;
      _draggingOrientation = orientation;
    });
  }

  void _handleRulerDragUpdate(Offset position) {
    // Guide will be created when drag ends inside canvas
  }

  void _handleRulerDragEnd(Offset position) {
    if (_isDraggingFromRuler && _draggingOrientation != null) {
      final canvasPos = _screenToCanvas(position);
      final guide = _draggingOrientation == GuideOrientation.horizontal
          ? Guide.horizontal(canvasPos.dy)
          : Guide.vertical(canvasPos.dx);
      widget.onGuideAdded?.call(guide);
    }

    setState(() {
      _isDraggingFromRuler = false;
      _draggingOrientation = null;
    });
  }

  void _handleGuideDragStart(String guideId) {
    setState(() {
      _draggingGuideId = guideId;
    });
  }

  void _handleGuideDragUpdate(String guideId, Offset position) {
    final guide = widget.guides.firstWhere((g) => g.id == guideId);
    if (guide.locked) return;

    final canvasPos = _screenToCanvas(position);
    final newPosition = guide.orientation == GuideOrientation.horizontal
        ? canvasPos.dy
        : canvasPos.dx;

    widget.onGuidePositionChanged?.call(guideId, newPosition);
  }

  void _handleGuideDragEnd(String guideId, Offset position) {
    // Check if guide was dragged outside canvas (remove it)
    final rulerThickness = widget.config.thickness;
    if (position.dx < rulerThickness || position.dy < rulerThickness) {
      widget.onGuideRemoved?.call(guideId);
    }

    setState(() {
      _draggingGuideId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Guides (behind rulers)
        if (widget.showGuides) _buildGuides(),

        // Horizontal ruler (top)
        if (widget.showRulers) _buildHorizontalRuler(),

        // Vertical ruler (left)
        if (widget.showRulers) _buildVerticalRuler(),

        // Corner square
        if (widget.showRulers) _buildCorner(),

        // Cursor position indicators on rulers
        if (widget.showRulers && widget.cursorPosition != null)
          _buildCursorIndicators(),
      ],
    );
  }

  Widget _buildHorizontalRuler() {
    return Positioned(
      left: widget.config.thickness,
      top: 0,
      right: 0,
      height: widget.config.thickness,
      child: GestureDetector(
        onVerticalDragStart: (details) {
          _handleRulerDragStart(
              GuideOrientation.horizontal, details.globalPosition);
        },
        onVerticalDragUpdate: (details) {
          _handleRulerDragUpdate(details.globalPosition);
        },
        onVerticalDragEnd: (details) {
          // Get position from local position
          _handleRulerDragEnd(details.localPosition);
        },
        child: CustomPaint(
          painter: _HorizontalRulerPainter(
            config: widget.config,
            scale: _scale,
            offsetX: _translation.dx,
            viewportWidth: widget.viewportSize.width - widget.config.thickness,
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalRuler() {
    return Positioned(
      left: 0,
      top: widget.config.thickness,
      width: widget.config.thickness,
      bottom: 0,
      child: GestureDetector(
        onHorizontalDragStart: (details) {
          _handleRulerDragStart(
              GuideOrientation.vertical, details.globalPosition);
        },
        onHorizontalDragUpdate: (details) {
          _handleRulerDragUpdate(details.globalPosition);
        },
        onHorizontalDragEnd: (details) {
          _handleRulerDragEnd(details.localPosition);
        },
        child: CustomPaint(
          painter: _VerticalRulerPainter(
            config: widget.config,
            scale: _scale,
            offsetY: _translation.dy,
            viewportHeight:
                widget.viewportSize.height - widget.config.thickness,
          ),
        ),
      ),
    );
  }

  Widget _buildCorner() {
    return Positioned(
      left: 0,
      top: 0,
      width: widget.config.thickness,
      height: widget.config.thickness,
      child: Container(
        color: widget.config.backgroundColor,
        child: Center(
          child: Text(
            widget.config.unitLabel,
            style: TextStyle(
              color: widget.config.textColor,
              fontSize: 8,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuides() {
    return Stack(
      children: [
        for (final guide in widget.guides)
          _GuideWidget(
            guide: guide,
            transform: widget.transform,
            viewportSize: widget.viewportSize,
            rulerThickness: widget.config.thickness,
            isDragging: _draggingGuideId == guide.id,
            onDragStart: () => _handleGuideDragStart(guide.id),
            onDragUpdate: (pos) => _handleGuideDragUpdate(guide.id, pos),
            onDragEnd: (pos) => _handleGuideDragEnd(guide.id, pos),
            onDoubleTap: () => widget.onGuideRemoved?.call(guide.id),
          ),
      ],
    );
  }

  Widget _buildCursorIndicators() {
    final screenPos = _canvasToScreen(widget.cursorPosition!);
    final rulerThickness = widget.config.thickness;

    return Stack(
      children: [
        // Horizontal ruler indicator
        Positioned(
          left: screenPos.dx,
          top: 0,
          child: Container(
            width: 1,
            height: rulerThickness,
            color: Colors.blue.withValues(alpha: 0.8),
          ),
        ),

        // Vertical ruler indicator
        Positioned(
          left: 0,
          top: screenPos.dy,
          child: Container(
            width: rulerThickness,
            height: 1,
            color: Colors.blue.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

/// Horizontal ruler painter
class _HorizontalRulerPainter extends CustomPainter {
  final RulerConfig config;
  final double scale;
  final double offsetX;
  final double viewportWidth;

  _HorizontalRulerPainter({
    required this.config,
    required this.scale,
    required this.offsetX,
    required this.viewportWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = config.backgroundColor,
    );

    // Calculate visible range
    final startCanvas = -offsetX / scale;
    final endCanvas = (viewportWidth - offsetX) / scale;

    // Determine tick interval based on zoom
    final baseInterval = config.majorInterval;
    double interval = baseInterval;

    // Adjust interval for zoom level
    if (scale < 0.25) {
      interval = baseInterval * 4;
    } else if (scale < 0.5) {
      interval = baseInterval * 2;
    } else if (scale > 2) {
      interval = baseInterval / 2;
    } else if (scale > 4) {
      interval = baseInterval / 4;
    }

    final minorInterval = interval / config.minorTicks;

    // Draw ticks
    final tickPaint = Paint()
      ..color = config.tickColor
      ..strokeWidth = 1;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Start from first tick before visible area
    final firstTick = (startCanvas / interval).floor() * interval;

    for (double pos = firstTick; pos <= endCanvas; pos += minorInterval) {
      final screenX = pos * scale + offsetX;
      if (screenX < 0 || screenX > viewportWidth) continue;

      final isMajor = (pos % interval).abs() < 0.001;
      final tickHeight = isMajor ? 10.0 : 5.0;

      canvas.drawLine(
        Offset(screenX, size.height - tickHeight),
        Offset(screenX, size.height),
        tickPaint,
      );

      // Draw label for major ticks
      if (isMajor) {
        final displayValue = config.toDisplayValue(pos);
        textPainter.text = TextSpan(
          text: displayValue.round().toString(),
          style: TextStyle(
            color: config.textColor,
            fontSize: config.fontSize,
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(screenX + 2, 2),
        );
      }
    }

    // Bottom border
    canvas.drawLine(
      Offset(0, size.height - 1),
      Offset(size.width, size.height - 1),
      Paint()
        ..color = Colors.black26
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _HorizontalRulerPainter oldDelegate) {
    return scale != oldDelegate.scale ||
        offsetX != oldDelegate.offsetX ||
        viewportWidth != oldDelegate.viewportWidth;
  }
}

/// Vertical ruler painter
class _VerticalRulerPainter extends CustomPainter {
  final RulerConfig config;
  final double scale;
  final double offsetY;
  final double viewportHeight;

  _VerticalRulerPainter({
    required this.config,
    required this.scale,
    required this.offsetY,
    required this.viewportHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = config.backgroundColor,
    );

    // Calculate visible range
    final startCanvas = -offsetY / scale;
    final endCanvas = (viewportHeight - offsetY) / scale;

    // Determine tick interval based on zoom
    final baseInterval = config.majorInterval;
    double interval = baseInterval;

    if (scale < 0.25) {
      interval = baseInterval * 4;
    } else if (scale < 0.5) {
      interval = baseInterval * 2;
    } else if (scale > 2) {
      interval = baseInterval / 2;
    } else if (scale > 4) {
      interval = baseInterval / 4;
    }

    final minorInterval = interval / config.minorTicks;

    // Draw ticks
    final tickPaint = Paint()
      ..color = config.tickColor
      ..strokeWidth = 1;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Start from first tick before visible area
    final firstTick = (startCanvas / interval).floor() * interval;

    for (double pos = firstTick; pos <= endCanvas; pos += minorInterval) {
      final screenY = pos * scale + offsetY;
      if (screenY < 0 || screenY > viewportHeight) continue;

      final isMajor = (pos % interval).abs() < 0.001;
      final tickWidth = isMajor ? 10.0 : 5.0;

      canvas.drawLine(
        Offset(size.width - tickWidth, screenY),
        Offset(size.width, screenY),
        tickPaint,
      );

      // Draw label for major ticks (rotated)
      if (isMajor) {
        final displayValue = config.toDisplayValue(pos);
        textPainter.text = TextSpan(
          text: displayValue.round().toString(),
          style: TextStyle(
            color: config.textColor,
            fontSize: config.fontSize,
          ),
        );
        textPainter.layout();

        canvas.save();
        canvas.translate(2, screenY + textPainter.width + 2);
        canvas.rotate(-math.pi / 2);
        textPainter.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }

    // Right border
    canvas.drawLine(
      Offset(size.width - 1, 0),
      Offset(size.width - 1, size.height),
      Paint()
        ..color = Colors.black26
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _VerticalRulerPainter oldDelegate) {
    return scale != oldDelegate.scale ||
        offsetY != oldDelegate.offsetY ||
        viewportHeight != oldDelegate.viewportHeight;
  }
}

/// Individual guide widget
class _GuideWidget extends StatelessWidget {
  final Guide guide;
  final Matrix4 transform;
  final Size viewportSize;
  final double rulerThickness;
  final bool isDragging;
  final VoidCallback onDragStart;
  final ValueChanged<Offset> onDragUpdate;
  final ValueChanged<Offset> onDragEnd;
  final VoidCallback onDoubleTap;

  const _GuideWidget({
    required this.guide,
    required this.transform,
    required this.viewportSize,
    required this.rulerThickness,
    required this.isDragging,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDoubleTap,
  });

  double get _scale => transform.getMaxScaleOnAxis();
  Offset get _translation {
    final t = transform.getTranslation();
    return Offset(t.x, t.y);
  }

  double get _screenPosition {
    if (guide.orientation == GuideOrientation.horizontal) {
      return guide.position * _scale + _translation.dy;
    } else {
      return guide.position * _scale + _translation.dx;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHorizontal = guide.orientation == GuideOrientation.horizontal;
    final screenPos = _screenPosition;

    // Don't render if off screen
    if (isHorizontal) {
      if (screenPos < rulerThickness || screenPos > viewportSize.height) {
        return const SizedBox.shrink();
      }
    } else {
      if (screenPos < rulerThickness || screenPos > viewportSize.width) {
        return const SizedBox.shrink();
      }
    }

    return Positioned(
      left: isHorizontal ? rulerThickness : screenPos - 2,
      top: isHorizontal ? screenPos - 2 : rulerThickness,
      width: isHorizontal ? viewportSize.width - rulerThickness : 5,
      height: isHorizontal ? 5 : viewportSize.height - rulerThickness,
      child: GestureDetector(
        onPanStart: (_) => onDragStart(),
        onPanUpdate: (details) => onDragUpdate(details.globalPosition),
        onPanEnd: (details) => onDragEnd(details.localPosition),
        onDoubleTap: onDoubleTap,
        child: MouseRegion(
          cursor: isHorizontal
              ? SystemMouseCursors.resizeRow
              : SystemMouseCursors.resizeColumn,
          child: Container(
            decoration: BoxDecoration(
              color: isDragging
                  ? guide.color.withValues(alpha: 0.5)
                  : Colors.transparent,
            ),
            child: Center(
              child: Container(
                width: isHorizontal ? null : 1,
                height: isHorizontal ? 1 : null,
                color: guide.color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Guide manager for handling guide state
class GuideManager extends ChangeNotifier {
  final List<Guide> _guides = [];

  List<Guide> get guides => List.unmodifiable(_guides);

  void addGuide(Guide guide) {
    _guides.add(guide);
    notifyListeners();
  }

  void removeGuide(String id) {
    _guides.removeWhere((g) => g.id == id);
    notifyListeners();
  }

  void updateGuidePosition(String id, double position) {
    final guide = _guides.firstWhere((g) => g.id == id);
    guide.position = position;
    notifyListeners();
  }

  void toggleGuideLock(String id) {
    final guide = _guides.firstWhere((g) => g.id == id);
    guide.locked = !guide.locked;
    notifyListeners();
  }

  void clearGuides() {
    _guides.clear();
    notifyListeners();
  }

  /// Find guides near a position (for snapping)
  List<Guide> findGuidesNear(double position, GuideOrientation orientation,
      {double threshold = 5.0}) {
    return _guides
        .where((g) =>
            g.orientation == orientation &&
            (g.position - position).abs() <= threshold)
        .toList();
  }
}
