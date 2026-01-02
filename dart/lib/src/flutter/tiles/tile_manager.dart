/// TileManager - manages tile-based rendering for large Figma documents
///
/// Coordinates between the Flutter UI and tile rendering backend,
/// managing tile caching and async tile generation.

import 'dart:async';
import 'dart:collection';
import 'dart:io' as io;
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'viewport.dart';
import 'tile_painter.dart';
import 'tile_backend.dart';

/// Priority levels for tile requests
enum TilePriority {
  critical,   // Center of viewport - render immediately
  high,       // Visible tiles - render soon
  medium,     // Adjacent prefetch tiles - render when idle
  low,        // Far prefetch tiles - render last
}

/// A tile render request with priority and distance info
class TileRequest implements Comparable<TileRequest> {
  final TileCoord coord;
  final TilePriority priority;
  final double distanceFromCenter;
  final DateTime requestTime;

  TileRequest({
    required this.coord,
    required this.priority,
    required this.distanceFromCenter,
  }) : requestTime = DateTime.now();

  @override
  int compareTo(TileRequest other) {
    // Sort by priority first (lower index = higher priority)
    final priorityCompare = priority.index.compareTo(other.priority.index);
    if (priorityCompare != 0) return priorityCompare;
    // Then by distance (closer = higher priority)
    return distanceFromCenter.compareTo(other.distanceFromCenter);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TileRequest && coord == other.coord;

  @override
  int get hashCode => coord.hashCode;
}

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

  /// Number of tile rings to prefetch beyond visible viewport
  final int prefetchRings;

  /// Maximum concurrent tile renders
  final int maxConcurrentRenders;

  const TileManagerConfig({
    this.maxCachedTiles = 128,
    this.showDebugOverlay = false,
    this.showTileBounds = false,
    this.viewportDebounce = const Duration(milliseconds: 16),
    this.backendType = TileBackendType.rust,
    this.prefetchRings = 1,
    this.maxConcurrentRenders = 4,
  });

  TileManagerConfig copyWith({
    int? maxCachedTiles,
    bool? showDebugOverlay,
    bool? showTileBounds,
    Duration? viewportDebounce,
    TileBackendType? backendType,
    int? prefetchRings,
    int? maxConcurrentRenders,
  }) {
    return TileManagerConfig(
      maxCachedTiles: maxCachedTiles ?? this.maxCachedTiles,
      showDebugOverlay: showDebugOverlay ?? this.showDebugOverlay,
      showTileBounds: showTileBounds ?? this.showTileBounds,
      viewportDebounce: viewportDebounce ?? this.viewportDebounce,
      backendType: backendType ?? this.backendType,
      prefetchRings: prefetchRings ?? this.prefetchRings,
      maxConcurrentRenders: maxConcurrentRenders ?? this.maxConcurrentRenders,
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

  /// Callback when a tile is rendered (for triggering parent rebuilds)
  final void Function(TileCoord coord, ui.Image image)? onTileRendered;

  /// Callback when state is ready (for parent to get reference)
  final void Function(TileManagerState state)? onStateReady;

  /// Explicit screen size (used when inside InteractiveViewer)
  final Size? screenSize;

  const TileManager({
    super.key,
    required this.document,
    required this.rootNodeId,
    required this.transformController,
    this.config = const TileManagerConfig(),
    this.overlayPainter,
    this.onBoundsCalculated,
    this.onBackendChanged,
    this.onTileRendered,
    this.onStateReady,
    this.screenSize,
  });

  @override
  State<TileManager> createState() => TileManagerState();
}

class TileManagerState extends State<TileManager> {
  /// Cache of rendered tile images
  final Map<TileCoord, ui.Image> _tileCache = {};

  /// Priority queue for tile requests (sorted by priority then distance)
  final SplayTreeSet<TileRequest> _requestQueue = SplayTreeSet();

  /// Map for quick lookup of pending tiles
  final Map<TileCoord, TileRequest> _pendingTiles = {};

  /// Number of tiles currently being rendered
  int _activeRenders = 0;

  /// Last calculated viewport (reserved for viewport change detection)
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

  /// Counter to force rebuilds when cache is invalidated
  int _updateCounter = 0;

  /// Get queue depth for debugging
  int get queueDepth => _requestQueue.length;

  /// Get active render count for debugging
  int get activeRenders => _activeRenders;

  @override
  void initState() {
    super.initState();
    _currentBackendType = widget.config.backendType;
    _backend = TileBackendFactory.create(_currentBackendType);
    widget.transformController.addListener(_onTransformChanged);
    _initBackend();
    // Notify parent that state is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onStateReady?.call(this);
    });
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
      // Set up callback to trigger re-render when images load
      _backend.onCacheInvalidated = () {
        if (mounted) {
          debugPrint('TileManager: Cache invalidated, clearing tile cache and re-rendering');
          // Clear our local tile cache so tiles are re-requested with new images
          _disposeCache();
          _requestQueue.clear();
          _pendingTiles.clear();
          _activeRenders = 0;
          setState(() {
            _updateCounter++;  // Force rebuild
          });
        }
      };

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
    // Don't manually dispose images - they may still be referenced by CustomPainter.
    // Just clear the cache map and let Dart's garbage collector handle disposal
    // when the images are no longer referenced.
    _tileCache.clear();
  }

