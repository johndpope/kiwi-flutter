# Flutter Integration Guide

## Prerequisites

- Flutter 3.0+
- Rust 1.70+
- For iOS: Xcode 14+
- For Android: NDK 25+

## Installation

### 1. Add Dependencies

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_rust_bridge: ^2.0.0
  ffi: ^2.0.0

dev_dependencies:
  ffigen: ^8.0.0
```

### 2. Build the Rust Library

```bash
cd rust_figma_renderer
./build.sh
```

This will:
- Build native libraries for your platform
- Build WASM for web
- Generate Dart bindings

### 3. Platform Configuration

#### iOS

Add to `ios/Runner/Runner.xcodeproj`:

1. Add `libfigma_renderer.a` to "Link Binary With Libraries"
2. Add header search path: `$(PROJECT_DIR)/../rust_figma_renderer/target/release`

Or in `Podfile`:

```ruby
target 'Runner' do
  # ... existing config

  # Link Rust library
  pod 'figma_renderer', :path => '../rust_figma_renderer'
end
```

#### Android

Add to `android/app/build.gradle`:

```gradle
android {
    // ... existing config

    sourceSets {
        main {
            jniLibs.srcDirs = ['../rust_figma_renderer/target/jniLibs']
        }
    }
}
```

#### macOS

Add to `macos/Runner/Runner.xcodeproj`:

1. Add `libfigma_renderer.dylib` to "Copy Files" build phase
2. Add to "Link Binary With Libraries"

#### Linux

Add to `linux/CMakeLists.txt`:

```cmake
target_link_libraries(${BINARY_NAME} PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/../rust_figma_renderer/target/release/libfigma_renderer.so
)
```

#### Windows

Add to `windows/CMakeLists.txt`:

```cmake
target_link_libraries(${BINARY_NAME} PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/../rust_figma_renderer/target/release/figma_renderer.dll
)
```

#### Web

The WASM module is automatically loaded. Ensure the built files are in `web/`:

```bash
cp rust_figma_renderer/target/wasm32-unknown-unknown/release/figma_renderer.wasm web/
cp rust_figma_renderer/pkg/figma_renderer.js web/
```

---

## Basic Usage

### Initialize

```dart
import 'package:figma_renderer/src/rust/api.dart';
import 'package:figma_renderer/src/rust/frb_generated.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Rust library
  await RustLib.init();

  runApp(MyApp());
}
```

### Load a Figma File

```dart
import 'dart:io';
import 'package:figma_renderer/src/rust/api.dart';

class FigmaLoader {
  FigmaDocument? _document;

  Future<void> loadFile(String path) async {
    final bytes = await File(path).readAsBytes();
    _document = await loadFigmaFile(data: bytes);

    final info = await getDocumentInfo(doc: _document!);
    print('Loaded: ${info.name}');
    print('Nodes: ${info.nodeCount}');
    print('Pages: ${info.pageIds}');
  }

  Future<List<DrawCommand>> renderPage(String pageId) async {
    if (_document == null) throw StateError('No document loaded');

    return await renderNode(
      doc: _document!,
      nodeId: pageId,
      includeChildren: true,
    );
  }
}
```

### Render with CustomPainter

```dart
class FigmaCanvas extends StatefulWidget {
  final String filePath;

  const FigmaCanvas({required this.filePath});

  @override
  State<FigmaCanvas> createState() => _FigmaCanvasState();
}

