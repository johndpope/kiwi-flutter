# Figma WASM Interface Analysis

## Overview

This document describes the interface between Figma's WebAssembly module and JavaScript, extracted from `compiled_wasm.wasm` (version as of December 2024).

## Module Statistics

| Metric | Value |
|--------|-------|
| Compressed size | 8.3 MB (Brotli) |
| Uncompressed size | 42.2 MB |
| Total functions | 39,305 |
| Imports (JS→WASM) | 1,606 |
| Exports (WASM→JS) | 3,920 |
| Type signatures | 406 |

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         JavaScript                               │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  React UI (TypeScript)                                    │  │
│  │  • Panels, menus, property editors                        │  │
│  │  • Plugin sandbox (QuickJS in WASM)                       │  │
│  └───────────────────────────────────────────────────────────┘  │
│                              │                                   │
│                    1,606 Import Functions                        │
│                              ▼                                   │
├─────────────────────────────────────────────────────────────────┤
│                         WASM Module                              │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  C++ Core (Emscripten compiled)                           │  │
│  │  • Document model                                         │  │
│  │  • Canvas rendering (WebGL/WebGPU)                        │  │
│  │  • Layout engine                                          │  │
│  │  • Kiwi serialization                                     │  │
│  └───────────────────────────────────────────────────────────┘  │
│                              │                                   │
│                    3,920 Export Functions                        │
│                              ▼                                   │
├─────────────────────────────────────────────────────────────────┤
│                         JavaScript                               │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Canvas element, WebGL context, DOM events                │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Key Import Categories (JS→WASM)

These are functions that the WASM module calls into JavaScript.

### Kiwi Serialization

```javascript
// Decode Kiwi-encoded paint data
JsKiwiSerialization_decodeFillPaintData(ptr, len)
JsKiwiSerialization_decodeEffectData(ptr, len)
JsKiwiSerialization_decodeVectorData(ptr, len)
JsKiwiSerialization_decodeTextData(ptr, len)
JsKiwiSerialization_decodePrototypeInteractions(ptr, len)
JsKiwiSerialization_decodeTransformModifierData(ptr, len)
```

### Scene Graph Hooks

```javascript
// Called when nodes are created/destroyed
DeprecatedJsSceneHooks_createScene()
DeprecatedJsSceneHooks_Node_created(nodePtr)
DeprecatedJsSceneHooks_Node_destroyed(nodePtr)
DeprecatedJsSceneHooks_updateNodeAfterPropertyChange(nodePtr)
DeprecatedJsSceneHooks_linkNodeToParent(childPtr, parentPtr)
```

### Graphics Context

```javascript
// WebGL operations
TsGlContext_init(canvas)
TsGlContext_release()
TsGlContext_isContextLost()
TsGlContext_drawingBufferWidth()
TsGlContext_drawingBufferHeight()

// WebGPU operations
WebGPUTsContext_writeBuffer(buffer, data)
WebGPUTsContext_writeTexture(texture, data)
WebGPUTsContext_copyExternalImageToTexture(src, dst)
WebGPUTsContext_readPixels()
```

### Multiplayer Sync

```javascript
WebMultiplayer_reconnectingStarted()
WebMultiplayer_reconnectingSucceeded()
WebMultiplayer_notifyCursorHidden()
WebUserSyncing_handleConnect()
WebUserSyncing_addUser(userId)
WebUserSyncing_removeUser(userId)
WebUserSyncing_setMouseCursor(cursor)
WebUserSyncing_setMousePosition(x, y)
```

### UI Bindings

```javascript
HTMLWindowBindings_windowSetupComplete()
HTMLWindowBindings_windowHandleBeforeTick()
HTMLWindowBindings_setTitle(title)
View_setCursor(cursor)
View_setLayout(layout)
```

### Image/Video

```javascript
ImageIo_decodeImage(data)
ImageIo_encodeImage(data, format)
ImageIo_scaleImage(data, width, height)
VideoTsBindings_createVideo(url)
VideoTsBindings_getWidth(videoId)
VideoTsBindings_getHeight(videoId)
```

## Key Export Categories (WASM→JS)

These are functions that JavaScript can call into the WASM module.

### Document Loading

```javascript
// Entry point
main()
__wasm_call_ctors()

// Memory management
free(ptr)
malloc(size)
```

### Kiwi Serialization (Viewer)

```javascript
ViewerJsKiwiSerialization_decodeFillPaintData(ptr, len)
ViewerJsKiwiSerialization_decodeSingleSolidFillWithNormalBlendMode(ptr)
ViewerJsKiwiSerialization_decodeEffectData(ptr, len)
ViewerJsKiwiSerialization_decodeTextData(ptr, len)
ViewerJsKiwiSerialization_decodeVectorData(ptr, len)
ViewerJsKiwiSerialization_decodeTransformModifierData(ptr, len)
ViewerJsKiwiSerialization_decodeCodeSnapshot(ptr, len)
```

### App State API

```javascript
// Get/set application state
AppStateTsApi_getMemoryUsage()
AppStateTsApi_bigNudgeAmount()
AppStateTsApi_isUserTyping()
AppStateTsApi_topLevelMode()
AppStateTsApi_canvasViewState()
AppStateTsApi_flattenNodes(nodeIds)
AppStateTsApi_invalidateCanvas()
```

### Node API