  void _clearCache() {
    _disposeCache();
    _requestQueue.clear();
    _pendingTiles.clear();
    _activeRenders = 0;
    _cacheHits = 0;
    _cacheMisses = 0;
    _backend.clearCache();
  }

  /// Request a tile to be rendered (legacy method - wraps priority version)
  Future<void> _requestTile(TileCoord coord) async {
    // Use default high priority for direct requests
    _requestTileWithPriority(coord, TilePriority.high, Offset.zero);
  }

  /// Request a tile with priority and distance info
  void _requestTileWithPriority(
    TileCoord coord,
    TilePriority priority,
    Offset viewportCenter,
  ) {
    // Don't request if already pending or cached
    if (_pendingTiles.containsKey(coord) || _tileCache.containsKey(coord)) {
      _cacheHits++;
      return;
    }

    _cacheMisses++;

    // Calculate distance from viewport center
    final tileBounds = coord.bounds;
    final tileCenter = tileBounds.center;
    final distance = sqrt(
      pow(tileCenter.dx - viewportCenter.dx, 2) +
      pow(tileCenter.dy - viewportCenter.dy, 2),
    );

    final request = TileRequest(
      coord: coord,
      priority: priority,
      distanceFromCenter: distance,
    );

    _requestQueue.add(request);
    _pendingTiles[coord] = request;

    // Process the queue
    _processQueue();
  }

  /// Process pending tile requests respecting concurrency limit
  void _processQueue() {
    while (_activeRenders < widget.config.maxConcurrentRenders &&
           _requestQueue.isNotEmpty) {
      final request = _requestQueue.first;
      _requestQueue.remove(request);
      _activeRenders++;

      _renderTileAsync(request.coord);
    }
  }

