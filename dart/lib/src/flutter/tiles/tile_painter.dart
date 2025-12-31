/// Tile-based CustomPainter for efficient canvas rendering
///
/// Renders only visible tiles from a tile cache, requesting
/// missing tiles asynchronously.

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'viewport.dart';

/// Callback for requesting a tile to be rendered
typedef TileRequestCallback = void Function(TileCoord coord);

/// Painter that renders cached tiles on the canvas
class TilePainter extends CustomPainter {
  /// Current viewport in world coordinates
  final WorldViewport viewport;

  /// Transformation matrix for converting world to screen
  final Matrix4 transform;

  /// Cache of rendered tile images
  final Map<TileCoord, ui.Image> tileCache;

  /// Callback when a tile is needed but not in cache
  final TileRequestCallback? onTileNeeded;

  /// Whether to show debug tile boundaries
  final bool showDebugBounds;

  /// Paint for tile borders in debug mode
  static final _debugBorderPaint = Paint()
    ..color = Colors.cyan
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.0;

  /// Paint for placeholder tiles - use a checkerboard pattern
  static final _placeholderPaint = Paint()
    ..color = const Color(0xFF2A2A2A);

  /// Text style for debug info
  static final _debugTextStyle = ui.TextStyle(
    color: Colors.white.withValues(alpha: 0.7),
    fontSize: 12,
  );

  TilePainter({
    required this.viewport,
    required this.transform,
    required this.tileCache,
    this.onTileNeeded,
    this.showDebugBounds = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF1A1A1A),
    );

    final visibleTiles = getVisibleTiles(viewport);
    final requestedTiles = <TileCoord>{};

    for (final coord in visibleTiles) {
      final tileBounds = coord.bounds;
      final screenBounds = _worldRectToScreen(tileBounds);

      if (tileCache.containsKey(coord)) {
        // Draw cached tile image
        final image = tileCache[coord]!;
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          screenBounds,
          Paint()..filterQuality = FilterQuality.medium,
        );
      } else {
        // Draw placeholder
        _drawPlaceholder(canvas, screenBounds, coord);

        // Request tile if not already requested this frame
        if (!requestedTiles.contains(coord)) {
          requestedTiles.add(coord);
          onTileNeeded?.call(coord);
        }
      }

      // Debug: draw tile boundaries
      if (showDebugBounds) {
        _drawDebugInfo(canvas, screenBounds, coord);
      }
    }
  }

  /// Draw a visible debug grid pattern
  void _drawDebugGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const gridSize = 100.0;
    for (var x = 0.0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw center crosshair
    final centerPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawLine(center - const Offset(50, 0), center + const Offset(50, 0), centerPaint);
    canvas.drawLine(center - const Offset(0, 50), center + const Offset(0, 50), centerPaint);
  }

  Rect _worldRectToScreen(Rect worldRect) {
    final translation = transform.getTranslation();
    final scale = transform.getMaxScaleOnAxis();

    return Rect.fromLTWH(
      worldRect.left * scale + translation.x,
      worldRect.top * scale + translation.y,
      worldRect.width * scale,
      worldRect.height * scale,
    );
  }

  void _drawPlaceholder(Canvas canvas, Rect bounds, TileCoord coord) {
    // Checkerboard color based on tile position
    final isEven = (coord.x + coord.y) % 2 == 0;
    final bgColor = isEven ? const Color(0xFF333333) : const Color(0xFF444444);

    // Draw background
    canvas.drawRect(bounds, Paint()..color = bgColor);

    // Draw visible grid pattern inside tile
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const gridSize = 50.0;
    for (var x = bounds.left; x < bounds.right; x += gridSize) {
      canvas.drawLine(Offset(x, bounds.top), Offset(x, bounds.bottom), gridPaint);
    }
    for (var y = bounds.top; y < bounds.bottom; y += gridSize) {
      canvas.drawLine(Offset(bounds.left, y), Offset(bounds.right, y), gridPaint);
    }

    // Draw tile coordinate in center
    final paragraphBuilder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: TextAlign.center,
    ))
      ..pushStyle(ui.TextStyle(
        color: Colors.yellow,
        fontSize: 16,
        fontWeight: ui.FontWeight.bold,
      ))
      ..addText('TILE\n(${coord.x}, ${coord.y})\nz${coord.zoomLevel}');

    final paragraph = paragraphBuilder.build()
      ..layout(ui.ParagraphConstraints(width: bounds.width));

    canvas.drawParagraph(
      paragraph,
      Offset(bounds.left, bounds.center.dy - 30),
    );
  }

  void _drawDebugInfo(Canvas canvas, Rect bounds, TileCoord coord) {
    // Draw border
    canvas.drawRect(bounds, _debugBorderPaint);

    // Draw tile coordinate text
    final paragraphBuilder = ui.ParagraphBuilder(ui.ParagraphStyle())
      ..pushStyle(_debugTextStyle)
      ..addText('(${coord.x}, ${coord.y}) z${coord.zoomLevel}');

    final paragraph = paragraphBuilder.build()
      ..layout(const ui.ParagraphConstraints(width: 200));

    canvas.drawParagraph(
      paragraph,
      Offset(bounds.left + 4, bounds.top + 4),
    );
  }

  @override
  bool shouldRepaint(TilePainter oldDelegate) {
    return viewport != oldDelegate.viewport ||
        tileCache.length != oldDelegate.tileCache.length ||
        showDebugBounds != oldDelegate.showDebugBounds;
  }
}

