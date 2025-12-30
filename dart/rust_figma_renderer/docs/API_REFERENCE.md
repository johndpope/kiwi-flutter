# API Reference

## Overview

The Figma Renderer exposes a Dart API via `flutter_rust_bridge`. After code generation, you'll have type-safe Dart classes that call into the Rust core.

## Initialization

```dart
import 'package:figma_renderer/src/rust/api.dart';
import 'package:figma_renderer/src/rust/frb_generated.dart';

void main() async {
  // Initialize the Rust library (required once at startup)
  await RustLib.init();

  runApp(MyApp());
}
```

---

## Core Types

### FigmaDocument

Opaque handle to a loaded Figma file. Created by `loadFigmaFile()`.

```dart
// Load a file
final doc = await loadFigmaFile(data: fileBytes);

// Use the document
final info = await getDocumentInfo(doc: doc);
final commands = await renderNode(doc: doc, nodeId: '1:2');

// Document is automatically cleaned up when no longer referenced
```

### DocumentInfo

```dart
class DocumentInfo {
  final String name;       // Document name
  final int version;       // Schema version
  final int nodeCount;     // Total nodes in document
  final List<String> pageIds;  // IDs of page (canvas) nodes
}
```

### NodeInfo

```dart
class NodeInfo {
  final String id;         // Unique node identifier (e.g., "1:42")
  final String name;       // Node name from Figma
  final String nodeType;   // "FRAME", "RECTANGLE", "TEXT", etc.
  final double x;          // X position relative to parent
  final double y;          // Y position relative to parent
  final double width;      // Node width
  final double height;     // Node height
  final double rotation;   // Rotation in degrees
  final double opacity;    // Opacity (0.0 - 1.0)
  final bool visible;      // Visibility flag
  final List<String> children;  // Child node IDs
}
```

### DrawCommand

Represents a single drawing operation for the Flutter Canvas.

```dart
class DrawCommand {
  final String commandType;  // "rect", "ellipse", "path", "text", "image"
  final PathData? path;      // SVG-like path data
  final RectInfo? rect;      // Rectangle bounds
  final List<PaintInfo> fills;    // Fill paints
  final List<PaintInfo> strokes;  // Stroke paints
  final double strokeWeight;      // Stroke width
  final List<EffectInfo> effects; // Visual effects
  final TransformInfo transform;  // 2D transform matrix
  final PathData? clipPath;       // Optional clipping path
}
```

### PathData

```dart
class PathData {
  final String commands;   // SVG path commands: "M 0 0 L 100 100 Z"
  final String fillRule;   // "nonzero" or "evenodd"
}
```

### RectInfo

```dart
class RectInfo {
  final double x;
  final double y;
  final double width;
  final double height;
  final List<double> cornerRadii;  // [topLeft, topRight, bottomRight, bottomLeft]
}
```

### PaintInfo

```dart
class PaintInfo {
  final String paintType;  // "solid", "gradient_linear", "gradient_radial",
                           // "gradient_angular", "gradient_diamond", "image"
  final ColorInfo? color;              // For solid paints
  final List<GradientStopInfo> gradientStops;  // For gradients
  final double opacity;                // Paint opacity
  final String blendMode;              // "NORMAL", "MULTIPLY", etc.
}
```

### ColorInfo

```dart
class ColorInfo {
  final int r;  // Red (0-255)
  final int g;  // Green (0-255)
  final int b;  // Blue (0-255)
  final int a;  // Alpha (0-255)
}
```

### GradientStopInfo

```dart
class GradientStopInfo {
  final double position;  // Position along gradient (0.0 - 1.0)
  final ColorInfo color;  // Color at this stop
}
```

### EffectInfo

```dart
class EffectInfo {
  final String effectType;  // "drop_shadow", "inner_shadow",
                            // "layer_blur", "background_blur"
  final bool visible;       // Effect visibility
  final double radius;      // Blur radius
  final ColorInfo? color;   // Shadow color (shadows only)
  final double offsetX;     // Shadow X offset (shadows only)
  final double offsetY;     // Shadow Y offset (shadows only)
  final double spread;      // Shadow spread (shadows only)
}
```