  /// Render a tile asynchronously
  Future<void> _renderTileAsync(TileCoord coord) async {
    try {
      final result = await _backend.renderTile(coord);

      if (result != null && mounted && !_tileCache.containsKey(coord)) {
        // Evict old tiles if over capacity
        _evictIfNeeded();

        _tileCache[coord] = result.image;

        // Notify parent that a tile was rendered
        widget.onTileRendered?.call(coord, result.image);

        setState(() {});
      }
    } catch (e) {
      debugPrint('TileManager: Error rendering tile $coord - $e');
    } finally {
      _pendingTiles.remove(coord);
      _activeRenders--;
      // Process next tile in queue
      _processQueue();
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

  /// Request visible and prefetch tiles with proper priority
  void requestTilesForViewport(WorldViewport viewport, Size screenSize) {
    final viewportCenter = Offset(
      viewport.x + viewport.width / 2,
      viewport.y + viewport.height / 2,
    );

    final lod = viewport.lod;
    final tileSize = viewport.effectiveTileSize;

    // Calculate visible tile range
    final minTx = (viewport.x / tileSize).floor();
    final minTy = (viewport.y / tileSize).floor();
    final maxTx = ((viewport.x + viewport.width) / tileSize).ceil();
    final maxTy = ((viewport.y + viewport.height) / tileSize).ceil();

    // Calculate viewport diagonal for priority thresholds
    final viewportDiagonal = sqrt(
      pow(screenSize.width, 2) + pow(screenSize.height, 2),
    );

    // Request visible tiles with appropriate priority
    for (var tx = minTx; tx <= maxTx; tx++) {
      for (var ty = minTy; ty <= maxTy; ty++) {
        final coord = TileCoord(tx, ty, lod);
        final priority = _calculateVisibleTilePriority(
          coord, viewportCenter, viewportDiagonal,
        );
        _requestTileWithPriority(coord, priority, viewportCenter);
      }
    }

    // Request prefetch tiles with lower priority
    if (widget.config.prefetchRings > 0) {
      _requestPrefetchTiles(
        minTx, minTy, maxTx, maxTy, lod, viewportCenter,
      );
    }
  }

  /// Calculate priority for a visible tile based on distance from center
  TilePriority _calculateVisibleTilePriority(
    TileCoord coord,
    Offset viewportCenter,
    double viewportDiagonal,
  ) {
    final tileBounds = coord.bounds;
    final tileCenter = tileBounds.center;
    final distance = sqrt(
      pow(tileCenter.dx - viewportCenter.dx, 2) +
      pow(tileCenter.dy - viewportCenter.dy, 2),
    );

    // Center 25% of viewport = critical priority
    if (distance < viewportDiagonal * 0.25) {
      return TilePriority.critical;
    }
    return TilePriority.high;
  }

  /// Request prefetch tiles around the visible area
  void _requestPrefetchTiles(
    int minTx, int minTy, int maxTx, int maxTy,
    int lod, Offset viewportCenter,
  ) {
    for (int ring = 1; ring <= widget.config.prefetchRings; ring++) {
      // Top and bottom edges
      for (int tx = minTx - ring; tx <= maxTx + ring; tx++) {
        _requestTileWithPriority(
          TileCoord(tx, minTy - ring, lod),
          TilePriority.medium,
          viewportCenter,
        );
        _requestTileWithPriority(
          TileCoord(tx, maxTy + ring, lod),
          TilePriority.medium,
          viewportCenter,
        );
      }
      // Left and right edges (excluding corners already done)
      for (int ty = minTy - ring + 1; ty <= maxTy + ring - 1; ty++) {
        _requestTileWithPriority(
          TileCoord(minTx - ring, ty, lod),
          TilePriority.medium,
          viewportCenter,
        );
        _requestTileWithPriority(
          TileCoord(maxTx + ring, ty, lod),
          TilePriority.medium,
          viewportCenter,
        );
      }
    }
  }

  /// Count how many prefetch tiles would be requested for the current viewport
  int _countPrefetchTiles(WorldViewport viewport) {
    if (widget.config.prefetchRings <= 0) return 0;

    final tileSize = viewport.effectiveTileSize;
    final minTx = (viewport.x / tileSize).floor();
    final minTy = (viewport.y / tileSize).floor();
    final maxTx = ((viewport.x + viewport.width) / tileSize).ceil();
    final maxTy = ((viewport.y + viewport.height) / tileSize).ceil();

    int count = 0;
    for (int ring = 1; ring <= widget.config.prefetchRings; ring++) {
      // Top and bottom edges
      count += 2 * (maxTx - minTx + 1 + 2 * ring);
      // Left and right edges (excluding corners already counted)
      count += 2 * (maxTy - minTy + 1 + 2 * ring - 2);
    }
    return count;
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'backend': _backend.name,
      'backendReady': _backend.isReady,
      'cachedTiles': _tileCache.length,
      'pendingTiles': _pendingTiles.length,
      'queueDepth': _requestQueue.length,
      'activeRenders': _activeRenders,
      'maxConcurrent': widget.config.maxConcurrentRenders,
      'prefetchRings': widget.config.prefetchRings,
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
    // Use explicit screenSize if provided (from TileCanvas), otherwise use LayoutBuilder
    if (widget.screenSize != null) {
      return _buildContent(widget.screenSize!);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenSize = Size(
          constraints.maxWidth.isFinite ? constraints.maxWidth : 800,
          constraints.maxHeight.isFinite ? constraints.maxHeight : 600,
        );
        return _buildContent(screenSize);
      },
    );
  }

  Widget _buildContent(Size screenSize) {
    final viewport = WorldViewport.fromController(
      screenSize: screenSize,
      controller: widget.transformController,
    );

    _lastViewport = viewport;

    return Stack(
      children: [
        // Main tile canvas
        Positioned.fill(
          child: CustomPaint(
            painter: TilePainter(
              viewport: viewport,
              transform: widget.transformController.value,
              tileCache: _tileCache,
              onTileNeeded: _requestTile,
              showDebugBounds: widget.config.showTileBounds,
            ),
            size: screenSize,
          ),
        ),

        // Overlay painter
        if (widget.overlayPainter != null)
          Positioned.fill(
            child: CustomPaint(
              painter: widget.overlayPainter,
              size: screenSize,
            ),
          ),

        // Debug overlay
        if (widget.config.showDebugOverlay)
          Positioned.fill(
            child: CustomPaint(
              painter: TileDebugOverlay(
                viewport: viewport,
                transform: widget.transformController.value,
                cachedTileCount: _tileCache.length,
                maxTiles: widget.config.maxCachedTiles,
                dirtyTiles: _pendingTiles.length,
                queueDepth: _requestQueue.length,
                activeRenders: _activeRenders,
                maxConcurrentRenders: widget.config.maxConcurrentRenders,
                prefetchRings: widget.config.prefetchRings,
                prefetchTileCount: _countPrefetchTiles(viewport),
              ),
              size: screenSize,
            ),
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
  Size _screenSize = Size.zero;
  int _tileUpdateCount = 0;  // Counter to trigger rebuilds when tiles are rendered
  Rect? _contentBounds;  // Bounds of the page content
  bool _initialTransformSet = false;

  // Track the TileManager state via callback instead of GlobalKey
  TileManagerState? _tileManagerState;

  // Queue for tile requests before backend is ready
  final Set<TileCoord> _pendingTileRequests = {};

  // Key for capturing screenshots
  final GlobalKey _repaintBoundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _transformController = TransformationController();
    _calculateContentBounds();
  }

  @override
  void didUpdateWidget(TileCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Recalculate bounds when page changes
    if (oldWidget.rootNodeId != widget.rootNodeId ||
        oldWidget.document != widget.document) {
      _initialTransformSet = false;  // Reset so we center on new content
      _contentBounds = null;
      _tileManagerState = null;  // Clear reference, new one will be set via callback
      // Reset LOD state for new page
      resetLodState();
      _calculateContentBounds();
    }
  }

  /// Calculate the bounds of all content on the current page
  void _calculateContentBounds() {
    final doc = widget.document;
    final nodeMap = doc.nodeMap;

    // Get the page node
    final pageNode = nodeMap[widget.rootNodeId];
    if (pageNode == null) {
      debugPrint('TileCanvas: Page node not found: ${widget.rootNodeId}');
      return;
    }

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;
    int nodeCount = 0;

    // Get the direct children of the page (top-level frames)
    final children = pageNode['children'] as List? ?? [];

    for (final childId in children) {
      final node = nodeMap[childId.toString()];
      if (node == null) continue;

      // Skip invisible nodes
      if (node['visible'] == false) continue;

      // Get bounds from transform + size or boundingBox
      double x = 0, y = 0, width = 0, height = 0;

      final transform = node['transform'];
      if (transform is Map) {
        x = (transform['m02'] as num?)?.toDouble() ?? 0;
        y = (transform['m12'] as num?)?.toDouble() ?? 0;
      }

      final size = node['size'];
      if (size is Map) {
        width = (size['x'] as num?)?.toDouble() ?? 0;
        height = (size['y'] as num?)?.toDouble() ?? 0;
      }

      // Try boundingBox as fallback
      if (width <= 0 || height <= 0) {
        final bbox = node['boundingBox'];
        if (bbox is Map) {
          x = (bbox['x'] as num?)?.toDouble() ?? x;
          y = (bbox['y'] as num?)?.toDouble() ?? y;
          width = (bbox['width'] as num?)?.toDouble() ?? 0;
          height = (bbox['height'] as num?)?.toDouble() ?? 0;
        }
      }

      if (width > 0 && height > 0) {
        minX = minX < x ? minX : x;
        minY = minY < y ? minY : y;
        maxX = maxX > (x + width) ? maxX : (x + width);
        maxY = maxY > (y + height) ? maxY : (y + height);
        nodeCount++;
      }
    }

    if (nodeCount > 0 && minX.isFinite && minY.isFinite) {
      _contentBounds = Rect.fromLTRB(minX, minY, maxX, maxY);
      debugPrint('TileCanvas: Content bounds = $_contentBounds ($nodeCount top-level frames)');
    } else {
      debugPrint('TileCanvas: No valid content bounds found (${children.length} children checked)');
    }
  }

  /// Set initial transform to center on content
  void _setInitialTransform(Size screenSize) {
    if (_initialTransformSet || _contentBounds == null) return;
    _initialTransformSet = true;

    final bounds = _contentBounds!;

    // Calculate scale to fit content with padding
    // Use more padding (400px) to ensure content fits comfortably
    final scaleX = screenSize.width / (bounds.width + 400);
    final scaleY = screenSize.height / (bounds.height + 400);
    // Allow zooming out to 1% minimum for very large canvases
    final scale = (scaleX < scaleY ? scaleX : scaleY).clamp(0.01, 2.0);
    debugPrint('TileCanvas: Content bounds = $bounds, screenSize = $screenSize');
    debugPrint('TileCanvas: scaleX=$scaleX, scaleY=$scaleY, chosen=${scaleX < scaleY ? scaleX : scaleY}, clamped=$scale');

    // Calculate translation to center content
    final contentCenterX = bounds.left + bounds.width / 2;
    final contentCenterY = bounds.top + bounds.height / 2;
    final screenCenterX = screenSize.width / 2;
    final screenCenterY = screenSize.height / 2;

    final translateX = screenCenterX - contentCenterX * scale;
    final translateY = screenCenterY - contentCenterY * scale;

    final matrix = Matrix4.identity();
    matrix.setEntry(0, 0, scale);
    matrix.setEntry(1, 1, scale);
    matrix.setEntry(0, 3, translateX);
    matrix.setEntry(1, 3, translateY);

    _transformController.value = matrix;
    debugPrint('TileCanvas: Initial transform set - scale=$scale, translate=($translateX, $translateY)');
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  /// Capture current canvas as PNG for debugging
  /// Returns the image bytes or null if capture fails
  Future<List<int>?> captureDebugScreenshot() async {
    try {
      final boundary = _repaintBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        debugPrint('TileCanvas: Cannot capture - no render boundary found');
        return null;
      }

      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        debugPrint('TileCanvas: Cannot capture - toByteData failed');
        return null;
      }

      final bytes = byteData.buffer.asUint8List();
      debugPrint('TileCanvas: Screenshot captured (${bytes.length} bytes, ${image.width}x${image.height})');
      return bytes;
    } catch (e) {
      debugPrint('TileCanvas: Screenshot capture error - $e');
      return null;
    }
  }

  /// Save screenshot to temp file and return path
  Future<String?> saveDebugScreenshot([String? prefix]) async {
    final bytes = await captureDebugScreenshot();
    if (bytes == null) return null;

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = '${prefix ?? 'tile_debug'}_$timestamp.png';
      final tempDir = '/tmp';
      final path = '$tempDir/$filename';

      await io.File(path).writeAsBytes(bytes);
      debugPrint('TileCanvas: Screenshot saved to $path');
      return path;
    } catch (e) {
      debugPrint('TileCanvas: Screenshot save error - $e');
      return null;
    }
  }

  void _onTileRendered(TileCoord coord, ui.Image image) {
    // Just increment counter to trigger rebuild - don't store image reference
    setState(() {
      _tileUpdateCount++;
    });
  }

  /// Get the tile cache directly from TileManager
  Map<TileCoord, ui.Image> get _tileCache =>
      _tileManagerState?._tileCache ?? {};

  /// Get tile manager state
  TileManagerState? get tileManager => _tileManagerState;

  /// Switch backend type
  void setBackendType(TileBackendType type) {
    _tileManagerState?.setBackendType(type);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _screenSize = Size(
          constraints.maxWidth.isFinite ? constraints.maxWidth : 800,
          constraints.maxHeight.isFinite ? constraints.maxHeight : 600,
        );

        // Set initial transform to center on content (only once)
        _setInitialTransform(_screenSize);

        return Container(
          color: const Color(0xFF1A1A2E),
          child: Stack(
            children: [
              // Gesture detector for pan/zoom that updates our transform
              GestureDetector(
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                child: MouseRegion(
                  child: Listener(
                    onPointerSignal: _onPointerSignal,
                    child: ClipRect(
                      // AnimatedBuilder for efficient repaints on transform changes
                      child: AnimatedBuilder(
                        animation: _transformController,
                        builder: (context, child) {
                          return RepaintBoundary(
                            key: _repaintBoundaryKey,
                            child: CustomPaint(
                              painter: _ViewportTilePainter(
                                transform: _transformController.value,
                                screenSize: _screenSize,
                                tileCache: _tileCache,
                                onTileNeeded: (coord) {
                                  if (_tileManagerState != null) {
                                    _tileManagerState!._requestTile(coord);
                                  } else {
                                    // Queue request until backend is ready
                                    _pendingTileRequests.add(coord);
                                  }
                                },
                              ),
                              size: _screenSize,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),

              // The TileManager (handles backend and caching)
              // Uses ValueKey to force recreation when page changes
              Offstage(
                child: TileManager(
                  key: ValueKey('tile_manager_${widget.rootNodeId}'),
                  document: widget.document,
                  rootNodeId: widget.rootNodeId,
                  transformController: _transformController,
                  config: widget.config,
                  onBoundsCalculated: widget.onBoundsCalculated,
                  onBackendChanged: widget.onBackendChanged,
                  onTileRendered: _onTileRendered,
                  onStateReady: (state) {
                    _tileManagerState = state;
                    // Process any tile requests that were queued before backend was ready
                    if (_pendingTileRequests.isNotEmpty) {
                      debugPrint('TileCanvas: Processing ${_pendingTileRequests.length} pending tile requests');
                      for (final coord in _pendingTileRequests) {
                        state._requestTile(coord);
                      }
                      _pendingTileRequests.clear();
                    }
                    // Trigger a repaint now that the backend is ready
                    // This ensures tiles are requested on initial load
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() {});
                    });
                  },
                  screenSize: _screenSize,
                ),
              ),

              // Debug overlay - wrapped in AnimatedBuilder for efficient updates
              Positioned(
                top: 60,
                right: 10,
                child: AnimatedBuilder(
                  animation: _transformController,
                  builder: (context, _) => Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: _buildDebugInfo(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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

    // Apply pan (translation) - directly in screen coordinates
    if (_lastFocalPoint != null) {
      final delta = details.localFocalPoint - _lastFocalPoint!;
      // Add delta directly to translation (screen-space panning)
      storage[12] += delta.dx;
      storage[13] += delta.dy;
    }

    // Apply scale around focal point
    if (details.scale != 1.0) {
      final focalPoint = details.localFocalPoint;
      final newScale = (_startScale * details.scale).clamp(0.01, 10.0);
      final currentScale = matrix.getMaxScaleOnAxis();
      final scaleChange = newScale / currentScale;

      // Scale around focal point
      storage[12] = focalPoint.dx - (focalPoint.dx - storage[12]) * scaleChange;
      storage[13] = focalPoint.dy - (focalPoint.dy - storage[13]) * scaleChange;
      storage[0] *= scaleChange;
      storage[5] *= scaleChange;
    }

    // Just update the controller - the AnimatedBuilder will handle repaints efficiently
    _transformController.value = matrix;
    _lastFocalPoint = details.localFocalPoint;
    // NO setState - let AnimatedBuilder handle repaint
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final scaleFactor = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
      final matrix = _transformController.value.clone();
      final storage = matrix.storage;
      final focalPoint = event.localPosition;

      // Scale around focal point using screen-space math (same as _onScaleUpdate)
      final currentScale = matrix.getMaxScaleOnAxis();
      final newScale = (currentScale * scaleFactor).clamp(0.01, 10.0);
      final scaleChange = newScale / currentScale;

      storage[12] = focalPoint.dx - (focalPoint.dx - storage[12]) * scaleChange;
      storage[13] = focalPoint.dy - (focalPoint.dy - storage[13]) * scaleChange;
      storage[0] *= scaleChange;
      storage[5] *= scaleChange;

      _transformController.value = matrix;
    }
  }

  Widget _buildDebugInfo() {
    final scale = _transformController.value.getMaxScaleOnAxis();
    final lod = _calculateLOD(scale);
    final translation = _transformController.value.getTranslation();
    final cacheSize = _tileCache.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Scale: ${scale.toStringAsFixed(2)}x',
             style: TextStyle(color: Colors.lime.shade300, fontSize: 11)),
        Text('LOD: $lod',
             style: TextStyle(color: Colors.cyan.shade300, fontSize: 11)),
        Text('Pos: (${translation.x.toInt()}, ${translation.y.toInt()})',
             style: TextStyle(color: Colors.orange.shade300, fontSize: 11)),
        Text('Cache: $cacheSize tiles',
             style: TextStyle(color: Colors.purple.shade300, fontSize: 11)),
        Text('Updates: $_tileUpdateCount',
             style: TextStyle(color: Colors.pink.shade300, fontSize: 11)),
      ],
    );
  }

  /// Calculate LOD using the 5-level system from viewport.dart
  /// Uses the global thresholds but without hysteresis (for display only)
  int _calculateLOD(double scale) {
    for (int i = 0; i < kLodScaleThresholds.length; i++) {
      if (scale >= kLodScaleThresholds[i]) {
        return i;
      }
    }
    return kLodScaleThresholds.length - 1;
  }
}

/// Painter that renders tiles based on current viewport
class _ViewportTilePainter extends CustomPainter {
  final Matrix4 transform;
  final Size screenSize;
  final Map<TileCoord, ui.Image> tileCache;
  final void Function(TileCoord) onTileNeeded;
  final bool showDebugPlaceholders;

  // Cached Paint objects for performance (avoid allocations during paint)
  static final _imagePaint = Paint()..filterQuality = FilterQuality.medium;
  static final _borderPaint = Paint()
    ..color = Colors.cyan.withValues(alpha: 0.5)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  static final _evenTilePaint = Paint()..color = const Color(0xFF2A2A3E);
  static final _oddTilePaint = Paint()..color = const Color(0xFF3A3A4E);

  _ViewportTilePainter({
    required this.transform,
    required this.screenSize,
    required this.tileCache,
    required this.onTileNeeded,
    this.showDebugPlaceholders = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = transform.getMaxScaleOnAxis();
    final translation = transform.getTranslation();

    // Calculate LOD based on zoom using the 5-level system
    final lod = _calculateLOD(scale);
    final tileMultiplier = kLodTileMultipliers[lod.clamp(0, 4)];
    final tileWorldSize = kTileSize * tileMultiplier;

    // Calculate visible world area
    final worldX = -translation.x / scale;
    final worldY = -translation.y / scale;
    final worldWidth = size.width / scale;
    final worldHeight = size.height / scale;

    // Calculate visible tile range
    final minTx = (worldX / tileWorldSize).floor();
    final minTy = (worldY / tileWorldSize).floor();
    final maxTx = ((worldX + worldWidth) / tileWorldSize).ceil();
    final maxTy = ((worldY + worldHeight) / tileWorldSize).ceil();

    // Draw each visible tile
    for (var tx = minTx; tx <= maxTx; tx++) {
      for (var ty = minTy; ty <= maxTy; ty++) {
        final coord = TileCoord(tx, ty, lod);

        // Calculate screen position
        final worldLeft = tx * tileWorldSize;
        final worldTop = ty * tileWorldSize;
        final screenLeft = worldLeft * scale + translation.x;
        final screenTop = worldTop * scale + translation.y;
        final screenSize = tileWorldSize * scale;

        final screenRect = Rect.fromLTWH(screenLeft, screenTop, screenSize, screenSize);

        // Draw tile content or placeholder
        if (tileCache.containsKey(coord)) {
          final image = tileCache[coord];
          // Validate image before drawing
          if (image != null && image.width > 0 && image.height > 0) {
            try {
              canvas.drawImageRect(
                image,
                Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
                screenRect,
                _imagePaint,  // Use cached Paint
              );
            } catch (e) {
              // Image might be disposed, draw placeholder instead
              _drawPlaceholder(canvas, screenRect, coord, lod);
            }
          } else {
            _drawPlaceholder(canvas, screenRect, coord, lod);
          }
        } else {
          _drawPlaceholder(canvas, screenRect, coord, lod);
          onTileNeeded(coord);
        }
      }
    }
  }

  // LOD tint paints (cached) - 5 levels
  static final _lodTintPaints = [
    Paint()..color = Colors.red.withValues(alpha: 0.2),      // LOD 0: finest
    Paint()..color = Colors.orange.withValues(alpha: 0.2),   // LOD 1
    Paint()..color = Colors.yellow.withValues(alpha: 0.2),   // LOD 2: base
    Paint()..color = Colors.green.withValues(alpha: 0.2),    // LOD 3
    Paint()..color = Colors.blue.withValues(alpha: 0.2),     // LOD 4: coarsest
  ];

  void _drawPlaceholder(Canvas canvas, Rect rect, TileCoord coord, int lod) {
    // Always draw a basic placeholder background for loading tiles
    // This prevents a blank/purple screen while tiles load
    final isEven = (coord.x + coord.y) % 2 == 0;
    canvas.drawRect(rect, isEven ? _evenTilePaint : _oddTilePaint);

    // Only show debug overlay if enabled
    if (!showDebugPlaceholders) return;

    // LOD tint overlay - use cached paint
    canvas.drawRect(rect, _lodTintPaints[lod % _lodTintPaints.length]);

    // Border - use cached paint
    canvas.drawRect(rect, _borderPaint);

    // Label (only if tile is large enough)
    if (rect.width > 50) {
      final paragraphBuilder = ui.ParagraphBuilder(ui.ParagraphStyle(
        textAlign: TextAlign.center,
      ))
        ..pushStyle(ui.TextStyle(
          color: Colors.yellow,
          fontSize: rect.width > 100 ? 12 : 8,
        ))
        ..addText('(${coord.x},${coord.y})\nz$lod');

      final paragraph = paragraphBuilder.build()
        ..layout(ui.ParagraphConstraints(width: rect.width));

      canvas.drawParagraph(
        paragraph,
        Offset(rect.left, rect.center.dy - 12),
      );
    }
  }

  /// Calculate LOD using the 5-level system
  /// Uses thresholds without hysteresis for painting
  int _calculateLOD(double scale) {
    for (int i = 0; i < kLodScaleThresholds.length; i++) {
      if (scale >= kLodScaleThresholds[i]) {
        return i;
      }
    }
    return kLodScaleThresholds.length - 1;
  }

  @override
  bool shouldRepaint(covariant _ViewportTilePainter oldDelegate) {
    return transform != oldDelegate.transform ||
           tileCache.length != oldDelegate.tileCache.length;
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
