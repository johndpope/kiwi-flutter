//! Kiwi binary format parsing for Figma files
//!
//! Handles:
//! - .fig file structure (header, chunks)
//! - DEFLATE decompression (schema chunk)
//! - ZSTD decompression (data chunk)
//! - Kiwi message decoding

use crate::{FigmaError, Result};
use crate::api::{PaintInfo, EffectInfo, PathData, ColorInfo, GradientStopInfo};
use crate::nodes::FigmaNode;

use std::collections::HashMap;
use std::io::{Read, Cursor};

/// Parsed Figma file
pub struct FigFile {
    pub name: String,
    pub version: u32,
    pub nodes: HashMap<String, FigmaNode>,
    pub page_ids: Vec<String>,
    schema: Vec<u8>,
}

impl FigFile {
    /// Parse a .fig file from bytes
    pub fn parse(data: &[u8]) -> Result<Self> {
        // Check header
        let header = &data[0..8];
        let (header_len, _encrypted) = match header {
            b"fig-kiwi" => (8, false),
            _ if &data[0..9] == b"fig-kiwie" => (9, true),
            _ => return Err(FigmaError::InvalidHeader),
        };

        // Parse chunks
        let mut cursor = Cursor::new(&data[header_len..]);
        let chunks = parse_chunks(&mut cursor)?;

        // Decompress schema (chunk 0) - raw DEFLATE
        let schema = decompress_deflate(&chunks[0])?;

        // Decompress message data (chunk 1) - ZSTD
        let message_data = decompress_zstd(&chunks[1])?;

        // Parse the Kiwi message using the schema
        let (nodes, page_ids) = decode_figma_message(&schema, &message_data)?;

        Ok(FigFile {
            name: String::new(), // Extracted from message
            version: 1,
            nodes,
            page_ids,
            schema,
        })
    }

    /// Get a node by ID
    pub fn get_node(&self, id: &str) -> Option<&FigmaNode> {
        self.nodes.get(id)
    }

    /// Get all root nodes (pages)
    pub fn get_pages(&self) -> Vec<&FigmaNode> {
        self.page_ids.iter()
            .filter_map(|id| self.nodes.get(id))
            .collect()
    }
}

/// Parse chunks from fig file
fn parse_chunks(cursor: &mut Cursor<&[u8]>) -> Result<Vec<Vec<u8>>> {
    let mut chunks = Vec::new();

    loop {
        // Read chunk size (4 bytes, little-endian)
        let mut size_buf = [0u8; 4];
        if cursor.read_exact(&mut size_buf).is_err() {
            break;
        }
        let size = u32::from_le_bytes(size_buf) as usize;

        if size == 0 {
            break;
        }

        // Read chunk data
        let mut chunk_data = vec![0u8; size];
        cursor.read_exact(&mut chunk_data)?;
        chunks.push(chunk_data);
    }

    Ok(chunks)
}

/// Decompress DEFLATE data (for schema chunk)
fn decompress_deflate(data: &[u8]) -> Result<Vec<u8>> {
    use flate2::read::DeflateDecoder;

    let mut decoder = DeflateDecoder::new(data);
    let mut decompressed = Vec::new();
    decoder.read_to_end(&mut decompressed)
        .map_err(|e| FigmaError::DecompressionError(e.to_string()))?;

    Ok(decompressed)
}

/// Decompress ZSTD data (for message chunk)
#[cfg(not(target_arch = "wasm32"))]
fn decompress_zstd(data: &[u8]) -> Result<Vec<u8>> {
    zstd::decode_all(data)
        .map_err(|e| FigmaError::DecompressionError(e.to_string()))
}

/// Decompress ZSTD data (for message chunk) - WASM version using pure Rust ruzstd
#[cfg(target_arch = "wasm32")]
fn decompress_zstd(data: &[u8]) -> Result<Vec<u8>> {
    use ruzstd::decoding::StreamingDecoder;
    use ruzstd::io::Read;

    let mut cursor = std::io::Cursor::new(data);
    let mut decoder = StreamingDecoder::new(&mut cursor)
        .map_err(|e| FigmaError::DecompressionError(format!("Failed to create zstd decoder: {:?}", e)))?;
    let mut decompressed = Vec::new();
    Read::read_to_end(&mut decoder, &mut decompressed)
        .map_err(|e| FigmaError::DecompressionError(format!("{:?}", e)))?;
    Ok(decompressed)
}

