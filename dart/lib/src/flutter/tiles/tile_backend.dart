/// Tile Backend Abstraction
///
/// Provides an interface for tile rendering backends, allowing
/// switching between Rust WASM/native and pure Dart implementations.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Canvas, Colors, Paint, PaintingStyle, Rect, RRect, Radius, Offset, LinearGradient, RadialGradient, SweepGradient, Gradient, Alignment, FilterQuality;
import 'package:flutter/painting.dart' show Color;
import 'viewport.dart';
import 'tile_rasterizer.dart';
import '../figma_canvas.dart' show FigmaDocument;
import '../node_renderer.dart' show FigmaNodeProperties, imageHashToHex;
import '../rendering/blend_modes.dart' show getBlendModeFromData;
import '../../rust/api.dart' as rust;

/// Result from rendering a tile
class TileResult {
  final TileCoord coord;
  final ui.Image image;
  final int nodeCount;
  final bool fromCache;

  TileResult({
    required this.coord,
    required this.image,
    required this.nodeCount,
    required this.fromCache,
  });
}

/// Abstract backend interface for tile rendering
abstract class TileBackend {
  /// Callback when cache is invalidated (e.g., after images load)
  void Function()? onCacheInvalidated;

  /// Initialize the backend with a document
  Future<void> initialize(dynamic document, String rootNodeId, {String? imagesDirectory});

  /// Render a single tile
  Future<TileResult?> renderTile(TileCoord coord);

  /// Get visible tiles for a viewport
  List<TileCoord> getVisibleTiles(WorldViewport viewport);

  /// Invalidate tiles for changed nodes
  Future<void> invalidateTiles(List<String> changedNodeIds);

  /// Clear all cached tiles
  Future<void> clearCache();

  /// Dispose resources
  void dispose();

  /// Whether this backend is ready
  bool get isReady;

  /// Backend name for debugging
  String get name;
}

/// Rust-powered tile backend using flutter_rust_bridge
class RustTileBackend extends TileBackend {
  rust.FigmaDocument? _rustDocument;
  FigmaDocument? _flutterDocument;  // Flutter FigmaDocument for fallback rendering
  String? _rootNodeId;
  bool _initialized = false;
  bool _dartRenderMode = false;  // True when using Dart rendering (no Rust)
  final TileRasterizer _rasterizer = TileRasterizer();
  final _DartTileRenderer _dartRenderer = _DartTileRenderer();

  @override
  String get name => _dartRenderMode ? 'Rust (Dart Fallback)' : 'Rust Native/WASM';

  @override
  bool get isReady => _initialized;

  @override
  Future<void> initialize(dynamic document, String rootNodeId, {String? imagesDirectory}) async {
    _rootNodeId = rootNodeId;

    // If document is raw bytes, load via Rust
    if (document is List<int>) {
      try {
        _rustDocument = await rust.loadFigmaFile(data: document);
        // Initialize spatial index
        await rust.initSpatialIndex(doc: _rustDocument!, rootId: rootNodeId);
        _initialized = true;
        debugPrint('RustTileBackend: Initialized with spatial index');
      } catch (e) {
        debugPrint('RustTileBackend: Failed to initialize - $e');
        _initialized = false;
      }
    } else if (document is rust.FigmaDocument) {
      _rustDocument = document;
      await rust.initSpatialIndex(doc: _rustDocument!, rootId: rootNodeId);
      _initialized = true;
    } else if (document is FigmaDocument) {
      // Flutter FigmaDocument - use Dart rendering
      debugPrint('RustTileBackend: Using Flutter FigmaDocument with Dart rendering');
      _flutterDocument = document;
      _dartRenderMode = true;
      _dartRenderer.initialize(_flutterDocument!, rootNodeId,
          imagesDirectory: imagesDirectory ?? document.imagesDirectory,
          onCacheInvalidated: () => onCacheInvalidated?.call());
      _initialized = true;
    } else if (document is Map<String, dynamic>) {
      // Raw Map - convert to FigmaDocument and use Dart rendering
      debugPrint('RustTileBackend: Converting Map to FigmaDocument');
      _flutterDocument = FigmaDocument.fromMessage(document);
      _dartRenderMode = true;
      _dartRenderer.initialize(_flutterDocument!, rootNodeId,
          imagesDirectory: imagesDirectory,
          onCacheInvalidated: () => onCacheInvalidated?.call());
      _initialized = true;
    } else {
      debugPrint('RustTileBackend: Unsupported document type ${document.runtimeType}');
      _initialized = false;
    }
  }

  @override
  Future<TileResult?> renderTile(TileCoord coord) async {
    if (!isReady) return null;

    // In Dart render mode, use the Dart renderer
    if (_dartRenderMode && _flutterDocument != null) {
      return _dartRenderer.renderTile(coord);
    }

    // Rust rendering path
    if (_rustDocument == null) {
      final image = await _rasterizer.createPlaceholderTile(coord);
      return TileResult(
        coord: coord,
        image: image,
        nodeCount: 0,
        fromCache: false,
      );
    }

    try {
      final result = await rust.renderSingleTile(
        doc: _rustDocument!,
        rootId: _rootNodeId!,
        coord: rust.TileCoordInfo(
          x: coord.x,
          y: coord.y,
          zoomLevel: coord.zoomLevel,
        ),
      );

      // Convert draw commands to image
      final commands = result.commands
          .map((cmd) => _convertDrawCommand(cmd))
          .toList();

      final image = await _rasterizer.rasterize(commands, coord);

      return TileResult(
        coord: coord,
        image: image,
        nodeCount: result.nodeCount.toInt(),
        fromCache: result.fromCache,
      );
    } catch (e) {
      debugPrint('RustTileBackend: Error rendering tile $coord - $e');
      return null;
    }
  }

  @override
  List<TileCoord> getVisibleTiles(WorldViewport viewport) {
    // Use local calculation for speed (matches Rust algorithm)
    return getVisibleTilesLocal(viewport);
  }

  @override
  Future<void> invalidateTiles(List<String> changedNodeIds) async {
    if (_dartRenderMode) {
      _dartRenderer.invalidateTiles(changedNodeIds);
      return;
    }
    if (!isReady || _rustDocument == null) return;

    try {
      await rust.invalidateTiles(
        doc: _rustDocument!,
        changedNodeIds: changedNodeIds,
      );
    } catch (e) {
      debugPrint('RustTileBackend: Error invalidating tiles - $e');
    }
  }

  @override
  Future<void> clearCache() async {
    if (_dartRenderMode) {
      _dartRenderer.clearCache();
      return;
    }
    if (!isReady || _rustDocument == null) return;

    try {
      await rust.clearTileCache(doc: _rustDocument!);
    } catch (e) {
      debugPrint('RustTileBackend: Error clearing cache - $e');
    }
  }

  @override
  void dispose() {
    _rustDocument = null;
    _flutterDocument = null;
    _initialized = false;
    _dartRenderMode = false;
    _dartRenderer.dispose();
  }

  /// Convert Rust DrawCommand to local DrawCommandData
  DrawCommandData _convertDrawCommand(rust.DrawCommand cmd) {
    return DrawCommandData(
      type: _parseCommandType(cmd.commandType),
      rect: cmd.rect != null
          ? ui.Rect.fromLTWH(
              cmd.rect!.x,
              cmd.rect!.y,
              cmd.rect!.width,
              cmd.rect!.height,
            )
          : null,
      path: cmd.path != null ? _parsePath(cmd.path!.commands) : null,
      cornerRadii: cmd.rect?.cornerRadii.toList(),
      fills: cmd.fills.map(_convertPaint).toList(),
      strokes: cmd.strokes.map(_convertPaint).toList(),
      strokeWeight: cmd.strokeWeight,
    );
  }

  DrawCommandType _parseCommandType(String type) {
    switch (type) {
      case 'rect':
        return DrawCommandType.rect;
      case 'ellipse':
        return DrawCommandType.ellipse;
      case 'path':
        return DrawCommandType.path;
      case 'text':
        return DrawCommandType.text;
      case 'image':
        return DrawCommandType.image;
      default:
        return DrawCommandType.rect;
    }
  }

