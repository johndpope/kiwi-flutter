/// Tile Test Harness - Simple test widget for debugging tile rendering
///
/// Creates a minimal "document" with known shapes at known positions
/// to validate tile rendering, panning, and zooming behavior.

import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'viewport.dart';

/// A simple test widget that renders colored rectangles at known positions
/// without any of the Figma document complexity.
class TileTestHarness extends StatefulWidget {
  const TileTestHarness({super.key});

  @override
  State<TileTestHarness> createState() => _TileTestHarnessState();
}

class _TileTestHarnessState extends State<TileTestHarness> {
  late TransformationController _transformController;

  // Test shapes at known positions
  final List<TestShape> _shapes = [
    // Origin marker - red square at (0,0)
    TestShape(Rect.fromLTWH(0, 0, 200, 200), Colors.red, 'Origin (0,0)'),

    // Blue square at (500, 0)
    TestShape(Rect.fromLTWH(500, 0, 200, 200), Colors.blue, '(500,0)'),

    // Green square at (0, 500)
    TestShape(Rect.fromLTWH(0, 500, 200, 200), Colors.green, '(0,500)'),

    // Yellow square at (500, 500)
    TestShape(Rect.fromLTWH(500, 500, 200, 200), Colors.yellow, '(500,500)'),

    // Purple square at (1000, 1000) - outside initial view
    TestShape(Rect.fromLTWH(1000, 1000, 200, 200), Colors.purple, '(1000,1000)'),

    // Cyan square at (-500, -500) - negative coordinates
    TestShape(Rect.fromLTWH(-500, -500, 200, 200), Colors.cyan, '(-500,-500)'),

    // Large orange rectangle spanning multiple tiles
    TestShape(Rect.fromLTWH(1500, 0, 800, 400), Colors.orange, 'Large (1500,0)'),
  ];

