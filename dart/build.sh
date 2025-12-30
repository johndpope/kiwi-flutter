#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUST_DIR="$SCRIPT_DIR/rust_figma_renderer"

# Parse arguments
BUILD_NATIVE=false
BUILD_WASM=false
GENERATE_BINDINGS=false
RUN_APP=false
CLEAN=false
RELEASE=false
PLATFORM="macos"  # Default platform

print_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --native          Build native Rust library"
    echo "  --wasm            Build WASM module"
    echo "  --bindings        Generate Flutter bindings"
    echo "  --run             Run the Flutter app"
    echo "  --all             Build everything and run"
    echo "  --clean           Clean build artifacts"
    echo "  --release         Build in release mode"
    echo "  --platform <p>    Platform to run on (macos, ios, chrome)"
    echo "  -h, --help        Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 --all                    # Build everything and run on macOS"
    echo "  $0 --native --bindings      # Build native + generate bindings"
    echo "  $0 --run --platform ios     # Run on iOS simulator"
    echo "  $0 --clean --all            # Clean and rebuild everything"
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --native)
            BUILD_NATIVE=true
            shift
            ;;
        --wasm)
            BUILD_WASM=true
            shift
            ;;
        --bindings)
            GENERATE_BINDINGS=true
            shift
            ;;
        --run)
            RUN_APP=true
            shift
            ;;
        --all)
            BUILD_NATIVE=true
            BUILD_WASM=true
            GENERATE_BINDINGS=true
            RUN_APP=true
            shift
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        --release)
            RELEASE=true
            shift
            ;;
        --platform)
            PLATFORM="$2"
            shift 2
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            print_usage
            exit 1
            ;;
    esac
done

# If no options specified, show help
if [[ "$BUILD_NATIVE" == "false" && "$BUILD_WASM" == "false" && "$GENERATE_BINDINGS" == "false" && "$RUN_APP" == "false" && "$CLEAN" == "false" ]]; then
    print_usage
    exit 0
fi

# Clean build artifacts
if [[ "$CLEAN" == "true" ]]; then
    echo -e "${YELLOW}🧹 Cleaning build artifacts...${NC}"

    # Clean Rust
    if [[ -d "$RUST_DIR" ]]; then
        cd "$RUST_DIR"
        cargo clean
        cd "$SCRIPT_DIR"
    fi

    # Clean Flutter
    flutter clean

    echo -e "${GREEN}✓ Clean complete${NC}"
fi

# Build native Rust library
if [[ "$BUILD_NATIVE" == "true" ]]; then
    echo -e "${BLUE}🦀 Building native Rust library...${NC}"

    if [[ ! -d "$RUST_DIR" ]]; then
        echo -e "${RED}Error: Rust directory not found at $RUST_DIR${NC}"
        exit 1
    fi

    cd "$RUST_DIR"

    if [[ "$RELEASE" == "true" ]]; then
        cargo build --release
        echo -e "${GREEN}✓ Native library built (release): target/release/libfigma_renderer.a${NC}"
    else
        cargo build
        echo -e "${GREEN}✓ Native library built (debug): target/debug/libfigma_renderer.a${NC}"
    fi

    cd "$SCRIPT_DIR"
fi

# Build WASM module
if [[ "$BUILD_WASM" == "true" ]]; then
    echo -e "${BLUE}🌐 Building WASM module...${NC}"

    if [[ ! -d "$RUST_DIR" ]]; then
        echo -e "${RED}Error: Rust directory not found at $RUST_DIR${NC}"
        exit 1
    fi

    # Check for wasm32 target
    if ! rustup target list --installed | grep -q "wasm32-unknown-unknown"; then
        echo -e "${YELLOW}Installing wasm32-unknown-unknown target...${NC}"
        rustup target add wasm32-unknown-unknown
    fi

    cd "$RUST_DIR"

    if [[ "$RELEASE" == "true" ]]; then
        cargo build --release --target wasm32-unknown-unknown
        WASM_SIZE=$(ls -lh target/wasm32-unknown-unknown/release/figma_renderer.wasm 2>/dev/null | awk '{print $5}')
        echo -e "${GREEN}✓ WASM module built (release): $WASM_SIZE${NC}"
    else
        cargo build --target wasm32-unknown-unknown
        WASM_SIZE=$(ls -lh target/wasm32-unknown-unknown/debug/figma_renderer.wasm 2>/dev/null | awk '{print $5}')
        echo -e "${GREEN}✓ WASM module built (debug): $WASM_SIZE${NC}"
    fi

    cd "$SCRIPT_DIR"
fi

# Generate Flutter bindings
if [[ "$GENERATE_BINDINGS" == "true" ]]; then
    echo -e "${BLUE}🔗 Generating Flutter bindings...${NC}"

    # Check if flutter_rust_bridge_codegen is installed
    if ! command -v flutter_rust_bridge_codegen &> /dev/null; then
        echo -e "${YELLOW}Installing flutter_rust_bridge_codegen...${NC}"
        cargo install flutter_rust_bridge_codegen
    fi

    cd "$SCRIPT_DIR"

    flutter_rust_bridge_codegen generate \
        --rust-input "crate::api" \
        --rust-root "$RUST_DIR" \
        --dart-output "lib/src/rust"

    echo -e "${GREEN}✓ Flutter bindings generated${NC}"

    # Verify generated code
    echo -e "${BLUE}📋 Analyzing generated Dart code...${NC}"
    flutter analyze lib/src/rust/ --no-fatal-infos --no-fatal-warnings || true
fi

# Get Flutter dependencies
if [[ "$RUN_APP" == "true" || "$GENERATE_BINDINGS" == "true" ]]; then
    echo -e "${BLUE}📦 Getting Flutter dependencies...${NC}"
    cd "$SCRIPT_DIR"
    flutter pub get
fi

# Run the app
if [[ "$RUN_APP" == "true" ]]; then
    echo -e "${BLUE}🚀 Running Flutter app on $PLATFORM...${NC}"
    cd "$SCRIPT_DIR"

    case $PLATFORM in
        macos)
            flutter run -d macos
            ;;
        ios)
            # Find an available iOS simulator
            SIMULATOR_ID=$(xcrun simctl list devices available | grep "iPhone" | head -1 | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}')
            if [[ -n "$SIMULATOR_ID" ]]; then
                echo -e "${YELLOW}Using simulator: $SIMULATOR_ID${NC}"
                flutter run -d "$SIMULATOR_ID"
            else
                echo -e "${RED}No iOS simulator found. Run 'xcrun simctl list devices' to see available devices.${NC}"
                exit 1
            fi
            ;;
        chrome|web)
            flutter run -d chrome
            ;;
        *)
            # Try to use the platform as a device ID
            flutter run -d "$PLATFORM"
            ;;
    esac
fi

echo -e "${GREEN}✅ Done!${NC}"
