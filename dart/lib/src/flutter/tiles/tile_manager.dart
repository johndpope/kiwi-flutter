/// TileManager - manages tile-based rendering for large Figma documents
///
/// Coordinates between the Flutter UI and Rust tile renderer,
/// managing tile caching and async tile generation.

import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'viewport.dart';
import 'tile_painter.dart';
import 'tile_rasterizer.dart';

/// Configuration for the tile manager
class TileManagerConfig {
  /// Maximum number of tiles to keep in Flutter-side cache
  final int maxCachedTiles;

  /// Whether to show debug overlay
  final bool showDebugOverlay;

  /// Whether to show tile boundaries
  final bool showTileBounds;

  /// Debounce duration for viewport changes
  final Duration viewportDebounce;

  const TileManagerConfig({
    this.maxCachedTiles = 128,
    this.showDebugOverlay = false,
    this.showTileBounds = false,
    this.viewportDebounce = const Duration(milliseconds: 16),
  });
}

/// Manages tile-based rendering for a Figma document
class TileManager extends StatefulWidget {
  /// The document being rendered
  final dynamic document; // FigmaDocument from your existing code

  /// Root node ID to render from
  final String rootNodeId;

  /// Transformation controller for pan/zoom
  final TransformationController transformController;

  /// Configuration options
  final TileManagerConfig config;

  /// Optional overlay painter (for selections, guides, etc.)
  final CustomPainter? overlayPainter;

  /// Callback when document bounds are calculated
  final void Function(Rect bounds)? onBoundsCalculated;

  const TileManager({
    super.key,
    required this.document,
    required this.rootNodeId,
    required this.transformController,
    this.config = const TileManagerConfig(),
    this.overlayPainter,
    this.onBoundsCalculated,
  });

  @override
  State<TileManager> createState() => TileManagerState();
}

class TileManagerState extends State<TileManager> {
  /// Cache of rendered tile images
  final Map<TileCoord, ui.Image> _tileCache = {};

  /// Set of tiles currently being rendered
  final Set<TileCoord> _pendingTiles = {};

  /// Last calculated viewport
  WorldViewport? _lastViewport;

  /// Timer for viewport change debouncing
  Timer? _viewportDebounceTimer;

  /// Whether spatial index has been initialized
  bool _spatialIndexReady = false;

  /// Cache statistics
  int _cacheHits = 0;
  int _cacheMisses = 0;

  /// Rasterizer for converting draw commands to images
  late TileRasterizer _rasterizer;

  @override
  void initState() {
    super.initState();
    _rasterizer = TileRasterizer();
    widget.transformController.addListener(_onTransformChanged);
    _initSpatialIndex();
  }

  @override
  void dispose() {
    widget.transformController.removeListener(_onTransformChanged);
    _viewportDebounceTimer?.cancel();
    _disposeCache();
    super.dispose();
  }

  @override
  void didUpdateWidget(TileManager oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.transformController != widget.transformController) {
      oldWidget.transformController.removeListener(_onTransformChanged);
      widget.transformController.addListener(_onTransformChanged);
    }

