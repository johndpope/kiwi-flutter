/**
 * Figma WASM Interceptor
 *
 * USAGE:
 * 1. Open Figma in Chrome
 * 2. Open DevTools (F12)
 * 3. Go to Sources > Snippets
 * 4. Create new snippet, paste this code
 * 5. Run BEFORE loading a Figma file (or refresh with snippet ready)
 * 6. Interact with Figma
 * 7. Run `FigmaInterceptor.export()` in console to download captured data
 *
 * IMPORTANT: Run this BEFORE the WASM module loads, or refresh the page after setting up.
 */

(function() {
  'use strict';

  // Configuration
  const CONFIG = {
    // Which function prefixes to capture (set to null to capture ALL - warning: huge!)
    capturePrefixes: [
      'CanvasContext_Internal_',
      'JsKiwiSerialization_',
      'ViewerJsKiwiSerialization_',
      'NodeTsApi_',
      'FillBindings_',
      'FillStrokeBindings_',
      'BlendBindings_',
      'BlurBindings_',
      'AnimationBindings_',
      'BaseNodeTsApiGenerated_',
    ],

    // Max calls to store per function (prevents memory explosion)
    maxCallsPerFunction: 100,

    // Log to console in real-time
    logToConsole: true,

    // Capture memory contents for pointer arguments
    captureMemory: true,

    // Memory capture size (bytes to read from each pointer)
    memoryCaptureSize: 64,

    // Throttle console logs (ms)
    logThrottleMs: 100,
  };

  // Storage for captured calls
  const capturedCalls = {
    imports: {},   // JS → WASM calls
    exports: {},   // WASM → JS calls
    timeline: [],  // Ordered sequence of all calls
    memory: {},    // Memory snapshots
    startTime: Date.now(),
  };

  let wasmMemory = null;
  let lastLogTime = 0;

  // Helper to read memory at pointer
  function readMemory(ptr, size = CONFIG.memoryCaptureSize) {
    if (!wasmMemory || !CONFIG.captureMemory || ptr === 0) return null;
    try {
      const buffer = new Uint8Array(wasmMemory.buffer, ptr, Math.min(size, wasmMemory.buffer.byteLength - ptr));
      return Array.from(buffer);
    } catch (e) {
      return null;
    }
  }

  // Helper to interpret memory as common types
  function interpretMemory(bytes) {
    if (!bytes || bytes.length < 4) return null;
    const buffer = new Uint8Array(bytes).buffer;
    const view = new DataView(buffer);
    return {
      asFloat32: bytes.length >= 4 ? view.getFloat32(0, true) : null,
      asInt32: bytes.length >= 4 ? view.getInt32(0, true) : null,
      asFloat32x4: bytes.length >= 16 ? [
        view.getFloat32(0, true),
        view.getFloat32(4, true),
        view.getFloat32(8, true),
        view.getFloat32(12, true),
      ] : null,
      asString: (() => {
        try {
          const nullIdx = bytes.indexOf(0);
          const strBytes = nullIdx >= 0 ? bytes.slice(0, nullIdx) : bytes;
          return new TextDecoder().decode(new Uint8Array(strBytes));
        } catch { return null; }
      })(),
    };
  }

  // Check if function should be captured
  function shouldCapture(name) {
    if (!CONFIG.capturePrefixes) return true;
    return CONFIG.capturePrefixes.some(prefix => name.startsWith(prefix));
  }

  // Wrap a function to intercept calls
  function wrapFunction(fn, name, direction) {
    return function(...args) {
      const timestamp = Date.now() - capturedCalls.startTime;

      // Capture memory for pointer-like arguments (i32 that could be pointers)
      const argsWithMemory = args.map((arg, i) => {
        if (typeof arg === 'number' && Number.isInteger(arg) && arg > 1000) {
          const mem = readMemory(arg);
          return {
            value: arg,
            memory: mem,
            interpreted: interpretMemory(mem),
          };
        }
        return { value: arg };
      });

      // Store the call
      const storage = direction === 'import' ? capturedCalls.imports : capturedCalls.exports;
      if (!storage[name]) {
        storage[name] = [];
      }

      const callData = {
        timestamp,
        args: argsWithMemory,
        direction,
      };

      // Call original function
      let result;
      let error;
      try {
        result = fn.apply(this, args);
        callData.result = result;

        // If result looks like a pointer, capture its memory too
        if (typeof result === 'number' && Number.isInteger(result) && result > 1000) {
          const mem = readMemory(result);
          callData.resultMemory = mem;
          callData.resultInterpreted = interpretMemory(mem);
        }
      } catch (e) {
        error = e;
        callData.error = e.message;
      }

      // Store if under limit
      if (storage[name].length < CONFIG.maxCallsPerFunction) {
        storage[name].push(callData);
      }

      // Add to timeline
      capturedCalls.timeline.push({
        name,
        ...callData,
      });

      // Log to console (throttled)
      if (CONFIG.logToConsole && Date.now() - lastLogTime > CONFIG.logThrottleMs) {
        lastLogTime = Date.now();
        const argsStr = args.map(a => typeof a === 'number' ? a : JSON.stringify(a)).join(', ');
        const resultStr = result !== undefined ? ` → ${result}` : '';
        console.log(`%c[${direction}] ${name}(${argsStr})${resultStr}`,
          direction === 'import' ? 'color: #4CAF50' : 'color: #2196F3');
      }

      if (error) throw error;
      return result;
    };
  }

  // Intercept WebAssembly.instantiate
  const originalInstantiate = WebAssembly.instantiate;
  WebAssembly.instantiate = async function(source, importObject) {
    console.log('%c[FigmaInterceptor] Intercepting WASM instantiation...', 'color: #FF9800; font-weight: bold');

    // Wrap import functions
    if (importObject) {
      for (const [moduleName, moduleImports] of Object.entries(importObject)) {
        for (const [funcName, func] of Object.entries(moduleImports)) {
          if (typeof func === 'function' && shouldCapture(funcName)) {
            importObject[moduleName][funcName] = wrapFunction(func, funcName, 'import');
          }
        }
      }
    }

    // Call original
    const result = await originalInstantiate.call(this, source, importObject);

    // Get memory reference
    if (result.instance.exports.memory) {
      wasmMemory = result.instance.exports.memory;
      console.log('%c[FigmaInterceptor] Got WASM memory reference', 'color: #FF9800');
    }

    // Wrap export functions
    const wrappedExports = {};
    for (const [name, exp] of Object.entries(result.instance.exports)) {
      if (typeof exp === 'function' && shouldCapture(name)) {
        wrappedExports[name] = wrapFunction(exp, name, 'export');
      } else {
        wrappedExports[name] = exp;
      }
    }

    // Replace exports with wrapped versions
    Object.defineProperty(result.instance, 'exports', {
      value: wrappedExports,
      writable: false,
    });

    console.log('%c[FigmaInterceptor] WASM interception active!', 'color: #4CAF50; font-weight: bold');
    console.log(`Capturing prefixes: ${CONFIG.capturePrefixes?.join(', ') || 'ALL'}`);

    return result;
  };

  // Also intercept instantiateStreaming
  const originalInstantiateStreaming = WebAssembly.instantiateStreaming;
  WebAssembly.instantiateStreaming = async function(source, importObject) {
    console.log('%c[FigmaInterceptor] Intercepting WASM streaming instantiation...', 'color: #FF9800; font-weight: bold');

    // Wrap imports same as above
    if (importObject) {
      for (const [moduleName, moduleImports] of Object.entries(importObject)) {
        for (const [funcName, func] of Object.entries(moduleImports)) {
          if (typeof func === 'function' && shouldCapture(funcName)) {
            importObject[moduleName][funcName] = wrapFunction(func, funcName, 'import');
          }
        }
      }
    }

    const result = await originalInstantiateStreaming.call(this, source, importObject);

    if (result.instance.exports.memory) {
      wasmMemory = result.instance.exports.memory;
    }

    const wrappedExports = {};
    for (const [name, exp] of Object.entries(result.instance.exports)) {
      if (typeof exp === 'function' && shouldCapture(name)) {
        wrappedExports[name] = wrapFunction(exp, name, 'export');
      } else {
        wrappedExports[name] = exp;
      }
    }

    Object.defineProperty(result.instance, 'exports', {
      value: wrappedExports,
      writable: false,
    });

    console.log('%c[FigmaInterceptor] WASM streaming interception active!', 'color: #4CAF50; font-weight: bold');

    return result;
  };

  // Export API
  window.FigmaInterceptor = {
    // Get captured data
    getData: () => capturedCalls,

    // Get call counts by function
    getStats: () => {
      const stats = { imports: {}, exports: {} };
      for (const [name, calls] of Object.entries(capturedCalls.imports)) {
        stats.imports[name] = calls.length;
      }
      for (const [name, calls] of Object.entries(capturedCalls.exports)) {
        stats.exports[name] = calls.length;
      }
      return stats;
    },

    // Get timeline of calls
    getTimeline: (limit = 100) => capturedCalls.timeline.slice(-limit),

    // Export to JSON file
    export: (filename = 'figma_wasm_capture.json') => {
      const data = JSON.stringify(capturedCalls, null, 2);
      const blob = new Blob([data], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = filename;
      a.click();
      URL.revokeObjectURL(url);
      console.log(`Exported ${capturedCalls.timeline.length} calls to ${filename}`);
    },

    // Export just Kiwi decode calls (most useful for our purposes)
    exportKiwiCalls: (filename = 'figma_kiwi_captures.json') => {
      const kiwiCalls = {
        fillPaint: capturedCalls.imports['JsKiwiSerialization_decodeFillPaintData'] ||
                   capturedCalls.imports['ViewerJsKiwiSerialization_decodeFillPaintData'] || [],
        effects: capturedCalls.imports['JsKiwiSerialization_decodeEffectData'] ||
                 capturedCalls.imports['ViewerJsKiwiSerialization_decodeEffectData'] || [],
        vectors: capturedCalls.imports['JsKiwiSerialization_decodeVectorData'] ||
                 capturedCalls.imports['ViewerJsKiwiSerialization_decodeVectorData'] || [],
        text: capturedCalls.imports['JsKiwiSerialization_decodeTextData'] ||
              capturedCalls.imports['ViewerJsKiwiSerialization_decodeTextData'] || [],
      };
      const data = JSON.stringify(kiwiCalls, null, 2);
      const blob = new Blob([data], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = filename;
      a.click();
      URL.revokeObjectURL(url);
      console.log(`Exported Kiwi decode calls to ${filename}`);
    },

    // Export Canvas drawing calls
    exportCanvasCalls: (filename = 'figma_canvas_captures.json') => {
      const canvasCalls = {};
      for (const [name, calls] of Object.entries(capturedCalls.exports)) {
        if (name.startsWith('CanvasContext_Internal_')) {
          canvasCalls[name] = calls;
        }
      }
      const data = JSON.stringify(canvasCalls, null, 2);
      const blob = new Blob([data], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = filename;
      a.click();
      URL.revokeObjectURL(url);
      console.log(`Exported Canvas calls to ${filename}`);
    },

    // Clear captured data
    clear: () => {
      capturedCalls.imports = {};
      capturedCalls.exports = {};
      capturedCalls.timeline = [];
      capturedCalls.startTime = Date.now();
      console.log('Cleared captured data');
    },

    // Pause/resume logging
    pauseLog: () => { CONFIG.logToConsole = false; },
    resumeLog: () => { CONFIG.logToConsole = true; },

    // Update config
    setConfig: (newConfig) => Object.assign(CONFIG, newConfig),
    getConfig: () => CONFIG,
  };

  console.log('%c[FigmaInterceptor] Ready! Refresh page or load a Figma file.', 'color: #4CAF50; font-weight: bold');
  console.log('Commands:');
  console.log('  FigmaInterceptor.getStats()      - View call counts');
  console.log('  FigmaInterceptor.getTimeline()   - View recent calls');
  console.log('  FigmaInterceptor.export()        - Download all captured data');
  console.log('  FigmaInterceptor.exportKiwiCalls() - Download Kiwi decode data');
  console.log('  FigmaInterceptor.exportCanvasCalls() - Download Canvas drawing calls');
  console.log('  FigmaInterceptor.clear()         - Clear captured data');

})();