  ui.Path _parsePath(String commands) {
    final path = ui.Path();
    final regex = RegExp(r'([MLCQZ])\s*([^MLCQZ]*)');

    for (final match in regex.allMatches(commands.toUpperCase())) {
      final cmd = match.group(1);
      final params = match
              .group(2)
              ?.trim()
              .split(RegExp(r'[\s,]+'))
              .where((s) => s.isNotEmpty)
              .map(double.tryParse)
              .whereType<double>()
              .toList() ??
          [];

      switch (cmd) {
        case 'M':
          if (params.length >= 2) path.moveTo(params[0], params[1]);
          break;
        case 'L':
          if (params.length >= 2) path.lineTo(params[0], params[1]);
          break;
        case 'C':
          if (params.length >= 6) {
            path.cubicTo(
              params[0], params[1],
              params[2], params[3],
              params[4], params[5],
            );
          }
          break;
        case 'Q':
          if (params.length >= 4) {
            path.quadraticBezierTo(
              params[0], params[1],
              params[2], params[3],
            );
          }
          break;
        case 'Z':
          path.close();
          break;
      }
    }

    return path;
  }

  PaintData _convertPaint(rust.PaintInfo paint) {
    return PaintData(
      type: _parsePaintType(paint.paintType),
      color: paint.color != null
          ? Color.fromARGB(
              paint.color!.a,
              paint.color!.r,
              paint.color!.g,
              paint.color!.b,
            )
          : null,
      opacity: paint.opacity,
    );
  }

  PaintType _parsePaintType(String type) {
    switch (type) {
      case 'solid':
        return PaintType.solid;
      case 'gradient_linear':
        return PaintType.linearGradient;
      case 'gradient_radial':
        return PaintType.radialGradient;
      case 'image':
        return PaintType.image;
      default:
        return PaintType.solid;
    }
  }
}

/// Pure Dart tile backend with full node rendering
class DartTileBackend extends TileBackend {
  FigmaDocument? _document;
  String? _rootNodeId;
  bool _initialized = false;
  final _DartTileRenderer _renderer = _DartTileRenderer();

  @override
  String get name => 'Pure Dart';

  @override
  bool get isReady => _initialized;

  @override
  Future<void> initialize(dynamic document, String rootNodeId, {String? imagesDirectory}) async {
    _rootNodeId = rootNodeId;

    if (document is FigmaDocument) {
      _document = document;
      _renderer.initialize(_document!, rootNodeId,
          imagesDirectory: imagesDirectory ?? document.imagesDirectory,
          onCacheInvalidated: () => onCacheInvalidated?.call());
      _initialized = true;
      debugPrint('DartTileBackend: Initialized with FigmaDocument (${_document!.nodeCount} nodes)');
    } else if (document is Map<String, dynamic>) {
      _document = FigmaDocument.fromMessage(document);
      _renderer.initialize(_document!, rootNodeId,
          imagesDirectory: imagesDirectory,
          onCacheInvalidated: () => onCacheInvalidated?.call());
      _initialized = true;
      debugPrint('DartTileBackend: Initialized from Map (${_document!.nodeCount} nodes)');
    } else {
      debugPrint('DartTileBackend: Unsupported document type ${document.runtimeType}');
      _initialized = false;
    }
  }

  @override
  Future<TileResult?> renderTile(TileCoord coord) async {
    if (!isReady || _document == null) return null;
    return _renderer.renderTile(coord);
  }

  @override
  List<TileCoord> getVisibleTiles(WorldViewport viewport) {
    return getVisibleTilesLocal(viewport);
  }

  @override
  Future<void> invalidateTiles(List<String> changedNodeIds) async {
    _renderer.invalidateTiles(changedNodeIds);
  }

  @override
  Future<void> clearCache() async {
    _renderer.clearCache();
  }

  @override
  void dispose() {
    _document = null;
    _initialized = false;
    _renderer.dispose();
  }
}

/// Local calculation of visible tiles (matches Rust algorithm)
List<TileCoord> getVisibleTilesLocal(WorldViewport viewport) {
  final zoomLevel = viewport.lod;
  final tileSize = viewport.effectiveTileSize;

  final minTx = (viewport.x / tileSize).floor();
  final minTy = (viewport.y / tileSize).floor();
  final maxTx = ((viewport.x + viewport.width) / tileSize).ceil();
  final maxTy = ((viewport.y + viewport.height) / tileSize).ceil();

  final tiles = <TileCoord>[];
  for (var tx = minTx; tx <= maxTx; tx++) {
    for (var ty = minTy; ty <= maxTy; ty++) {
      tiles.add(TileCoord(tx, ty, zoomLevel));
    }
  }

  return tiles;
}

/// Backend type enum
enum TileBackendType {
  rust,
  dart,
}

/// Factory to create appropriate backend
class TileBackendFactory {
  static TileBackend create(TileBackendType type) {
    switch (type) {
      case TileBackendType.rust:
        return RustTileBackend();
      case TileBackendType.dart:
        return DartTileBackend();
    }
  }

  /// Detect best available backend
  static TileBackendType detectBest() {
    // Try Rust first, fall back to Dart
    // In a real implementation, we'd check if Rust library is loaded
    return TileBackendType.rust;
  }
}

/// Node bounds entry for spatial indexing
class _NodeBounds {
  final String id;
  final Rect bounds;
  final int zIndex;  // For back-to-front ordering

  _NodeBounds(this.id, this.bounds, this.zIndex);
}

/// Dart-based tile renderer with spatial indexing and LOD support
class _DartTileRenderer {
  FigmaDocument? _document;
  String? _rootNodeId;
  String? _imagesDirectory;  // Directory containing image files by hash
  final List<_NodeBounds> _spatialIndex = [];
  final Map<TileCoord, ui.Image> _tileCache = {};
  final int _tilePixelSize = 1024;

  /// Image cache for decoded images (hex hash -> decoded ui.Image)
  final Map<String, ui.Image> _imageCache = {};

  /// Set of images currently being decoded
  final Set<String> _pendingImages = {};

  /// Debug flag to show node labels (set to true for debugging)
  bool showDebugLabels = true;

  /// Callback when cache is invalidated (images loaded)
  void Function()? onCacheInvalidated;

  /// Timer for debouncing cache invalidation
  Timer? _cacheInvalidationTimer;

  /// Whether cache invalidation is pending
  bool _cacheInvalidationPending = false;

  /// Initialize with document and build spatial index
  void initialize(FigmaDocument document, String rootNodeId, {String? imagesDirectory, void Function()? onCacheInvalidated}) {
    this.onCacheInvalidated = onCacheInvalidated;
    _document = document;
    _rootNodeId = rootNodeId;
    _imagesDirectory = imagesDirectory;
    _buildSpatialIndex();
    debugPrint('_DartTileRenderer: Built spatial index with ${_spatialIndex.length} nodes');
    if (_imagesDirectory != null) {
      debugPrint('_DartTileRenderer: Images directory: $_imagesDirectory');
    }
  }

  /// Build spatial index from document nodes - only nodes under rootNodeId
  void _buildSpatialIndex() {
    _spatialIndex.clear();
    if (_document == null || _rootNodeId == null) return;

    // Get the root node (page) and walk only its children
    final rootNode = _document!.nodeMap[_rootNodeId];
    if (rootNode == null) {
      debugPrint('_DartTileRenderer: Root node not found: $_rootNodeId');
      return;
    }

    int zIndex = 0;
    _collectNodesRecursive(_rootNodeId!, zIndex);

    // Sort by z-index for correct rendering order
    _spatialIndex.sort((a, b) => a.zIndex.compareTo(b.zIndex));

    debugPrint('_DartTileRenderer: Built spatial index for page $_rootNodeId');
  }