  @override
  void initState() {
    super.initState();
    _transformController = TransformationController();

    // Start centered on origin with some padding
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerOnContent();
    });
  }

  void _centerOnContent() {
    // Calculate bounds of all shapes
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;

    for (final shape in _shapes) {
      minX = minX < shape.rect.left ? minX : shape.rect.left;
      minY = minY < shape.rect.top ? minY : shape.rect.top;
      maxX = maxX > shape.rect.right ? maxX : shape.rect.right;
      maxY = maxY > shape.rect.bottom ? maxY : shape.rect.bottom;
    }

    final contentBounds = Rect.fromLTRB(minX, minY, maxX, maxY);
    final screenSize = MediaQuery.of(context).size;

    // Calculate scale to fit with padding
    final scaleX = (screenSize.width - 100) / contentBounds.width;
    final scaleY = (screenSize.height - 100) / contentBounds.height;
    final scale = (scaleX < scaleY ? scaleX : scaleY).clamp(0.1, 2.0);

    // Calculate translation to center
    final contentCenterX = contentBounds.center.dx;
    final contentCenterY = contentBounds.center.dy;
    final translateX = screenSize.width / 2 - contentCenterX * scale;
    final translateY = screenSize.height / 2 - contentCenterY * scale;

    final matrix = Matrix4.identity();
    matrix.setEntry(0, 0, scale);
    matrix.setEntry(1, 1, scale);
    matrix.setEntry(0, 3, translateX);
    matrix.setEntry(1, 3, translateY);

    _transformController.value = matrix;
    debugPrint('TestHarness: Content bounds = $contentBounds');
    debugPrint('TestHarness: Initial transform - scale=$scale, translate=($translateX, $translateY)');
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('Tile Test Harness'),
        actions: [
          IconButton(
            icon: const Icon(Icons.center_focus_strong),
            onPressed: _centerOnContent,
            tooltip: 'Center on content',
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: () => _zoom(1.5),
            tooltip: 'Zoom in',
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: () => _zoom(0.67),
            tooltip: 'Zoom out',
          ),
        ],
      ),
      body: Stack(
        children: [
          // The canvas with pan/zoom
          GestureDetector(
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            child: Listener(
              onPointerSignal: _onPointerSignal,
              child: AnimatedBuilder(
                animation: _transformController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _TestHarnessPainter(
                      transform: _transformController.value,
                      shapes: _shapes,
                    ),
                    size: Size.infinite,
                  );
                },
              ),
            ),
          ),

          // Debug info overlay
          Positioned(
            top: 10,
            left: 10,
            child: AnimatedBuilder(
              animation: _transformController,
              builder: (context, _) => _buildDebugInfo(),
            ),
          ),

          // Tile grid overlay toggle
          Positioned(
            bottom: 10,
            left: 10,
            child: _buildControls(),
          ),
        ],
      ),
    );
  }

  Offset? _lastFocalPoint;
  double _startScale = 1.0;

  void _onScaleStart(ScaleStartDetails details) {
    _lastFocalPoint = details.localFocalPoint;
    _startScale = _transformController.value.getMaxScaleOnAxis();
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final matrix = _transformController.value.clone();
    final storage = matrix.storage;

    // Apply pan - directly in screen coordinates
    if (_lastFocalPoint != null) {
      final delta = details.localFocalPoint - _lastFocalPoint!;
      storage[12] += delta.dx;
      storage[13] += delta.dy;
    }

    // Apply scale around focal point
    if (details.scale != 1.0) {
      final focalPoint = details.localFocalPoint;
      final newScale = (_startScale * details.scale).clamp(0.05, 10.0);
      final currentScale = matrix.getMaxScaleOnAxis();
      final scaleChange = newScale / currentScale;

      storage[12] = focalPoint.dx - (focalPoint.dx - storage[12]) * scaleChange;
      storage[13] = focalPoint.dy - (focalPoint.dy - storage[13]) * scaleChange;
      storage[0] *= scaleChange;
      storage[5] *= scaleChange;
    }

    _transformController.value = matrix;
    _lastFocalPoint = details.localFocalPoint;
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final scale = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
      _zoomAt(scale, event.localPosition);
    }
  }

  void _zoom(double factor) {
    final size = MediaQuery.of(context).size;
    _zoomAt(factor, Offset(size.width / 2, size.height / 2));
  }

  void _zoomAt(double factor, Offset focalPoint) {
    final matrix = _transformController.value.clone();
    final tx = matrix.storage[12];
    final ty = matrix.storage[13];

    matrix.storage[12] = focalPoint.dx - (focalPoint.dx - tx) * factor;
    matrix.storage[13] = focalPoint.dy - (focalPoint.dy - ty) * factor;
    matrix.storage[0] *= factor;
    matrix.storage[5] *= factor;

    _transformController.value = matrix;
  }

  Widget _buildDebugInfo() {
    final matrix = _transformController.value;
    final scale = matrix.getMaxScaleOnAxis();
    final tx = matrix.storage[12];
    final ty = matrix.storage[13];

    // Calculate world position of screen center
    final screenSize = MediaQuery.of(context).size;
    final worldCenterX = (screenSize.width / 2 - tx) / scale;
    final worldCenterY = (screenSize.height / 2 - ty) / scale;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Scale: ${scale.toStringAsFixed(3)}x',
               style: const TextStyle(color: Colors.lime, fontSize: 12)),
          Text('Translation: (${tx.toInt()}, ${ty.toInt()})',
               style: const TextStyle(color: Colors.cyan, fontSize: 12)),
          Text('World Center: (${worldCenterX.toInt()}, ${worldCenterY.toInt()})',
               style: const TextStyle(color: Colors.orange, fontSize: 12)),
          const SizedBox(height: 8),
          const Text('Shapes:', style: TextStyle(color: Colors.white70, fontSize: 11)),
          for (final shape in _shapes.take(4))
            Text('  ${shape.label}',
                 style: TextStyle(color: shape.color, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: () {
              // Reset to identity
              _transformController.value = Matrix4.identity();
            },
            child: const Text('Reset'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _centerOnContent,
            child: const Text('Fit'),
          ),
        ],
      ),
    );
  }
}

/// Simple shape for testing
class TestShape {
  final Rect rect;
  final Color color;
  final String label;

  const TestShape(this.rect, this.color, this.label);
}

/// Painter that renders test shapes with world-to-screen transform
class _TestHarnessPainter extends CustomPainter {
  final Matrix4 transform;
  final List<TestShape> shapes;

