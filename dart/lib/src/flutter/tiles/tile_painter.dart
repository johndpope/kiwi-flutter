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
    // Use LOD-specific color for border
    final lodColor = kLodColors[coord.zoomLevel.clamp(0, 4)];
    final borderPaint = Paint()
      ..color = lodColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // Draw border with LOD color
    canvas.drawRect(bounds, borderPaint);

    // Draw corner indicators to show tile boundaries more clearly
    const cornerSize = 12.0;
    final cornerPaint = Paint()
      ..color = lodColor
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;

    // Top-left corner
    canvas.drawLine(bounds.topLeft, bounds.topLeft + const Offset(cornerSize, 0), cornerPaint);
    canvas.drawLine(bounds.topLeft, bounds.topLeft + const Offset(0, cornerSize), cornerPaint);

    // Top-right corner
    canvas.drawLine(bounds.topRight, bounds.topRight + const Offset(-cornerSize, 0), cornerPaint);
    canvas.drawLine(bounds.topRight, bounds.topRight + const Offset(0, cornerSize), cornerPaint);

    // Bottom-left corner
    canvas.drawLine(bounds.bottomLeft, bounds.bottomLeft + const Offset(cornerSize, 0), cornerPaint);
    canvas.drawLine(bounds.bottomLeft, bounds.bottomLeft + const Offset(0, -cornerSize), cornerPaint);

    // Bottom-right corner
    canvas.drawLine(bounds.bottomRight, bounds.bottomRight + const Offset(-cornerSize, 0), cornerPaint);
    canvas.drawLine(bounds.bottomRight, bounds.bottomRight + const Offset(0, -cornerSize), cornerPaint);

    // Draw tile coordinate text with LOD indicator
    final paragraphBuilder = ui.ParagraphBuilder(ui.ParagraphStyle())
      ..pushStyle(ui.TextStyle(
        color: Colors.white,
        fontSize: 11,
        background: Paint()..color = lodColor.withValues(alpha: 0.8),
      ))
      ..addText(' (${coord.x}, ${coord.y}) LOD${coord.zoomLevel} ');

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

/// LOD color coding for debug visualization
/// LOD 0 (finest) to LOD 4 (coarsest)
const List<Color> kLodColors = [
  Colors.red,      // LOD 0: 256px tiles (finest, zoomed in)
  Colors.orange,   // LOD 1: 512px tiles
  Colors.yellow,   // LOD 2: 1024px tiles (base)
  Colors.green,    // LOD 3: 2048px tiles
  Colors.blue,     // LOD 4: 4096px tiles (coarsest, overview)
];

/// LOD names for display
const List<String> kLodNames = [
  'Finest (256px)',
  'High (512px)',
  'Base (1024px)',
  'Low (2048px)',
  'Coarse (4096px)',
];

/// Debug overlay painter showing tile grid and cache stats
class TileDebugOverlay extends CustomPainter {
  final WorldViewport viewport;
  final Matrix4 transform;
  final int cachedTileCount;
  final int maxTiles;
  final int dirtyTiles;

  /// Number of tiles in the request queue
  final int queueDepth;

  /// Number of currently active tile renders
  final int activeRenders;

  /// Maximum concurrent renders allowed
  final int maxConcurrentRenders;

  /// Number of prefetch rings configured
  final int prefetchRings;

  /// Number of prefetch tiles currently requested
  final int prefetchTileCount;

  TileDebugOverlay({
    required this.viewport,
    required this.transform,
    required this.cachedTileCount,
    required this.maxTiles,
    required this.dirtyTiles,
    this.queueDepth = 0,
    this.activeRenders = 0,
    this.maxConcurrentRenders = 4,
    this.prefetchRings = 1,
    this.prefetchTileCount = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final visibleTiles = getVisibleTiles(viewport);
    final lod = viewport.lod;
    final lodColor = kLodColors[lod.clamp(0, 4)];
    final lodName = kLodNames[lod.clamp(0, 4)];

    // Draw LOD indicator bar at top
    _drawLodIndicator(canvas, size, lod);

    // Draw stats in corner
    final statsText = [
      'Viewport: ${viewport.x.toStringAsFixed(0)}, ${viewport.y.toStringAsFixed(0)}',
      'Size: ${viewport.width.toStringAsFixed(0)} x ${viewport.height.toStringAsFixed(0)}',
      'Scale: ${viewport.scale.toStringAsFixed(2)}x',
      'LOD: $lod - $lodName',
      'Tile size: ${viewport.effectiveTileSize.toInt()}px',
      '─────────────────',
      'Visible tiles: ${visibleTiles.length}',
      'Cached: $cachedTileCount / $maxTiles',
      'Dirty: $dirtyTiles',
      '─────────────────',
      'Queue: $queueDepth ($activeRenders/$maxConcurrentRenders active)',
      'Prefetch: $prefetchRings ring${prefetchRings != 1 ? 's' : ''} ($prefetchTileCount tiles)',
    ].join('\n');

    // Background rect for stats
    final bgPaint = Paint()..color = Colors.black.withValues(alpha: 0.8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(8, 30, 220, 195),
        const Radius.circular(6),
      ),
      bgPaint,
    );

    // LOD color indicator stripe on left side of stats panel
    final lodStripePaint = Paint()..color = lodColor;
    canvas.drawRect(
      const Rect.fromLTWH(8, 30, 4, 195),
      lodStripePaint,
    );

    final paragraphBuilder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: TextAlign.left,
    ))
      ..pushStyle(ui.TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontFamily: 'monospace',
      ))
      ..addText(statsText);

    final paragraph = paragraphBuilder.build()
      ..layout(const ui.ParagraphConstraints(width: 210));

    canvas.drawParagraph(paragraph, const Offset(18, 38));
  }

  /// Draw LOD level indicator bar at top of screen
  void _drawLodIndicator(Canvas canvas, Size size, int currentLod) {
    const barHeight = 20.0;
    const barPadding = 8.0;
    final barWidth = (size.width - barPadding * 2) / 5;

    for (int i = 0; i < 5; i++) {
      final isActive = i == currentLod;
      final rect = Rect.fromLTWH(
        barPadding + i * barWidth,
        barPadding,
        barWidth - 2,
        barHeight,
      );

      // Background
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()
          ..color = isActive
              ? kLodColors[i]
              : kLodColors[i].withValues(alpha: 0.3),
      );

      // Border for active LOD
      if (isActive) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }

      // Label
      final label = 'LOD $i';
      final paragraphBuilder = ui.ParagraphBuilder(ui.ParagraphStyle(
        textAlign: TextAlign.center,
      ))
        ..pushStyle(ui.TextStyle(
          color: isActive ? Colors.black : Colors.white.withValues(alpha: 0.7),
          fontSize: 10,
          fontWeight: isActive ? ui.FontWeight.bold : ui.FontWeight.normal,
        ))
        ..addText(label);

      final paragraph = paragraphBuilder.build()
        ..layout(ui.ParagraphConstraints(width: barWidth - 4));

      canvas.drawParagraph(
        paragraph,
        Offset(rect.left + 2, rect.top + 4),
      );
    }
  }

  @override
  bool shouldRepaint(TileDebugOverlay oldDelegate) {
    return viewport != oldDelegate.viewport ||
        cachedTileCount != oldDelegate.cachedTileCount ||
        queueDepth != oldDelegate.queueDepth ||
        activeRenders != oldDelegate.activeRenders ||
        prefetchTileCount != oldDelegate.prefetchTileCount;
  }
}
