#!/usr/bin/env node
/**
 * CDP-based Figma WASM capture tool
 * Connects to existing Chrome with debug port and captures WASM traffic
 */

const WebSocket = require('ws');
const fs = require('fs');

const CDP_URL = 'ws://localhost:9222/devtools/page/497854E6982881434DA7FB5C54905FA2';

async function connect() {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(CDP_URL);
    ws.on('open', () => resolve(ws));
    ws.on('error', reject);
  });
}

let msgId = 1;
function sendCommand(ws, method, params = {}) {
  return new Promise((resolve) => {
    const id = msgId++;
    const handler = (data) => {
      const msg = JSON.parse(data);
      if (msg.id === id) {
        ws.off('message', handler);
        resolve(msg.result);
      }
    };
    ws.on('message', handler);
    ws.send(JSON.stringify({ id, method, params }));
  });
}

async function evaluate(ws, expression) {
  const result = await sendCommand(ws, 'Runtime.evaluate', {
    expression,
    returnByValue: true,
    awaitPromise: true,
  });
  return result?.result?.value;
}

async function main() {
  console.log('Connecting to Chrome DevTools...');
  const ws = await connect();
  console.log('Connected!\n');

  // Enable Runtime
  await sendCommand(ws, 'Runtime.enable');

  // Inject live interceptor for ongoing calls
  console.log('Injecting live call interceptor...');

  const interceptorCode = `
    (function() {
      if (window.__figmaInterceptorActive) {
        return { status: 'already_active', callCount: window.__figmaCapturedCalls?.length || 0 };
      }

      window.__figmaInterceptorActive = true;
      window.__figmaCapturedCalls = [];
      window.__figmaCallStats = {};

      // Find WASM instance in window
      let wasmExports = null;
      let wasmMemory = null;

      // Search for WASM module in common locations
      const searchLocations = [
        () => window.Module?.asm,
        () => window.wasmExports,
        () => window._wasmInstance?.exports,
      ];

      for (const search of searchLocations) {
        try {
          const result = search();
          if (result && typeof result === 'object') {
            wasmExports = result;
            break;
          }
        } catch (e) {}
      }

      if (!wasmExports) {
        // Try to find via prototype chain on window objects
        for (const key of Object.keys(window)) {
          try {
            const obj = window[key];
            if (obj && obj.exports && obj.exports.memory) {
              wasmExports = obj.exports;
              wasmMemory = obj.exports.memory;
              break;
            }
          } catch (e) {}
        }
      }

      // Hook into common Figma globals
      const figmaGlobals = ['figma', 'Figma', 'FigmaApp', 'app'];
      let foundFigma = null;
      for (const name of figmaGlobals) {
        if (window[name]) {
          foundFigma = name;
          break;
        }
      }

      return {
        status: 'installed',
        wasmExportsFound: !!wasmExports,
        wasmExportCount: wasmExports ? Object.keys(wasmExports).length : 0,
        figmaGlobal: foundFigma,
        memoryFound: !!wasmMemory,
      };
    })()
  `;

  const interceptResult = await evaluate(ws, interceptorCode);
  console.log('Interceptor result:', interceptResult);

  // Get WASM export names
  console.log('\nExtracting WASM export names...');
  const exportNames = await evaluate(ws, `
    (function() {
      // Find exports
      for (const key of Object.keys(window)) {
        try {
          const obj = window[key];
          if (obj && obj.exports && typeof obj.exports === 'object') {
            const names = Object.keys(obj.exports).filter(n => typeof obj.exports[n] === 'function');
            if (names.length > 100) {
              return { source: key, count: names.length, sample: names.slice(0, 50) };
            }
          }
        } catch (e) {}
      }

      // Try Module.asm
      if (window.Module && window.Module.asm) {
        const names = Object.keys(window.Module.asm).filter(n => typeof window.Module.asm[n] === 'function');
        return { source: 'Module.asm', count: names.length, sample: names.slice(0, 50) };
      }

      return { source: null, count: 0, sample: [] };
    })()
  `);
  console.log('WASM exports:', exportNames);

  // Try to find and hook CanvasContext functions
  console.log('\nLooking for CanvasContext functions...');
  const canvasSearch = await evaluate(ws, `
    (function() {
      const results = [];

      // Search all object properties recursively (limited depth)
      function searchObj(obj, path, depth) {
        if (depth > 3) return;
        if (!obj || typeof obj !== 'object') return;

        try {
          for (const key of Object.keys(obj)) {
            if (key.includes('CanvasContext') || key.includes('canvas')) {
              results.push({ path: path + '.' + key, type: typeof obj[key] });
            }
            if (typeof obj[key] === 'object' && obj[key] !== null) {
              searchObj(obj[key], path + '.' + key, depth + 1);
            }
          }
        } catch (e) {}
      }

      searchObj(window, 'window', 0);
      return results.slice(0, 20);
    })()
  `);
  console.log('Canvas-related:', canvasSearch);

  // Get current Figma document info
  console.log('\nGetting Figma document info...');
  const docInfo = await evaluate(ws, `
    (function() {
      // Try various ways to get document info
      if (window.figma && window.figma.currentPage) {
        return {
          source: 'figma API',
          pageName: window.figma.currentPage.name,
          nodeCount: window.figma.currentPage.children?.length,
        };
      }

      // Check for Figma app state
      const appState = window.__FIGMA_APP_STATE__ || window.appState;
      if (appState) {
        return { source: 'appState', keys: Object.keys(appState).slice(0, 10) };
      }

      return { source: null };
    })()
  `);
  console.log('Document info:', docInfo);

  // Set up real-time call monitoring
  console.log('\nSetting up real-time monitoring (will capture for 30 seconds)...');

  const monitorCode = `
    (function() {
      window.__captureLog = [];
      window.__captureActive = true;

      // Override console to capture Figma logs
      const originalLog = console.log;
      console.log = function(...args) {
        if (window.__captureActive && args.length > 0) {
          const msg = args.map(a => typeof a === 'object' ? JSON.stringify(a) : String(a)).join(' ');
          if (msg.includes('Canvas') || msg.includes('render') || msg.includes('draw')) {
            window.__captureLog.push({ time: Date.now(), type: 'log', msg: msg.slice(0, 200) });
          }
        }
        return originalLog.apply(console, args);
      };

      // Try to intercept requestAnimationFrame to see render cycles
      const originalRAF = window.requestAnimationFrame;
      let rafCount = 0;
      window.requestAnimationFrame = function(callback) {
        rafCount++;
        if (rafCount % 60 === 0) { // Log every 60 frames
          window.__captureLog.push({ time: Date.now(), type: 'raf', frame: rafCount });
        }
        return originalRAF.call(window, callback);
      };

      return { status: 'monitoring', rafCount };
    })()
  `;
  await evaluate(ws, monitorCode);
  console.log('Monitoring started. Interact with Figma now...');

  // Capture for 30 seconds
  await new Promise(r => setTimeout(r, 10000));

  // Get captured data
  const captured = await evaluate(ws, `
    (function() {
      window.__captureActive = false;
      return {
        logCount: window.__captureLog?.length || 0,
        logs: window.__captureLog?.slice(-50) || [],
      };
    })()
  `);

  console.log('\n=== CAPTURED DATA ===');
  console.log('Log entries:', captured?.logCount);
  if (captured?.logs) {
    for (const log of captured.logs.slice(-20)) {
      console.log(`  [${log.type}] ${log.msg || log.frame}`);
    }
  }

  // Save results
  const output = {
    timestamp: new Date().toISOString(),
    interceptResult,
    exportNames,
    canvasSearch,
    docInfo,
    captured,
  };

  fs.writeFileSync('cdp_capture_result.json', JSON.stringify(output, null, 2));
  console.log('\nSaved results to cdp_capture_result.json');

  ws.close();
}

main().catch(console.error);