class _FigmaCanvasState extends State<FigmaCanvas> {
  final FigmaLoader _loader = FigmaLoader();
  List<DrawCommand>? _commands;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  Future<void> _loadFile() async {
    try {
      await _loader.loadFile(widget.filePath);
      final info = await getDocumentInfo(doc: _loader._document!);

      if (info.pageIds.isNotEmpty) {
        final commands = await _loader.renderPage(info.pageIds.first);
        setState(() {
          _commands = commands;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text('Error: $_error'));
    }

    return InteractiveViewer(
      boundaryMargin: const EdgeInsets.all(100),
      minScale: 0.1,
      maxScale: 10.0,
      child: CustomPaint(
        painter: FigmaNodePainter(_commands!),
        size: Size.infinite,
      ),
    );
  }
}
```

### The Painter

```dart
class FigmaNodePainter extends CustomPainter {
  final List<DrawCommand> commands;

  FigmaNodePainter(this.commands);

  @override
  void paint(Canvas canvas, Size size) {
    for (final cmd in commands) {
      _renderCommand(canvas, cmd);
    }
  }

  void _renderCommand(Canvas canvas, DrawCommand cmd) {
    // Apply transform
    canvas.save();
    canvas.transform(Float64List.fromList([
      cmd.transform.m00, cmd.transform.m10, 0, 0,
      cmd.transform.m01, cmd.transform.m11, 0, 0,
      0, 0, 1, 0,
      cmd.transform.m02, cmd.transform.m12, 0, 1,
    ]));

    // Render effects (shadows first, as they go behind)
    for (final effect in cmd.effects) {
      if (effect.effectType == 'drop_shadow' && effect.visible) {
        _renderShadow(canvas, cmd, effect);
      }
    }

    // Render based on type
    switch (cmd.commandType) {
      case 'rect':
        _renderRect(canvas, cmd);
        break;
      case 'ellipse':
        _renderEllipse(canvas, cmd);
        break;
      case 'path':
        _renderPath(canvas, cmd);
        break;
      case 'text':
        _renderText(canvas, cmd);
        break;
    }

    canvas.restore();
  }

  void _renderRect(Canvas canvas, DrawCommand cmd) {
    final rect = cmd.rect;
    if (rect == null) return;

    final rrect = RRect.fromRectAndCorners(
      Rect.fromLTWH(0, 0, rect.width, rect.height),
      topLeft: Radius.circular(rect.cornerRadii[0]),
      topRight: Radius.circular(rect.cornerRadii[1]),
      bottomRight: Radius.circular(rect.cornerRadii[2]),
      bottomLeft: Radius.circular(rect.cornerRadii[3]),
    );

    // Draw fills
    for (final fill in cmd.fills) {
      canvas.drawRRect(rrect, _createPaint(fill));
    }

    // Draw strokes
    for (final stroke in cmd.strokes) {
      canvas.drawRRect(rrect, _createPaint(stroke)
        ..style = PaintingStyle.stroke
        ..strokeWidth = cmd.strokeWeight);
    }
  }

  void _renderEllipse(Canvas canvas, DrawCommand cmd) {
    final rect = cmd.rect;
    if (rect == null) return;

    final oval = Rect.fromLTWH(0, 0, rect.width, rect.height);

    for (final fill in cmd.fills) {
      canvas.drawOval(oval, _createPaint(fill));
    }

    for (final stroke in cmd.strokes) {
      canvas.drawOval(oval, _createPaint(stroke)
        ..style = PaintingStyle.stroke
        ..strokeWidth = cmd.strokeWeight);
    }
  }

  void _renderPath(Canvas canvas, DrawCommand cmd) {
    final pathData = cmd.path;
    if (pathData == null) return;

    final path = _parseSvgPath(pathData.commands);
    if (pathData.fillRule == 'evenodd') {
      path.fillType = PathFillType.evenOdd;
    }

    for (final fill in cmd.fills) {
      canvas.drawPath(path, _createPaint(fill));
    }

    for (final stroke in cmd.strokes) {
      canvas.drawPath(path, _createPaint(stroke)
        ..style = PaintingStyle.stroke
        ..strokeWidth = cmd.strokeWeight);
    }
  }

  void _renderText(Canvas canvas, DrawCommand cmd) {
    // Text rendering implementation
    // Would need access to text content and font info
  }

  void _renderShadow(Canvas canvas, DrawCommand cmd, EffectInfo effect) {
    final shadowPaint = Paint()
      ..color = Color.fromARGB(
        effect.color?.a ?? 128,
        effect.color?.r ?? 0,
        effect.color?.g ?? 0,
        effect.color?.b ?? 0,
      )
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, effect.radius);

    canvas.save();
    canvas.translate(effect.offsetX, effect.offsetY);

    if (cmd.rect != null) {
      final rect = cmd.rect!;
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(0, 0, rect.width, rect.height),
          topLeft: Radius.circular(rect.cornerRadii[0]),
          topRight: Radius.circular(rect.cornerRadii[1]),
          bottomRight: Radius.circular(rect.cornerRadii[2]),
          bottomLeft: Radius.circular(rect.cornerRadii[3]),
        ),
        shadowPaint,
      );
    }

