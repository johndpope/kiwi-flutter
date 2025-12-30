//! Tile-based rendering system
//!
//! Divides the canvas into fixed-size tiles for efficient rendering of large documents.
//! Each tile caches draw commands for nodes intersecting its bounds.

use crate::api::{DrawCommand, RectInfo};
use crate::spatial::{NodeBounds, SpatialIndex};
use crate::nodes::FigmaNode;
use std::collections::HashMap;

/// Fixed tile size in world coordinates (power of 2 for GPU efficiency)
pub const TILE_SIZE: f64 = 1024.0;

/// Maximum number of cached tiles (LRU eviction when exceeded)
pub const MAX_CACHED_TILES: usize = 256;

/// Tile coordinate in grid space
#[derive(Clone, Copy, Hash, Eq, PartialEq, Debug)]
pub struct TileCoord {
    pub x: i32,
    pub y: i32,
    /// Level of detail: 0=full, 1=half, 2=quarter, etc.
    pub zoom_level: u8,
}

impl TileCoord {
    pub fn new(x: i32, y: i32, zoom_level: u8) -> Self {
        Self { x, y, zoom_level }
    }

    /// Get the world-space bounds of this tile
    pub fn bounds(&self) -> RectInfo {
        let scale = 2.0_f64.powi(self.zoom_level as i32);
        let tile_size = TILE_SIZE * scale;

        RectInfo {
            x: self.x as f64 * tile_size,
            y: self.y as f64 * tile_size,
            width: tile_size,
            height: tile_size,
            corner_radii: [0.0; 4],
        }
    }
}

/// Single tile with cached draw commands
#[derive(Debug, Clone)]
pub struct Tile {
    pub coord: TileCoord,
    pub bounds: RectInfo,
    /// Cached draw commands for this tile
    pub commands: Vec<DrawCommand>,
    /// IDs of nodes intersecting this tile
    pub node_ids: Vec<String>,
    /// Whether this tile needs regeneration
    pub dirty: bool,
    /// Access counter for LRU eviction
    pub last_accessed: u64,
}

impl Tile {
    pub fn new(coord: TileCoord) -> Self {
        let bounds = coord.bounds();
        Self {
            coord,
            bounds,
            commands: Vec::new(),
            node_ids: Vec::new(),
            dirty: true,
            last_accessed: 0,
        }
    }
}

/// Tile grid manager with LRU cache
pub struct TileGrid {
    /// Cached tiles by coordinate
    tiles: HashMap<TileCoord, Tile>,
    /// Maximum number of tiles to cache
    max_cached_tiles: usize,
    /// Counter for LRU tracking
    access_counter: u64,
}

impl TileGrid {
    pub fn new() -> Self {
        Self::with_capacity(MAX_CACHED_TILES)
    }

    pub fn with_capacity(max_cached_tiles: usize) -> Self {
        Self {
            tiles: HashMap::new(),
            max_cached_tiles,
            access_counter: 0,
        }
    }

    /// Get visible tile coordinates for a viewport
    pub fn get_visible_tiles(&self, viewport: &Viewport) -> Vec<TileCoord> {
        let zoom_level = self.zoom_to_lod(viewport.scale);
        let scale = 2.0_f64.powi(zoom_level as i32);
        let tile_size = TILE_SIZE * scale;

        // Calculate tile range covering viewport
        let min_tx = (viewport.x / tile_size).floor() as i32;
        let min_ty = (viewport.y / tile_size).floor() as i32;
        let max_tx = ((viewport.x + viewport.width) / tile_size).ceil() as i32;
        let max_ty = ((viewport.y + viewport.height) / tile_size).ceil() as i32;

        let mut tiles = Vec::with_capacity(
            ((max_tx - min_tx + 1) * (max_ty - min_ty + 1)) as usize
        );

        for tx in min_tx..=max_tx {
            for ty in min_ty..=max_ty {
                tiles.push(TileCoord::new(tx, ty, zoom_level));
            }
        }

        tiles
    }