  /// Recursively collect nodes under a parent
  int _collectNodesRecursive(String nodeId, int zIndex) {
    final node = _document!.nodeMap[nodeId];
    if (node == null) return zIndex;

    // Skip non-renderable types but still traverse children
    final type = node['type'] as String? ?? '';
    final isContainer = type == 'DOCUMENT' || type == 'CANVAS' || type == 'PAGE';

    if (!isContainer) {
      // Extract bounds from node
      final bounds = _getNodeBounds(node);
      if (bounds != null && bounds.width > 0 && bounds.height > 0) {
        _spatialIndex.add(_NodeBounds(nodeId, bounds, zIndex++));
      }
    }

    // Recursively process children
    final children = node['children'] as List?;
    if (children != null) {
      for (final childId in children) {
        zIndex = _collectNodesRecursive(childId.toString(), zIndex);
      }
    }

    return zIndex;
  }

  /// Extract node bounds from node data
  Rect? _getNodeBounds(Map<String, dynamic> node) {
    double x = 0, y = 0, width = 0, height = 0;

    // Try transform first (absolute position)
    final transform = node['transform'];
    if (transform is Map) {
      x = (transform['m02'] as num?)?.toDouble() ?? 0;
      y = (transform['m12'] as num?)?.toDouble() ?? 0;
    }

    // Get size
    final size = node['size'];
    if (size is Map) {
      width = (size['x'] as num?)?.toDouble() ?? 0;
      height = (size['y'] as num?)?.toDouble() ?? 0;
    }

    // Fall back to boundingBox if available
    if (width == 0 || height == 0) {
      final bbox = node['boundingBox'];
      if (bbox is Map) {
        x = (bbox['x'] as num?)?.toDouble() ?? x;
        y = (bbox['y'] as num?)?.toDouble() ?? y;
        width = (bbox['width'] as num?)?.toDouble() ?? 0;
        height = (bbox['height'] as num?)?.toDouble() ?? 0;
      }
    }

    if (width <= 0 || height <= 0) return null;
    return Rect.fromLTWH(x, y, width, height);
  }

  /// Render a tile with nodes that intersect its bounds
  Future<TileResult?> renderTile(TileCoord coord) async {
    if (_document == null) return null;

    // Check cache first
    if (_tileCache.containsKey(coord)) {
      return TileResult(
        coord: coord,
        image: _tileCache[coord]!,
        nodeCount: 0,
        fromCache: true,
      );
    }

    // Calculate tile bounds in world space
    final tileBounds = coord.bounds;

    // Calculate LOD scale factor for node filtering
    // LOD 0 = 1x, LOD 1 = 4x
    final lodScale = coord.zoomLevel == 0 ? 1 : 4;
    final minNodeSize = 2.0 * lodScale;  // Skip nodes smaller than 2px at current LOD

    // Find nodes that intersect this tile
    final intersectingNodes = <_NodeBounds>[];
    for (final nodeBounds in _spatialIndex) {
      if (tileBounds.overlaps(nodeBounds.bounds)) {
        // LOD filtering: skip small nodes when zoomed out
        if (nodeBounds.bounds.width >= minNodeSize ||
            nodeBounds.bounds.height >= minNodeSize) {
          intersectingNodes.add(nodeBounds);
        }
      }
    }

    // Render to image
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Calculate transform from world to tile pixel space
    final scale = _tilePixelSize / kTileSize;
    canvas.scale(scale);
    canvas.translate(-tileBounds.left, -tileBounds.top);

    // Render each node
    int renderedCount = 0;
    for (final nodeBounds in intersectingNodes) {
      final node = _document!.nodeMap[nodeBounds.id];
      if (node != null) {
        _renderNode(canvas, node, nodeBounds.bounds);
        renderedCount++;
      }
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(_tilePixelSize, _tilePixelSize);

    // Cache the result
    _tileCache[coord] = image;

    return TileResult(
      coord: coord,
      image: image,
      nodeCount: renderedCount,
      fromCache: false,
    );
  }

  /// Render a single node to the canvas
  void _renderNode(Canvas canvas, Map<String, dynamic> node, Rect bounds) {
    final type = node['type'] as String? ?? '';
    final name = node['name'] as String? ?? '';
    final visible = node['visible'] as bool? ?? true;
    if (!visible) return;

    // Extract properties using FigmaNodeProperties
    final props = FigmaNodeProperties.fromMap(node, nodeMap: _document?.nodeMap);

    // Render drop shadows BEFORE the main shape
    if (props.effects.isNotEmpty) {
      _renderDropShadows(canvas, props);
    }

    // Check for layer blur effect
    final blurRadius = _getBlurRadius(props.effects);
    final hasBlur = blurRadius != null && blurRadius > 0;

    // Get blend mode
    final blendMode = getBlendModeFromData(props.raw);

    // Apply opacity, blend mode, and optional blur
    final layerPaint = Paint()
      ..color = Colors.white.withValues(alpha: props.opacity);

    if (blendMode != ui.BlendMode.srcOver) {
      layerPaint.blendMode = blendMode;
    }

    if (hasBlur) {
      layerPaint.imageFilter = ui.ImageFilter.blur(sigmaX: blurRadius, sigmaY: blurRadius);
    }

    canvas.saveLayer(bounds, layerPaint);

    switch (type) {
      case 'RECTANGLE':
      case 'ROUNDED_RECTANGLE':
        _renderRect(canvas, props);
        break;
      case 'ELLIPSE':
        _renderEllipse(canvas, props);
        break;
      case 'FRAME':
      case 'GROUP':
      case 'COMPONENT':
      case 'COMPONENT_SET':
      case 'INSTANCE':
        _renderFrame(canvas, props);
        break;
      case 'TEXT':
        _renderText(canvas, props);
        break;
      case 'VECTOR':
      case 'STAR':
      case 'REGULAR_POLYGON':
      case 'LINE':
        _renderVector(canvas, props);
        break;
      case 'IMAGE':
        _renderImage(canvas, props);
        break;
      default:
        // Default: render as rectangle
        _renderRect(canvas, props);
    }

    canvas.restore();

    // Render inner shadows AFTER the main shape
    if (props.effects.isNotEmpty) {
      _renderInnerShadows(canvas, props);
    }

    // Draw debug label if enabled
    if (showDebugLabels && name.isNotEmpty) {
      _renderDebugLabel(canvas, props, name, type);
    }
  }

  /// Get blur radius from effects
  double? _getBlurRadius(List<Map<String, dynamic>> effects) {
    for (final effect in effects) {
      if (effect['visible'] == false) continue;
      final type = effect['type'] as String?;
      if (type == 'LAYER_BLUR' || type == 'BACKGROUND_BLUR' || type == 'FOREGROUND_BLUR') {
        return (effect['radius'] as num?)?.toDouble();
      }
    }
    return null;
  }

  /// Render drop shadows for a node
  void _renderDropShadows(Canvas canvas, FigmaNodeProperties props) {
    final rect = Rect.fromLTWH(props.x, props.y, props.width, props.height);

    for (final effect in props.effects) {
      if (effect['visible'] == false) continue;
      if (effect['type'] != 'DROP_SHADOW') continue;

      // Extract shadow properties
      final colorData = effect['color'] as Map?;
      Color shadowColor = const Color(0x40000000);
      if (colorData != null) {
        final r = ((colorData['r'] as num?)?.toDouble() ?? 0) * 255;
        final g = ((colorData['g'] as num?)?.toDouble() ?? 0) * 255;
        final b = ((colorData['b'] as num?)?.toDouble() ?? 0) * 255;
        final a = ((colorData['a'] as num?)?.toDouble() ?? 0.25) * 255;
        shadowColor = Color.fromARGB(a.round(), r.round(), g.round(), b.round());
      }

      final offsetData = effect['offset'] as Map?;
      final offsetX = (offsetData?['x'] as num?)?.toDouble() ?? 0;
      final offsetY = (offsetData?['y'] as num?)?.toDouble() ?? 0;

      final blurRadius = (effect['radius'] as num?)?.toDouble() ?? 4;
      final spread = (effect['spread'] as num?)?.toDouble() ?? 0;

      // Draw shadow rectangle
      final shadowRect = rect.shift(Offset(offsetX, offsetY)).inflate(spread);

      // Calculate corner radii for shadow
      final radii = props.cornerRadii ?? [props.cornerRadius ?? 0, props.cornerRadius ?? 0,
                                           props.cornerRadius ?? 0, props.cornerRadius ?? 0];
      final rrect = RRect.fromRectAndCorners(
        shadowRect,
        topLeft: Radius.circular(radii[0]),
        topRight: Radius.circular(radii[1]),
        bottomRight: Radius.circular(radii[2]),
        bottomLeft: Radius.circular(radii[3]),
      );

      final paint = Paint()
        ..color = shadowColor
        ..maskFilter = blurRadius > 0
            ? ui.MaskFilter.blur(ui.BlurStyle.normal, blurRadius * 0.5)
            : null;

      canvas.drawRRect(rrect, paint);
    }
  }

  /// Render inner shadows for a node
  void _renderInnerShadows(Canvas canvas, FigmaNodeProperties props) {
    final rect = Rect.fromLTWH(props.x, props.y, props.width, props.height);

    final radii = props.cornerRadii ?? [props.cornerRadius ?? 0, props.cornerRadius ?? 0,
                                         props.cornerRadius ?? 0, props.cornerRadius ?? 0];
    final rrect = RRect.fromRectAndCorners(
      rect,
      topLeft: Radius.circular(radii[0]),
      topRight: Radius.circular(radii[1]),
      bottomRight: Radius.circular(radii[2]),
      bottomLeft: Radius.circular(radii[3]),
    );

    for (final effect in props.effects) {
      if (effect['visible'] == false) continue;
      if (effect['type'] != 'INNER_SHADOW') continue;

      // Extract shadow properties
      final colorData = effect['color'] as Map?;
      Color shadowColor = const Color(0x40000000);
      if (colorData != null) {
        final r = ((colorData['r'] as num?)?.toDouble() ?? 0) * 255;
        final g = ((colorData['g'] as num?)?.toDouble() ?? 0) * 255;
        final b = ((colorData['b'] as num?)?.toDouble() ?? 0) * 255;
        final a = ((colorData['a'] as num?)?.toDouble() ?? 0.25) * 255;
        shadowColor = Color.fromARGB(a.round(), r.round(), g.round(), b.round());
      }

      final offsetData = effect['offset'] as Map?;
      final offsetX = (offsetData?['x'] as num?)?.toDouble() ?? 0;
      final offsetY = (offsetData?['y'] as num?)?.toDouble() ?? 0;

      final blurRadius = (effect['radius'] as num?)?.toDouble() ?? 4;

      // Clip to the shape
      canvas.save();
      canvas.clipRRect(rrect);

      // Create inverted path for inner shadow effect
      final outerPath = ui.Path()..addRect(rect.inflate(100));
      final innerPath = ui.Path()..addRRect(rrect.shift(Offset(offsetX, offsetY)));
      final shadowPath = ui.Path.combine(ui.PathOperation.difference, outerPath, innerPath);

      final paint = Paint()
        ..color = shadowColor
        ..maskFilter = blurRadius > 0
            ? ui.MaskFilter.blur(ui.BlurStyle.normal, blurRadius * 0.5)
            : null;

      canvas.drawPath(shadowPath, paint);
      canvas.restore();
    }
  }

  /// Render a debug label showing node name and type
  void _renderDebugLabel(Canvas canvas, FigmaNodeProperties props, String name, String type) {
    final labelText = '$name ($type)';
    final truncatedLabel = labelText.length > 30 ? '${labelText.substring(0, 27)}...' : labelText;

    final paragraphBuilder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: ui.TextAlign.left,
      fontSize: 10,
    ))
      ..pushStyle(ui.TextStyle(
        color: const Color(0xFF000000),
        fontSize: 10,
        background: Paint()..color = const Color(0xAAFFFF00),
      ))
      ..addText(truncatedLabel);