    canvas.restore();
  }

  Paint _createPaint(PaintInfo info) {
    final paint = Paint();

    switch (info.paintType) {
      case 'solid':
        if (info.color != null) {
          paint.color = Color.fromARGB(
            info.color!.a,
            info.color!.r,
            info.color!.g,
            info.color!.b,
          ).withOpacity(info.opacity);
        }
        break;

      case 'gradient_linear':
        if (info.gradientStops.isNotEmpty) {
          paint.shader = ui.Gradient.linear(
            Offset.zero,
            const Offset(1, 0), // Default direction
            info.gradientStops.map((s) => Color.fromARGB(
              s.color.a, s.color.r, s.color.g, s.color.b,
            )).toList(),
            info.gradientStops.map((s) => s.position).toList(),
          );
        }
        break;

      case 'gradient_radial':
        if (info.gradientStops.isNotEmpty) {
          paint.shader = ui.Gradient.radial(
            const Offset(0.5, 0.5),
            0.5,
            info.gradientStops.map((s) => Color.fromARGB(
              s.color.a, s.color.r, s.color.g, s.color.b,
            )).toList(),
            info.gradientStops.map((s) => s.position).toList(),
          );
        }
        break;
    }

    paint.blendMode = _parseBlendMode(info.blendMode);
    return paint;
  }

  BlendMode _parseBlendMode(String mode) {
    const modes = {
      'NORMAL': BlendMode.srcOver,
      'MULTIPLY': BlendMode.multiply,
      'SCREEN': BlendMode.screen,
      'OVERLAY': BlendMode.overlay,
      'DARKEN': BlendMode.darken,
      'LIGHTEN': BlendMode.lighten,
      'COLOR_DODGE': BlendMode.colorDodge,
      'COLOR_BURN': BlendMode.colorBurn,
      'HARD_LIGHT': BlendMode.hardLight,
      'SOFT_LIGHT': BlendMode.softLight,
      'DIFFERENCE': BlendMode.difference,
      'EXCLUSION': BlendMode.exclusion,
      'HUE': BlendMode.hue,
      'SATURATION': BlendMode.saturation,
      'COLOR': BlendMode.color,
      'LUMINOSITY': BlendMode.luminosity,
    };
    return modes[mode] ?? BlendMode.srcOver;
  }

  Path _parseSvgPath(String commands) {
    final path = Path();
    final regex = RegExp(r'([MLCQZmlcqz])([^MLCQZmlcqz]*)');

    for (final match in regex.allMatches(commands)) {
      final cmd = match.group(1)!;
      final args = match.group(2)!
          .trim()
          .split(RegExp(r'[\s,]+'))
          .where((s) => s.isNotEmpty)
          .map((s) => double.tryParse(s) ?? 0.0)
          .toList();

      switch (cmd) {
        case 'M':
          if (args.length >= 2) path.moveTo(args[0], args[1]);
          break;
        case 'L':
          if (args.length >= 2) path.lineTo(args[0], args[1]);
          break;
        case 'C':
          if (args.length >= 6) {
            path.cubicTo(args[0], args[1], args[2], args[3], args[4], args[5]);
          }
          break;
        case 'Q':
          if (args.length >= 4) {
            path.quadraticBezierTo(args[0], args[1], args[2], args[3]);
          }
          break;
        case 'Z':
        case 'z':
          path.close();
          break;
      }
    }

    return path;
  }

  @override
  bool shouldRepaint(FigmaNodePainter oldDelegate) {
    return commands != oldDelegate.commands;
  }
}
```

---

## Advanced Usage

### Selective Node Rendering

```dart
// Render only specific nodes
Future<Widget> renderNode(String nodeId) async {
  final commands = await renderNode(
    doc: _document!,
    nodeId: nodeId,
    includeChildren: false, // Only this node
  );

  return CustomPaint(painter: FigmaNodePainter(commands));
}
```

### Node Tree Navigation

```dart
// Build a tree widget from node hierarchy
Future<Widget> buildNodeTree(String rootId) async {
  final root = await getNodeInfo(doc: _document!, nodeId: rootId);

  return ExpansionTile(
    title: Text('${root.name} (${root.nodeType})'),
    children: await Future.wait(
      root.children.map((childId) => buildNodeTree(childId)),
    ),
  );
}
```

### Export to SVG

```dart
Future<String> exportFrameToSvg(String frameId) async {
  final node = await getNodeInfo(doc: _document!, nodeId: frameId);
  final path = await exportSvgPath(doc: _document!, nodeId: frameId);

  return '''
<svg width="${node.width}" height="${node.height}" xmlns="http://www.w3.org/2000/svg">
  <path d="$path" fill="currentColor" />
</svg>
''';
}
```

### Caching Rendered Commands

```dart
class CachedFigmaRenderer {
  final Map<String, List<DrawCommand>> _cache = {};

