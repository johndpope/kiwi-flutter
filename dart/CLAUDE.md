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
│       └── flutter/
│           ├── node_renderer.dart   # Node rendering widgets
│           └── figma_canvas.dart    # Canvas view with pan/zoom
├── test/
│   ├── kiwi_test.dart               # Core encoding tests (99 tests)
│   ├── figma_test.dart              # Figma schema tests (33 tests)
│   ├── fig_file_test.dart           # .fig file parsing tests (13 tests)
│   └── fixtures/
│       ├── figma_schema.bin         # Extracted Figma binary schema
│       ├── figma_message.bin        # Decompressed Figma message data
│       └── figma_message_sample.bin # Truncated sample for quick tests
└── example/
    ├── main.dart                    # Schema encoding demo
    └── figma_viewer.dart            # Figma file viewer example
```

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

### Extended Types (Figma)
- `int64` / `uint64` - 64-bit integers (type indices 6, 7)

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

### Working with Test Fixtures

The test fixtures contain pre-extracted data from the Apple iOS UI Kit:
- `figma_schema.bin` - Binary schema (deflate-decompressed)
- `figma_message.bin` - Full message (zstd-decompressed, 17,748 nodes)

## Dependencies

- `flutter` SDK - Required for renderer widgets
- `test` - Dev dependency for testing

External libraries needed for full .fig file parsing:
- ZSTD decompression (e.g., `zstd_dart` package)
- Raw DEFLATE available via `dart:io` zlib

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
- Fills from `fillPaints`
- Strokes from `strokePaints`
- Effects from `effects`
- Corner radii from `rectangleCornerRadii` or `cornerRadius`

## Known Limitations

1. Vector paths use simplified SVG path parsing (M, L, C, Q, Z commands)
2. Gradients support LINEAR and RADIAL only
3. Text rendering uses basic font properties (no OpenType features)
4. Images require external blob handling (not rendered inline)
5. Prototype interactions are parsed but not executable

## References

- [Kiwi original repo](https://github.com/evanw/kiwi)
- [grida renderer reference](https://github.com/gridaco/grida/tree/main/editor/grida-canvas-react-renderer-dom/nodes)
- [Figma Plugin API](https://www.figma.com/plugin-docs/) (node type reference)
