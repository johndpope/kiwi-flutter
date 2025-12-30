/// Tile-based rendering system for efficient large document display
///
/// This module provides viewport culling, tile caching, and LOD support
/// for rendering large Figma documents (17,000+ nodes) efficiently.
///
/// ## Usage
///
/// ```dart
/// TileCanvas(
///   document: figmaDocument,
///   rootNodeId: pageId,
///   config: TileManagerConfig(
///     showDebugOverlay: true,
///     maxCachedTiles: 256,
///     backendType: TileBackendType.rust, // or TileBackendType.dart
///   ),
/// )
/// ```
///
/// ## Backend Toggle
///
/// Use `BackendToggle` widget to let users switch between Rust and Dart backends:
///
/// ```dart
/// BackendToggle(
///   currentType: tileManager.backendType,
///   onChanged: (type) => tileManager.setBackendType(type),
/// )
/// ```

export 'viewport.dart';
export 'tile_painter.dart';
export 'tile_manager.dart';
export 'tile_rasterizer.dart';
export 'tile_backend.dart';
