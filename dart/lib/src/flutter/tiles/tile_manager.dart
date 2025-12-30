/// TileManager - manages tile-based rendering for large Figma documents
///
/// Coordinates between the Flutter UI and tile rendering backend,
/// managing tile caching and async tile generation.

import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'viewport.dart';
import 'tile_painter.dart';
import 'tile_backend.dart';

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

  /// Which backend to use
  final TileBackendType backendType;

  const TileManagerConfig({
    this.maxCachedTiles = 128,
    this.showDebugOverlay = false,
    this.showTileBounds = false,
    this.viewportDebounce = const Duration(milliseconds: 16),
    this.backendType = TileBackendType.rust,
  });

  TileManagerConfig copyWith({
    int? maxCachedTiles,
    bool? showDebugOverlay,
    bool? showTileBounds,
    Duration? viewportDebounce,
    TileBackendType? backendType,
  }) {
    return TileManagerConfig(
      maxCachedTiles: maxCachedTiles ?? this.maxCachedTiles,
      showDebugOverlay: showDebugOverlay ?? this.showDebugOverlay,
      showTileBounds: showTileBounds ?? this.showTileBounds,
      viewportDebounce: viewportDebounce ?? this.viewportDebounce,
      backendType: backendType ?? this.backendType,
    );
  }
}

/// Manages tile-based rendering for a Figma document
class TileManager extends StatefulWidget {
  /// The document being rendered (raw bytes or FigmaDocument)
  final dynamic document;

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

  /// Callback when backend changes
  final void Function(TileBackendType type)? onBackendChanged;

  const TileManager({
    super.key,
    required this.document,
    required this.rootNodeId,
    required this.transformController,
    this.config = const TileManagerConfig(),
    this.overlayPainter,
    this.onBoundsCalculated,
    this.onBackendChanged,
  });

  @override
  State<TileManager> createState() => TileManagerState();
}

class TileManagerState extends State<TileManager> {
  /// Cache of rendered tile images
  final Map<TileCoord, ui.Image> _tileCache = {};

  /// Set of tiles currently being rendered
  final Set<TileCoord> _pendingTiles = {};

  /// Last calculated viewport (reserved for viewport change detection)
  // ignore: unused_field
  WorldViewport? _lastViewport;

  /// Timer for viewport change debouncing
  Timer? _viewportDebounceTimer;

  /// The rendering backend
  late TileBackend _backend;

  /// Cache statistics
  int _cacheHits = 0;
  int _cacheMisses = 0;

  /// Current backend type
  late TileBackendType _currentBackendType;

  @override
  void initState() {
    super.initState();
    _currentBackendType = widget.config.backendType;
    _backend = TileBackendFactory.create(_currentBackendType);
    widget.transformController.addListener(_onTransformChanged);
    _initBackend();
  }

  @override
  void dispose() {
    widget.transformController.removeListener(_onTransformChanged);
    _viewportDebounceTimer?.cancel();
    _disposeCache();
    _backend.dispose();
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
      _initBackend();
    }

    if (oldWidget.config.backendType != widget.config.backendType) {
      _switchBackend(widget.config.backendType);
    }
  }

  /// Initialize the backend
  Future<void> _initBackend() async {
    try {
      await _backend.initialize(widget.document, widget.rootNodeId);
      if (mounted) {
        setState(() {});
        debugPrint('TileManager: Backend ${_backend.name} initialized');
      }
    } catch (e) {
      debugPrint('TileManager: Failed to initialize backend - $e');
      // Fall back to Dart backend if Rust fails
      if (_currentBackendType == TileBackendType.rust) {
        _switchBackend(TileBackendType.dart);
      }
    }
  }

  /// Switch to a different backend
  Future<void> _switchBackend(TileBackendType type) async {
    if (_currentBackendType == type) return;

    debugPrint('TileManager: Switching backend from $_currentBackendType to $type');

    // Dispose old backend
    _backend.dispose();
    _clearCache();

    // Create new backend
    _currentBackendType = type;
    _backend = TileBackendFactory.create(type);

    // Initialize new backend
    await _initBackend();

    widget.onBackendChanged?.call(type);
  }

  /// Public method to switch backend
  void setBackendType(TileBackendType type) {
    _switchBackend(type);
  }

  /// Get current backend type
  TileBackendType get backendType => _currentBackendType;

  /// Get backend name
  String get backendName => _backend.name;

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
    _backend.clearCache();
  }

  /// Request a tile to be rendered
  Future<void> _requestTile(TileCoord coord) async {
    // Don't request if already pending or cached
    if (_pendingTiles.contains(coord) || _tileCache.containsKey(coord)) {
      _cacheHits++;
      return;
    }

    _pendingTiles.add(coord);
    _cacheMisses++;

    try {
      final result = await _backend.renderTile(coord);

      if (result != null && mounted && !_tileCache.containsKey(coord)) {
        // Evict old tiles if over capacity
        _evictIfNeeded();

        setState(() {
          _tileCache[coord] = result.image;
          _pendingTiles.remove(coord);
        });
      } else if (result == null) {
        _pendingTiles.remove(coord);
      }
    } catch (e) {
      debugPrint('TileManager: Error rendering tile $coord - $e');
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
    await _backend.invalidateTiles(changedNodeIds);
    _clearCache();
    if (mounted) {
      setState(() {});
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'backend': _backend.name,
      'backendReady': _backend.isReady,
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

            // Backend indicator
            if (widget.config.showDebugOverlay)
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _backend.isReady
                        ? Colors.green.withValues(alpha: 0.8)
                        : Colors.orange.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _backend.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
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
  final void Function(TileBackendType)? onBackendChanged;

  const TileCanvas({
    super.key,
    required this.document,
    required this.rootNodeId,
    this.config = const TileManagerConfig(),
    this.minScale = 0.1,
    this.maxScale = 10.0,
    this.onBoundsCalculated,
    this.overlayBuilder,
    this.onBackendChanged,
  });

  @override
  State<TileCanvas> createState() => TileCanvasState();
}

class TileCanvasState extends State<TileCanvas> {
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

  /// Get tile manager state
  TileManagerState? get tileManager => _tileManagerKey.currentState;

  /// Switch backend type
  void setBackendType(TileBackendType type) {
    _tileManagerKey.currentState?.setBackendType(type);
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
              onBackendChanged: widget.onBackendChanged,
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

/// Backend toggle widget
class BackendToggle extends StatelessWidget {
  final TileBackendType currentType;
  final void Function(TileBackendType) onChanged;

  const BackendToggle({
    super.key,
    required this.currentType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<TileBackendType>(
      segments: const [
        ButtonSegment(
          value: TileBackendType.rust,
          label: Text('Rust'),
          icon: Icon(Icons.speed),
        ),
        ButtonSegment(
          value: TileBackendType.dart,
          label: Text('Dart'),
          icon: Icon(Icons.code),
        ),
      ],
      selected: {currentType},
      onSelectionChanged: (selected) {
        onChanged(selected.first);
      },
    );
  }
}
