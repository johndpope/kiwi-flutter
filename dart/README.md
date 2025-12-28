# Kiwi Schema - Dart/Flutter Port

A Dart/Flutter implementation of the [Kiwi](https://github.com/evanw/kiwi) binary schema format for efficiently encoding trees of data, with full support for Figma's `.fig` file format.

## Features

- **Efficient compact encoding** using variable-length encoding for small values
- **Support for optional fields** with detectable presence
- **Linear serialization** - single-scan reads and writes for cache efficiency
- **Backwards & forwards compatibility** - new schemas can read old data and vice versa
- **Figma .fig file support** - parse and render Figma design files
- **Flutter renderer** - render Figma nodes as Flutter widgets
- **Pure Dart core** - no native dependencies for schema encoding/decoding

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  kiwi_schema:
    path: ../dart  # or from pub.dev when published
```

## Quick Start

### Basic Schema Usage

```dart
import 'package:kiwi_schema/kiwi.dart';

const schemaText = '''
enum Type {
  FLAT = 0;
  ROUND = 1;
  POINTED = 2;
}

struct Color {
  byte red;
  byte green;
  byte blue;
  byte alpha;
}

message Example {
  uint clientID = 1;
  Type type = 2;
  Color[] colors = 3;
}
''';

void main() {
  // Parse and compile the schema
  var schema = compileSchema(schemaText);

  // Encode a message
  var message = {
    'clientID': 100,
    'type': 'POINTED',
    'colors': [
      {'red': 255, 'green': 127, 'blue': 0, 'alpha': 255}
    ]
  };

  var encoded = schema.encode('Example', message);
  var decoded = schema.decode('Example', encoded);
}
```

### Parsing Figma Files

```dart
import 'dart:io';
import 'package:kiwi_schema/kiwi.dart';

void main() {
  final fileData = File('design.fig').readAsBytesSync();

  // Parse with decompression (requires zstd and zlib libraries)
  final parsed = parseFigFile(
    fileData,
    zstdDecompress: (data) => yourZstdDecoder(data),
    deflateDecompress: (data) => zlib.ZLibDecoder(raw: true).convert(data),
  );

  // Access the design data
  print('Nodes: ${parsed.nodeChanges.length}');
  print('Schema definitions: ${parsed.schema.definitions.length}');

  // Iterate nodes
  for (final node in parsed.nodeChanges) {
    print('${node['type']}: ${node['name']}');
  }
}
```

### Flutter Renderer

```dart
import 'package:flutter/material.dart';
import 'package:kiwi_schema/kiwi.dart';
import 'package:kiwi_schema/flutter_renderer.dart';

class FigmaViewerPage extends StatelessWidget {
  final Map<String, dynamic> message;

  const FigmaViewerPage({required this.message});

  @override
  Widget build(BuildContext context) {
    // Create document from parsed message
    final document = FigmaDocument.fromMessage(message);

    // Full canvas view with pan/zoom and page navigation
    return FigmaCanvasView(
      document: document,
      showPageSelector: true,
      showDebugInfo: true,
    );
  }
}
```

## Figma File Format

The `.fig` file format uses Kiwi binary encoding with compression:

```
┌─────────────────────────────────────┐
│ Header: "fig-kiwi" or "fig-kiwie"   │
├─────────────────────────────────────┤
│ Chunk 0: Binary Schema (DEFLATE)    │
├─────────────────────────────────────┤
│ Chunk 1: Message Data (ZSTD)        │
├─────────────────────────────────────┤
│ Chunk 2: Preview Image (optional)   │
└─────────────────────────────────────┘
```

### Supported Node Types

The Flutter renderer supports all major Figma node types:

| Type | Widget | Description |
|------|--------|-------------|
| FRAME | `FigmaFrameWidget` | Frames with background, borders, shadows |
| GROUP | `FigmaFrameWidget` | Grouped elements |
| COMPONENT | `FigmaFrameWidget` | Reusable components |
| INSTANCE | `FigmaFrameWidget` | Component instances |
| RECTANGLE | `FigmaRectangleWidget` | Rectangles with corner radii |
| ELLIPSE | `FigmaEllipseWidget` | Ellipses and circles |
| TEXT | `FigmaTextWidget` | Text with font styling |
| VECTOR | `FigmaVectorWidget` | Vector paths (SVG) |
| LINE | `FigmaVectorWidget` | Lines |
| STAR | `FigmaVectorWidget` | Star shapes |
| POLYGON | `FigmaVectorWidget` | Polygons |
| CANVAS | `FigmaCanvasWidget` | Pages |

## Supported Types

### Native Types
- `bool` - Boolean value (1 byte)
- `byte` - Unsigned 8-bit integer (1 byte)
- `int` - Signed 32-bit integer (variable-length, 1-5 bytes)
- `uint` - Unsigned 32-bit integer (variable-length, 1-5 bytes)
- `int64` - Signed 64-bit integer (variable-length, Figma extension)
- `uint64` - Unsigned 64-bit integer (variable-length, Figma extension)
- `float` - 32-bit IEEE 754 float (1 byte for 0, otherwise 4 bytes)
- `string` - UTF-8 null-terminated string

### User-Defined Types
- `enum` - Named integer values
- `struct` - Fixed fields, all required, cannot be extended
- `message` - Optional fields, extensible with field IDs

## Running Tests

```bash
cd dart
flutter pub get
flutter test
```

All 145 tests cover:
- Core Kiwi encoding/decoding (99 tests)
- Figma schema parsing (33 tests)
- Figma file parsing and message decoding (13 tests)

## Examples

### Flutter Web Demo

Basic schema encoding demo:

```bash
cd dart/example
flutter pub get
flutter run -d chrome
```

### Figma Viewer

See `example/figma_viewer.dart` for a complete Figma file viewer example.

## API Reference

### Core Functions

```dart
// Schema parsing
parseSchema(String text) → Schema
compileSchema(Schema | String) → CompiledSchema
encodeBinarySchema(Schema) → Uint8List
decodeBinarySchema(Uint8List) → Schema
prettyPrintSchema(Schema) → String

// Figma file parsing
parseFigFile(Uint8List, {...decompressors}) → ParsedFigFile
parseFigFileStructure(Uint8List) → FigFile
```

### CompiledSchema

```dart
encode(String typeName, Map<String, dynamic> message) → Uint8List
decode(String typeName, Uint8List data) → Map<String, dynamic>
getEnumValues(String enumName) → Map<String, int>?
getEnumNames(String enumName) → Map<int, String>?
```

### Flutter Widgets

```dart
// Document helper
FigmaDocument.fromMessage(Map<String, dynamic> message)

// Full canvas view
FigmaCanvasView(document: FigmaDocument, ...)

// Simple embeddable canvas
FigmaSimpleCanvas(node: Map, nodeMap: Map, ...)

// Individual node renderer
FigmaNodeWidget(node: Map, nodeMap: Map, scale: double)
```

### ByteBuffer

Low-level binary encoding/decoding:

```dart
readByte() / writeByte(int)
readByteArray() / writeByteArray(Uint8List)
readVarUint() / writeVarUint(int)
readVarInt() / writeVarInt(int)
readVarUint64() / writeVarUint64(int)
readVarInt64() / writeVarInt64(int)
readVarFloat() / writeVarFloat(double)
readString() / writeString(String)
toUint8Array() → Uint8List
```

## Compression Support

Figma files use ZSTD and raw DEFLATE compression. You'll need external libraries:

```dart
// Example with dart:io for DEFLATE
import 'dart:io';

final deflateDecompress = (Uint8List data) {
  return Uint8List.fromList(
    zlib.ZLibDecoder(raw: true).convert(data.toList())
  );
};

// For ZSTD, use a native binding like zstd_dart
import 'package:zstd/zstd.dart' as zstd;

final zstdDecompress = (Uint8List data) {
  return Uint8List.fromList(zstd.decode(data));
};
```

## License

MIT