/// Decode Figma message from Kiwi binary
fn decode_figma_message(
    schema: &[u8],
    data: &[u8],
) -> Result<(HashMap<String, FigmaNode>, Vec<String>)> {
    let mut nodes = HashMap::new();
    let mut page_ids = Vec::new();

    // Parse using Kiwi decoder
    let mut decoder = KiwiDecoder::new(schema, data)?;

    // The root message contains nodeChanges array
    while let Some(field) = decoder.next_field()? {
        match field.name.as_str() {
            "nodeChanges" => {
                // Array of node change messages
                for _ in 0..field.array_length {
                    if let Some(node) = decode_node_change(&mut decoder)? {
                        if node.node_type == "CANVAS" {
                            page_ids.push(node.id.clone());
                        }
                        nodes.insert(node.id.clone(), node);
                    }
                }
            }
            _ => decoder.skip_field(&field)?,
        }
    }

    Ok((nodes, page_ids))
}

/// Decode a single node change message
fn decode_node_change(decoder: &mut KiwiDecoder) -> Result<Option<FigmaNode>> {
    let mut node = FigmaNode::default();

    while let Some(field) = decoder.next_field()? {
        match field.name.as_str() {
            "guid" => node.id = decoder.read_guid()?,
            "parentIndex" => {
                let parent = decoder.read_parent_index()?;
                node.parent_id = parent.0;
            }
            "type" => node.node_type = decoder.read_node_type()?,
            "name" => node.name = decoder.read_string()?,
            "visible" => node.visible = decoder.read_bool()?,
            "opacity" => node.opacity = decoder.read_float()? as f64,
            "transform" => {
                let t = decoder.read_transform()?;
                node.x = t.tx;
                node.y = t.ty;
                node.rotation = t.rotation();
            }
            "size" => {
                let (w, h) = decoder.read_size()?;
                node.width = w;
                node.height = h;
            }
            "fillPaints" => node.fill_paints_data = decoder.read_bytes()?,
            "strokePaints" => node.stroke_paints_data = decoder.read_bytes()?,
            "effects" => node.effects_data = decoder.read_bytes()?,
            "vectorData" => node.vector_data = decoder.read_bytes()?,
            "strokeWeight" => node.stroke_weight = decoder.read_float()? as f64,
            "cornerRadius" => node.corner_radius = decoder.read_float()? as f64,
            "rectangleCornerRadii" => {
                node.corner_radii = [
                    decoder.read_float()? as f64,
                    decoder.read_float()? as f64,
                    decoder.read_float()? as f64,
                    decoder.read_float()? as f64,
                ];
            }
            "children" => {
                for _ in 0..field.array_length {
                    node.children.push(decoder.read_guid()?);
                }
            }
            // Text properties
            "textData" => node.text_data = decoder.read_bytes()?,
            "fontName" => node.font_name = decoder.read_string()?,
            "fontSize" => node.font_size = decoder.read_float()? as f64,
            // Layout properties
            "layoutMode" => node.layout_mode = decoder.read_enum()?,
            "primaryAxisSizingMode" => node.primary_axis_sizing = decoder.read_enum()?,
            "counterAxisSizingMode" => node.counter_axis_sizing = decoder.read_enum()?,
            "itemSpacing" => node.item_spacing = decoder.read_float()? as f64,
            "paddingLeft" => node.padding[0] = decoder.read_float()? as f64,
            "paddingTop" => node.padding[1] = decoder.read_float()? as f64,
            "paddingRight" => node.padding[2] = decoder.read_float()? as f64,
            "paddingBottom" => node.padding[3] = decoder.read_float()? as f64,
            _ => decoder.skip_field(&field)?,
        }
    }

    Ok(Some(node))
}

// =============================================================================
// Kiwi Decoder
// =============================================================================

