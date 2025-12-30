#!/bin/bash
set -e

echo "🦀 Building Figma Renderer (Rust)"

# Install dependencies if needed
if ! command -v cargo &> /dev/null; then
    echo "Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source $HOME/.cargo/env
fi

# Install WASM target
rustup target add wasm32-unknown-unknown

# Install flutter_rust_bridge_codegen
cargo install flutter_rust_bridge_codegen

# Build native library (for iOS/Android/Desktop)
echo "📦 Building native library..."
cargo build --release

# Build WASM (for Flutter web)
echo "🌐 Building WASM..."
cargo build --target wasm32-unknown-unknown --release --features wasm

# Generate Flutter bindings
echo "🔗 Generating Flutter bindings..."
flutter_rust_bridge_codegen generate --config-file flutter_rust_bridge.yaml

echo "✅ Build complete!"
echo ""
echo "Native library: target/release/libfigma_renderer.a"
echo "WASM module: target/wasm32-unknown-unknown/release/figma_renderer.wasm"
echo ""
echo "Next steps:"
echo "1. Add to your Flutter pubspec.yaml:"
echo "   dependencies:"
echo "     flutter_rust_bridge: ^2.0.0"
echo ""
echo "2. Import in your Dart code:"
echo "   import 'package:your_app/src/rust/api.dart';"
echo ""
echo "3. Initialize at app startup:"
echo "   await RustLib.init();"
