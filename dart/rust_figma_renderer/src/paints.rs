//! Paint types (fills, strokes, gradients)

use crate::api::{ColorInfo, GradientStopInfo};

#[derive(Debug, Clone)]
pub enum Paint {
    Solid(SolidPaint),
    GradientLinear(GradientPaint),
    GradientRadial(GradientPaint),
    GradientAngular(GradientPaint),
    GradientDiamond(GradientPaint),
    Image(ImagePaint),
}

#[derive(Debug, Clone)]
pub struct SolidPaint {
    pub color: ColorInfo,
    pub opacity: f64,
    pub blend_mode: BlendMode,
}

#[derive(Debug, Clone)]
pub struct GradientPaint {
    pub stops: Vec<GradientStopInfo>,
    pub transform: [[f64; 3]; 2],
    pub opacity: f64,
    pub blend_mode: BlendMode,
}

#[derive(Debug, Clone)]
pub struct ImagePaint {
    pub image_ref: String,
    pub scale_mode: ScaleMode,
    pub opacity: f64,
    pub blend_mode: BlendMode,
}

#[derive(Debug, Clone, Copy, Default)]
pub enum BlendMode {
    #[default]
    Normal,
    Multiply,
    Screen,
    Overlay,
    Darken,
    Lighten,
    ColorDodge,
    ColorBurn,
    HardLight,
    SoftLight,
    Difference,
    Exclusion,
    Hue,
    Saturation,
    Color,
    Luminosity,
}

#[derive(Debug, Clone, Copy, Default)]
pub enum ScaleMode {
    #[default]
    Fill,
    Fit,
    Tile,
    Stretch,
}