### TransformInfo

2D affine transformation matrix.

```dart
class TransformInfo {
  final double m00;  // Scale X
  final double m01;  // Skew Y
  final double m02;  // Translate X
  final double m10;  // Skew X
  final double m11;  // Scale Y
  final double m12;  // Translate Y
}

// Matrix layout:
// | m00  m01  m02 |   | scaleX  skewY   translateX |
// | m10  m11  m12 | = | skewX   scaleY  translateY |
// |  0    0    1  |   |   0       0         1      |
```

### LayoutResult

```dart
class LayoutResult {
  final String nodeId;
  final double x;
  final double y;
  final double width;
  final double height;
}
```

---

## Functions

### loadFigmaFile

Load a Figma file from raw bytes.

```dart
Future<FigmaDocument> loadFigmaFile({
  required Uint8List data,
});
```

**Parameters:**
- `data`: Raw bytes of a .fig file

**Returns:** `FigmaDocument` handle

**Throws:** `FigmaError` if file is invalid

**Example:**
```dart
final bytes = await File('design.fig').readAsBytes();
final doc = await loadFigmaFile(data: bytes);
```

---

### getDocumentInfo

Get metadata about a loaded document.

```dart
Future<DocumentInfo> getDocumentInfo({
  required FigmaDocument doc,
});
```

**Parameters:**
- `doc`: Document handle from `loadFigmaFile`

**Returns:** `DocumentInfo` with name, version, node count, page IDs

**Example:**
```dart
final info = await getDocumentInfo(doc: doc);
print('Loaded "${info.name}" with ${info.nodeCount} nodes');
print('Pages: ${info.pageIds}');
```

---

### getNodeInfo

Get detailed information about a specific node.

```dart
Future<NodeInfo> getNodeInfo({
  required FigmaDocument doc,
  required String nodeId,
});
```

**Parameters:**
- `doc`: Document handle
- `nodeId`: Node identifier (e.g., "1:42")

**Returns:** `NodeInfo` with all node properties

**Throws:** `FigmaError.NodeNotFound` if node doesn't exist

**Example:**
```dart
final node = await getNodeInfo(doc: doc, nodeId: '1:42');
print('${node.name} (${node.nodeType}): ${node.width}x${node.height}');
```

---

### getChildren

Get all child nodes of a parent node.

```dart
Future<List<NodeInfo>> getChildren({
  required FigmaDocument doc,
  required String nodeId,
});
```

**Parameters:**
- `doc`: Document handle
- `nodeId`: Parent node identifier

**Returns:** List of `NodeInfo` for all children

**Example:**
```dart
final children = await getChildren(doc: doc, nodeId: pageId);
for (final child in children) {
  print('- ${child.name}');
}
```

---

### renderNode

Generate drawing commands for a node and optionally its children.

```dart
Future<List<DrawCommand>> renderNode({
  required FigmaDocument doc,
  required String nodeId,
  required bool includeChildren,
});
```

**Parameters:**
- `doc`: Document handle
- `nodeId`: Node to render
- `includeChildren`: Whether to include descendant nodes

**Returns:** List of `DrawCommand` in render order (back to front)

**Example:**
```dart
final commands = await renderNode(
  doc: doc,
  nodeId: frameId,
  includeChildren: true,
);

// Use in CustomPainter
CustomPaint(
  painter: FigmaNodePainter(commands),
)
```

---

### calculateLayout

Calculate auto-layout positions for a frame and its children.

```dart
Future<List<LayoutResult>> calculateLayout({
  required FigmaDocument doc,
  required String rootId,
});
```

**Parameters:**
- `doc`: Document handle
- `rootId`: Root frame node ID

**Returns:** List of `LayoutResult` with computed positions

