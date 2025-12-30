# Figma WASM Function Signatures - Complete Reference

## Overview

This document contains **complete function signatures** extracted from Figma's compiled WASM module (`compiled_wasm.wasm`), with inferred parameter meanings based on function names and signature patterns.

**Module Stats:**
| Metric | Value |
|--------|-------|
| Types | 406 |
| Imports (JS→WASM) | 1,605 |
| Internal Functions | 39,305 |
| Exports (WASM→JS) | 3,920 |
| Compressed Size | 8.3 MB (Brotli) |
| Uncompressed Size | 42.2 MB |

---

## Table of Contents

1. [Canvas Drawing Primitives](#canvas-drawing-primitives)
2. [Fill/Stroke Bindings](#fillstroke-bindings)
3. [Blend/Effect Bindings](#blendeffect-bindings)
4. [Shadow Bindings](#shadow-bindings)
5. [Animation Bindings](#animation-bindings)
6. [Node Property API](#node-property-api)
7. [Text Rendering](#text-rendering)
8. [Vector/Path Operations](#vectorpath-operations)
9. [Kiwi Serialization](#kiwi-serialization)
10. [Auto-Layout Grid](#auto-layout-grid)
11. [Graphics Context (WebGL/WebGPU)](#graphics-context)
12. [Data Types](#data-types)
13. [Enumerations](#enumerations)
14. [Flutter Canvas Mapping](#flutter-canvas-mapping)

---

## Canvas Drawing Primitives

These are the core drawing operations. First `i32` param is typically `this` (CanvasContext pointer).

### Rectangle Operations

```c
// Fill a solid rectangle
CanvasContext_Internal_fillRect(ctx: i32, rect_ptr: i32, color_ptr: i32)
// rect_ptr → Rect {x, y, width, height}
// color_ptr → Color {r, g, b, a}

// Stroke a rectangle outline
CanvasContext_Internal_strokeRect(ctx: i32, rect_ptr: i32, color_ptr: i32, stroke_width: f32)

// Fill rounded rectangle (all corners)
CanvasContext_Internal_fillRoundedRect(ctx: i32, rect_ptr: i32, radius_ptr: i32, color_ptr: i32)
// radius_ptr → CornerRadii [topLeft, topRight, bottomRight, bottomLeft]

// Stroke rounded rectangle
CanvasContext_Internal_strokeRoundedRect(ctx: i32, rect_ptr: i32, radius: f64, color_ptr: i32, stroke_width: f64, flags: i32)

// Stroke rounded rect with dashed line
CanvasContext_Internal_strokeRoundedRectWithDash(
    ctx: i32,
    rect_ptr: i32,
    radius: f32,
    color_ptr: i32,
    stroke_width: f32,
    dash_length: f32,
    gap_length: f32,
    flags: i32
)

// Combined fill and stroke
CanvasContext_Internal_renderFillAndStrokeRoundedRect(
    ctx: i32,
    rect_ptr: i32,
    fill_opacity: f32,
    stroke_opacity: f32,
    fill_color_ptr: i32,
    stroke_color_ptr: i32,
    stroke_width: f32,
    flags: i32
)
```

### Circle Operations

```c
// Fill a solid circle
CanvasContext_Internal_fillCircle(ctx: i32, center_ptr: i32, radius: f32, color_ptr: i32)
// center_ptr → Point {x, y}

// Stroke a circle outline
CanvasContext_Internal_strokeCircle(ctx: i32, center_ptr: i32, radius: f32, color_ptr: i32, stroke_width: f32)

// Combined fill and stroke circle
CanvasContext_Internal_fillAndStrokeCircle(
    ctx: i32,
    center_ptr: i32,
    radius: f32,
    fill_color_ptr: i32,
    stroke_color_ptr: i32,
    stroke_width: f32,
    flags: i32
)
```

### Text Operations

```c
// Basic text fill
CanvasContext_Internal_fillText(
    ctx: i32,
    text_ptr: i32,      // UTF-8 string pointer
    text_len: i32,      // String length
    x: i32,             // Position (fixed-point)
    y: i32,
    color_ptr: i32,
    font_size: f32
)

// Text with font weight
CanvasContext_Internal_fillTextWithFontWeight(
    ctx: i32,
    text_ptr: i32,
    text_len: i32,
    x: i32,
    y: i32,
    color_ptr: i32,
    font_weight: i32,   // 100-900
    font_size: f32
)

// Text with background box
CanvasContext_Internal_fillTextWithBox(
    ctx: i32,
    text_ptr: i32,
    text_len: i32,
    x: i32,
    y: i32,
    color_ptr: i32,
    font_weight: i32,
    font_size: f32,
    box_color_ptr: i32,
    box_padding: i32,
    corner_radius: i32,
    opacity: f64
)

// Text with box and offset
CanvasContext_Internal_fillTextWithBoxAndTextOffset(
    ctx: i32,
    text_ptr: i32,
    text_len: i32,
    x: i32,
    y: i32,
    text_offset_x: i32,
    text_offset_y: i32,
    color_ptr: i32,
    font_size: f32,
    box_color_ptr: i32,
    box_padding: i32,
    corner_radius: i32,
    opacity: f64
)

// Measure text dimensions
CanvasContext_Internal_measureText(ctx: i32, text_ptr: i32, text_len: i32) -> i32
// Returns pointer to Size {width, height}

// Truncate text to fit width
CanvasContext_Internal_truncateName(ctx: i32, text_ptr: i32, text_len: i32, max_width: f32) -> i32
// Returns truncated string length
```

### Line Operations

```c
// Render dashed lines through points
CanvasContext_Internal_renderDashedLines(
    ctx: i32,
    points_ptr: i32,    // Array of Point {x, y}
    dash_length: f64,
    gap_length: f64,
    color_ptr: i32,
    stroke_width: f64
)
```

### Icon/Indicator Operations

```c
CanvasContext_Internal_renderContentFillIcon(ctx: i32, position_ptr: i32)
CanvasContext_Internal_renderTemplateFillIcon(ctx: i32, position_ptr: i32, size: i32)
CanvasContext_Internal_renderTemplateInfoIcon(ctx: i32, position_ptr: i32, size: i32)
CanvasContext_Internal_renderWrappingIndicator(ctx: i32, rect_ptr: i32)
```

---

## Fill/Stroke Bindings

Accessors for paint data during render operations.

### FillBindings

```c
FillBindings_geometry(fill_ptr: i32) -> i32      // Returns geometry/path pointer
FillBindings_paintSize(fill_ptr: i32) -> i32    // Returns size for gradient/image
FillBindings_transform(fill_ptr: i32) -> i32    // Returns transform matrix pointer
```

### FillStrokeBindings

```c
FillStrokeBindings_fillGeometries(node_ptr: i32) -> i32    // Array of fill paths
FillStrokeBindings_strokeGeometries(node_ptr: i32) -> i32  // Array of stroke paths
FillStrokeBindings_mode(node_ptr: i32) -> i32              // FillStrokeMode enum
FillStrokeBindings_paintSize(node_ptr: i32) -> i32         // Paint dimensions
FillStrokeBindings_transform(node_ptr: i32) -> i32         // Transform matrix
```

### PaintedGeometryBindings

```c
PaintedGeometryBindings_paints(ptr: i32) -> i32            // Array of paints
PaintedGeometryBindings_uniquePath(ptr: i32) -> i32        // Unique path identifier
PaintedGeometryBindings_windingRuleIsOdd(ptr: i32) -> i32  // Winding rule (odd/even)
```

---

## Blend/Effect Bindings

### BlendBindings

```c
BlendBindings_child(blend_ptr: i32) -> i32       // Child render operation
BlendBindings_mode(blend_ptr: i32) -> i32        // BlendMode enum value
BlendBindings_opacity(blend_ptr: i32) -> f32     // Opacity 0.0-1.0
```

### BlurBindings

```c
BlurBindings_child(blur_ptr: i32) -> i32                      // Child operation
BlurBindings_blurOpType(blur_ptr: i32) -> i32                 // 0=layer, 1=background
BlurBindings_startRadius(blur_ptr: i32) -> f32                // Start blur radius
BlurBindings_endRadius(blur_ptr: i32) -> f32                  // End blur radius
BlurBindings_startPoint(blur_ptr: i32) -> i32                 // Point pointer (gradient blur)
BlurBindings_endPoint(blur_ptr: i32) -> i32                   // Point pointer
BlurBindings_clamp(blur_ptr: i32) -> i32                      // Boolean clamp
BlurBindings_hasInvertedStartAndEndPoints(blur_ptr: i32) -> i32
```

### MaskBindings

```c
MaskBindings_type(mask_ptr: i32) -> i32                       // Mask type enum
MaskBindings_color(mask_ptr: i32) -> i32                      // Mask color pointer
MaskBindings_alpha(mask_ptr: i32) -> i32                      // Alpha channel pointer
MaskBindings_innerShadowFill(mask_ptr: i32) -> i32            // Inner shadow fill
MaskBindings_innerShadowAlphaRequiresHardMask(ptr: i32) -> i32
```

---

## Animation Bindings

```c
// Set relative transform with animation
AnimationBindings_setRelativeTransform(
    node_ptr: i32,
    transform_ptr: i32,
    duration: i32,      // milliseconds
    easing: i32         // EasingType enum
) -> i32                // Returns animation ID

// Set opacity with animation
AnimationBindings_setOpacity(
    node_ptr: i32,
    opacity: f32,
    duration: i32,
    easing: i32
) -> i32

// Animation control
AnimationBindings_cancelAnimation(anim_id: i32)
AnimationBindings_cancelAllAnimationsForNode(node_ptr: i32)
AnimationBindings_isActive(anim_id: i32) -> i32
AnimationBindings_isAnimating(node_ptr: i32) -> i32
```

### Slide Animations

```c
SlideAnimationBindings_Internal_getSlideTransition(ctx: i32, slide_id: i32) -> i32
SlideAnimationBindings_Internal_setSlideTransition(ctx: i32, slide_id: i32, transition: i32)
SlideAnimationBindings_Internal_setSlideTransitionForAll(ctx: i32, transition: i32)
SlidesObjectAnimationBindings_getInvalidAnimationTargets(ctx: i32, anim_id: i32) -> i32
```

---

## Node Property API

### Type & Identity

```c
BaseNodeTsApiGenerated_getType(node: i32) -> i32     // NodeType enum
NodeTsApi_exists(node: i32) -> i32                   // Boolean
NodeTsApi_getName(node: i32) -> i32                  // String pointer
NodeTsApi_getParent(node: i32) -> i32                // Parent node pointer
NodeTsApi_getParentIndex(node: i32) -> i32           // Index in parent's children
NodeTsApi_getChildren(node: i32) -> i32              // Array of child nodes
NodeTsApi_getVisibleChildren(node: i32) -> i32       // Visible children only
NodeTsApi_getVisibleDescendants(node: i32, depth: i32) -> i32
```

### Geometry & Bounds

```c
NodeTsApi_getAbsoluteBoundingBox(node: i32) -> i32        // Rect in canvas coords
NodeTsApi_getAbsoluteRenderBounds(node: i32) -> i32       // Render bounds with effects
NodeTsApi_getRelativeTransform(node: i32, parent: i32) -> i32  // Transform matrix
NodeTsApi_getFillGeometry(node: i32) -> i32               // Fill path data
NodeTsApi_getFillGeometryRegions(node: i32) -> i32        // Fill regions
NodeTsApi_getStrokeGeometry(node: i32) -> i32             // Stroke path data
NodeTsApi_getStrokeGeometryRegions(node: i32) -> i32      // Stroke regions
```

### Visual Properties

```c
NodeTsApi_getLocalOpacity(node: i32) -> f32               // Opacity 0.0-1.0
NodeTsApi_getCornerRadiusOrMixed(node: i32) -> i32        // Single or mixed radii
NodeTsApi_getCornerRadiusValues(node: i32) -> i32         // [TL, TR, BR, BL]
```

### Stroke Properties

```c
NodeTsApi_getStrokeCap(node: i32) -> i32            // StrokeCap enum
NodeTsApi_getStrokeCapOrMixed(node: i32) -> i32
NodeTsApi_getStrokeJoin(node: i32) -> i32           // StrokeJoin enum
NodeTsApi_getStrokeJoinOrMixed(node: i32) -> i32
NodeTsApi_getDashPattern(node: i32) -> i32          // Array of f32
```

### Transform Modifiers

```c
NodeTsApi_getTransformModifiers(node: i32) -> i32   // Encoded transform data
```

---

## Text Rendering

### Node Text Properties

```c
NodeTsApi_getTextContent(node: i32) -> i32          // String pointer
NodeTsApi_getTextData(node: i32) -> i32             // Kiwi-encoded text data
NodeTsApi_getTextCase(node: i32) -> i32             // TextCase enum
NodeTsApi_getTextGeometryRegions(node: i32) -> i32  // Text layout regions
NodeTsApi_getTextPathStartData(node: i32) -> i32    // Text on path data
NodeTsApi_getFontName(node: i32) -> i32             // Font family name
```

### Text Facet API

```c
TextFacetTsApiGenerated_getTextAlignHorizontal(node: i32) -> i32  // LEFT/CENTER/RIGHT/JUSTIFIED
TextFacetTsApiGenerated_getTextAlignVertical(node: i32) -> i32    // TOP/CENTER/BOTTOM
TextFacetTsApiGenerated_getTextAutoResize(node: i32) -> i32       // NONE/HEIGHT/WIDTH_AND_HEIGHT
TextFacetTsApiGenerated_getTextDecoration(node: i32) -> i32       // NONE/UNDERLINE/STRIKETHROUGH
TextFacetTsApiGenerated_getTextDecorationSkipInk(node: i32) -> i32
TextFacetTsApiGenerated_getTextDecorationStyle(node: i32) -> i32  // SOLID/DASHED/DOTTED
TextFacetTsApiGenerated_getTextTruncation(node: i32) -> i32       // DISABLED/ENDING
```

---

## Vector/Path Operations

### Vector Data

```c
NodeTsApi_getVectorData(node: i32) -> i32           // Kiwi-encoded vector paths
NodeTsApi_setVectorData(node: i32, data: i32) -> i32
NodeTsApi_isComplexVectorNetwork(node: i32) -> i32  // Has complex topology
```

### Vector Facet

```c
VectorFacetTsApiGenerated_getArcData(node: i32) -> i32
VectorFacetTsApiGenerated_getIsVectorLike(node: i32) -> i32
VectorFacetTsApiGenerated_setArcData(node: i32, data: i32) -> i32
```

### Path Tools

```c
// Offset Path Tool
OffsetPathTsApi_apply()
OffsetPathTsApi_cancel()
OffsetPathTsApi_setJoinType(join_type: i32)
OffsetPathTsApi_setOffset(offset: f64)

// Simplify Vector Tool
SimplifyVectorToolTsApi_apply()
SimplifyVectorToolTsApi_cancel()
SimplifyVectorToolTsApi_setThreshold(threshold: f64)
SimplifyVectorToolTsApi_state() -> i32
```

---

## Kiwi Serialization

### Editor Functions (Imports: JS→WASM)

```c
JsKiwiSerialization_decodeFillPaintData(ptr: i32) -> i32
JsKiwiSerialization_decodeEffectData(ptr: i32) -> i32
JsKiwiSerialization_decodeVectorData(ptr: i32) -> i32
JsKiwiSerialization_decodeTextData(ptr: i32) -> i32
JsKiwiSerialization_decodePrototypeInteractions(ptr: i32) -> i32
JsKiwiSerialization_decodeTransformModifierData(ptr: i32) -> i32
```

### Viewer Functions (Imports: JS→WASM)

```c
ViewerJsKiwiSerialization_decodeFillPaintData(ptr: i32) -> i32
ViewerJsKiwiSerialization_decodeSingleSolidFillWithNormalBlendMode(ptr: i32, opacity: f32, visible: i32) -> i32
ViewerJsKiwiSerialization_decodeEffectData(ptr: i32) -> i32
ViewerJsKiwiSerialization_decodeTextData(ptr: i32) -> i32
ViewerJsKiwiSerialization_decodeVectorData(ptr: i32) -> i32
ViewerJsKiwiSerialization_decodeTransformModifierData(ptr: i32) -> i32
ViewerJsKiwiSerialization_decodeCodeSnapshot(ptr: i32) -> i32
ViewerJsKiwiSerialization_decodeDerivedTextData(ptr: i32, font_data: i32, options: i32) -> i32
ViewerJsKiwiSerialization_decodePrototypeInteractions(ptr: i32) -> i32
```

---

## Auto-Layout Grid

### Grid Properties

```c
CanvasGrid_Internal_gridRowSpacing(grid: i32) -> f64      // Space between rows
CanvasGrid_Internal_gridChildSpacing(grid: i32) -> f64    // Space between children
CanvasGrid_Internal_gridPadding(grid: i32) -> f64         // Grid padding
CanvasGrid_Internal_gridWidth(grid: i32, available: f64) -> f64
CanvasGrid_Internal_gridHeight(grid: i32, available: f64) -> f64
CanvasGrid_Internal_rowMaxSize(grid: i32) -> i32          // Max items per row
CanvasGrid_Internal_stateGroupRowPadding(grid: i32) -> f64
```

### Grid Coordinates

```c
CanvasGrid_Internal_coordForChild(grid: i32, child_index: i32) -> i32   // Returns coord ptr
CanvasGrid_Internal_getClosestGridCoord(grid: i32, x: i32, y: i32) -> i32
CanvasGrid_Internal_getLastChildCoord(grid: i32) -> i32
CanvasGrid_Internal_rectForCoord(grid: i32, row: i32, col: i32, size: i32) -> i32
```

### Grid Operations

```c
CanvasGrid_Internal_gridGUID(grid: i32) -> i32
CanvasGrid_Internal_getRowGUID(grid: i32, row_index: i32) -> i32
CanvasGrid_Internal_createRow(grid: i32, at_index: i32) -> i32
CanvasGrid_Internal_moveRow(grid: i32, from: i32, to: i32)
CanvasGrid_Internal_insertChildAtCoord(grid: i32, child: i32, row: i32, col: i32, animate: i32)
CanvasGrid_Internal_moveChildrenToCoord(grid: i32, children: i32, coord: i32)
CanvasGrid_Internal_replaceChildInGrid(grid: i32, old_child: i32, new_child: i32)
CanvasGrid_Internal_recomputeGrid(grid: i32)
```

### Grid Selection

```c
CanvasGrid_Internal_isRowSelected(grid: i32, row_index: i32) -> i32
CanvasGrid_Internal_selectRow(grid: i32, row_index: i32)
CanvasGrid_Internal_selectChildrenInRow(grid: i32, row_index: i32)
CanvasGrid_Internal_addOrRemoveRowFromSelection(grid: i32, row_index: i32)
CanvasGrid_Internal_addOrRemoveRowChildrenFromSelection(grid: i32, row_index: i32)
CanvasGrid_Internal_rowContentBoundsInCanvas(grid: i32, row: i32, padding: i32) -> i32
```

### Stack/Auto-Layout Facet

```c
StackFacetTsApiGenerated_getStackChildPrimaryGrow(node: i32) -> f32
StackFacetTsApiGenerated_setStackChildPrimaryGrow(value: f32, node: i32) -> i32
StackFacetTsApiGenerated_getStackPaddingBottom(node: i32) -> f32
StackFacetTsApiGenerated_setStackPaddingBottom(value: f32, node: i32) -> i32
StackFacetTsApiGenerated_getStackPaddingLeft(node: i32) -> f32
StackFacetTsApiGenerated_setStackPaddingLeft(value: f32, node: i32) -> i32
StackFacetTsApiGenerated_getStackPaddingRight(node: i32) -> f32
StackFacetTsApiGenerated_setStackPaddingRight(value: f32, node: i32) -> i32
StackFacetTsApiGenerated_getStackPaddingTop(node: i32) -> f32
StackFacetTsApiGenerated_setStackPaddingTop(value: f32, node: i32) -> i32
```

---

## Graphics Context

### WebGL Context (TsGlContext)

```c
TsGlContext_init(canvas: i32)
TsGlContext_release(ctx: i32)
TsGlContext_isContextLost(ctx: i32) -> i32
TsGlContext_installContextLostHandler(ctx: i32, callback: i32)
TsGlContext_drawingBufferWidth(ctx: i32) -> i32
TsGlContext_drawingBufferHeight(ctx: i32) -> i32
TsGlContext_unmaskedVendorName(ctx: i32) -> i32     // String ptr
TsGlContext_unmaskedRendererName(ctx: i32) -> i32   // String ptr
TsGlContext_texImage2D(ctx: i32, target: i32, level: i32, internalformat: i32,
                       width: i32, height: i32, border: i32, format: i32, type: i32, data: i32)
TsGlContext_texImage2DFloat32(ctx: i32, target: i32, level: i32, internalformat: i32,
                              width: i32, height: i32, border: i32, format: i32, type: i32, data: i32)
```

### WebGPU Context

```c
WebGPUTsContext_writeBuffer(ctx: i32, buffer: i32, offset: i32, data: i32, size: i32, flags: i32)
WebGPUTsContext_writeTexture(ctx: i32, texture: i32, data: i32, layout: i32)
WebGPUTsContext_copyExternalImageToTexture(ctx: i32, src: i32, dst: i32)
WebGPUTsContext_readPixels(ctx: i32, x: i32, y: i32, w: i32, h: i32, buffer: i32, options: i32) -> i32
WebGPUTsContext_readPixelsAsync(ctx: i32, x: i32, y: i32, w: i32, h: i32, callback: i32) -> i32
WebGPUTsContext_setRecreateDeviceOnNextDestroy(flag: i32)
WebGPUTsContext_isDeviceInitialized() -> i32
WebGPUTsContext_wasDeviceInitializedAtLeastOnce() -> i32
WebGPUTsContext_needToConfigure(ctx: i32) -> i32
WebGPUTsContext_configure(ctx: i32, config: i32)
```

### Bitmap Context

```c
BitmapContext_new(width: i32)
BitmapContext_setSize(ctx: i32, width: i32, height: i32, scale: f32)
BitmapContext_beginPath(ctx: i32)
BitmapContext_stroke(ctx: i32, color: i32, width: f32)
BitmapContext_fill(ctx: i32, color: i32)
BitmapContext_fillGradient(ctx: i32, gradient: i32, type: i32, x0: f32, y0: f32, x1: f32, y1: f32)
BitmapContext_clear(ctx: i32)
BitmapContext_upload(ctx: i32, x: i32, y: i32, w: i32, h: i32, data: i32)
BitmapContext_download(ctx: i32, x: i32, y: i32, w: i32, h: i32, buffer: i32)
BitmapContext_fillText(ctx: i32, x: f32, y: f32, text: i32, font: i32, color: i32, size: f32, align: i32)
```

---

## Data Types

### Rect (16 bytes)

```c
struct Rect {
    float x;       // offset 0
    float y;       // offset 4
    float width;   // offset 8
    float height;  // offset 12
};
```

### Point / Vector2 (8 bytes)

```c
struct Point {
    float x;  // offset 0
    float y;  // offset 4
};
```

### Color (16 bytes)

```c
struct Color {
    float r;  // 0.0-1.0
    float g;
    float b;
    float a;
};
```

### Transform Matrix (24 bytes)

2x3 affine transformation matrix in column-major order:

```c
struct Matrix {
    float m00;  // scale x (cos for rotation)
    float m01;  // skew y (sin for rotation)
    float m10;  // skew x (-sin for rotation)
    float m11;  // scale y (cos for rotation)
    float m02;  // translate x
    float m12;  // translate y
};
```

Matrix transforms point (x, y) as:
```
x' = m00*x + m10*y + m02
y' = m01*x + m11*y + m12
```

### CornerRadii (16 bytes)

```c
struct CornerRadii {
    float topLeft;
    float topRight;
    float bottomRight;
    float bottomLeft;
};
```

### Size (8 bytes)

```c
struct Size {
    float width;
    float height;
};
```

---

## Enumerations

### NodeType

```
0  = DOCUMENT
1  = CANVAS
2  = FRAME
3  = GROUP
4  = VECTOR
5  = BOOLEAN_OPERATION
6  = STAR
7  = LINE
8  = ELLIPSE
9  = REGULAR_POLYGON
10 = RECTANGLE
11 = TEXT
12 = SLICE
13 = COMPONENT
14 = COMPONENT_SET
15 = INSTANCE
16 = STICKY
17 = SHAPE_WITH_TEXT
18 = CONNECTOR
19 = SECTION
20 = TABLE
21 = TABLE_CELL
22 = WASHI_TAPE
23 = HIGHLIGHT
24 = CODE_BLOCK
25 = WIDGET
26 = EMBED
27 = LINK_UNFURL
28 = MEDIA
```

### BlendMode

```
0  = PASS_THROUGH
1  = NORMAL
2  = DARKEN
3  = MULTIPLY
4  = LINEAR_BURN
5  = COLOR_BURN
6  = LIGHTEN
7  = SCREEN
8  = LINEAR_DODGE
9  = COLOR_DODGE
10 = OVERLAY
11 = SOFT_LIGHT
12 = HARD_LIGHT
13 = DIFFERENCE
14 = EXCLUSION
15 = HUE
16 = SATURATION
17 = COLOR
18 = LUMINOSITY
```

### PaintType

```
0 = SOLID
1 = GRADIENT_LINEAR
2 = GRADIENT_RADIAL
3 = GRADIENT_ANGULAR
4 = GRADIENT_DIAMOND
5 = IMAGE
6 = VIDEO
7 = EMOJI
```

### EffectType

```
0 = DROP_SHADOW
1 = INNER_SHADOW
2 = LAYER_BLUR
3 = BACKGROUND_BLUR
```

### StrokeCap

```
0 = NONE
1 = ROUND
2 = SQUARE
3 = ARROW_LINES
4 = ARROW_EQUILATERAL
5 = TRIANGLE_FILLED
6 = CIRCLE_FILLED
7 = DIAMOND_FILLED
8 = SQUARE_FILLED
```

### StrokeJoin

```
0 = MITER
1 = BEVEL
2 = ROUND
```

### LayoutMode (StackMode)

```
0 = NONE
1 = HORIZONTAL
2 = VERTICAL
```

### SizingMode

```
0 = FIXED
1 = HUG
2 = FILL
```

### TextAlignHorizontal

```
0 = LEFT
1 = CENTER
2 = RIGHT
3 = JUSTIFIED
```

### TextAlignVertical

```
0 = TOP
1 = CENTER
2 = BOTTOM
```

### TextAutoResize

```
0 = NONE
1 = HEIGHT
2 = WIDTH_AND_HEIGHT
3 = TRUNCATE
```

### TextDecoration

```
0 = NONE
1 = UNDERLINE
2 = STRIKETHROUGH
```

### TextCase

```
0 = ORIGINAL
1 = UPPER
2 = LOWER
3 = TITLE
4 = SMALL_CAPS
5 = SMALL_CAPS_FORCED
```

### EasingType (Animation)

```
0 = LINEAR
1 = EASE_IN
2 = EASE_OUT
3 = EASE_IN_OUT
4 = EASE_IN_BACK
5 = EASE_OUT_BACK
6 = EASE_IN_OUT_BACK
7 = CUSTOM_CUBIC_BEZIER
8 = GENTLE
9 = QUICK
10 = BOUNCY
11 = SLOW
12 = CUSTOM_SPRING
```

---

## Flutter Canvas Mapping

| Figma WASM Function | Flutter Canvas API |
|---------------------|-------------------|
| `fillRect` | `canvas.drawRect(rect, paint)` |
| `strokeRect` | `canvas.drawRect(rect, paint..style=PaintingStyle.stroke)` |
| `fillRoundedRect` | `canvas.drawRRect(rrect, paint)` |
| `strokeRoundedRect` | `canvas.drawRRect(rrect, paint..style=stroke)` |
| `fillCircle` | `canvas.drawCircle(center, radius, paint)` |
| `strokeCircle` | `canvas.drawCircle(center, radius, paint..style=stroke)` |
| `fillText` | `TextPainter.paint(canvas, offset)` |
| `measureText` | `TextPainter.width / .height` |
| `renderDashedLines` | `canvas.drawPath(dashedPath, paint)` |
| `BlendBindings_mode` | `paint.blendMode = BlendMode.xxx` |
| `BlendBindings_opacity` | `paint.color = color.withOpacity(x)` |
| `BlurBindings_*` | `ImageFilter.blur(sigmaX, sigmaY)` |

---

## Usage in Rust Implementation

```rust
use flutter_rust_bridge::frb;

/// Draw a filled rounded rectangle
#[frb(sync)]
pub fn fill_rounded_rect(
    ctx: &mut CanvasContext,
    rect: Rect,
    radii: CornerRadii,
    color: Color,
) {
    // Maps to Flutter's:
    // canvas.drawRRect(
    //     RRect.fromRectAndCorners(
    //         Rect.fromLTWH(rect.x, rect.y, rect.width, rect.height),
    //         topLeft: Radius.circular(radii.top_left),
    //         topRight: Radius.circular(radii.top_right),
    //         bottomRight: Radius.circular(radii.bottom_right),
    //         bottomLeft: Radius.circular(radii.bottom_left),
    //     ),
    //     Paint()..color = Color.fromRGBO(
    //         (color.r * 255).round(),
    //         (color.g * 255).round(),
    //         (color.b * 255).round(),
    //         color.a,
    //     ),
    // )
}

/// Decode Kiwi-encoded fill paint data
#[frb(sync)]
pub fn decode_fill_paint(data: &[u8]) -> Result<Vec<PaintInfo>, String> {
    // Matches ViewerJsKiwiSerialization_decodeFillPaintData behavior
    kiwi::decode_fill_paint_data(data)
        .map_err(|e| e.to_string())
}
```

---

## Import/Export Statistics by Category

### Top Import Categories (JS → WASM)

| Category | Count |
|----------|-------|
| init_bindings_* | 419 |
| FigmaApp_* | 265 |
| JsValue_* | 59 |
| AccessibilityBindings_* | 56 |
| WebReporting_* | 38 |
| SitesJsBindings_* | 34 |
| invoke_* | 31 |
| HTMLWindowBindings_* | 24 |
| TsGlContext_* | 21 |
| WidgetBindings_* | 21 |

### Top Export Categories (WASM → JS)

| Category | Count |
|----------|-------|
| NodeTsApi_* | 579 |
| Fullscreen_* | 435 |
| SceneNodeCpp_* | 170 |
| ObservableValue_* | 147 |
| WritableObservableValue_* | 144 |
| AppStateTsApi_* | 107 |
| EditorPreferences_* | 97 |
| InteractionCpp_* | 93 |
| DebuggingHelpers_* | 84 |
| VariablesBindings_* | 71 |

---

## References

- **Figma Plugin API**: https://www.figma.com/plugin-docs/
- **Kiwi Binary Format**: https://github.com/evanw/kiwi
- **flutter_rust_bridge**: https://cjycode.com/flutter_rust_bridge/
- **WebAssembly Binary Toolkit**: https://github.com/WebAssembly/wabt