```javascript
// Node type info
BaseNodeTsApiGenerated_getType(nodePtr)

// Node properties
NodeTsApi_getFillGeometry(nodePtr)
NodeTsApi_getStrokeGeometry(nodePtr)
NodeTsApi_getCodeFilePath(nodePtr)
```

### Canvas Context

```javascript
// Drawing primitives
CanvasContext_Internal_fillRect(x, y, w, h)
CanvasContext_Internal_strokeRect(x, y, w, h)
CanvasContext_Internal_fillCircle(x, y, r)
CanvasContext_Internal_strokeCircle(x, y, r)
CanvasContext_Internal_fillRoundedRect(x, y, w, h, r)
CanvasContext_Internal_fillText(text, x, y)
CanvasContext_Internal_measureText(text)
```

### Render Bindings

```javascript
// Fill/stroke operations
FillBindings_geometry(nodePtr)
FillBindings_paintSize(nodePtr)
FillBindings_transform(nodePtr)
FillStrokeBindings_fillGeometries(nodePtr)
FillStrokeBindings_strokeGeometries(nodePtr)
```

### Blend/Effect Bindings

```javascript
BlendBindings_child(ptr)
BlendBindings_mode(ptr)
BlendBindings_opacity(ptr)

BlurBindings_blurOpType(ptr)
BlurBindings_startRadius(ptr)
BlurBindings_endRadius(ptr)
```

### Layout API

```javascript
// Auto-layout calculations
CanvasGrid_Internal_gridRowSpacing(gridPtr)
CanvasGrid_Internal_gridChildSpacing(gridPtr)
CanvasGrid_Internal_gridPadding(gridPtr)
CanvasGrid_Internal_coordForChild(gridPtr, childIndex)
```

### Animation

```javascript
AnimationBindings_setRelativeTransform(nodePtr, transform)
AnimationBindings_setOpacity(nodePtr, opacity)
AnimationBindings_cancelAnimation(animId)
AnimationBindings_isActive(animId)
AnimationBindings_cancelAllAnimationsForNode(nodePtr)
```

## Type Signatures

The WASM module uses 406 unique function signatures. Common patterns:

```wasm
;; Void function with pointer arg
(func (param i32))

;; Return i32 from pointer
(func (param i32) (result i32))

;; Two pointers
(func (param i32 i32))

;; Return float from pointer
(func (param i32) (result f32))

;; Multiple args, no return
(func (param i32 i32 i32 i32))

;; Complex: 6 floats for transform
(func (param i32 f32 f32 f32 f32 f32 f32))
```

## Memory Layout

```
Address Range       Purpose
─────────────────────────────────────
0x00000000          Stack (grows down)
...
0x00100000          Heap start
...
0x04000000          Function table
...
0x05000000          Code section
...
0x06000000          Globals
```

## Binding Categories by Count

| Category | Import Count | Export Count |
|----------|-------------|--------------|
| FigmaApp | - | 265 |
| AppStateTsApi | - | 107 |
| JsValue | 59 | - |
| AccessibilityBindings | 56 | - |
| init_bindings_* | 419 | - |
| *TsApiGenerated | - | ~200 |
| Canvas* | - | ~100 |
| *Bindings | ~400 | ~300 |

## Interception Example

```javascript
// Intercept Kiwi decode calls
const originalInstantiate = WebAssembly.instantiateStreaming;
WebAssembly.instantiateStreaming = async (source, imports) => {
  // Wrap decode functions
  const originalDecodeFilll = imports.env.JsKiwiSerialization_decodeFillPaintData;
  imports.env.JsKiwiSerialization_decodeFillPaintData = (ptr, len) => {
    console.log('Decoding fill paint:', ptr, len);
    // Read memory at ptr for len bytes
    const memory = new Uint8Array(wasmMemory.buffer, ptr, len);
    console.log('Data:', memory);
    return originalDecodeFill(ptr, len);
  };

  return originalInstantiate(source, imports);
};
```

## Key Insights for Implementation

### 1. Serialization Functions Match Our API

Figma exports:
```
JsKiwiSerialization_decodeFillPaintData
JsKiwiSerialization_decodeEffectData
JsKiwiSerialization_decodeVectorData
```

Our Rust implements:
```rust
pub fn decode_fill_paint_data(data: &[u8]) -> Result<Vec<PaintInfo>>
pub fn decode_effect_data(data: &[u8]) -> Result<Vec<EffectInfo>>
pub fn decode_vector_data(data: &[u8]) -> Result<PathData>
```

### 2. Node Structure Matches

Figma's `NodeTsApi_*` exports reveal property names:
- `getFillGeometry` → our `fill_paints_data`
- `getStrokeGeometry` → our `stroke_paints_data`
- Type from `BaseNodeTsApiGenerated_getType`

### 3. Canvas Operations

Figma's `CanvasContext_Internal_*` exports show primitives:
- `fillRect`, `strokeRect`
- `fillCircle`, `strokeCircle`
- `fillRoundedRect`
- `fillText`, `measureText`

Flutter's Canvas API provides all these.

### 4. Layout System

`CanvasGrid_Internal_*` exports reveal auto-layout algorithm:
- `gridRowSpacing`, `gridChildSpacing`
- `gridPadding`, `coordForChild`

Matches our `layout.rs` implementation.

## Full Export List

See `figma_wasm_interface.txt` in the project root for the complete list of all 1,606 imports and 3,920 exports.
