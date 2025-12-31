/// Viewport calculations for tile-based rendering
///
/// Handles conversion between screen coordinates and world coordinates,
/// and calculates which tiles are visible.

import 'package:flutter/widgets.dart';

/// Fixed tile size in world coordinates (must match Rust TILE_SIZE)
const double kTileSize = 1024.0;

/// LOD Configuration - simplified to 2 levels with hysteresis
///
/// LOD 0: High detail (scale >= 0.5) - 1024x1024 tiles
/// LOD 1: Low detail (scale < 0.5) - 4096x4096 tiles (4x larger)
///
/// Hysteresis prevents rapid LOD switching at threshold boundaries
const double kLodThreshold = 0.5;      // Primary threshold
const double kLodHysteresis = 0.15;    // 15% buffer zone
const double kLodUpThreshold = kLodThreshold + kLodHysteresis;   // 0.65 - switch UP to LOD 0
const double kLodDownThreshold = kLodThreshold - kLodHysteresis; // 0.35 - switch DOWN to LOD 1

/// Global LOD state tracker for hysteresis
class _LodState {
  static int currentLod = 1;  // Start at low detail (safe default)

  /// Calculate LOD with hysteresis to prevent thrashing
  static int calculateLod(double scale) {
    if (currentLod == 0) {
      // Currently high detail - only drop to low if scale goes well below threshold
      if (scale < kLodDownThreshold) {
        currentLod = 1;
      }
    } else {
      // Currently low detail - only jump to high if scale goes well above threshold
      if (scale >= kLodUpThreshold) {
        currentLod = 0;
      }
    }
    return currentLod;
  }

  /// Reset LOD state (call when switching documents/pages)
  static void reset() {
    currentLod = 1;
  }
}

/// Public function to reset LOD state when switching pages/documents
void resetLodState() {
  _LodState.reset();
}

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

  /// Get the level of detail for this zoom level (with hysteresis)
  /// LOD 0: High detail - 1024x1024 tiles
  /// LOD 1: Low detail - 4096x4096 tiles
  int get lod => _LodState.calculateLod(scale);

  /// Get the effective tile size at current LOD
  /// LOD 0: 1024 (1x) - for close-up work
  /// LOD 1: 4096 (4x) - for overview/zoomed out
  double get effectiveTileSize {
    return lod == 0 ? kTileSize : kTileSize * 4;
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
  /// LOD 0: 1024x1024 tiles
  /// LOD 1: 4096x4096 tiles
  Rect get bounds {
    final tileSize = zoomLevel == 0 ? kTileSize : kTileSize * 4;
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