    /// Convert zoom scale to LOD level
    fn zoom_to_lod(&self, scale: f64) -> u8 {
        if scale >= 0.5 {
            0 // Full detail
        } else if scale >= 0.25 {
            1 // Half detail
        } else if scale >= 0.125 {
            2 // Quarter detail
        } else {
            3 // Minimum detail
        }
    }

    /// Get or create a tile, returning it with updated access time
    pub fn get_or_create_tile(
        &mut self,
        coord: TileCoord,
        nodes: &HashMap<String, FigmaNode>,
        spatial_index: &SpatialIndex,
    ) -> &Tile {
        self.access_counter += 1;

        // Check if tile exists and is valid
        if let Some(tile) = self.tiles.get_mut(&coord) {
            tile.last_accessed = self.access_counter;
            if !tile.dirty {
                return self.tiles.get(&coord).unwrap();
            }
        }

        // Evict LRU tile if at capacity
        if self.tiles.len() >= self.max_cached_tiles {
            self.evict_lru();
        }

        // Generate new tile
        let tile = self.generate_tile(coord, nodes, spatial_index);
        self.tiles.insert(coord, tile);
        self.tiles.get(&coord).unwrap()
    }

    /// Generate draw commands for a tile
    fn generate_tile(
        &self,
        coord: TileCoord,
        nodes: &HashMap<String, FigmaNode>,
        spatial_index: &SpatialIndex,
    ) -> Tile {
        let bounds = coord.bounds();
        let node_ids = spatial_index.query_rect(
            bounds.x,
            bounds.y,
            bounds.x + bounds.width,
            bounds.y + bounds.height,
        );

        let lod = coord.zoom_level;
        let simplification = match lod {
            0 => 1.0,   // Full detail
            1 => 0.5,   // Skip nodes < 2px
            2 => 0.25,  // Skip nodes < 4px
            _ => 0.125, // Aggressive simplification
        };

        let mut commands = Vec::new();

        for id in &node_ids {
            if let Some(node) = nodes.get(id) {
                // Skip if node too small at this LOD
                let min_visible_size = 1.0 / simplification;
                if node.width < min_visible_size && node.height < min_visible_size {
                    continue;
                }

                if let Some(cmd) = node.to_draw_command() {
                    commands.push(cmd);
                }
            }
        }

        Tile {
            coord,
            bounds,
            commands,
            node_ids,
            dirty: false,
            last_accessed: self.access_counter,
        }
    }

    /// Evict the least recently used tile
    fn evict_lru(&mut self) {
        if let Some((&oldest_coord, _)) = self
            .tiles
            .iter()
            .min_by_key(|(_, t)| t.last_accessed)
        {
            self.tiles.remove(&oldest_coord);
        }
    }

    /// Mark tiles dirty for changed nodes
    pub fn invalidate_for_nodes(
        &mut self,
        changed_ids: &[String],
        spatial_index: &SpatialIndex,
    ) -> Vec<TileCoord> {
        let mut dirty_tiles = Vec::new();

        for id in changed_ids {
            // Get bounds for this node from spatial index
            if let Some(bounds) = spatial_index.get_node_bounds(id) {
                // Find all tiles this node intersects
                let affected = self.tiles_for_bounds(&bounds);
                for coord in affected {
                    if let Some(tile) = self.tiles.get_mut(&coord) {
                        tile.dirty = true;
                        dirty_tiles.push(coord);
                    }
                }
            }
        }

        dirty_tiles
    }

    /// Get all tile coordinates that intersect with given bounds
    fn tiles_for_bounds(&self, bounds: &NodeBounds) -> Vec<TileCoord> {
        // For each LOD level, find tiles that intersect
        let mut coords = Vec::new();

        for zoom_level in 0..=3u8 {
            let scale = 2.0_f64.powi(zoom_level as i32);
            let tile_size = TILE_SIZE * scale;

            let min_tx = (bounds.min_x / tile_size).floor() as i32;
            let min_ty = (bounds.min_y / tile_size).floor() as i32;
            let max_tx = (bounds.max_x / tile_size).ceil() as i32;
            let max_ty = (bounds.max_y / tile_size).ceil() as i32;

            for tx in min_tx..=max_tx {
                for ty in min_ty..=max_ty {
                    coords.push(TileCoord::new(tx, ty, zoom_level));
                }
            }
        }

        coords
    }

