/// Tile Backend Abstraction
///
/// Provides an interface for tile rendering backends, allowing
/// switching between Rust WASM/native and pure Dart implementations.

import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'viewport.dart';
import 'tile_rasterizer.dart';
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
  /// Initialize the backend with a document
  Future<void> initialize(dynamic document, String rootNodeId);

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
  String? _rootNodeId;
  bool _initialized = false;
  final TileRasterizer _rasterizer = TileRasterizer();

  @override
  String get name => 'Rust Native/WASM';

  @override
  bool get isReady => _initialized && _rustDocument != null;

  @override
  Future<void> initialize(dynamic document, String rootNodeId) async {
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
    } else {
      debugPrint('RustTileBackend: Unsupported document type ${document.runtimeType}');
      _initialized = false;
    }
  }

  @override
  Future<TileResult?> renderTile(TileCoord coord) async {
    if (!isReady) return null;

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
    if (!isReady) return;

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
    if (!isReady) return;

    try {
      await rust.clearTileCache(doc: _rustDocument!);
    } catch (e) {
      debugPrint('RustTileBackend: Error clearing cache - $e');
    }
  }

  @override
  void dispose() {
    _rustDocument = null;
    _initialized = false;
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

/// Pure Dart tile backend (placeholder implementation)
class DartTileBackend extends TileBackend {
  // ignore: unused_field - reserved for future Dart-native rendering
  dynamic _document;
  // ignore: unused_field - reserved for future Dart-native rendering
  String? _rootNodeId;
  bool _initialized = false;
  final TileRasterizer _rasterizer = TileRasterizer();

  @override
  String get name => 'Pure Dart';

  @override
  bool get isReady => _initialized;

  @override
  Future<void> initialize(dynamic document, String rootNodeId) async {
    _document = document;
    _rootNodeId = rootNodeId;
    _initialized = true;
    debugPrint('DartTileBackend: Initialized');
  }

  @override
  Future<TileResult?> renderTile(TileCoord coord) async {
    if (!isReady) return null;

    // Create placeholder tile for now
    final image = await _rasterizer.createPlaceholderTile(coord);

    return TileResult(
      coord: coord,
      image: image,
      nodeCount: 0,
      fromCache: false,
    );
  }

  @override
  List<TileCoord> getVisibleTiles(WorldViewport viewport) {
    return getVisibleTilesLocal(viewport);
  }

  @override
  Future<void> invalidateTiles(List<String> changedNodeIds) async {
    // No-op for Dart backend currently
  }

  @override
  Future<void> clearCache() async {
    // No-op for Dart backend currently
  }

  @override
  void dispose() {
    _document = null;
    _initialized = false;
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