/// Low-level Kiwi binary decoder
pub struct KiwiDecoder<'a> {
    schema: &'a [u8],
    data: &'a [u8],
    pos: usize,
    field_defs: Vec<FieldDef>,
}

struct FieldDef {
    name: String,
    field_type: u8,
    is_array: bool,
}

pub struct Field {
    pub name: String,
    pub field_type: u8,
    pub array_length: usize,
}

impl<'a> KiwiDecoder<'a> {
    pub fn new(schema: &'a [u8], data: &'a [u8]) -> Result<Self> {
        // Parse schema to get field definitions
        let field_defs = parse_schema(schema)?;

        Ok(KiwiDecoder {
            schema,
            data,
            pos: 0,
            field_defs,
        })
    }

    pub fn next_field(&mut self) -> Result<Option<Field>> {
        if self.pos >= self.data.len() {
            return Ok(None);
        }

        let field_index = self.read_varint()? as usize;
        if field_index == 0 {
            return Ok(None);
        }

        // Clone the field definition data to avoid borrow conflict
        let (name, field_type, is_array) = {
            let def = self.field_defs.get(field_index - 1)
                .ok_or_else(|| FigmaError::DecodeError(format!("Unknown field index: {}", field_index)))?;
            (def.name.clone(), def.field_type, def.is_array)
        };

        let array_length = if is_array {
            self.read_varint()? as usize
        } else {
            1
        };

        Ok(Some(Field {
            name,
            field_type,
            array_length,
        }))
    }

    pub fn skip_field(&mut self, field: &Field) -> Result<()> {
        for _ in 0..field.array_length {
            match field.field_type {
                0 => { self.read_bool()?; }
                1 => { self.read_varint()?; } // byte
                2 | 3 => { self.read_varint()?; } // int/uint
                4 => { self.read_float()?; }
                5 => { self.read_string()?; }
                6 | 7 => { self.read_varint()?; self.read_varint()?; } // int64/uint64
                _ => { self.skip_message()?; }
            }
        }
        Ok(())
    }

    fn skip_message(&mut self) -> Result<()> {
        loop {
            let field_index = self.read_varint()?;
            if field_index == 0 {
                break;
            }
            // Would need schema info to properly skip - for now just skip varint
            self.read_varint()?;
        }
        Ok(())
    }

    // Primitive readers

    pub fn read_bool(&mut self) -> Result<bool> {
        let b = self.data.get(self.pos)
            .ok_or_else(|| FigmaError::DecodeError("Unexpected end of data".into()))?;
        self.pos += 1;
        Ok(*b != 0)
    }

    pub fn read_varint(&mut self) -> Result<u64> {
        let mut result: u64 = 0;
        let mut shift = 0;

        loop {
            let byte = *self.data.get(self.pos)
                .ok_or_else(|| FigmaError::DecodeError("Unexpected end of data".into()))?;
            self.pos += 1;

            result |= ((byte & 0x7F) as u64) << shift;
            if byte & 0x80 == 0 {
                break;
            }
            shift += 7;
        }

        Ok(result)
    }

    pub fn read_signed_varint(&mut self) -> Result<i64> {
        let unsigned = self.read_varint()?;
        // Zigzag decoding
        Ok(((unsigned >> 1) as i64) ^ (-((unsigned & 1) as i64)))
    }

    pub fn read_float(&mut self) -> Result<f32> {
        // Kiwi float encoding: first byte indicates encoding type
        let first = *self.data.get(self.pos)
            .ok_or_else(|| FigmaError::DecodeError("Unexpected end of data".into()))?;
        self.pos += 1;

        if first == 0 {
            // Zero value
            return Ok(0.0);
        }

        // Read remaining 3 bytes
        if self.pos + 3 > self.data.len() {
            return Err(FigmaError::DecodeError("Unexpected end of data".into()));
        }

        let mut bits = (first as u32) << 24
            | (self.data[self.pos] as u32) << 16
            | (self.data[self.pos + 1] as u32) << 8
            | (self.data[self.pos + 2] as u32);
        self.pos += 3;

        // Kiwi float bit rotation
        bits = (bits << 23) | (bits >> 9);

        Ok(f32::from_bits(bits))
    }

