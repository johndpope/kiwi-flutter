# Figma Renderer Documentation

## Quick Links

| Document | Description |
|----------|-------------|
| [Architecture](./ARCHITECTURE.md) | System design, data flow, module responsibilities |
| [API Reference](./API_REFERENCE.md) | Complete Dart API documentation |
| [Integration Guide](./INTEGRATION_GUIDE.md) | Flutter setup, platform configuration, examples |
| [Kiwi Format](./KIWI_FORMAT.md) | Binary format specification |
| [Figma WASM Interface](./FIGMA_WASM_INTERFACE.md) | Analysis of Figma's WebAssembly module |

## Project Structure

```
rust_figma_renderer/
├── Cargo.toml                      # Rust dependencies
├── build.sh                        # Build script
├── flutter_rust_bridge.yaml        # FFI/WASM codegen config
├── flutter_integration.dart        # Example Flutter usage
├── README.md                       # Project overview
│
├── src/
│   ├── lib.rs                      # Library entry point
│   ├── api.rs                      # Public API (Flutter bindings)
│   ├── kiwi.rs                     # .fig file parser
│   ├── nodes.rs                    # Node types & rendering
│   ├── paints.rs                   # Fill/stroke/gradient
│   ├── effects.rs                  # Shadows, blurs
│   ├── layout.rs                   # Auto-layout algorithm
│   ├── vector.rs                   # Path operations
│   ├── render.rs                   # Render tree
│   └── schema.rs                   # Figma schema definitions
│
└── docs/
    ├── INDEX.md                    # This file
    ├── ARCHITECTURE.md             # System architecture
    ├── API_REFERENCE.md            # API documentation
    ├── INTEGRATION_GUIDE.md        # Flutter integration
    ├── KIWI_FORMAT.md              # Binary format spec
    └── FIGMA_WASM_INTERFACE.md     # WASM analysis
```

## Getting Started

### 1. Build the Rust Library

```bash
cd rust_figma_renderer
./build.sh
```

### 2. Add to Flutter Project

```yaml
# pubspec.yaml
dependencies:
  flutter_rust_bridge: ^2.0.0
```

### 3. Initialize and Load

```dart
import 'package:figma_renderer/src/rust/api.dart';

void main() async {
  await RustLib.init();

  final bytes = await rootBundle.load('assets/design.fig');
  final doc = await loadFigmaFile(data: bytes.buffer.asUint8List());

  final commands = await renderNode(
    doc: doc,
    nodeId: 'some-node-id',
    includeChildren: true,
  );

  // Use with CustomPainter
}
```

## Key Concepts

### File Flow

```
.fig file → parse header → decompress chunks → decode Kiwi → build node tree
```

### Render Flow

```
FigmaDocument → render_node() → DrawCommands → CustomPainter → Canvas
```

### Platform Support

| Platform | Integration |
|----------|-------------|
| iOS | Static library via FFI |
| Android | Shared library via FFI |
| macOS | Dynamic library via FFI |
| Linux | Shared library via FFI |
| Windows | DLL via FFI |
| Web | WASM via wasm-bindgen |

## Performance

- **Lazy decoding**: Paint/effect data decoded on demand
- **Render caching**: Cache DrawCommands for unchanged nodes
- **Native speed**: Rust compiled to optimized native/WASM code
- **Memory efficient**: No garbage collection overhead

## Limitations

- Text rendering requires font data (not included in .fig)
- Images stored as references, not embedded
- Prototype interactions parsed but not executable
- Some advanced effects may not render identically

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes with tests
4. Submit a pull request

## License

MIT License - See LICENSE file
