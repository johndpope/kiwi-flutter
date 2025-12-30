//! Effect types (shadows, blurs)

use crate::api::ColorInfo;

#[derive(Debug, Clone)]
pub enum Effect {
    DropShadow(ShadowEffect),
    InnerShadow(ShadowEffect),
    LayerBlur(BlurEffect),
    BackgroundBlur(BlurEffect),
}

#[derive(Debug, Clone)]
pub struct ShadowEffect {
    pub color: ColorInfo,
    pub offset: (f64, f64),
    pub radius: f64,
    pub spread: f64,
    pub visible: bool,
}

#[derive(Debug, Clone)]
pub struct BlurEffect {
    pub radius: f64,
    pub visible: bool,
}