    pub fn read_string(&mut self) -> Result<String> {
        let mut end = self.pos;
        while end < self.data.len() && self.data[end] != 0 {
            end += 1;
        }

        let s = String::from_utf8_lossy(&self.data[self.pos..end]).to_string();
        self.pos = end + 1; // Skip null terminator

        Ok(s)
    }

    pub fn read_bytes(&mut self) -> Result<Vec<u8>> {
        let len = self.read_varint()? as usize;
        if self.pos + len > self.data.len() {
            return Err(FigmaError::DecodeError("Unexpected end of data".into()));
        }
        let bytes = self.data[self.pos..self.pos + len].to_vec();
        self.pos += len;
        Ok(bytes)
    }

    pub fn read_guid(&mut self) -> Result<String> {
        // GUID is two uint32 values
        let session = self.read_varint()? as u32;
        let local = self.read_varint()? as u32;
        Ok(format!("{}:{}", session, local))
    }

    pub fn read_parent_index(&mut self) -> Result<(Option<String>, String)> {
        let guid = self.read_guid()?;
        let position = self.read_string()?;
        Ok((Some(guid), position))
    }

    pub fn read_node_type(&mut self) -> Result<String> {
        let type_id = self.read_varint()? as u32;
        Ok(node_type_name(type_id))
    }

    pub fn read_enum(&mut self) -> Result<String> {
        let val = self.read_varint()? as u32;
        Ok(format!("{}", val))
    }

    pub fn read_transform(&mut self) -> Result<Transform> {
        Ok(Transform {
            m00: self.read_float()? as f64,
            m01: self.read_float()? as f64,
            m10: self.read_float()? as f64,
            m11: self.read_float()? as f64,
            tx: self.read_float()? as f64,
            ty: self.read_float()? as f64,
        })
    }

    pub fn read_size(&mut self) -> Result<(f64, f64)> {
        Ok((
            self.read_float()? as f64,
            self.read_float()? as f64,
        ))
    }
}

pub struct Transform {
    pub m00: f64,
    pub m01: f64,
    pub m10: f64,
    pub m11: f64,
    pub tx: f64,
    pub ty: f64,
}

impl Transform {
    pub fn rotation(&self) -> f64 {
        self.m01.atan2(self.m00).to_degrees()
    }
}

/// Parse Kiwi schema binary
fn parse_schema(data: &[u8]) -> Result<Vec<FieldDef>> {
    // Schema format: definitions of enums, structs, messages
    // For now, return empty - real impl would parse schema binary
    Ok(vec![])
}

/// Convert node type ID to name
fn node_type_name(id: u32) -> String {
    match id {
        0 => "DOCUMENT",
        1 => "CANVAS",
        2 => "FRAME",
        3 => "GROUP",
        4 => "VECTOR",
        5 => "BOOLEAN_OPERATION",
        6 => "STAR",
        7 => "LINE",
        8 => "ELLIPSE",
        9 => "REGULAR_POLYGON",
        10 => "RECTANGLE",
        11 => "TEXT",
        12 => "SLICE",
        13 => "COMPONENT",
        14 => "COMPONENT_SET",
        15 => "INSTANCE",
        16 => "STICKY",
        17 => "SHAPE_WITH_TEXT",
        18 => "CONNECTOR",
        19 => "SECTION",
        _ => "UNKNOWN",
    }.to_string()
}

// =============================================================================
// Paint/Effect/Vector decoders (match Figma's JsKiwiSerialization_*)
// =============================================================================

