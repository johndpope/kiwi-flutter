//! Figma Renderer - High-performance Figma file parser and renderer
//!
//! This crate provides:
//! - .fig file parsing (Kiwi binary format)
//! - Node tree construction
//! - Layout calculations (auto-layout, constraints)
//! - Render command generation for Flutter

mod frb_generated; // AUTO INJECTED BY flutter_rust_bridge

pub mod kiwi;
pub mod schema;
pub mod nodes;
pub mod paints;
pub mod effects;
pub mod layout;
pub mod vector;
pub mod render;
pub mod api;

// Re-export main API for flutter_rust_bridge
pub use api::*;

use thiserror::Error;

#[derive(Error, Debug)]
pub enum FigmaError {
    #[error("Invalid file header: expected 'fig-kiwi' or 'fig-kiwie'")]
    InvalidHeader,

    #[error("Decompression failed: {0}")]
    DecompressionError(String),

    #[error("Schema parsing failed: {0}")]
    SchemaError(String),

    #[error("Message decoding failed: {0}")]
    DecodeError(String),

    #[error("Node not found: {0}")]
    NodeNotFound(String),

    #[error("Unsupported node type: {0}")]
    UnsupportedNodeType(String),

    #[error("IO error: {0}")]
    IoError(#[from] std::io::Error),
}

pub type Result<T> = std::result::Result<T, FigmaError>;