    final paragraph = paragraphBuilder.build()
      ..layout(ui.ParagraphConstraints(width: props.width.clamp(50, 300)));

    canvas.drawParagraph(paragraph, Offset(props.x + 2, props.y + 2));
  }

  void _renderRect(Canvas canvas, FigmaNodeProperties props) {
    final rect = Rect.fromLTWH(props.x, props.y, props.width, props.height);

    // Calculate corner radii
    final radii = props.cornerRadii ?? [props.cornerRadius ?? 0, props.cornerRadius ?? 0,
                                         props.cornerRadius ?? 0, props.cornerRadius ?? 0];
    final rrect = RRect.fromRectAndCorners(
      rect,
      topLeft: Radius.circular(radii[0]),
      topRight: Radius.circular(radii[1]),
      bottomRight: Radius.circular(radii[2]),
      bottomLeft: Radius.circular(radii[3]),
    );

    // Draw fills
    for (final fill in props.fills) {
      if (fill['visible'] == false) continue;

      final type = fill['type'] as String? ?? 'SOLID';

      // Debug: log fill types for frames with potential images
      if (type == 'IMAGE' || fill.containsKey('image') || fill.containsKey('imageRef') || fill.containsKey('imageHash')) {
        debugPrint('_DartTileRenderer: RECT Fill type=$type, keys=${fill.keys.take(10).toList()}');
      }

      // Handle IMAGE fills specially
      if (type == 'IMAGE') {
        // Save canvas state for clipping
        canvas.save();
        canvas.clipRRect(rrect);

        // Try to render the image
        final success = _tryRenderImageFill(canvas, fill, rect);
        if (!success) {
          // Draw placeholder while loading
          final isLoading = _pendingImages.isNotEmpty;
          _drawImagePlaceholder(canvas, rect, isLoading);
        }

        canvas.restore();
        continue;
      }

      final paint = _createPaint(fill, rect);
      if (paint != null) {
        canvas.drawRRect(rrect, paint);
      }
    }

    // Draw strokes
    for (final stroke in props.strokes) {
      final paint = _createPaint(stroke, rect);
      if (paint != null) {
        paint.style = PaintingStyle.stroke;
        paint.strokeWidth = props.strokeWeight;
        canvas.drawRRect(rrect, paint);
      }
    }
  }

  void _renderEllipse(Canvas canvas, FigmaNodeProperties props) {
    final rect = Rect.fromLTWH(props.x, props.y, props.width, props.height);

    // Draw fills
    for (final fill in props.fills) {
      if (fill['visible'] == false) continue;

      final type = fill['type'] as String? ?? 'SOLID';

      // Handle IMAGE fills specially
      if (type == 'IMAGE') {
        // Clip to ellipse and draw image
        canvas.save();
        final path = ui.Path()..addOval(rect);
        canvas.clipPath(path);

        final success = _tryRenderImageFill(canvas, fill, rect);
        if (!success) {
          _drawImagePlaceholder(canvas, rect, _pendingImages.isNotEmpty);
        }

        canvas.restore();
        continue;
      }

      final paint = _createPaint(fill, rect);
      if (paint != null) {
        canvas.drawOval(rect, paint);
      }
    }

    // Draw strokes
    for (final stroke in props.strokes) {
      final paint = _createPaint(stroke, rect);
      if (paint != null) {
        paint.style = PaintingStyle.stroke;
        paint.strokeWidth = props.strokeWeight;
        canvas.drawOval(rect, paint);
      }
    }
  }

  void _renderFrame(Canvas canvas, FigmaNodeProperties props) {
    // Frames render their background/fills like rectangles
    _renderRect(canvas, props);
  }

  /// Render IMAGE node type - these are standalone image nodes
  void _renderImage(Canvas canvas, FigmaNodeProperties props) {
    final rect = Rect.fromLTWH(props.x, props.y, props.width, props.height);

    // IMAGE nodes may have the image data directly or in fills
    // First try to render from fills with type IMAGE
    for (final fill in props.fills) {
      if (fill['visible'] == false) continue;
      final type = fill['type'] as String? ?? '';

      if (type == 'IMAGE') {
        final success = _tryRenderImageFill(canvas, fill, rect);
        if (success) return;
      }
    }

    // If no IMAGE fill found, try to extract image from node directly
    final raw = props.raw;
    final imageRef = raw['image'] ?? raw['imageRef'] ?? raw['imageHash'];
    if (imageRef != null) {
      // Create a synthetic fill for the image
      final syntheticFill = <String, dynamic>{
        'type': 'IMAGE',
        'image': imageRef,
        'visible': true,
        'opacity': 1.0,
      };
      final success = _tryRenderImageFill(canvas, syntheticFill, rect);
      if (success) return;
    }

    // Fallback: draw placeholder
    _drawImagePlaceholder(canvas, rect, _pendingImages.isNotEmpty);
  }

  void _renderText(Canvas canvas, FigmaNodeProperties props) {
    final rect = Rect.fromLTWH(props.x, props.y, props.width, props.height);

    // Extract text content
    final raw = props.raw;
    String text = '';
    final textData = raw['textData'];
    if (textData is Map) {
      text = textData['characters'] as String? ?? '';
    } else {
      text = raw['characters'] as String? ?? props.name ?? '';
    }

    if (text.isEmpty) {
      // Draw placeholder for empty text
      canvas.drawRect(rect, Paint()
        ..color = Colors.grey.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5);
      return;
    }

    // Get text color from fills
    Color textColor = Colors.black;
    for (final fill in props.fills) {
      if (fill['visible'] == false) continue;
      if (fill['type'] == 'SOLID') {
        final color = fill['color'];
        if (color is Map) {
          final r = ((color['r'] as num?)?.toDouble() ?? 0) * 255;
          final g = ((color['g'] as num?)?.toDouble() ?? 0) * 255;
          final b = ((color['b'] as num?)?.toDouble() ?? 0) * 255;
          final a = ((color['a'] as num?)?.toDouble() ?? 1.0) * 255;
          final opacity = (fill['opacity'] as num?)?.toDouble() ?? 1.0;
          textColor = Color.fromARGB((a * opacity).round(), r.round(), g.round(), b.round());
          break;
        }
      }
    }

    // Get font size
    double fontSize = 14.0;
    final derivedTextData = raw['derivedTextData'];
    if (derivedTextData is Map) {
      final baseFontSize = derivedTextData['baseFontSize'];
      if (baseFontSize is num) {
        fontSize = baseFontSize.toDouble();
      }
    }
    final rawFontSize = raw['fontSize'];
    if (rawFontSize is num) {
      fontSize = rawFontSize.toDouble();
    }

    // Get font weight
    ui.FontWeight fontWeight = ui.FontWeight.w400;
    final rawFontWeight = raw['fontWeight'];
    if (rawFontWeight is num) {
      final weight = rawFontWeight.toInt();
      if (weight >= 700) {
        fontWeight = ui.FontWeight.w700;
      } else if (weight >= 600) {
        fontWeight = ui.FontWeight.w600;
      } else if (weight >= 500) {
        fontWeight = ui.FontWeight.w500;
      } else if (weight <= 300) {
        fontWeight = ui.FontWeight.w300;
      }
    }

    // Get text alignment
    ui.TextAlign textAlign = ui.TextAlign.left;
    final textAlignHorizontal = raw['textAlignHorizontal'] as String?;
    if (textAlignHorizontal == 'CENTER') {
      textAlign = ui.TextAlign.center;
    } else if (textAlignHorizontal == 'RIGHT') {
      textAlign = ui.TextAlign.right;
    } else if (textAlignHorizontal == 'JUSTIFIED') {
      textAlign = ui.TextAlign.justify;
    }

    // Build paragraph
    final paragraphBuilder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: textAlign,
      fontSize: fontSize,
      maxLines: null,
    ))
      ..pushStyle(ui.TextStyle(
        color: textColor,
        fontSize: fontSize,
        fontWeight: fontWeight,
      ))
      ..addText(text);

    final paragraph = paragraphBuilder.build()
      ..layout(ui.ParagraphConstraints(width: props.width));

    // Draw the text
    canvas.drawParagraph(paragraph, Offset(props.x, props.y));
  }

  void _renderVector(Canvas canvas, FigmaNodeProperties props) {
    final rect = Rect.fromLTWH(props.x, props.y, props.width, props.height);
    final raw = props.raw;

    // Get vector paths from fillGeometry and strokeGeometry
    final fillGeometry = raw['fillGeometry'];
    final strokeGeometry = raw['strokeGeometry'];
    final size = ui.Size(props.width, props.height);

    bool hasGeometry = false;

    // Draw fills from fillGeometry
    if (fillGeometry is List) {
      for (final geom in fillGeometry) {
        if (geom is Map) {
          final path = _parseGeometry(geom, size);
          if (path == null) continue;

          // Translate path to node position
          final translatedPath = path.shift(Offset(props.x, props.y));
          hasGeometry = true;

          for (final fill in props.fills) {
            if (fill['visible'] == false) continue;
            final paint = _createPaint(fill, rect);
            if (paint != null) {
              canvas.drawPath(translatedPath, paint);
            }
          }
        }
      }
    }

    // Draw strokes from strokeGeometry
    if (strokeGeometry is List && props.strokeWeight > 0) {
      for (final geom in strokeGeometry) {
        if (geom is Map) {
          final path = _parseGeometry(geom, size);
          if (path == null) continue;

          // Translate path to node position
          final translatedPath = path.shift(Offset(props.x, props.y));
          hasGeometry = true;

          for (final stroke in props.strokes) {
            if (stroke['visible'] == false) continue;
            final paint = _createPaint(stroke, rect);
            if (paint != null) {
              paint.style = PaintingStyle.stroke;
              paint.strokeWidth = props.strokeWeight;
              canvas.drawPath(translatedPath, paint);
            }
          }
        }
      }
    }

    // Fallback: draw simple shape if no geometry
    if (!hasGeometry) {
      for (final fill in props.fills) {
        if (fill['visible'] == false) continue;
        final paint = _createPaint(fill, rect);
        if (paint != null) {
          canvas.drawRect(rect, paint);
        }
      }

      for (final stroke in props.strokes) {
        if (stroke['visible'] == false) continue;
        final paint = _createPaint(stroke, rect);
        if (paint != null) {
          paint.style = PaintingStyle.stroke;
          paint.strokeWidth = props.strokeWeight;
          canvas.drawRect(rect, paint);
        }
      }
    }
  }

  /// Parse geometry data to a UI path
  ui.Path? _parseGeometry(Map geom, ui.Size size) {
    // Try binary commands blob first (more accurate)
    final commandsBlobIndex = geom['commandsBlob'];
    if (commandsBlobIndex is num && _document != null) {
      final blobKey = 'blob_${commandsBlobIndex.toInt()}';
      final blobData = _document!.blobMap[blobKey];
      if (blobData != null) {
        return _parseCommandsBlob(Uint8List.fromList(blobData));
      }
    }

    // Fallback to SVG path string
    final pathData = geom['path'] as String?;
    if (pathData != null) {
      return _parseSvgPath(pathData, size);
    }

    return null;
  }

  /// Parse Figma binary commands blob format
  /// Format: command_byte followed by float32 coordinates
  /// Commands: 0=close, 1=moveTo(x,y), 2=lineTo(x,y), 3=quadTo, 4=cubicTo
  ui.Path _parseCommandsBlob(Uint8List bytes) {
    final path = ui.Path();
    if (bytes.isEmpty) return path;

    final data = ByteData.sublistView(bytes);
    int offset = 0;

    double readFloat() {
      if (offset + 4 > bytes.length) return 0.0;
      final value = data.getFloat32(offset, Endian.little);
      offset += 4;
      return value;
    }

    while (offset < bytes.length) {
      final cmd = bytes[offset];
      offset++;

      switch (cmd) {
        case 0: // closePath
          path.close();
          break;
        case 1: // moveTo
          final x = readFloat();
          final y = readFloat();
          path.moveTo(x, y);
          break;
        case 2: // lineTo
          final x = readFloat();
          final y = readFloat();
          path.lineTo(x, y);
          break;
        case 3: // quadraticBezierTo
          final x1 = readFloat();
          final y1 = readFloat();
          final x2 = readFloat();
          final y2 = readFloat();
          path.quadraticBezierTo(x1, y1, x2, y2);
          break;
        case 4: // cubicTo
          final x1 = readFloat();
          final y1 = readFloat();
          final x2 = readFloat();
          final y2 = readFloat();
          final x3 = readFloat();
          final y3 = readFloat();
          path.cubicTo(x1, y1, x2, y2, x3, y3);
          break;
        default:
          // Unknown command - skip to avoid infinite loop
          break;
      }
    }

    return path;
  }

  /// Parse SVG path data string
  ui.Path _parseSvgPath(String pathData, ui.Size size) {
    final path = ui.Path();
    final commands = pathData.split(RegExp(r'(?=[MLHVCSQTAZmlhvcsqtaz])'));

    double x = 0, y = 0;
    double lastCx = 0, lastCy = 0;

    for (var cmd in commands) {
      cmd = cmd.trim();
      if (cmd.isEmpty) continue;

      final type = cmd[0];
      final args = cmd.substring(1).trim().split(RegExp(r'[\s,]+')).where((s) => s.isNotEmpty).map((s) => double.tryParse(s) ?? 0).toList();

      switch (type) {
        case 'M':
          if (args.length >= 2) {
            x = args[0];
            y = args[1];
            path.moveTo(x, y);
            for (int i = 2; i + 1 < args.length; i += 2) {
              x = args[i];
              y = args[i + 1];
              path.lineTo(x, y);
            }
          }
          break;
        case 'm':
          if (args.length >= 2) {
            x += args[0];
            y += args[1];
            path.moveTo(x, y);
            for (int i = 2; i + 1 < args.length; i += 2) {
              x += args[i];
              y += args[i + 1];
              path.lineTo(x, y);
            }
          }
          break;
        case 'L':
          for (int i = 0; i + 1 < args.length; i += 2) {
            x = args[i];
            y = args[i + 1];
            path.lineTo(x, y);
          }
          break;
        case 'l':
          for (int i = 0; i + 1 < args.length; i += 2) {
            x += args[i];
            y += args[i + 1];
            path.lineTo(x, y);
          }
          break;
        case 'H':
          for (final arg in args) {
            x = arg;
            path.lineTo(x, y);
          }
          break;
        case 'h':
          for (final arg in args) {
            x += arg;
            path.lineTo(x, y);
          }
          break;
        case 'V':
          for (final arg in args) {
            y = arg;
            path.lineTo(x, y);
          }
          break;
        case 'v':
          for (final arg in args) {
            y += arg;
            path.lineTo(x, y);
          }
          break;
        case 'C':
          for (int i = 0; i + 5 < args.length; i += 6) {
            lastCx = args[i + 2];
            lastCy = args[i + 3];
            x = args[i + 4];
            y = args[i + 5];
            path.cubicTo(args[i], args[i + 1], lastCx, lastCy, x, y);
          }
          break;
        case 'c':
          for (int i = 0; i + 5 < args.length; i += 6) {
            final x1 = x + args[i];
            final y1 = y + args[i + 1];
            lastCx = x + args[i + 2];
            lastCy = y + args[i + 3];
            x += args[i + 4];
            y += args[i + 5];
            path.cubicTo(x1, y1, lastCx, lastCy, x, y);
          }
          break;
        case 'S':
          for (int i = 0; i + 3 < args.length; i += 4) {
            final x1 = 2 * x - lastCx;
            final y1 = 2 * y - lastCy;
            lastCx = args[i];
            lastCy = args[i + 1];
            x = args[i + 2];
            y = args[i + 3];
            path.cubicTo(x1, y1, lastCx, lastCy, x, y);
          }
          break;
        case 's':
          for (int i = 0; i + 3 < args.length; i += 4) {
            final x1 = 2 * x - lastCx;
            final y1 = 2 * y - lastCy;
            lastCx = x + args[i];
            lastCy = y + args[i + 1];
            x += args[i + 2];
            y += args[i + 3];
            path.cubicTo(x1, y1, lastCx, lastCy, x, y);
          }
          break;
        case 'Q':
          for (int i = 0; i + 3 < args.length; i += 4) {
            lastCx = args[i];
            lastCy = args[i + 1];
            x = args[i + 2];
            y = args[i + 3];
            path.quadraticBezierTo(lastCx, lastCy, x, y);
          }
          break;
        case 'q':
          for (int i = 0; i + 3 < args.length; i += 4) {
            lastCx = x + args[i];
            lastCy = y + args[i + 1];
            x += args[i + 2];
            y += args[i + 3];
            path.quadraticBezierTo(lastCx, lastCy, x, y);
          }
          break;
        case 'T':
          for (int i = 0; i + 1 < args.length; i += 2) {
            lastCx = 2 * x - lastCx;
            lastCy = 2 * y - lastCy;
            x = args[i];
            y = args[i + 1];
            path.quadraticBezierTo(lastCx, lastCy, x, y);
          }
          break;
        case 't':
          for (int i = 0; i + 1 < args.length; i += 2) {
            lastCx = 2 * x - lastCx;
            lastCy = 2 * y - lastCy;
            x += args[i];
            y += args[i + 1];
            path.quadraticBezierTo(lastCx, lastCy, x, y);
          }
          break;
        case 'A':
        case 'a':
          // Arc command - simplified to line for now
          for (int i = 0; i + 6 < args.length; i += 7) {
            final endX = type == 'A' ? args[i + 5] : x + args[i + 5];
            final endY = type == 'A' ? args[i + 6] : y + args[i + 6];
            path.lineTo(endX, endY);
            x = endX;
            y = endY;
          }
          break;
        case 'Z':
        case 'z':
          path.close();
          break;
      }
    }

    return path;
  }

  /// Create a Paint from fill/stroke data
  /// [rect] is needed for gradient shader creation
  Paint? _createPaint(Map<String, dynamic> paintData, Rect rect) {
    final type = paintData['type'] as String? ?? 'SOLID';
    final visible = paintData['visible'] as bool? ?? true;
    final opacity = (paintData['opacity'] as num?)?.toDouble() ?? 1.0;

    if (!visible) return null;

    final paint = Paint();

    switch (type) {
      case 'SOLID':
        final color = paintData['color'];
        if (color is Map) {
          final r = ((color['r'] as num?)?.toDouble() ?? 0) * 255;
          final g = ((color['g'] as num?)?.toDouble() ?? 0) * 255;
          final b = ((color['b'] as num?)?.toDouble() ?? 0) * 255;
          final a = ((color['a'] as num?)?.toDouble() ?? 1.0) * 255 * opacity;
          paint.color = Color.fromARGB(a.round(), r.round(), g.round(), b.round());
        } else {
          paint.color = Colors.grey.withValues(alpha: opacity);
        }
        break;

      case 'GRADIENT_LINEAR':
      case 'GRADIENT_RADIAL':
      case 'GRADIENT_ANGULAR':
      case 'GRADIENT_DIAMOND':
        // Build proper gradient with shader
        final gradient = _buildGradient(paintData, type, rect.size);
        if (gradient != null) {
          paint.shader = gradient.createShader(rect);
        } else {
          // Fallback to first stop color
          final stops = paintData['gradientStops'] as List?;
          if (stops != null && stops.isNotEmpty) {
            final firstStop = stops.first as Map?;
            final color = firstStop?['color'] as Map?;
            if (color != null) {
              paint.color = _buildColor(color, opacity) ?? Colors.grey;
            }
          } else {
            paint.color = Colors.grey.withValues(alpha: opacity);
          }
        }
        break;

      case 'IMAGE':
        // Image fills need special handling - return null here
        // and handle images separately in the render methods
        // This signals that we should try to draw an image instead
        return null;

      default:
        paint.color = Colors.grey.withValues(alpha: opacity);
    }

    return paint;
  }

  /// Build a Flutter Color from Figma color data
  Color? _buildColor(Map colorData, [double opacity = 1.0]) {
    final r = (colorData['r'] as num?)?.toDouble() ?? 0;
    final g = (colorData['g'] as num?)?.toDouble() ?? 0;
    final b = (colorData['b'] as num?)?.toDouble() ?? 0;
    final a = (colorData['a'] as num?)?.toDouble() ?? 1.0;

    return Color.fromRGBO(
      (r * 255).round().clamp(0, 255),
      (g * 255).round().clamp(0, 255),
      (b * 255).round().clamp(0, 255),
      a * opacity,
    );
  }

  /// Build a Flutter Gradient from Figma paint data
  Gradient? _buildGradient(Map<String, dynamic> paint, String type, ui.Size size) {
    final stops = paint['gradientStops'] as List?;
    if (stops == null || stops.isEmpty) return null;

    final colors = <Color>[];
    final stopPositions = <double>[];

    for (final stop in stops) {
      if (stop is Map) {
        final color = stop['color'];
        final position = (stop['position'] as num?)?.toDouble() ?? 0;

        if (color is Map) {
          colors.add(_buildColor(color) ?? Colors.transparent);
        }
        stopPositions.add(position);
      }
    }

    if (colors.length < 2) return null;

    // Parse gradient transform handles
    final gradientTransform = paint['gradientTransform'] as Map<String, dynamic>?;
    final matrixTransform = paint['transform'] as Map<String, dynamic>?;
    final handles = _parseGradientHandles(gradientTransform, matrixTransform);

    switch (type) {
      case 'GRADIENT_LINEAR':
        return _buildLinearGradient(colors, stopPositions, handles);
      case 'GRADIENT_RADIAL':
        return _buildRadialGradient(colors, stopPositions, handles);
      case 'GRADIENT_ANGULAR':
        return _buildAngularGradient(colors, stopPositions, handles);
      case 'GRADIENT_DIAMOND':
        // Approximate diamond as radial
        return _buildRadialGradient(colors, stopPositions, handles);
      default:
        return null;
    }
  }

  /// Parse gradient handle positions from transform data
  _GradientHandles _parseGradientHandles(
    Map<String, dynamic>? gradientTransform,
    Map<String, dynamic>? matrixTransform,
  ) {
    // Try handle positions format first
    if (gradientTransform != null) {
      final handleA = gradientTransform['handlePositionA'] as Map<String, dynamic>?;
      final handleB = gradientTransform['handlePositionB'] as Map<String, dynamic>?;
      final handleC = gradientTransform['handlePositionC'] as Map<String, dynamic>?;

      if (handleA != null || handleB != null) {
        return _GradientHandles(
          a: _parseVector(handleA) ?? const Offset(0.5, 0),
          b: _parseVector(handleB) ?? const Offset(0.5, 1),
          c: _parseVector(handleC) ?? const Offset(0, 0.5),
        );
      }
    }

    // Try transform matrix format
    if (matrixTransform != null) {
      final m00 = (matrixTransform['m00'] as num?)?.toDouble() ?? 1.0;
      final m01 = (matrixTransform['m01'] as num?)?.toDouble() ?? 0.0;
      final m02 = (matrixTransform['m02'] as num?)?.toDouble() ?? 0.0;
      final m10 = (matrixTransform['m10'] as num?)?.toDouble() ?? 0.0;
      final m11 = (matrixTransform['m11'] as num?)?.toDouble() ?? 1.0;
      final m12 = (matrixTransform['m12'] as num?)?.toDouble() ?? 0.0;

      // Transform from gradient space to node space
      final startX = m00 * 0.0 + m01 * 0.5 + m02;
      final startY = m10 * 0.0 + m11 * 0.5 + m12;
      final endX = m00 * 1.0 + m01 * 0.5 + m02;
      final endY = m10 * 1.0 + m11 * 0.5 + m12;
      final ctrlX = m00 * 0.5 + m01 * 0.0 + m02;
      final ctrlY = m10 * 0.5 + m11 * 0.0 + m12;

      return _GradientHandles(
        a: Offset(startX, startY),
        b: Offset(endX, endY),
        c: Offset(ctrlX, ctrlY),
      );
    }

    // Default: vertical gradient from top to bottom
    return _GradientHandles(
      a: const Offset(0.5, 0),
      b: const Offset(0.5, 1),
      c: const Offset(0, 0.5),
    );
  }

  Offset? _parseVector(Map<String, dynamic>? vector) {
    if (vector == null) return null;
    final x = (vector['x'] as num?)?.toDouble() ?? 0;
    final y = (vector['y'] as num?)?.toDouble() ?? 0;
    return Offset(x, y);
  }

  /// Build a linear gradient with proper transform
  LinearGradient _buildLinearGradient(
    List<Color> colors,
    List<double> stops,
    _GradientHandles handles,
  ) {
    // Convert normalized coordinates (0-1) to Flutter alignment (-1 to 1)
    final beginAlign = Alignment(
      (handles.a.dx * 2) - 1,
      (handles.a.dy * 2) - 1,
    );
    final endAlign = Alignment(
      (handles.b.dx * 2) - 1,
      (handles.b.dy * 2) - 1,
    );

    return LinearGradient(
      colors: colors,
      stops: stops,
      begin: beginAlign,
      end: endAlign,
    );
  }

  /// Build a radial gradient with proper transform
  RadialGradient _buildRadialGradient(
    List<Color> colors,
    List<double> stops,
    _GradientHandles handles,
  ) {
    final centerAlign = Alignment(
      (handles.a.dx * 2) - 1,
      (handles.a.dy * 2) - 1,
    );

    // Calculate radius from handles
    final radius = (handles.b - handles.a).distance;

    return RadialGradient(
      colors: colors,
      stops: stops,
      center: centerAlign,
      radius: radius > 0 ? radius : 0.5,
    );
  }

  /// Build an angular/sweep gradient
  SweepGradient _buildAngularGradient(
    List<Color> colors,
    List<double> stops,
    _GradientHandles handles,
  ) {
    final centerAlign = Alignment(
      (handles.a.dx * 2) - 1,
      (handles.a.dy * 2) - 1,
    );

    // Calculate start angle from handle positions
    final direction = handles.b - handles.a;
    final startAngle = math.atan2(direction.dy, direction.dx);

    return SweepGradient(
      colors: colors,
      stops: stops,
      center: centerAlign,
      startAngle: startAngle,
      endAngle: startAngle + 2 * math.pi,
    );
  }

  /// Try to render an image fill
  /// Returns true if image was drawn, false if placeholder should be used
  bool _tryRenderImageFill(Canvas canvas, Map<String, dynamic> fill, Rect rect) {
    if (_document == null) return false;

    final blobMap = _document!.blobMap;
    List<int>? imageBytes;
    String cacheKey = '';
    String? hexHash;

    // First, extract the image hash from the fill data
    dynamic imageRef = fill['image'] ?? fill['imageHash'] ?? fill['imageRef'] ?? fill['hash'];
    if (imageRef != null) {
      if (imageRef is Map) {
        final bytes = imageRef['hash'] ?? imageRef['bytes'];
        if (bytes is List) {
          hexHash = imageHashToHex(bytes);
        }
      } else if (imageRef is List) {
        hexHash = imageHashToHex(imageRef);
      } else if (imageRef is String) {
        hexHash = imageRef;
      }
    }

    // Method 1: Try loading from filesystem (imagesDirectory) - this is primary
    if (hexHash != null && hexHash.isNotEmpty && _imagesDirectory != null) {
      final imagePath = '$_imagesDirectory/$hexHash';
      cacheKey = 'file_$hexHash';

      // Check cache first
      if (_imageCache.containsKey(cacheKey)) {
        final image = _imageCache[cacheKey]!;
        debugPrint('_DartTileRenderer: CACHE HIT for $cacheKey, drawing image ${image.width}x${image.height}');
        _drawImage(canvas, image, rect, fill);
        return true;
      } else {
        debugPrint('_DartTileRenderer: CACHE MISS for $cacheKey (cache has ${_imageCache.length} images)');
      }

      // Try to load from file
      final file = File(imagePath);
      if (file.existsSync()) {
        if (!_pendingImages.contains(cacheKey)) {
          _pendingImages.add(cacheKey);
          _decodeImageFromFile(cacheKey, imagePath);
        }
        return false; // Show placeholder while loading
      }
    }

    // Method 2: Use imagePaintDataIndex or blobIndex (numeric index lookup)
    final blobIndex = fill['imagePaintDataIndex'] ?? fill['blobIndex'];
    if (imageBytes == null && blobIndex is num) {
      final blobKey = 'blob_${blobIndex.toInt()}';
      if (blobMap.containsKey(blobKey)) {
        imageBytes = blobMap[blobKey];
        cacheKey = blobKey;
      }
    }

    // Method 3: Try blob lookup by hex hash
    if (imageBytes == null && hexHash != null && hexHash.isNotEmpty) {
      cacheKey = hexHash;
      if (blobMap.containsKey(hexHash)) {
        imageBytes = blobMap[hexHash];
      }
    }

    // If no valid image blob found, don't try to decode
    if (imageBytes == null || !_isValidImageBlob(imageBytes)) {
      return false;
    }

    if (cacheKey.isEmpty) return false;

    // Check if image is already decoded and cached
    if (_imageCache.containsKey(cacheKey)) {
      final image = _imageCache[cacheKey]!;
      _drawImage(canvas, image, rect, fill);
      return true;
    }

    // Start async decode if we have bytes and aren't already decoding
    if (imageBytes != null && !_pendingImages.contains(cacheKey)) {
      _pendingImages.add(cacheKey);
      _decodeImage(cacheKey, imageBytes);
    }

    // Draw placeholder while loading
    return false;
  }

  /// Decode image bytes asynchronously and cache
  Future<void> _decodeImage(String hexHash, List<int> bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(
        Uint8List.fromList(bytes),
      );
      final frame = await codec.getNextFrame();
      _imageCache[hexHash] = frame.image;
      _pendingImages.remove(hexHash);

      // Schedule debounced cache invalidation (batches multiple image loads)
      _scheduleCacheInvalidation();
    } catch (e) {
      debugPrint('_DartTileRenderer: Failed to decode image $hexHash - $e');
      _pendingImages.remove(hexHash);
    }
  }

  /// Decode image from filesystem path asynchronously and cache
  Future<void> _decodeImageFromFile(String cacheKey, String filePath) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();

      if (!_isValidImageBlob(bytes)) {
        debugPrint('_DartTileRenderer: Invalid image format at $filePath');
        _pendingImages.remove(cacheKey);
        return;
      }

      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      _imageCache[cacheKey] = frame.image;
      _pendingImages.remove(cacheKey);

      // Schedule debounced cache invalidation (batches multiple image loads)
      _scheduleCacheInvalidation();
      debugPrint('_DartTileRenderer: Loaded image from file $filePath');
    } catch (e) {
      debugPrint('_DartTileRenderer: Failed to load image from $filePath - $e');
      _pendingImages.remove(cacheKey);
    }
  }

  /// Draw a cached image to the canvas
  void _drawImage(Canvas canvas, ui.Image image, Rect destRect, Map<String, dynamic> fill) {
    final opacity = (fill['opacity'] as num?)?.toDouble() ?? 1.0;
    final scaleMode = fill['scaleMode'] as String? ?? 'FILL';

    final srcRect = Rect.fromLTWH(
      0, 0,
      image.width.toDouble(),
      image.height.toDouble(),
    );

    Rect drawRect = destRect;

    // Apply scale mode
    if (scaleMode == 'FIT') {
      // Contain - fit entire image within bounds
      final srcAspect = srcRect.width / srcRect.height;
      final destAspect = destRect.width / destRect.height;

      if (srcAspect > destAspect) {
        // Image is wider - fit to width
        final newHeight = destRect.width / srcAspect;
        final yOffset = (destRect.height - newHeight) / 2;
        drawRect = Rect.fromLTWH(
          destRect.left, destRect.top + yOffset,
          destRect.width, newHeight,
        );
      } else {
        // Image is taller - fit to height
        final newWidth = destRect.height * srcAspect;
        final xOffset = (destRect.width - newWidth) / 2;
        drawRect = Rect.fromLTWH(
          destRect.left + xOffset, destRect.top,
          newWidth, destRect.height,
        );
      }
    }
    // FILL and STRETCH use destRect as-is

    debugPrint('_DartTileRenderer: Drawing image at $drawRect (src: $srcRect, opacity: $opacity)');
    canvas.drawImageRect(
      image,
      srcRect,
      drawRect,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Color.fromRGBO(255, 255, 255, opacity),
    );
  }

  /// Draw an image placeholder (loading or error state)
  void _drawImagePlaceholder(Canvas canvas, Rect rect, bool isLoading) {
    // Draw a light gray background
    canvas.drawRect(rect, Paint()..color = const Color(0xFFE0E0E0));

    // Draw loading indicator or error icon
    final iconPaint = Paint()
      ..color = const Color(0xFF9E9E9E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final center = rect.center;
    final size = (rect.shortestSide * 0.3).clamp(10.0, 40.0);

    if (isLoading) {
      // Draw a simple loading spinner representation
      canvas.drawCircle(center, size / 2, iconPaint);
    } else {
      // Draw image icon (simplified)
      final iconRect = Rect.fromCenter(center: center, width: size, height: size * 0.75);
      canvas.drawRect(iconRect, iconPaint);
      // Small triangle for "mountain" in image icon
      final path = ui.Path()
        ..moveTo(iconRect.left + size * 0.2, iconRect.bottom - 5)
        ..lineTo(iconRect.left + size * 0.5, iconRect.top + size * 0.3)
        ..lineTo(iconRect.right - size * 0.2, iconRect.bottom - 5);
      canvas.drawPath(path, iconPaint);
    }
  }

  /// Check if blob data looks like a valid image (PNG/JPEG/GIF/WebP)
  bool _isValidImageBlob(List<int>? bytes) {
    if (bytes == null || bytes.length < 8) return false;

    // Check for PNG magic bytes: 89 50 4E 47 0D 0A 1A 0A
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 &&
        bytes[4] == 0x0D && bytes[5] == 0x0A && bytes[6] == 0x1A && bytes[7] == 0x0A) {
      return true;
    }

    // Check for JPEG magic bytes: FF D8 FF
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return true;
    }

    // Check for GIF magic bytes: GIF87a or GIF89a
    if (bytes.length >= 6 &&
        bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38 &&
        (bytes[4] == 0x37 || bytes[4] == 0x39) && bytes[5] == 0x61) {
      return true;
    }

    // Check for WebP magic bytes: RIFF....WEBP
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
        bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
      return true;
    }

    return false;
  }

  /// Invalidate tiles that contain changed nodes
  void invalidateTiles(List<String> changedNodeIds) {
    // Simple approach: clear all cached tiles
    // More sophisticated: find affected tiles and clear only those
    clearCache();
  }

  /// Clear all cached tiles
  void clearCache() {
    for (final image in _tileCache.values) {
      try {
        // Only dispose if image is still valid
        if (image.width > 0 && image.height > 0) {
          image.dispose();
        }
      } catch (e) {
        // Image may already be disposed or invalid, ignore
      }
    }
    _tileCache.clear();

    // Notify listeners that cache was invalidated (triggers re-render)
    onCacheInvalidated?.call();
  }

  /// Schedule a debounced cache invalidation
  /// This batches multiple image loads into a single invalidation
  void _scheduleCacheInvalidation() {
    // Mark that invalidation is needed
    _cacheInvalidationPending = true;

    // Cancel any existing timer
    _cacheInvalidationTimer?.cancel();

    // Schedule invalidation after 100ms of no new image loads
    _cacheInvalidationTimer = Timer(const Duration(milliseconds: 100), () {
      if (_cacheInvalidationPending) {
        _cacheInvalidationPending = false;
        debugPrint('_DartTileRenderer: Executing batched cache invalidation');
        clearCache();
      }
    });
  }

  /// Dispose resources
  void dispose() {
    // Cancel any pending timer
    _cacheInvalidationTimer?.cancel();
    _cacheInvalidationTimer = null;
    // Don't call clearCache here - let Flutter handle image disposal
    _tileCache.clear();
    _spatialIndex.clear();
    _document = null;
  }
}

/// Helper class to hold gradient handle positions
class _GradientHandles {
  final Offset a; // Start/center point
  final Offset b; // End point
  final Offset c; // Control/width point

  const _GradientHandles({
    required this.a,
    required this.b,
    required this.c,
  });
}
