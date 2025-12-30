# Figma Renderer Architecture

## Overview

This project provides a high-performance Figma file renderer for Flutter, implemented in Rust with bindings for both native platforms (FFI) and web (WASM).

## Why Rust + WASM?

Figma itself uses this exact architecture:
- **C++ core** compiled to **WebAssembly** for the browser
- Native builds for desktop apps
- Same codebase, multiple targets

Our implementation mirrors this:

```
┌─────────────────────────────────────────────────────────────────┐
│                         FIGMA                                    │
│  C++ → WASM (browser) / Native (desktop)                        │
├─────────────────────────────────────────────────────────────────┤
│                      OUR RENDERER                                │
│  Rust → WASM (Flutter web) / FFI (iOS/Android/Desktop)          │
└─────────────────────────────────────────────────────────────────┘
```

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Flutter Application                       │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    UI Layer (Dart)                        │   │
│  │  • FigmaCanvasView - Pan/zoom canvas widget               │   │
│  │  • FigmaNodeWidget - Renders individual nodes             │   │
│  │  • FigmaNodePainter - CustomPainter for draw commands     │   │
│  └──────────────────────────────────────────────────────────┘   │
│                              │                                   │
│                              ▼                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              flutter_rust_bridge (Generated)              │   │
│  │  • Dart API classes (FigmaDocument, DrawCommand, etc.)    │   │
│  │  • FFI bindings for native platforms                      │   │
│  │  • WASM bindings for web platform                         │   │
│  └──────────────────────────────────────────────────────────┘   │
│                              │                                   │
├──────────────────────────────┼───────────────────────────────────┤
│          Native (FFI)        │           Web (WASM)              │
│  ┌────────────────────┐      │      ┌────────────────────┐       │
│  │ libfigma_renderer  │      │      │ figma_renderer.wasm│       │
│  │     .dylib/.so/.a  │      │      │                    │       │
│  └────────────────────┘      │      └────────────────────┘       │
├──────────────────────────────┴───────────────────────────────────┤
│                                                                  │
│                      Rust Core Library                           │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                        api.rs                               │ │
│  │  Public API exposed to Flutter via flutter_rust_bridge      │ │
│  │  • load_figma_file()    • render_node()                     │ │
│  │  • get_node_info()      • decode_fill_paint()               │ │
│  └────────────────────────────────────────────────────────────┘ │
│                              │                                   │
│         ┌────────────────────┼────────────────────┐              │
│         ▼                    ▼                    ▼              │
│  ┌─────────────┐     ┌─────────────┐      ┌─────────────┐       │
│  │   kiwi.rs   │     │  nodes.rs   │      │  render.rs  │       │
│  │  .fig file  │     │ Node types  │      │ Render tree │       │
│  │   parsing   │     │ & rendering │      │ generation  │       │
│  └─────────────┘     └─────────────┘      └─────────────┘       │
│         │                    │                    │              │
│         ▼                    ▼                    ▼              │
│  ┌─────────────┐     ┌─────────────┐      ┌─────────────┐       │
│  │  schema.rs  │     │  paints.rs  │      │  layout.rs  │       │
│  │   Figma     │     │   Fills,    │      │ Auto-layout │       │
│  │   schema    │     │  gradients  │      │ constraints │       │
│  └─────────────┘     └─────────────┘      └─────────────┘       │
│                              │                                   │
│                      ┌───────┴───────┐                          │
│                      ▼               ▼                          │
│               ┌─────────────┐ ┌─────────────┐                   │
│               │ effects.rs  │ │  vector.rs  │                   │
│               │  Shadows,   │ │    Path     │                   │
│               │   blurs     │ │ operations  │                   │
│               └─────────────┘ └─────────────┘                   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow

### 1. File Loading

```
.fig file (binary)
       │
       ▼
┌─────────────────────┐
│   Parse Header      │  "fig-kiwi" or "fig-kiwie"
│   (8-9 bytes)       │
└─────────────────────┘
       │
       ▼
┌─────────────────────┐
│   Parse Chunks      │  Length-prefixed binary chunks
└─────────────────────┘
       │
       ├─── Chunk 0: Schema (DEFLATE compressed)
       │         │
       │         ▼
       │    ┌─────────────────────┐
       │    │  Decompress Schema  │  flate2 crate
       │    └─────────────────────┘
       │
       ├─── Chunk 1: Data (ZSTD compressed)
       │         │
       │         ▼
       │    ┌─────────────────────┐
       │    │   Decompress Data   │  zstd crate
       │    └─────────────────────┘
       │
       └─── Chunk 2: Preview (optional PNG)
                     │
                     ▼
              ┌─────────────────────┐
              │   Decode Kiwi Msg   │  brine-kiwi
              └─────────────────────┘
                     │
                     ▼
              ┌─────────────────────┐
              │   Build Node Tree   │  HashMap<GUID, Node>
              └─────────────────────┘
```

### 2. Rendering Pipeline

```
FigmaDocument
       │
       ▼
┌─────────────────────┐
│  render_node(id)    │  API call from Flutter
└─────────────────────┘
       │
       ▼
┌─────────────────────┐
│  Build Render Tree  │  Compute absolute positions
└─────────────────────┘
       │
       ▼
┌─────────────────────┐
│ Generate Commands   │  Convert nodes to DrawCommands
└─────────────────────┘
       │
       ├─── Decode fill paints (Kiwi binary → PaintInfo)
       ├─── Decode stroke paints
       ├─── Decode effects (shadows, blurs)
       └─── Decode vector paths (SVG-like commands)
                     │
                     ▼
              Vec<DrawCommand>
                     │
                     ▼
              ┌─────────────────────┐
              │  Flutter Canvas     │  CustomPainter.paint()
              └─────────────────────┘
```