/// Decode fill paint data (matches JsKiwiSerialization_decodeFillPaintData)
pub fn decode_fill_paint_data(data: &[u8]) -> Result<Vec<PaintInfo>> {
    let mut paints = Vec::new();

    if data.is_empty() {
        return Ok(paints);
    }

    let mut pos = 0;

    // Read paint count
    let count = read_varint_at(data, &mut pos)? as usize;

    for _ in 0..count {
        let paint_type = read_varint_at(data, &mut pos)? as u8;

        let mut paint = PaintInfo {
            paint_type: paint_type_name(paint_type),
            color: None,
            gradient_stops: vec![],
            opacity: 1.0,
            blend_mode: "NORMAL".to_string(),
        };

        // Read based on paint type
        match paint_type {
            0 => {
                // Solid color
                let r = data.get(pos).copied().unwrap_or(0);
                let g = data.get(pos + 1).copied().unwrap_or(0);
                let b = data.get(pos + 2).copied().unwrap_or(0);
                let a = data.get(pos + 3).copied().unwrap_or(255);
                pos += 4;

                paint.color = Some(ColorInfo { r, g, b, a });
            }
            1..=4 => {
                // Gradient (linear, radial, angular, diamond)
                let stop_count = read_varint_at(data, &mut pos)? as usize;
                for _ in 0..stop_count {
                    let position = read_float_at(data, &mut pos)?;
                    let r = data.get(pos).copied().unwrap_or(0);
                    let g = data.get(pos + 1).copied().unwrap_or(0);
                    let b = data.get(pos + 2).copied().unwrap_or(0);
                    let a = data.get(pos + 3).copied().unwrap_or(255);
                    pos += 4;

                    paint.gradient_stops.push(GradientStopInfo {
                        position: position as f64,
                        color: ColorInfo { r, g, b, a },
                    });
                }
            }
            5 => {
                // Image paint - read image ref
                let _image_ref = read_string_at(data, &mut pos)?;
            }
            _ => {}
        }

        // Read opacity
        paint.opacity = read_float_at(data, &mut pos)? as f64;

        // Read blend mode
        let blend = read_varint_at(data, &mut pos)? as u8;
        paint.blend_mode = blend_mode_name(blend);

        paints.push(paint);
    }

    Ok(paints)
}

/// Decode effect data (matches JsKiwiSerialization_decodeEffectData)
pub fn decode_effect_data(data: &[u8]) -> Result<Vec<EffectInfo>> {
    let mut effects = Vec::new();

    if data.is_empty() {
        return Ok(effects);
    }

    let mut pos = 0;
    let count = read_varint_at(data, &mut pos)? as usize;

    for _ in 0..count {
        let effect_type = read_varint_at(data, &mut pos)? as u8;
        let visible = data.get(pos).copied().unwrap_or(1) != 0;
        pos += 1;

        let radius = read_float_at(data, &mut pos)? as f64;

        let mut effect = EffectInfo {
            effect_type: effect_type_name(effect_type),
            visible,
            radius,
            color: None,
            offset_x: 0.0,
            offset_y: 0.0,
            spread: 0.0,
        };

        // Shadow-specific fields
        if effect_type == 0 || effect_type == 1 {
            let r = data.get(pos).copied().unwrap_or(0);
            let g = data.get(pos + 1).copied().unwrap_or(0);
            let b = data.get(pos + 2).copied().unwrap_or(0);
            let a = data.get(pos + 3).copied().unwrap_or(255);
            pos += 4;

            effect.color = Some(ColorInfo { r, g, b, a });
            effect.offset_x = read_float_at(data, &mut pos)? as f64;
            effect.offset_y = read_float_at(data, &mut pos)? as f64;
            effect.spread = read_float_at(data, &mut pos)? as f64;
        }

        effects.push(effect);
    }

    Ok(effects)
}