  Future<List<DrawCommand>> render(
    FigmaDocument doc,
    String nodeId,
  ) async {
    if (_cache.containsKey(nodeId)) {
      return _cache[nodeId]!;
    }

    final commands = await renderNode(
      doc: doc,
      nodeId: nodeId,
      includeChildren: true,
    );

    _cache[nodeId] = commands;
    return commands;
  }

  void invalidate(String nodeId) {
    _cache.remove(nodeId);
  }

  void clear() {
    _cache.clear();
  }
}
```

---

## Web-Specific Notes

### WASM Loading

The WASM module is loaded automatically, but you can customize:

```dart
// In web/index.html
<script>
  var serviceWorkerVersion = null;
  var scriptLoaded = false;

  // Load WASM before Flutter
  WebAssembly.instantiateStreaming(
    fetch('figma_renderer.wasm'),
    {}
  ).then(result => {
    window.figmaRendererWasm = result.instance;
  });
</script>
```

### Memory Considerations

WASM has a 4GB memory limit. For large files:

```dart
// Check memory usage
final info = await getDocumentInfo(doc: doc);
if (info.nodeCount > 50000) {
  print('Warning: Large file may cause memory issues on web');
}
```

---

## Troubleshooting

### "Library not found"

Ensure the native library is in the correct location:

```bash
# iOS
ls ios/Frameworks/libfigma_renderer.a

# Android
ls android/app/src/main/jniLibs/arm64-v8a/libfigma_renderer.so

# macOS
ls macos/Frameworks/libfigma_renderer.dylib
```

### "Invalid file header"

The file must be a valid .fig file:

```dart
// Check file header
final bytes = await File(path).readAsBytes();
final header = String.fromCharCodes(bytes.sublist(0, 8));
if (!header.startsWith('fig-kiwi')) {
  throw Exception('Not a valid Figma file');
}
```

### "WASM not loading"

Check browser console for errors. Ensure CORS headers allow WASM:

```
Access-Control-Allow-Origin: *
Content-Type: application/wasm
```
