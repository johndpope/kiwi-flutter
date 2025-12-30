//! Figma node type definitions and rendering

use crate::api::{NodeInfo, DrawCommand, PathData, RectInfo, TransformInfo};
use crate::kiwi::{decode_fill_paint_data, decode_effect_data, decode_vector_data};

/// Node type enumeration matching Figma's types
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum NodeType {
    Document,
    Canvas,
    Frame,
    Group,
    Vector,
    BooleanOperation,
    Star,
    Line,
    Ellipse,
    RegularPolygon,
    Rectangle,
    Text,
    Slice,
    Component,
    ComponentSet,
    Instance,
    Sticky,
    ShapeWithText,
    Connector,
    Section,
    Unknown(String),
}

impl From<&str> for NodeType {
    fn from(s: &str) -> Self {
        match s {
            "DOCUMENT" => NodeType::Document,
            "CANVAS" => NodeType::Canvas,
            "FRAME" => NodeType::Frame,
            "GROUP" => NodeType::Group,
            "VECTOR" => NodeType::Vector,
            "BOOLEAN_OPERATION" => NodeType::BooleanOperation,
            "STAR" => NodeType::Star,
            "LINE" => NodeType::Line,
            "ELLIPSE" => NodeType::Ellipse,
            "REGULAR_POLYGON" => NodeType::RegularPolygon,
            "RECTANGLE" => NodeType::Rectangle,
            "TEXT" => NodeType::Text,
            "SLICE" => NodeType::Slice,
            "COMPONENT" => NodeType::Component,
            "COMPONENT_SET" => NodeType::ComponentSet,
            "INSTANCE" => NodeType::Instance,
            "STICKY" => NodeType::Sticky,
            "SHAPE_WITH_TEXT" => NodeType::ShapeWithText,
            "CONNECTOR" => NodeType::Connector,
            "SECTION" => NodeType::Section,
            other => NodeType::Unknown(other.to_string()),
        }
    }
}

/// Figma node with all properties
#[derive(Debug, Clone, Default)]
pub struct FigmaNode {
    pub id: String,
    pub parent_id: Option<String>,
    pub name: String,
    pub node_type: String,
    pub visible: bool,
    pub opacity: f64,

    // Transform
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
    pub rotation: f64,

    // Children
    pub children: Vec<String>,

    // Paint data (Kiwi-encoded)
    pub fill_paints_data: Vec<u8>,
    pub stroke_paints_data: Vec<u8>,
    pub effects_data: Vec<u8>,

    // Stroke
    pub stroke_weight: f64,

    // Corner radius
    pub corner_radius: f64,
    pub corner_radii: [f64; 4],

    // Vector data
    pub vector_data: Vec<u8>,

    // Text properties
    pub text_data: Vec<u8>,
    pub font_name: String,
    pub font_size: f64,

    // Layout properties
    pub layout_mode: String,
    pub primary_axis_sizing: String,
    pub counter_axis_sizing: String,
    pub item_spacing: f64,
    pub padding: [f64; 4],
}

impl FigmaNode {
    /// Convert to NodeInfo for Flutter
    pub fn to_node_info(&self) -> NodeInfo {
        NodeInfo {
            id: self.id.clone(),
            name: self.name.clone(),
            node_type: self.node_type.clone(),
            x: self.x,
            y: self.y,
            width: self.width,
            height: self.height,
            rotation: self.rotation,
            opacity: self.opacity,
            visible: self.visible,
            children: self.children.clone(),
        }
    }