/// Painter that combines tile rendering with overlay content
class TileCanvasPainter extends CustomPainter {
  final TilePainter tilePainter;
  final CustomPainter? overlayPainter;

  TileCanvasPainter({
    required this.tilePainter,
    this.overlayPainter,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // First paint tiles
    tilePainter.paint(canvas, size);

    // Then paint overlay (selections, guides, etc.)
    overlayPainter?.paint(canvas, size);
  }

  @override
  bool shouldRepaint(TileCanvasPainter oldDelegate) {
    return tilePainter.shouldRepaint(oldDelegate.tilePainter) ||
        (overlayPainter?.shouldRepaint(oldDelegate.overlayPainter!) ?? false);
  }
}

/// Debug overlay painter showing tile grid and cache stats
class TileDebugOverlay extends CustomPainter {
  final WorldViewport viewport;
  final Matrix4 transform;
  final int cachedTileCount;
  final int maxTiles;
  final int dirtyTiles;

  TileDebugOverlay({
    required this.viewport,
    required this.transform,
    required this.cachedTileCount,
    required this.maxTiles,
    required this.dirtyTiles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final visibleTiles = getVisibleTiles(viewport);

    // Draw stats in corner
    final statsText = [
      'Viewport: ${viewport.x.toStringAsFixed(0)}, ${viewport.y.toStringAsFixed(0)}',
      'Size: ${viewport.width.toStringAsFixed(0)} x ${viewport.height.toStringAsFixed(0)}',
      'Scale: ${viewport.scale.toStringAsFixed(2)}x (LOD ${viewport.lod})',
      'Visible tiles: ${visibleTiles.length}',
      'Cached: $cachedTileCount / $maxTiles',
      'Dirty: $dirtyTiles',
    ].join('\n');

    final paragraphBuilder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: TextAlign.left,
    ))
      ..pushStyle(ui.TextStyle(
        color: Colors.white,
        fontSize: 11,
        background: Paint()..color = Colors.black.withValues(alpha: 0.7),
      ))
      ..addText(statsText);

    final paragraph = paragraphBuilder.build()
      ..layout(const ui.ParagraphConstraints(width: 300));

    canvas.drawParagraph(paragraph, const Offset(10, 10));
  }

  @override
  bool shouldRepaint(TileDebugOverlay oldDelegate) {
    return viewport != oldDelegate.viewport ||
        cachedTileCount != oldDelegate.cachedTileCount;
  }
}