**Example:**
```dart
final layout = await calculateLayout(doc: doc, rootId: frameId);
for (final result in layout) {
  print('${result.nodeId}: (${result.x}, ${result.y})');
}
```

---

### exportSvgPath

Export a node's geometry as SVG path data.

```dart
Future<String> exportSvgPath({
  required FigmaDocument doc,
  required String nodeId,
});
```

**Parameters:**
- `doc`: Document handle
- `nodeId`: Node to export

**Returns:** SVG path string (e.g., "M 0 0 L 100 0 L 100 100 Z")

**Example:**
```dart
final svgPath = await exportSvgPath(doc: doc, nodeId: vectorId);
print('<path d="$svgPath" />');
```

---

### decodeFillPaint

Decode Kiwi-encoded fill paint data.

```dart
Future<List<PaintInfo>> decodeFillPaint({
  required Uint8List data,
});
```

**Parameters:**
- `data`: Raw Kiwi-encoded paint bytes

**Returns:** List of `PaintInfo` objects

**Example:**
```dart
// If you have raw paint data from elsewhere
final paints = await decodeFillPaint(data: paintBytes);
for (final paint in paints) {
  print('${paint.paintType}: ${paint.color}');
}
```

---

### decodeEffects

Decode Kiwi-encoded effect data.

```dart
Future<List<EffectInfo>> decodeEffects({
  required Uint8List data,
});
```

**Parameters:**
- `data`: Raw Kiwi-encoded effect bytes

**Returns:** List of `EffectInfo` objects

---

### decodeVector

Decode Kiwi-encoded vector path data.

```dart
Future<PathData> decodeVector({
  required Uint8List data,
});
```

**Parameters:**
- `data`: Raw Kiwi-encoded vector bytes

**Returns:** `PathData` with SVG commands and fill rule

---

## Error Handling

All functions can throw `FigmaError`:

```dart
try {
  final doc = await loadFigmaFile(data: bytes);
} on FigmaError catch (e) {
  switch (e.type) {
    case FigmaErrorType.invalidHeader:
      print('Not a valid .fig file');
      break;
    case FigmaErrorType.decompressionError:
      print('Failed to decompress: ${e.message}');
      break;
    case FigmaErrorType.schemaError:
      print('Schema parsing failed: ${e.message}');
      break;
    case FigmaErrorType.decodeError:
      print('Message decoding failed: ${e.message}');
      break;
    case FigmaErrorType.nodeNotFound:
      print('Node not found: ${e.message}');
      break;
  }
}
```

---

## Constants

### Node Types

```dart
const nodeTypes = {
  'DOCUMENT',
  'CANVAS',
  'FRAME',
  'GROUP',
  'VECTOR',
  'BOOLEAN_OPERATION',
  'STAR',
  'LINE',
  'ELLIPSE',
  'REGULAR_POLYGON',
  'RECTANGLE',
  'TEXT',
  'SLICE',
  'COMPONENT',
  'COMPONENT_SET',
  'INSTANCE',
  'STICKY',
  'SHAPE_WITH_TEXT',
  'CONNECTOR',
  'SECTION',
};
```

### Blend Modes

```dart
const blendModes = {
  'PASS_THROUGH',
  'NORMAL',
  'DARKEN',
  'MULTIPLY',
  'LINEAR_BURN',
  'COLOR_BURN',
  'LIGHTEN',
  'SCREEN',
  'LINEAR_DODGE',
  'COLOR_DODGE',
  'OVERLAY',
  'SOFT_LIGHT',
  'HARD_LIGHT',
  'DIFFERENCE',
  'EXCLUSION',
  'HUE',
  'SATURATION',
  'COLOR',
  'LUMINOSITY',
};
```

### Paint Types

```dart
const paintTypes = {
  'solid',
  'gradient_linear',
  'gradient_radial',
  'gradient_angular',
  'gradient_diamond',
  'image',
};
```

### Effect Types

```dart
const effectTypes = {
  'drop_shadow',
  'inner_shadow',
  'layer_blur',
  'background_blur',
};
```