/// Decode vector data (matches JsKiwiSerialization_decodeVectorData)
pub fn decode_vector_data(data: &[u8]) -> Result<PathData> {
    if data.is_empty() {
        return Ok(PathData {
            commands: String::new(),
            fill_rule: "nonzero".to_string(),
        });
    }

    let mut commands = String::new();
    let mut pos = 0;

    // Read fill rule
    let fill_rule_byte = data.get(pos).copied().unwrap_or(0);
    pos += 1;
    let fill_rule = if fill_rule_byte == 1 { "evenodd" } else { "nonzero" };

    // Read path commands
    while pos < data.len() {
        let cmd = data.get(pos).copied().unwrap_or(0);
        pos += 1;

        match cmd {
            0 => break, // End
            1 => {
                // MoveTo
                let x = read_float_at(data, &mut pos)?;
                let y = read_float_at(data, &mut pos)?;
                commands.push_str(&format!("M {} {} ", x, y));
            }
            2 => {
                // LineTo
                let x = read_float_at(data, &mut pos)?;
                let y = read_float_at(data, &mut pos)?;
                commands.push_str(&format!("L {} {} ", x, y));
            }
            3 => {
                // CubicTo
                let x1 = read_float_at(data, &mut pos)?;
                let y1 = read_float_at(data, &mut pos)?;
                let x2 = read_float_at(data, &mut pos)?;
                let y2 = read_float_at(data, &mut pos)?;
                let x = read_float_at(data, &mut pos)?;
                let y = read_float_at(data, &mut pos)?;
                commands.push_str(&format!("C {} {} {} {} {} {} ", x1, y1, x2, y2, x, y));
            }
            4 => {
                // QuadTo
                let x1 = read_float_at(data, &mut pos)?;
                let y1 = read_float_at(data, &mut pos)?;
                let x = read_float_at(data, &mut pos)?;
                let y = read_float_at(data, &mut pos)?;
                commands.push_str(&format!("Q {} {} {} {} ", x1, y1, x, y));
            }
            5 => {
                // Close
                commands.push_str("Z ");
            }
            _ => break,
        }
    }

    Ok(PathData {
        commands: commands.trim().to_string(),
        fill_rule: fill_rule.to_string(),
    })
}

// Helper functions

fn read_varint_at(data: &[u8], pos: &mut usize) -> Result<u64> {
    let mut result: u64 = 0;
    let mut shift = 0;

    loop {
        let byte = *data.get(*pos)
            .ok_or_else(|| FigmaError::DecodeError("Unexpected end of data".into()))?;
        *pos += 1;

        result |= ((byte & 0x7F) as u64) << shift;
        if byte & 0x80 == 0 {
            break;
        }
        shift += 7;
    }

    Ok(result)
}

fn read_float_at(data: &[u8], pos: &mut usize) -> Result<f32> {
    let first = *data.get(*pos)
        .ok_or_else(|| FigmaError::DecodeError("Unexpected end of data".into()))?;
    *pos += 1;

    if first == 0 {
        return Ok(0.0);
    }

    if *pos + 3 > data.len() {
        return Err(FigmaError::DecodeError("Unexpected end of data".into()));
    }

    let mut bits = (first as u32) << 24
        | (data[*pos] as u32) << 16
        | (data[*pos + 1] as u32) << 8
        | (data[*pos + 2] as u32);
    *pos += 3;

    bits = (bits << 23) | (bits >> 9);

    Ok(f32::from_bits(bits))
}

fn read_string_at(data: &[u8], pos: &mut usize) -> Result<String> {
    let mut end = *pos;
    while end < data.len() && data[end] != 0 {
        end += 1;
    }
    let s = String::from_utf8_lossy(&data[*pos..end]).to_string();
    *pos = end + 1;
    Ok(s)
}

fn paint_type_name(id: u8) -> String {
    match id {
        0 => "solid",
        1 => "gradient_linear",
        2 => "gradient_radial",
        3 => "gradient_angular",
        4 => "gradient_diamond",
        5 => "image",
        _ => "unknown",
    }.to_string()
}

fn effect_type_name(id: u8) -> String {
    match id {
        0 => "drop_shadow",
        1 => "inner_shadow",
        2 => "layer_blur",
        3 => "background_blur",
        _ => "unknown",
    }.to_string()
}

fn blend_mode_name(id: u8) -> String {
    match id {
        0 => "PASS_THROUGH",
        1 => "NORMAL",
        2 => "DARKEN",
        3 => "MULTIPLY",
        4 => "LINEAR_BURN",
        5 => "COLOR_BURN",
        6 => "LIGHTEN",
        7 => "SCREEN",
        8 => "LINEAR_DODGE",
        9 => "COLOR_DODGE",
        10 => "OVERLAY",
        11 => "SOFT_LIGHT",
        12 => "HARD_LIGHT",
        13 => "DIFFERENCE",
        14 => "EXCLUSION",
        15 => "HUE",
        16 => "SATURATION",
        17 => "COLOR",
        18 => "LUMINOSITY",
        _ => "NORMAL",
    }.to_string()
}
