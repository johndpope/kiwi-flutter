# Figma Renderer - Rust + Flutter Architecture

## Overview

This Rust crate provides a high-performance Figma file parser and renderer that integrates with Flutter via:
- **Native FFI** for iOS/Android/Desktop
- **WASM** for Flutter Web

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Flutter App                             │
├─────────────────────────────────────────────────────────────┤
│                  flutter_rust_bridge                         │
│              (auto-generated Dart bindings)                  │
├──────────────────────┬──────────────────────────────────────┤
│    Native (FFI)      │           Web (WASM)                 │
│  iOS/Android/Desktop │      wasm-bindgen + JS interop       │
├──────────────────────┴──────────────────────────────────────┤
│                                                              │
│                    Rust Core Library                         │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  figma_renderer                                        │ │
│  │  ├── kiwi/        # Kiwi binary parser (brine-kiwi)    │ │
│  │  ├── schema/      # Figma schema definitions           │ │
│  │  ├── nodes/       # Node type implementations          │ │
│  │  ├── paints/      # Fill, stroke, gradient, image      │ │
│  │  ├── effects/     # Blur, shadow, noise                │ │
│  │  ├── layout/      # Auto-layout, constraints           │ │
│  │  ├── text/        # Text layout, font handling         │ │
│  │  ├── vector/      # Path operations, boolean ops       │ │
│  │  └── render/      # Render tree → draw commands        │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Key Components

### 1. Kiwi Parser (brine-kiwi based)
- Parse .fig file structure (header, chunks)
- Decompress schema (DEFLATE) and data (ZSTD)
- Decode binary Kiwi messages to structured data

### 2. Figma Schema
- Generated from extracted Figma schema
- Node types, paint types, effect types
- Property definitions matching Figma's internal model

### 3. Render Pipeline
- Build render tree from node hierarchy
- Calculate layout (auto-layout, constraints)
- Generate platform-agnostic draw commands
- Flutter receives commands and draws via Canvas/CustomPainter

## Build Commands

```bash
# Build native library
cargo build --release

# Build WASM
cargo build --target wasm32-unknown-unknown --release

# Generate Flutter bindings
flutter_rust_bridge_codegen generate --wasm

# Run tests
cargo test
```

## Integration with Flutter

```dart
// In your Flutter app
import 'package:figma_renderer/figma_renderer.dart';

// Load a .fig file
final figFile = await FigmaRenderer.loadFile('design.fig');

// Get render commands for a node
final commands = figFile.renderNode(nodeId);

// Draw in a CustomPainter
canvas.drawPath(commands.path, commands.paint);
```

## Why Rust?

1. **Performance**: Near-native speed for complex rendering
2. **Memory Safety**: No crashes from buffer overflows
3. **WASM**: Same code runs on web with near-native performance
4. **Existing Libraries**: brine-kiwi, zstd-rs, lyon (2D paths)
5. **flutter_rust_bridge**: Seamless Dart/Rust interop

## Documentation

| Document | Description |
|----------|-------------|
| [Architecture](./docs/ARCHITECTURE.md) | System design, data flow, module responsibilities |
| [API Reference](./docs/API_REFERENCE.md) | Complete Dart API documentation |
| [Integration Guide](./docs/INTEGRATION_GUIDE.md) | Flutter setup, platform config, examples |
| [Kiwi Format](./docs/KIWI_FORMAT.md) | Binary format specification |
| [Figma WASM Interface](./docs/FIGMA_WASM_INTERFACE.md) | Analysis of Figma's WASM module |

## Dependencies

- `brine-kiwi` - Kiwi binary format parser
- `zstd` - ZSTD decompression
- `flate2` - DEFLATE decompression
- `lyon` - 2D path tessellation
- `euclid` - Geometry primitives
- `flutter_rust_bridge` - Dart FFI/WASM bindings

## Project Structure

```
rust_figma_renderer/
├── Cargo.toml              # Rust dependencies
├── build.sh                # Build script
├── flutter_rust_bridge.yaml
├── src/
│   ├── lib.rs              # Library entry point
│   ├── api.rs              # Public API (Flutter bindings)
│   ├── kiwi.rs             # .fig file parser
│   ├── nodes.rs            # Node types & rendering
│   ├── paints.rs           # Fill/stroke/gradient
│   ├── effects.rs          # Shadows, blurs
│   ├── layout.rs           # Auto-layout algorithm
│   ├── vector.rs           # Path operations
│   ├── render.rs           # Render tree
│   └── schema.rs           # Figma schema definitions
└── docs/                   # Documentation
```

## License

MIT