    /// Generate draw command for this node
    pub fn to_draw_command(&self) -> Option<DrawCommand> {
        if !self.visible {
            return None;
        }

        let node_type = NodeType::from(self.node_type.as_str());

        // Decode paints and effects
        let fills = decode_fill_paint_data(&self.fill_paints_data).unwrap_or_default();
        let strokes = decode_fill_paint_data(&self.stroke_paints_data).unwrap_or_default();
        let effects = decode_effect_data(&self.effects_data).unwrap_or_default();

        match node_type {
            NodeType::Rectangle | NodeType::Frame | NodeType::Component | NodeType::Instance => {
                Some(DrawCommand {
                    command_type: "rect".to_string(),
                    path: None,
                    rect: Some(RectInfo {
                        x: self.x,
                        y: self.y,
                        width: self.width,
                        height: self.height,
                        corner_radii: if self.corner_radii.iter().any(|&r| r != 0.0) {
                            self.corner_radii
                        } else {
                            [self.corner_radius; 4]
                        },
                    }),
                    fills,
                    strokes,
                    stroke_weight: self.stroke_weight,
                    effects,
                    transform: TransformInfo {
                        m00: 1.0,
                        m01: 0.0,
                        m02: self.x,
                        m10: 0.0,
                        m11: 1.0,
                        m12: self.y,
                    },
                    clip_path: None,
                })
            }

            NodeType::Ellipse => {
                // Generate ellipse path
                let path = generate_ellipse_path(self.x, self.y, self.width, self.height);
                Some(DrawCommand {
                    command_type: "ellipse".to_string(),
                    path: Some(path),
                    rect: Some(RectInfo {
                        x: self.x,
                        y: self.y,
                        width: self.width,
                        height: self.height,
                        corner_radii: [0.0; 4],
                    }),
                    fills,
                    strokes,
                    stroke_weight: self.stroke_weight,
                    effects,
                    transform: TransformInfo::default(),
                    clip_path: None,
                })
            }

            NodeType::Vector | NodeType::Star | NodeType::RegularPolygon | NodeType::Line => {
                let path = decode_vector_data(&self.vector_data).unwrap_or(PathData {
                    commands: String::new(),
                    fill_rule: "nonzero".to_string(),
                });

                Some(DrawCommand {
                    command_type: "path".to_string(),
                    path: Some(path),
                    rect: None,
                    fills,
                    strokes,
                    stroke_weight: self.stroke_weight,
                    effects,
                    transform: TransformInfo {
                        m00: 1.0,
                        m01: 0.0,
                        m02: self.x,
                        m10: 0.0,
                        m11: 1.0,
                        m12: self.y,
                    },
                    clip_path: None,
                })
            }

            NodeType::Text => {
                // Text rendering handled separately
                Some(DrawCommand {
                    command_type: "text".to_string(),
                    path: None,
                    rect: Some(RectInfo {
                        x: self.x,
                        y: self.y,
                        width: self.width,
                        height: self.height,
                        corner_radii: [0.0; 4],
                    }),
                    fills,
                    strokes,
                    stroke_weight: self.stroke_weight,
                    effects,
                    transform: TransformInfo::default(),
                    clip_path: None,
                })
            }

            NodeType::Group | NodeType::BooleanOperation => {
                // Groups don't draw themselves, just transform children
                None
            }

            NodeType::Document | NodeType::Canvas | NodeType::Section | NodeType::Slice => {
                // Container nodes don't render
                None
            }

            _ => None,
        }
    }

    /// Export as SVG path
    pub fn to_svg_path(&self) -> String {
        let node_type = NodeType::from(self.node_type.as_str());

        match node_type {
            NodeType::Rectangle | NodeType::Frame => {
                let r = if self.corner_radii.iter().any(|&r| r != 0.0) {
                    self.corner_radii
                } else {
                    [self.corner_radius; 4]
                };
                generate_rounded_rect_svg(0.0, 0.0, self.width, self.height, r)
            }

            NodeType::Ellipse => {
                let cx = self.width / 2.0;
                let cy = self.height / 2.0;
                let rx = self.width / 2.0;
                let ry = self.height / 2.0;
                format!(
                    "M {} {} A {} {} 0 1 1 {} {} A {} {} 0 1 1 {} {} Z",
                    cx + rx, cy,
                    rx, ry, cx - rx, cy,
                    rx, ry, cx + rx, cy
                )
            }

            NodeType::Vector | NodeType::Star | NodeType::RegularPolygon | NodeType::Line => {
                decode_vector_data(&self.vector_data)
                    .map(|p| p.commands)
                    .unwrap_or_default()
            }

            _ => String::new(),
        }
    }
}

/// Generate ellipse as SVG path
fn generate_ellipse_path(x: f64, y: f64, width: f64, height: f64) -> PathData {
    let cx = x + width / 2.0;
    let cy = y + height / 2.0;
    let rx = width / 2.0;
    let ry = height / 2.0;

    // Ellipse as two arcs
    let commands = format!(
        "M {} {} A {} {} 0 1 1 {} {} A {} {} 0 1 1 {} {} Z",
        cx + rx, cy,
        rx, ry, cx - rx, cy,
        rx, ry, cx + rx, cy
    );

    PathData {
        commands,
        fill_rule: "nonzero".to_string(),
    }
}

/// Generate rounded rectangle as SVG path
fn generate_rounded_rect_svg(x: f64, y: f64, w: f64, h: f64, r: [f64; 4]) -> String {
    let [tl, tr, br, bl] = r;

    if tl == 0.0 && tr == 0.0 && br == 0.0 && bl == 0.0 {
        // Simple rectangle
        return format!("M {} {} H {} V {} H {} Z", x, y, x + w, y + h, x);
    }

    // Rounded rectangle with potentially different corner radii
    format!(
        "M {} {} \
         L {} {} \
         Q {} {} {} {} \
         L {} {} \
         Q {} {} {} {} \
         L {} {} \
         Q {} {} {} {} \
         L {} {} \
         Q {} {} {} {} \
         Z",
        x + tl, y,
        x + w - tr, y,
        x + w, y, x + w, y + tr,
        x + w, y + h - br,
        x + w, y + h, x + w - br, y + h,
        x + bl, y + h,
        x, y + h, x, y + h - bl,
        x, y + tl,
        x, y, x + tl, y
    )
}
