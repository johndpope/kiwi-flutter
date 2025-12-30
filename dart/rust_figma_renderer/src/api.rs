//! Public API for Flutter integration via flutter_rust_bridge
//!
//! These functions are exposed to Dart and can be called from Flutter.

use crate::{FigmaError, Result};
use crate::kiwi::FigFile;
use crate::nodes::FigmaNode;
use crate::render::RenderTree;
use crate::spatial::SpatialIndex;
use crate::tiles::{TileGrid, TileCoord, Viewport, TILE_SIZE};

use flutter_rust_bridge::frb;
use serde::Serialize;
use std::sync::RwLock;

/// Opaque handle to a loaded Figma document
#[frb(opaque)]
pub struct FigmaDocument {
    file: FigFile,
    render_tree: RwLock<Option<RenderTree>>,
    spatial_index: RwLock<Option<SpatialIndex>>,
    tile_grid: RwLock<TileGrid>,
}

/// Node information returned to Flutter
#[frb]
#[derive(Debug, Clone, Serialize)]
pub struct NodeInfo {
    pub id: String,
    pub name: String,
    pub node_type: String,
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
    pub rotation: f64,
    pub opacity: f64,
    pub visible: bool,
    pub children: Vec<String>,
}

/// Paint information for fills/strokes
#[frb]
#[derive(Debug, Clone, Serialize)]
pub struct PaintInfo {
    pub paint_type: String, // "solid", "gradient_linear", "gradient_radial", "image"
    pub color: Option<ColorInfo>,
    pub gradient_stops: Vec<GradientStopInfo>,
    pub opacity: f64,
    pub blend_mode: String,
}

/// Color represented as RGBA (0-255)
#[frb]
#[derive(Debug, Clone, Serialize)]
pub struct ColorInfo {
    pub r: u8,
    pub g: u8,
    pub b: u8,
    pub a: u8,
}

/// Gradient stop
#[frb]
#[derive(Debug, Clone, Serialize)]
pub struct GradientStopInfo {
    pub position: f64,
    pub color: ColorInfo,
}

/// Effect information (shadows, blurs)
#[frb]
#[derive(Debug, Clone, Serialize)]
pub struct EffectInfo {
    pub effect_type: String, // "drop_shadow", "inner_shadow", "layer_blur", "background_blur"
    pub visible: bool,
    pub radius: f64,
    pub color: Option<ColorInfo>,
    pub offset_x: f64,
    pub offset_y: f64,
    pub spread: f64,
}

/// Path data for vector rendering
#[frb]
#[derive(Debug, Clone, Serialize)]
pub struct PathData {
    /// SVG-like path commands: M, L, C, Q, Z
    pub commands: String,
    pub fill_rule: String, // "nonzero" or "evenodd"
}

/// Render command sent to Flutter for drawing
#[frb]
#[derive(Debug, Clone, Serialize)]
pub struct DrawCommand {
    pub command_type: String, // "path", "rect", "ellipse", "text", "image"
    pub path: Option<PathData>,
    pub rect: Option<RectInfo>,
    pub fills: Vec<PaintInfo>,
    pub strokes: Vec<PaintInfo>,
    pub stroke_weight: f64,
    pub effects: Vec<EffectInfo>,
    pub transform: TransformInfo,
    pub clip_path: Option<PathData>,
}

/// Rectangle info
#[frb]
#[derive(Debug, Clone, Serialize)]
pub struct RectInfo {
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
    pub corner_radii: [f64; 4], // top-left, top-right, bottom-right, bottom-left
}

/// 2D affine transform matrix [a, b, c, d, tx, ty]
#[frb]
#[derive(Debug, Clone, Serialize)]
pub struct TransformInfo {
    pub m00: f64, // scale x
    pub m01: f64, // skew y
    pub m02: f64, // translate x
    pub m10: f64, // skew x
    pub m11: f64, // scale y
    pub m12: f64, // translate y
}

impl Default for TransformInfo {
    fn default() -> Self {
        Self {
            m00: 1.0, m01: 0.0, m02: 0.0,
            m10: 0.0, m11: 1.0, m12: 0.0,
        }
    }
}

// =============================================================================
// Public API Functions (exposed to Flutter)
// =============================================================================

/// Load a Figma file from bytes
#[frb]
pub fn load_figma_file(data: Vec<u8>) -> Result<FigmaDocument> {
    let file = FigFile::parse(&data)?;
    Ok(FigmaDocument {
        file,
        render_tree: RwLock::new(None),
        spatial_index: RwLock::new(None),
        tile_grid: RwLock::new(TileGrid::new()),
    })
}