    /// Clear all cached tiles
    pub fn clear(&mut self) {
        self.tiles.clear();
    }

    /// Get cache statistics
    pub fn stats(&self) -> TileCacheStats {
        TileCacheStats {
            cached_tiles: self.tiles.len(),
            max_tiles: self.max_cached_tiles,
            dirty_tiles: self.tiles.values().filter(|t| t.dirty).count(),
        }
    }
}

impl Default for TileGrid {
    fn default() -> Self {
        Self::new()
    }
}

/// Viewport definition for culling
#[derive(Debug, Clone, Copy)]
pub struct Viewport {
    /// World-space X coordinate of viewport top-left
    pub x: f64,
    /// World-space Y coordinate of viewport top-left
    pub y: f64,
    /// Viewport width in world coordinates
    pub width: f64,
    /// Viewport height in world coordinates
    pub height: f64,
    /// Zoom scale (1.0 = 100%, 0.5 = 50%, etc.)
    pub scale: f64,
}

impl Viewport {
    pub fn new(x: f64, y: f64, width: f64, height: f64, scale: f64) -> Self {
        Self { x, y, width, height, scale }
    }

    /// Create viewport from screen coordinates and transform
    pub fn from_screen(
        screen_width: f64,
        screen_height: f64,
        translate_x: f64,
        translate_y: f64,
        scale: f64,
    ) -> Self {
        Self {
            x: -translate_x / scale,
            y: -translate_y / scale,
            width: screen_width / scale,
            height: screen_height / scale,
            scale,
        }
    }

    /// Check if a rectangle intersects this viewport
    pub fn intersects(&self, rect: &RectInfo) -> bool {
        !(rect.x + rect.width < self.x
            || rect.x > self.x + self.width
            || rect.y + rect.height < self.y
            || rect.y > self.y + self.height)
    }
}

/// Tile cache statistics
#[derive(Debug, Clone)]
pub struct TileCacheStats {
    pub cached_tiles: usize,
    pub max_tiles: usize,
    pub dirty_tiles: usize,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_tile_coord_bounds() {
        let coord = TileCoord::new(0, 0, 0);
        let bounds = coord.bounds();
        assert_eq!(bounds.x, 0.0);
        assert_eq!(bounds.y, 0.0);
        assert_eq!(bounds.width, TILE_SIZE);
        assert_eq!(bounds.height, TILE_SIZE);

        let coord = TileCoord::new(1, 2, 0);
        let bounds = coord.bounds();
        assert_eq!(bounds.x, TILE_SIZE);
        assert_eq!(bounds.y, 2.0 * TILE_SIZE);
    }

    #[test]
    fn test_viewport_visible_tiles() {
        let grid = TileGrid::new();
        let viewport = Viewport::new(0.0, 0.0, 2048.0, 1536.0, 1.0);
        let tiles = grid.get_visible_tiles(&viewport);

        // Should cover 2x2 tiles at zoom level 0
        assert!(tiles.len() >= 4);
        assert!(tiles.contains(&TileCoord::new(0, 0, 0)));
        assert!(tiles.contains(&TileCoord::new(1, 0, 0)));
        assert!(tiles.contains(&TileCoord::new(0, 1, 0)));
        assert!(tiles.contains(&TileCoord::new(1, 1, 0)));
    }

    #[test]
    fn test_zoom_to_lod() {
        let grid = TileGrid::new();
        assert_eq!(grid.zoom_to_lod(1.0), 0);
        assert_eq!(grid.zoom_to_lod(0.5), 0);
        assert_eq!(grid.zoom_to_lod(0.4), 1);
        assert_eq!(grid.zoom_to_lod(0.25), 1);
        assert_eq!(grid.zoom_to_lod(0.2), 2);
        assert_eq!(grid.zoom_to_lod(0.1), 3);
    }
}