## Module Responsibilities

### `api.rs` - Public Interface

Exposes all functionality to Flutter via flutter_rust_bridge:

| Function | Purpose |
|----------|---------|
| `load_figma_file()` | Parse .fig bytes into FigmaDocument |
| `get_document_info()` | Get metadata (name, version, node count) |
| `get_node_info()` | Get properties of a specific node |
| `get_children()` | Get child nodes |
| `render_node()` | Generate DrawCommands for rendering |
| `calculate_layout()` | Compute auto-layout positions |
| `export_svg_path()` | Export node as SVG path string |
| `decode_fill_paint()` | Decode Kiwi paint data |
| `decode_effects()` | Decode Kiwi effect data |
| `decode_vector()` | Decode Kiwi vector path data |

### `kiwi.rs` - Binary Parsing

Handles Figma's Kiwi binary format:

- **File structure**: Header, chunk parsing
- **Decompression**: DEFLATE (schema), ZSTD (data)
- **Kiwi decoding**: Variable-length integers, floats, strings
- **Message parsing**: nodeChanges array → node properties

Key insight: Figma's float encoding uses bit rotation:
```rust
// Kiwi float: bits = (bits << 23) | (bits >> 9)
```

### `nodes.rs` - Node Types

Implements all Figma node types:

| Type | Renders As |
|------|------------|
| RECTANGLE, FRAME | Rounded rect |
| ELLIPSE | Oval path |
| VECTOR, STAR, POLYGON | SVG path |
| TEXT | Text spans |
| GROUP | Transform container |
| COMPONENT, INSTANCE | Frame + overrides |

### `paints.rs` - Fill/Stroke

Paint types matching Figma:

- **Solid**: RGBA color
- **Gradient Linear/Radial/Angular/Diamond**: Color stops + transform
- **Image**: Reference + scale mode

### `effects.rs` - Visual Effects

- **Drop Shadow**: Color, offset, radius, spread
- **Inner Shadow**: Same, rendered inside
- **Layer Blur**: Gaussian blur on layer
- **Background Blur**: Blur content behind

### `layout.rs` - Auto-Layout

Implements Figma's auto-layout algorithm:

- **Direction**: Horizontal / Vertical
- **Sizing**: Fixed / Hug / Fill
- **Alignment**: Min / Center / Max / Stretch
- **Spacing**: Gap between children
- **Padding**: Frame insets

### `vector.rs` - Path Operations

Uses `lyon` crate for 2D path operations:

- SVG path command parsing
- Path tessellation
- Boolean operations (future)

### `render.rs` - Render Tree

Builds optimized render tree from node hierarchy:

- Absolute position calculation
- Opacity inheritance
- Clip region handling
- Draw order (back to front)

## Platform-Specific Details

### Native (FFI)

```
Rust Library
     │
     ▼
┌─────────────┐
│  cdylib     │  Dynamic library
│  staticlib  │  Static library
└─────────────┘
     │
     ▼
┌─────────────┐
│  Dart FFI   │  dart:ffi
└─────────────┘
```

Platforms:
- **iOS**: `libfigma_renderer.a` (static)
- **Android**: `libfigma_renderer.so` (dynamic)
- **macOS**: `libfigma_renderer.dylib`
- **Linux**: `libfigma_renderer.so`
- **Windows**: `figma_renderer.dll`

### Web (WASM)

```
Rust Library
     │
     ▼
┌─────────────────────┐
│  wasm32-unknown-    │  WASM target
│  unknown            │
└─────────────────────┘
     │
     ▼
┌─────────────────────┐
│  wasm-bindgen       │  JS interop
└─────────────────────┘
     │
     ▼
┌─────────────────────┐
│  Dart JS interop    │  package:js
└─────────────────────┘
```

## Memory Management

### Rust Side

- **FigmaDocument**: Owned by Rust, exposed as opaque handle
- **Node data**: Stored in HashMap, accessed by reference
- **DrawCommands**: Allocated per render, passed to Dart

### Dart Side

- **Opaque handles**: Reference counted via Arc
- **DrawCommands**: Copied to Dart heap
- **Automatic cleanup**: Drop when Dart object collected

## Performance Considerations

1. **Lazy decoding**: Paint/effect data decoded on demand
2. **Render caching**: Cache DrawCommands for unchanged nodes
3. **Incremental updates**: Only re-render changed subtrees
4. **Memory mapping**: Large files can be memory-mapped
5. **SIMD**: lyon uses SIMD for path operations

## Comparison with Figma's WASM

| Aspect | Figma | Our Renderer |
|--------|-------|--------------|
| Language | C++ | Rust |
| WASM | Emscripten | wasm-bindgen |
| Size | ~42MB | ~2-5MB (est.) |
| Functions | 39,305 | ~100 |
| Imports | 1,606 | ~20 |
| Exports | 3,920 | ~50 |

We implement a focused subset for rendering, not the full editor.

## Future Enhancements

1. **Prototype playback**: Interaction animations
2. **Code generation**: Export to Flutter widgets
3. **Real-time sync**: Connect to Figma API for live updates
4. **Plugin system**: Extend with custom renderers
5. **GPU rendering**: Direct WebGL/Metal/Vulkan path