/// Get document metadata
#[frb]
pub fn get_document_info(doc: &FigmaDocument) -> DocumentInfo {
    DocumentInfo {
        name: doc.file.name.clone(),
        version: doc.file.version,
        node_count: doc.file.nodes.len(),
        page_ids: doc.file.page_ids.clone(),
    }
}

#[frb]
#[derive(Debug, Clone)]
pub struct DocumentInfo {
    pub name: String,
    pub version: u32,
    pub node_count: usize,
    pub page_ids: Vec<String>,
}

/// Get information about a specific node
#[frb]
pub fn get_node_info(doc: &FigmaDocument, node_id: String) -> Result<NodeInfo> {
    doc.file.get_node(&node_id)
        .map(|node| node.to_node_info())
        .ok_or_else(|| FigmaError::NodeNotFound(node_id))
}

/// Get all children of a node
#[frb]
pub fn get_children(doc: &FigmaDocument, node_id: String) -> Result<Vec<NodeInfo>> {
    let node = doc.file.get_node(&node_id)
        .ok_or_else(|| FigmaError::NodeNotFound(node_id))?;

    Ok(node.children.iter()
        .filter_map(|id| doc.file.get_node(id))
        .map(|n| n.to_node_info())
        .collect())
}

/// Get render commands for a node (and optionally its children)
#[frb]
pub fn render_node(
    doc: &FigmaDocument,
    node_id: String,
    include_children: bool,
) -> Result<Vec<DrawCommand>> {
    let node = doc.file.get_node(&node_id)
        .ok_or_else(|| FigmaError::NodeNotFound(node_id))?;

    let mut commands = Vec::new();
    render_node_recursive(doc, node, include_children, &mut commands)?;
    Ok(commands)
}

fn render_node_recursive(
    doc: &FigmaDocument,
    node: &FigmaNode,
    include_children: bool,
    commands: &mut Vec<DrawCommand>,
) -> Result<()> {
    // Generate draw command for this node
    if let Some(cmd) = node.to_draw_command() {
        commands.push(cmd);
    }

    // Recursively render children
    if include_children {
        for child_id in &node.children {
            if let Some(child) = doc.file.get_node(child_id) {
                render_node_recursive(doc, child, true, commands)?;
            }
        }
    }

    Ok(())
}

/// Calculate layout for auto-layout frames
#[frb]
pub fn calculate_layout(doc: &FigmaDocument, root_id: String) -> Result<Vec<LayoutResult>> {
    // TODO: Implement auto-layout algorithm
    Ok(vec![])
}

#[frb]
#[derive(Debug, Clone)]
pub struct LayoutResult {
    pub node_id: String,
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
}

/// Export a node as SVG path data
#[frb]
pub fn export_svg_path(doc: &FigmaDocument, node_id: String) -> Result<String> {
    let node = doc.file.get_node(&node_id)
        .ok_or_else(|| FigmaError::NodeNotFound(node_id))?;

    Ok(node.to_svg_path())
}

/// Decode Kiwi-encoded fill paint data (matches Figma's JsKiwiSerialization_decodeFillPaintData)
#[frb]
pub fn decode_fill_paint(data: Vec<u8>) -> Result<Vec<PaintInfo>> {
    crate::kiwi::decode_fill_paint_data(&data)
}

/// Decode Kiwi-encoded effect data
#[frb]
pub fn decode_effects(data: Vec<u8>) -> Result<Vec<EffectInfo>> {
    crate::kiwi::decode_effect_data(&data)
}

/// Decode Kiwi-encoded vector data
#[frb]
pub fn decode_vector(data: Vec<u8>) -> Result<PathData> {
    crate::kiwi::decode_vector_data(&data)
}

// =============================================================================
// Tile-based Rendering API
// =============================================================================

/// Viewport information for tile culling (exposed to Flutter)
#[frb]
#[derive(Debug, Clone, Copy)]
pub struct ViewportInfo {
    /// World-space X coordinate of viewport top-left
    pub x: f64,
    /// World-space Y coordinate of viewport top-left
    pub y: f64,
    /// Viewport width in world coordinates
    pub width: f64,
    /// Viewport height in world coordinates
    pub height: f64,
    /// Zoom scale (1.0 = 100%, 0.5 = 50%)
    pub scale: f64,
}

impl ViewportInfo {
    /// Convert to internal Viewport
    fn to_viewport(&self) -> Viewport {
        Viewport::new(self.x, self.y, self.width, self.height, self.scale)
    }
}

/// Tile coordinate for Flutter (exposed to Flutter)
#[frb]
#[derive(Debug, Clone, Copy)]
pub struct TileCoordInfo {
    pub x: i32,
    pub y: i32,
    pub zoom_level: u8,
}