    if (oldWidget.rootNodeId != widget.rootNodeId ||
        oldWidget.document != widget.document) {
      _clearCache();
      _initSpatialIndex();
    }
  }

  /// Initialize spatial index for the document
  Future<void> _initSpatialIndex() async {
    // This would call the Rust init_spatial_index function
    // For now, we mark it as ready
    setState(() {
      _spatialIndexReady = true;
    });

    // TODO: Call Rust API to initialize spatial index
    // final count = await rustBridge.initSpatialIndex(widget.document, widget.rootNodeId);
    // print('Spatial index initialized with $count nodes');
  }

  void _onTransformChanged() {
    _viewportDebounceTimer?.cancel();
    _viewportDebounceTimer = Timer(widget.config.viewportDebounce, () {
      if (mounted) {
        setState(() {
          // Trigger repaint with new viewport
        });
      }
    });
  }

  void _disposeCache() {
    for (final image in _tileCache.values) {
      image.dispose();
    }
    _tileCache.clear();
  }

  void _clearCache() {
    _disposeCache();
    _pendingTiles.clear();
    _cacheHits = 0;
    _cacheMisses = 0;
  }

  /// Request a tile to be rendered
  Future<void> _requestTile(TileCoord coord) async {
    // Don't request if already pending or cached
    if (_pendingTiles.contains(coord) || _tileCache.containsKey(coord)) {
      return;
    }

    _pendingTiles.add(coord);
    _cacheMisses++;

    try {
      // TODO: Call Rust API to get tile render result
      // final result = await rustBridge.renderSingleTile(
      //   widget.document,
      //   widget.rootNodeId,
      //   TileCoordInfo(x: coord.x, y: coord.y, zoomLevel: coord.zoomLevel),
      // );

      // For now, create a placeholder image
      final image = await _rasterizer.createPlaceholderTile(coord);

      if (mounted && !_tileCache.containsKey(coord)) {
        // Evict old tiles if over capacity
        _evictIfNeeded();

        setState(() {
          _tileCache[coord] = image;
          _pendingTiles.remove(coord);
        });
      } else {
        image.dispose();
      }
    } catch (e) {
      debugPrint('Error rendering tile $coord: $e');
      _pendingTiles.remove(coord);
    }
  }

  /// Evict least recently used tiles if over capacity
  void _evictIfNeeded() {
    while (_tileCache.length >= widget.config.maxCachedTiles) {
      // Simple LRU: remove first entry (oldest)
      final oldest = _tileCache.keys.first;
      _tileCache[oldest]?.dispose();
      _tileCache.remove(oldest);
    }
  }

  /// Invalidate tiles for changed nodes
  Future<void> invalidateTiles(List<String> changedNodeIds) async {
    // TODO: Call Rust API to get affected tiles
    // final dirtyCoords = await rustBridge.invalidateTiles(widget.document, changedNodeIds);

    // For now, clear entire cache
    _clearCache();
    if (mounted) {
      setState(() {});
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'cachedTiles': _tileCache.length,
      'pendingTiles': _pendingTiles.length,
      'maxTiles': widget.config.maxCachedTiles,
      'cacheHits': _cacheHits,
      'cacheMisses': _cacheMisses,
      'hitRate': _cacheHits + _cacheMisses > 0
          ? (_cacheHits / (_cacheHits + _cacheMisses) * 100).toStringAsFixed(1)
          : '0.0',
    };
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenSize = Size(
          constraints.maxWidth,
          constraints.maxHeight,
        );

        final viewport = WorldViewport.fromController(
          screenSize: screenSize,
          controller: widget.transformController,
        );

        _lastViewport = viewport;

        return Stack(
          children: [
            // Main tile canvas
            CustomPaint(
              painter: TilePainter(
                viewport: viewport,
                transform: widget.transformController.value,
                tileCache: _tileCache,
                onTileNeeded: _requestTile,
                showDebugBounds: widget.config.showTileBounds,
              ),
              size: screenSize,
            ),

            // Overlay painter
            if (widget.overlayPainter != null)
              CustomPaint(
                painter: widget.overlayPainter,
                size: screenSize,
              ),

            // Debug overlay
            if (widget.config.showDebugOverlay)
              CustomPaint(
                painter: TileDebugOverlay(
                  viewport: viewport,
                  transform: widget.transformController.value,
                  cachedTileCount: _tileCache.length,
                  maxTiles: widget.config.maxCachedTiles,
                  dirtyTiles: _pendingTiles.length,
                ),
                size: screenSize,
              ),
          ],
        );
      },
    );
  }
}

/// Widget that wraps TileManager with InteractiveViewer
class TileCanvas extends StatefulWidget {
  final dynamic document;
  final String rootNodeId;
  final TileManagerConfig config;
  final double minScale;
  final double maxScale;
  final void Function(Rect bounds)? onBoundsCalculated;
  final Widget Function(BuildContext, TileManagerState)? overlayBuilder;

  const TileCanvas({
    super.key,
    required this.document,
    required this.rootNodeId,
    this.config = const TileManagerConfig(),
    this.minScale = 0.1,
    this.maxScale = 10.0,
    this.onBoundsCalculated,
    this.overlayBuilder,
  });

  @override
  State<TileCanvas> createState() => _TileCanvasState();
}

class _TileCanvasState extends State<TileCanvas> {
  late TransformationController _transformController;
  final GlobalKey<TileManagerState> _tileManagerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _transformController = TransformationController();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer.builder(
      transformationController: _transformController,
      minScale: widget.minScale,
      maxScale: widget.maxScale,
      boundaryMargin: const EdgeInsets.all(double.infinity),
      builder: (context, quad) {
        return Stack(
          children: [
            TileManager(
              key: _tileManagerKey,
              document: widget.document,
              rootNodeId: widget.rootNodeId,
              transformController: _transformController,
              config: widget.config,
              onBoundsCalculated: widget.onBoundsCalculated,
            ),
            if (widget.overlayBuilder != null &&
                _tileManagerKey.currentState != null)
              widget.overlayBuilder!(context, _tileManagerKey.currentState!),
          ],
        );
      },
    );
  }
}
