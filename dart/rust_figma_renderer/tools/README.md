# Figma WASM Interception Tools

Tools for capturing and analyzing Figma's WASM-JavaScript bridge traffic.

## Why Intercept?

By capturing live WASM traffic, we can:
1. **Validate signatures** - Confirm our inferred parameter types
2. **Capture real data** - Get actual Kiwi-encoded paint/effect/vector samples
3. **Understand sequences** - See exact order of calls for rendering
4. **Debug rendering** - Compare our output with Figma's actual calls

## Quick Start

### Step 1: Set Up Chrome DevTools Snippet

1. Open Figma in Chrome (https://www.figma.com)
2. Open DevTools (F12 or Cmd+Option+I)
3. Go to **Sources** → **Snippets** (in left sidebar)
4. Click **+ New snippet**
5. Paste contents of `figma_wasm_interceptor.js`
6. Right-click snippet → **Run**

### Step 2: Capture Data

1. **Refresh the page** (interceptor must load before WASM)
2. Open a Figma file
3. Interact with the design (click, select, pan, zoom)
4. In Console, run:
   ```js
   FigmaInterceptor.export()  // Download all captured data
   ```

### Step 3: Analyze Captures

```bash
python analyze_capture.py figma_wasm_capture.json
```

## Interceptor Commands

```js
// View statistics
FigmaInterceptor.getStats()

// View recent calls (last 100)
FigmaInterceptor.getTimeline()

// Export all data
FigmaInterceptor.export()
FigmaInterceptor.export('my_capture.json')

// Export specific categories
FigmaInterceptor.exportKiwiCalls()    // Kiwi decode calls only
FigmaInterceptor.exportCanvasCalls()  // Canvas drawing calls only

// Clear captured data
FigmaInterceptor.clear()

// Pause/resume console logging
FigmaInterceptor.pauseLog()
FigmaInterceptor.resumeLog()

// Configure what to capture
FigmaInterceptor.setConfig({
  capturePrefixes: ['CanvasContext_'],  // Only capture these
  maxCallsPerFunction: 50,               // Limit per function
  logToConsole: false,                   // Quiet mode
  captureMemory: true,                   // Read memory at pointers
  memoryCaptureSize: 128,                // Bytes to read
})
```

## Capture Scenarios

### Scenario 1: File Loading
Captures the sequence of calls when opening a .fig file:
- Schema loading
- Node tree construction
- Initial render

```js
FigmaInterceptor.clear()
// Open a Figma file
// Wait for it to fully load
FigmaInterceptor.export('file_load_capture.json')
```

### Scenario 2: Selection & Inspection
Captures calls when selecting and viewing node properties:

```js
FigmaInterceptor.clear()
// Click on various nodes (rectangles, text, frames)
// Watch for NodeTsApi_* calls
FigmaInterceptor.export('selection_capture.json')
```

### Scenario 3: Rendering Pipeline
Captures drawing operations:

```js
FigmaInterceptor.setConfig({
  capturePrefixes: ['CanvasContext_Internal_', 'Fill', 'Blend', 'Blur'],
  logToConsole: true,
})
FigmaInterceptor.clear()
// Pan/zoom to trigger redraws
FigmaInterceptor.exportCanvasCalls()
```

### Scenario 4: Kiwi Data Extraction
Captures encoded paint/effect data:

```js
FigmaInterceptor.setConfig({
  capturePrefixes: ['JsKiwiSerialization_', 'ViewerJsKiwiSerialization_'],
  captureMemory: true,
  memoryCaptureSize: 256,  // Capture more bytes
})
FigmaInterceptor.clear()
// Select nodes with various fills, gradients, effects
FigmaInterceptor.exportKiwiCalls()
```

## Analysis Script

```bash
# Full analysis
python analyze_capture.py capture.json

# Extract raw Kiwi samples for testing
python analyze_capture.py capture.json --extract-kiwi
```

This creates a `kiwi_samples/` directory with binary files you can use for testing your Kiwi decoder.

## Captured Data Format

```json
{
  "startTime": 1703954400000,
  "timeline": [
    {
      "timestamp": 100,
      "name": "CanvasContext_Internal_fillRect",
      "direction": "export",
      "args": [
        {"value": 12345},
        {"value": 67890, "memory": [0,0,128,63,...], "interpreted": {...}}
      ],
      "result": null
    }
  ],
  "imports": {
    "JsKiwiSerialization_decodeFillPaintData": [...]
  },
  "exports": {
    "CanvasContext_Internal_fillRect": [...]
  }
}
```

## Tips

1. **Reduce noise**: Set specific `capturePrefixes` to avoid capturing everything
2. **Memory limits**: Captured data can get large fast; use `maxCallsPerFunction`
3. **Refresh required**: The interceptor must run before WASM loads
4. **Console logging**: Disable with `pauseLog()` for cleaner capture

## High-Value Captures

For building the Rust renderer, focus on capturing:

| Category | Functions | Purpose |
|----------|-----------|---------|
| Kiwi Decode | `JsKiwiSerialization_*` | Validate Kiwi parser |
| Canvas Drawing | `CanvasContext_Internal_*` | Understand render primitives |
| Node Properties | `NodeTsApi_get*` | Property access patterns |
| Fill/Stroke | `FillBindings_*` | Paint data structure |
| Blend/Effects | `BlendBindings_*`, `BlurBindings_*` | Effect rendering |