impl From<TileCoord> for TileCoordInfo {
    fn from(c: TileCoord) -> Self {
        Self { x: c.x, y: c.y, zoom_level: c.zoom_level }
    }
}

impl From<TileCoordInfo> for TileCoord {
    fn from(c: TileCoordInfo) -> Self {
        TileCoord::new(c.x, c.y, c.zoom_level)
    }
}

/// Result of rendering a single tile
#[frb]
#[derive(Debug, Clone)]
pub struct TileRenderResult {
    pub coord: TileCoordInfo,
    pub bounds: RectInfo,
    pub commands: Vec<DrawCommand>,
    pub node_count: usize,
    pub from_cache: bool,
}

/// Cache statistics
#[frb]
#[derive(Debug, Clone)]
pub struct TileCacheStatsInfo {
    pub cached_tiles: usize,
    pub max_tiles: usize,
    pub dirty_tiles: usize,
}

/// Initialize spatial index for a document (call once after loading)
#[frb]
pub fn init_spatial_index(doc: &FigmaDocument, root_id: String) -> Result<usize> {
    let index = SpatialIndex::build_with_absolute_coords(&doc.file.nodes, &root_id);
    let count = index.len();

    let mut spatial_lock = doc.spatial_index.write()
        .map_err(|_| FigmaError::DecodeError("Lock poisoned".into()))?;
    *spatial_lock = Some(index);

    Ok(count)
}

/// Get visible tile coordinates for a viewport
#[frb]
pub fn get_visible_tiles(doc: &FigmaDocument, viewport: ViewportInfo) -> Vec<TileCoordInfo> {
    let grid = doc.tile_grid.read().unwrap();
    let vp = viewport.to_viewport();

    grid.get_visible_tiles(&vp)
        .into_iter()
        .map(|c| c.into())
        .collect()
}

/// Render tiles visible in viewport
#[frb]
pub fn render_tiles(
    doc: &FigmaDocument,
    root_id: String,
    viewport: ViewportInfo,
) -> Result<Vec<TileRenderResult>> {
    // Ensure spatial index is built
    {
        let spatial_lock = doc.spatial_index.read()
            .map_err(|_| FigmaError::DecodeError("Lock poisoned".into()))?;

        if spatial_lock.is_none() {
            drop(spatial_lock);
            init_spatial_index(doc, root_id.clone())?;
        }
    }

    let spatial_lock = doc.spatial_index.read()
        .map_err(|_| FigmaError::DecodeError("Lock poisoned".into()))?;
    let spatial_index = spatial_lock.as_ref()
        .ok_or_else(|| FigmaError::DecodeError("Spatial index not initialized".into()))?;

    let mut grid = doc.tile_grid.write()
        .map_err(|_| FigmaError::DecodeError("Lock poisoned".into()))?;

    let vp = viewport.to_viewport();
    let visible_coords = grid.get_visible_tiles(&vp);

    let mut results = Vec::with_capacity(visible_coords.len());

    for coord in visible_coords {
        let tile = grid.get_or_create_tile(coord, &doc.file.nodes, spatial_index);

        results.push(TileRenderResult {
            coord: tile.coord.into(),
            bounds: tile.bounds.clone(),
            commands: tile.commands.clone(),
            node_count: tile.node_ids.len(),
            from_cache: !tile.dirty,
        });
    }

    Ok(results)
}

/// Render a single tile by coordinates
#[frb]
pub fn render_single_tile(
    doc: &FigmaDocument,
    root_id: String,
    coord: TileCoordInfo,
) -> Result<TileRenderResult> {
    // Ensure spatial index is built
    {
        let spatial_lock = doc.spatial_index.read()
            .map_err(|_| FigmaError::DecodeError("Lock poisoned".into()))?;

        if spatial_lock.is_none() {
            drop(spatial_lock);
            init_spatial_index(doc, root_id.clone())?;
        }
    }

    let spatial_lock = doc.spatial_index.read()
        .map_err(|_| FigmaError::DecodeError("Lock poisoned".into()))?;
    let spatial_index = spatial_lock.as_ref()
        .ok_or_else(|| FigmaError::DecodeError("Spatial index not initialized".into()))?;

    let mut grid = doc.tile_grid.write()
        .map_err(|_| FigmaError::DecodeError("Lock poisoned".into()))?;

    let tile_coord: TileCoord = coord.into();
    let tile = grid.get_or_create_tile(tile_coord, &doc.file.nodes, spatial_index);

    Ok(TileRenderResult {
        coord: tile.coord.into(),
        bounds: tile.bounds.clone(),
        commands: tile.commands.clone(),
        node_count: tile.node_ids.len(),
        from_cache: !tile.dirty,
    })
}