  _TestHarnessPainter({
    required this.transform,
    required this.shapes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = transform.getMaxScaleOnAxis();
    final tx = transform.storage[12];
    final ty = transform.storage[13];

    // Draw background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF1A1A2E),
    );

    // Draw tile grid (world coordinates)
    _drawTileGrid(canvas, size, scale, tx, ty);

    // Draw each shape transformed to screen coordinates
    for (final shape in shapes) {
      final screenRect = Rect.fromLTWH(
        shape.rect.left * scale + tx,
        shape.rect.top * scale + ty,
        shape.rect.width * scale,
        shape.rect.height * scale,
      );

      // Fill
      canvas.drawRect(screenRect, Paint()..color = shape.color.withOpacity(0.7));

      // Border
      canvas.drawRect(screenRect, Paint()
        ..color = shape.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);

      // Label
      if (screenRect.width > 40) {
        final paragraphBuilder = ui.ParagraphBuilder(ui.ParagraphStyle(
          textAlign: TextAlign.center,
        ))
          ..pushStyle(ui.TextStyle(
            color: Colors.white,
            fontSize: (12 * scale).clamp(8, 14),
            fontWeight: ui.FontWeight.bold,
          ))
          ..addText(shape.label);

        final paragraph = paragraphBuilder.build()
          ..layout(ui.ParagraphConstraints(width: screenRect.width));

        canvas.drawParagraph(
          paragraph,
          Offset(screenRect.left, screenRect.center.dy - 8),
        );
      }
    }

    // Draw origin crosshair
    _drawOriginMarker(canvas, scale, tx, ty);
  }

  void _drawTileGrid(Canvas canvas, Size size, double scale, double tx, double ty) {
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final tileLabelStyle = ui.TextStyle(
      color: Colors.white.withOpacity(0.3),
      fontSize: 10,
    );

    // Calculate visible world area
    final worldLeft = -tx / scale;
    final worldTop = -ty / scale;
    final worldRight = (size.width - tx) / scale;
    final worldBottom = (size.height - ty) / scale;

    // Draw tile boundaries
    final tileSize = kTileSize.toDouble();
    final minTx = (worldLeft / tileSize).floor();
    final minTy = (worldTop / tileSize).floor();
    final maxTx = (worldRight / tileSize).ceil();
    final maxTy = (worldBottom / tileSize).ceil();

    for (var x = minTx; x <= maxTx; x++) {
      final screenX = x * tileSize * scale + tx;
      canvas.drawLine(
        Offset(screenX, 0),
        Offset(screenX, size.height),
        gridPaint,
      );
    }

    for (var y = minTy; y <= maxTy; y++) {
      final screenY = y * tileSize * scale + ty;
      canvas.drawLine(
        Offset(0, screenY),
        Offset(size.width, screenY),
        gridPaint,
      );
    }

    // Draw tile labels
    for (var x = minTx; x <= maxTx; x++) {
      for (var y = minTy; y <= maxTy; y++) {
        final screenX = x * tileSize * scale + tx + 4;
        final screenY = y * tileSize * scale + ty + 4;

        if (screenX > 0 && screenX < size.width && screenY > 0 && screenY < size.height) {
          final paragraphBuilder = ui.ParagraphBuilder(ui.ParagraphStyle())
            ..pushStyle(tileLabelStyle)
            ..addText('($x,$y)');

          final paragraph = paragraphBuilder.build()
            ..layout(const ui.ParagraphConstraints(width: 100));

          canvas.drawParagraph(paragraph, Offset(screenX, screenY));
        }
      }
    }
  }

  void _drawOriginMarker(Canvas canvas, double scale, double tx, double ty) {
    // World origin in screen coordinates
    final originX = tx;
    final originY = ty;

    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2;

    // Crosshair at origin
    canvas.drawLine(
      Offset(originX - 20, originY),
      Offset(originX + 20, originY),
      paint,
    );
    canvas.drawLine(
      Offset(originX, originY - 20),
      Offset(originX, originY + 20),
      paint,
    );

    // Circle at origin
    canvas.drawCircle(Offset(originX, originY), 5, paint..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant _TestHarnessPainter oldDelegate) {
    return transform != oldDelegate.transform;
  }
}
