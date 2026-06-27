/// Viewport calculations for tile-based rendering
///
/// Handles conversion between screen coordinates and world coordinates,
/// and calculates which tiles are visible.

import 'package:flutter/widgets.dart';

/// Fixed tile size in world coordinates (must match Rust TILE_SIZE)
const double kTileSize = 1024.0;

/// LOD Configuration - 5 levels for granular detail control
///
/// LOD 0: Finest detail (scale >= 2.0) - 256x256 tiles (zoomed in)
/// LOD 1: High detail (scale >= 1.0) - 512x512 tiles
/// LOD 2: Base detail (scale >= 0.5) - 1024x1024 tiles (default)
/// LOD 3: Low detail (scale >= 0.25) - 2048x2048 tiles
/// LOD 4: Coarse detail (scale < 0.25) - 4096x4096 tiles (overview)
///
/// Hysteresis prevents rapid LOD switching at threshold boundaries

/// Scale thresholds for each LOD level (descending order)
const List<double> kLodScaleThresholds = [
  2.0,   // LOD 0: scale >= 2.0 (zoomed in, finest detail)
  1.0,   // LOD 1: scale >= 1.0
  0.5,   // LOD 2: scale >= 0.5 (base/default)
  0.25,  // LOD 3: scale >= 0.25
  0.0,   // LOD 4: scale < 0.25 (overview, coarsest)
];

/// Tile size multipliers relative to kTileSize (1024)
const List<double> kLodTileMultipliers = [
  0.25,  // LOD 0: 256x256 tiles (fine detail when zoomed in)
  0.5,   // LOD 1: 512x512 tiles
  1.0,   // LOD 2: 1024x1024 tiles (base)
  2.0,   // LOD 3: 2048x2048 tiles
  4.0,   // LOD 4: 4096x4096 tiles (coarse for overview)
];

/// Hysteresis buffer (10% per level transition)
const double kLodHysteresis = 0.1;

/// Global LOD state tracker for hysteresis
class _LodState {
  static int currentLod = 2;  // Start at base LOD (1024x1024)

  /// Calculate LOD with hysteresis to prevent thrashing
  static int calculateLod(double scale) {
    // Find target LOD based on scale
    int targetLod = kLodScaleThresholds.length - 1;
    for (int i = 0; i < kLodScaleThresholds.length; i++) {
      if (scale >= kLodScaleThresholds[i]) {
        targetLod = i;
        break;
      }
    }

    // Apply hysteresis - only change if crossing threshold by margin
    if (targetLod < currentLod) {
      // Zooming in - need scale > threshold * (1 + hysteresis) to switch to finer LOD
      final threshold = kLodScaleThresholds[targetLod];
      if (scale >= threshold * (1 + kLodHysteresis)) {
        currentLod = targetLod;
      }
    } else if (targetLod > currentLod) {
      // Zooming out - need scale < threshold * (1 - hysteresis) to switch to coarser LOD
      final threshold = kLodScaleThresholds[currentLod];
      if (scale < threshold * (1 - kLodHysteresis)) {
        currentLod = targetLod;
      }
    }

    return currentLod;
  }

  /// Reset LOD state (call when switching documents/pages)
  static void reset() {
    currentLod = 2;  // Reset to base LOD
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
  /// LOD 0-4: Finer to coarser detail levels
  int get lod => _LodState.calculateLod(scale);

  /// Get the effective tile size at current LOD
  /// LOD 0: 256 (0.25x) - fine detail when zoomed in
  /// LOD 1: 512 (0.5x)
  /// LOD 2: 1024 (1x) - base
  /// LOD 3: 2048 (2x)
  /// LOD 4: 4096 (4x) - coarse for overview
  double get effectiveTileSize {
    return kTileSize * kLodTileMultipliers[lod.clamp(0, 4)];
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
  /// Uses kLodTileMultipliers for LOD 0-4
  Rect get bounds {
    final multiplier = kLodTileMultipliers[zoomLevel.clamp(0, 4)];
    final tileSize = kTileSize * multiplier;
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
