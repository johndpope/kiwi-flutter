# CLAUDE.md - Development Context

This file provides context for Claude Code sessions working on this project.

## Project Overview

This is a Dart/Flutter port of the [Kiwi](https://github.com/evanw/kiwi) binary schema format, extended with full support for Figma's `.fig` file format and a Flutter renderer for visualizing Figma designs.

## Directory Structure

```
dart/
├── lib/
│   ├── kiwi.dart                    # Main library export
│   ├── flutter_renderer.dart        # Flutter widgets export
│   └── src/
│       ├── byte_buffer.dart         # Binary encoding/decoding
│       ├── schema.dart              # Schema data structures
│       ├── parser.dart              # Schema text parser
│       ├── compiler.dart            # Schema compiler (encode/decode)
│       ├── binary.dart              # Binary schema encoding
│       ├── printer.dart             # Schema pretty printer
│       ├── figma.dart               # Figma schema definitions
│       ├── fig_file.dart            # .fig file parser
│       ├── rust_figma_loader.dart   # Rust/WASM bridge wrapper
│       ├── rust/                    # Generated flutter_rust_bridge code
│       │   └── api.dart             # Rust API bindings
│       └── flutter/
│           ├── node_renderer.dart   # Node rendering widgets
│           ├── figma_canvas.dart    # Canvas view with pan/zoom
│           ├── variables/           # Variables panel UI
│           └── assets/variables.dart # Variable types & resolver
├── rust_figma_renderer/             # Rust crate for .fig parsing
│   ├── src/
│   │   ├── lib.rs                   # Crate root
│   │   ├── api.rs                   # flutter_rust_bridge API
│   │   ├── kiwi.rs                  # Kiwi binary decoder
│   │   ├── schema.rs                # Figma schema types
│   │   └── ...                      # Other modules
│   ├── tools/                       # WASM interception tools
│   │   ├── figma_wasm_interceptor.js
│   │   ├── capture_node_data.js
│   │   └── analyze_capture.py
│   └── docs/                        # Architecture docs
├── test/
│   └── fixtures/
│       ├── figma_schema.bin         # Extracted Figma binary schema
│       └── figma_message.bin        # Decompressed message data
├── build.sh                         # Build script for Rust + Flutter
└── example/
```

## Quick Start

### Build & Run
```bash
./build.sh --all                    # Full build (Rust + bindings + run)
./build.sh --native --bindings      # Just Rust + bindings
./build.sh --run --platform macos   # Run on macOS
./build.sh --run --platform ios     # Run on iOS simulator
./build.sh --clean --all --release  # Clean rebuild in release mode
```

### Build Script Options
- `--native` - Build native Rust library
- `--wasm` - Build WASM module
- `--bindings` - Generate Flutter bindings via flutter_rust_bridge
- `--run` - Run the Flutter app
- `--all` - Build everything and run
- `--clean` - Clean build artifacts
- `--release` - Build in release mode
- `--platform <p>` - Target platform (macos, ios, chrome)

## Key Concepts

### Kiwi Encoding
- Variable-length integers (varint) for compact encoding
- Zigzag encoding for signed integers
- Special float encoding (0 = 1 byte, non-zero = 4 bytes with reordered exponent)
- Null-terminated UTF-8 strings

### Figma File Format
- Header: `fig-kiwi` (8 bytes) or `fig-kiwie` (9 bytes)
- Chunk 0: Binary schema (raw DEFLATE compressed)
- Chunk 1: Message data (ZSTD compressed)
- Chunk 2: Preview image (optional)

### Variables System
- `VARIABLE_SET` nodes = Collections with modes (Light/Dark)
- `VARIABLE` nodes = Individual variables with values per mode
- `colorVar` on fills = Reference to a variable via guid
- Resolution: `colorVar.value.alias.guid` → VARIABLE node → `variableDataValues.entries[mode].variableData.value.colorValue`

## WASM Interception Tools

### Capture Figma's WASM Traffic
See `rust_figma_renderer/tools/README.md` for full guide.

**Quick Start:**
1. Open Figma in Chrome
2. DevTools → Sources → Snippets → New snippet
3. Paste `rust_figma_renderer/tools/figma_wasm_interceptor.js`
4. Run snippet, then **refresh page** (interceptor must load before WASM)
5. Navigate to nodes, interact with Figma
6. Console: `FigmaInterceptor.export()` to download capture

**Commands:**
```js
FigmaInterceptor.getStats()        // View call counts
FigmaInterceptor.getTimeline()     // View recent calls
FigmaInterceptor.export()          // Download all data
FigmaInterceptor.exportKiwiCalls() // Download Kiwi decode data
FigmaInterceptor.clear()           // Clear captured data
```

**High-Value Prefixes:**
- `JsKiwiSerialization_` - Kiwi decode calls
- `CanvasContext_Internal_` - Drawing operations
- `NodeTsApi_` - Node property access
- `FillBindings_`, `BlendBindings_` - Paint/effect data

### Analyze Captures
```bash
cd rust_figma_renderer/tools
python analyze_capture.py figma_wasm_capture.json
python analyze_capture.py capture.json --extract-kiwi  # Extract samples
```

## Running Tests

```bash
flutter test                           # All tests
flutter test test/kiwi_test.dart       # Core tests only
flutter test test/fig_file_test.dart   # Figma file tests
```

## Common Tasks

### Adding a New Node Type Renderer

1. Add case in `FigmaNodeWidget.build()` in `node_renderer.dart`
2. Create new widget class following the pattern of existing widgets
3. Extract properties from `FigmaNodeProperties`

### Debugging Figma File Parsing

```dart
// Parse structure only (no decompression needed)
final figFile = parseFigFileStructure(data);
print('Header: ${figFile.header}');
print('Schema: ${figFile.schemaChunk.compression}');
print('Data: ${figFile.dataChunk.compression}');
```

### Debugging Variable Resolution

```dart
// In node_renderer.dart, FigmaNodeProperties.fromMap resolves colorVar
// Check if fill has colorVar and no static color
if (fillMap['colorVar'] != null && fillMap['color'] == null) {
  final resolved = _resolveColorVar(fillMap['colorVar'], nodeMap);
  // resolved is {r: 0-1, g: 0-1, b: 0-1, a: 0-1} or null
}
```

### Working with Rust/WASM Bridge

```dart
// Initialize Rust library
final loader = RustFigmaLoader();
await loader.initialize();

// Load .fig file
final doc = await loader.loadFile(fileBytes);
final info = await loader.getDocumentInfo(doc);
print('${info.pageCount} pages, ${info.nodeCount} nodes');

// Get node info
final nodeInfo = await loader.getNodeInfo(doc, nodeId);
```

## Architecture Notes

### Node Rendering Flow

```
FigmaDocument.fromMessage(message)
    ↓
nodeMap: Map<guid, node>  (built from nodeChanges)
    ↓
FigmaCanvasView
    ↓
FigmaNodeWidget (routes by node.type)
    ↓
Specific widgets: Frame, Rectangle, Text, etc.
```

### Property Extraction

`FigmaNodeProperties.fromMap()` extracts common properties:
- Position from `transform.m02/m12` or `boundingBox`
- Size from `size.x/y` or `boundingBox`
- Fills from `fillPaints` (with colorVar resolution if nodeMap provided)
- Strokes from `strokePaints`
- Effects from `effects`
- Corner radii from `rectangleCornerRadii` or `cornerRadius`

### Variable Resolution Flow

```
Node.fillPaints[].colorVar
    ↓
colorVar.value.alias.guid → "sessionID:localID"
    ↓
nodeMap["sessionID:localID"] → VARIABLE node
    ↓
VARIABLE.variableDataValues.entries[mode].variableData.value.colorValue
    ↓
{r: 0-1, g: 0-1, b: 0-1, a: 0-1}
```

## Known Limitations

1. Vector paths use simplified SVG path parsing (M, L, C, Q, Z commands)
2. Gradients support LINEAR and RADIAL only
3. Text rendering uses basic font properties (no OpenType features)
4. Images require external blob handling (not rendered inline)
5. Prototype interactions are parsed but not executable
6. Variable aliases to external libraries (assetRef) cannot be resolved

## References

- [Kiwi original repo](https://github.com/evanw/kiwi)
- [grida renderer reference](https://github.com/gridaco/grida/tree/main/editor/grida-canvas-react-renderer-dom/nodes)
- [Figma Plugin API](https://www.figma.com/plugin-docs/) (node type reference)
- [flutter_rust_bridge docs](https://cjycode.com/flutter_rust_bridge/)
- `rust_figma_renderer/tools/README.md` - WASM interception guide
- `rust_figma_renderer/docs/` - Architecture documentation
