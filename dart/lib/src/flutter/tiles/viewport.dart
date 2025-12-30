/// Viewport calculations for tile-based rendering
///
/// Handles conversion between screen coordinates and world coordinates,
/// and calculates which tiles are visible.

import 'package:flutter/widgets.dart';

/// Fixed tile size in world coordinates (must match Rust TILE_SIZE)
const double kTileSize = 1024.0;

/// Viewport in world coordinates
class WorldViewport {
  /// World-space X coordinate of viewport top-left
  final double x;

  /// World-space Y coordinate of viewport top-left
  final double y;

  /// Viewport width in world coordinates
  final double width;

  /// Viewport height in world coordinates
  final double height;

  /// Zoom scale (1.0 = 100%, 0.5 = 50%)
  final double scale;

  const WorldViewport({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.scale,
  });

  /// Create viewport from screen size and transformation matrix
  factory WorldViewport.fromScreen({
    required Size screenSize,
    required Matrix4 transform,
  }) {
    // Extract scale from matrix
    final scale = transform.getMaxScaleOnAxis();

    // Extract translation
    final translation = transform.getTranslation();

    return WorldViewport(
      x: -translation.x / scale,
      y: -translation.y / scale,
      width: screenSize.width / scale,
      height: screenSize.height / scale,
      scale: scale,
    );
  }

  /// Create viewport from TransformationController
  factory WorldViewport.fromController({
    required Size screenSize,
    required TransformationController controller,
  }) {
    return WorldViewport.fromScreen(
      screenSize: screenSize,
      transform: controller.value,
    );
  }

  /// Get the level of detail for this zoom level
  int get lod {
    if (scale >= 0.5) return 0; // Full detail
    if (scale >= 0.25) return 1; // Half detail
    if (scale >= 0.125) return 2; // Quarter detail
    return 3; // Minimum detail
  }

  /// Get the effective tile size at current LOD
  double get effectiveTileSize {
    final lodScale = 1 << lod; // 2^lod
    return kTileSize * lodScale;
  }

  /// Check if a rectangle in world coordinates intersects this viewport
  bool intersects(Rect rect) {
    return !(rect.right < x ||
        rect.left > x + width ||
        rect.bottom < y ||
        rect.top > y + height);
  }

  /// Convert world coordinates to screen coordinates
  Offset worldToScreen(Offset worldPoint, Matrix4 transform) {
    final translation = transform.getTranslation();
    return Offset(
      worldPoint.dx * scale + translation.x,
      worldPoint.dy * scale + translation.y,
    );
  }

  /// Convert screen coordinates to world coordinates
  Offset screenToWorld(Offset screenPoint, Matrix4 transform) {
    final translation = transform.getTranslation();
    return Offset(
      (screenPoint.dx - translation.x) / scale,
      (screenPoint.dy - translation.y) / scale,
    );
  }

  @override
  String toString() => 'WorldViewport($x, $y, ${width}x$height @ ${scale}x)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WorldViewport &&
        other.x == x &&
        other.y == y &&
        other.width == width &&
        other.height == height &&
        other.scale == scale;
  }

  @override
  int get hashCode => Object.hash(x, y, width, height, scale);
}

/// Tile coordinate in grid space
class TileCoord {
  final int x;
  final int y;
  final int zoomLevel;

  const TileCoord(this.x, this.y, this.zoomLevel);

  /// Get the world-space bounds of this tile
  Rect get bounds {
    final lodScale = 1 << zoomLevel; // 2^zoomLevel
    final tileSize = kTileSize * lodScale;
    return Rect.fromLTWH(
      x * tileSize,
      y * tileSize,
      tileSize,
      tileSize,
    );
  }

  @override
  String toString() => 'TileCoord($x, $y, z$zoomLevel)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TileCoord &&
        other.x == x &&
        other.y == y &&
        other.zoomLevel == zoomLevel;
  }

  @override
  int get hashCode => Object.hash(x, y, zoomLevel);
}

/// Calculate visible tiles for a viewport
List<TileCoord> getVisibleTiles(WorldViewport viewport) {
  final zoomLevel = viewport.lod;
  final tileSize = viewport.effectiveTileSize;

  // Calculate tile range covering viewport
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

/// Extension to get translation from Matrix4
extension Matrix4Translation on Matrix4 {
  Offset getTranslation() {
    return Offset(storage[12], storage[13]);
  }
}