/// Invalidate tiles for changed nodes
#[frb]
pub fn invalidate_tiles(
    doc: &FigmaDocument,
    changed_node_ids: Vec<String>,
) -> Result<Vec<TileCoordInfo>> {
    let spatial_lock = doc.spatial_index.read()
        .map_err(|_| FigmaError::DecodeError("Lock poisoned".into()))?;

    let spatial_index = match spatial_lock.as_ref() {
        Some(idx) => idx,
        None => return Ok(vec![]), // No index means nothing to invalidate
    };

    let mut grid = doc.tile_grid.write()
        .map_err(|_| FigmaError::DecodeError("Lock poisoned".into()))?;

    let dirty = grid.invalidate_for_nodes(&changed_node_ids, spatial_index);

    Ok(dirty.into_iter().map(|c| c.into()).collect())
}

/// Clear all cached tiles
#[frb]
pub fn clear_tile_cache(doc: &FigmaDocument) -> Result<()> {
    let mut grid = doc.tile_grid.write()
        .map_err(|_| FigmaError::DecodeError("Lock poisoned".into()))?;
    grid.clear();
    Ok(())
}

/// Get tile cache statistics
#[frb]
pub fn get_tile_cache_stats(doc: &FigmaDocument) -> Result<TileCacheStatsInfo> {
    let grid = doc.tile_grid.read()
        .map_err(|_| FigmaError::DecodeError("Lock poisoned".into()))?;

    let stats = grid.stats();
    Ok(TileCacheStatsInfo {
        cached_tiles: stats.cached_tiles,
        max_tiles: stats.max_tiles,
        dirty_tiles: stats.dirty_tiles,
    })
}

/// Get the fixed tile size constant
#[frb]
pub fn get_tile_size() -> f64 {
    TILE_SIZE
}

/// Query nodes at a point (for hit testing)
#[frb]
pub fn query_nodes_at_point(
    doc: &FigmaDocument,
    x: f64,
    y: f64,
) -> Result<Vec<String>> {
    let spatial_lock = doc.spatial_index.read()
        .map_err(|_| FigmaError::DecodeError("Lock poisoned".into()))?;

    match spatial_lock.as_ref() {
        Some(index) => Ok(index.query_point(x, y)),
        None => Ok(vec![]),
    }
}

/// Query nodes in a rectangular region
#[frb]
pub fn query_nodes_in_rect(
    doc: &FigmaDocument,
    min_x: f64,
    min_y: f64,
    max_x: f64,
    max_y: f64,
) -> Result<Vec<String>> {
    let spatial_lock = doc.spatial_index.read()
        .map_err(|_| FigmaError::DecodeError("Lock poisoned".into()))?;

    match spatial_lock.as_ref() {
        Some(index) => Ok(index.query_rect(min_x, min_y, max_x, max_y)),
        None => Ok(vec![]),
    }
}

/// Get overall document bounds from spatial index
#[frb]
pub fn get_document_bounds(doc: &FigmaDocument) -> Result<Option<RectInfo>> {
    let spatial_lock = doc.spatial_index.read()
        .map_err(|_| FigmaError::DecodeError("Lock poisoned".into()))?;

    match spatial_lock.as_ref() {
        Some(index) => {
            match index.overall_bounds() {
                Some(bounds) => Ok(Some(RectInfo {
                    x: bounds.min_x,
                    y: bounds.min_y,
                    width: bounds.width(),
                    height: bounds.height(),
                    corner_radii: [0.0; 4],
                })),
                None => Ok(None),
            }
        },
        None => Ok(None),
    }
}

// =============================================================================
// WASM-specific exports
// =============================================================================

#[cfg(target_arch = "wasm32")]
mod wasm {
    use super::*;
    use wasm_bindgen::prelude::*;

    #[wasm_bindgen]
    pub fn wasm_load_figma_file(data: &[u8]) -> std::result::Result<JsValue, JsValue> {
        let doc = load_figma_file(data.to_vec())
            .map_err(|e| JsValue::from_str(&e.to_string()))?;

        // Return handle as opaque pointer
        Ok(JsValue::from(Box::into_raw(Box::new(doc)) as u32))
    }

    #[wasm_bindgen]
    pub fn wasm_render_node(doc_ptr: u32, node_id: &str) -> std::result::Result<JsValue, JsValue> {
        let doc = unsafe { &*(doc_ptr as *const FigmaDocument) };
        let commands = render_node(doc, node_id.to_string(), true)
            .map_err(|e| JsValue::from_str(&e.to_string()))?;

        serde_wasm_bindgen::to_value(&commands)
            .map_err(|e| JsValue::from_str(&e.to_string()))
    }
}
