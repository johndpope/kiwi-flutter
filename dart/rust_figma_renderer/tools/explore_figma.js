#!/usr/bin/env node
/**
 * Deep exploration of running Figma instance
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

async function evaluate(ws, expression, returnByValue = true) {
  const result = await sendCommand(ws, 'Runtime.evaluate', {
    expression,
    returnByValue,
    awaitPromise: true,
    generatePreview: true,
  });
  if (result?.exceptionDetails) {
    console.error('Eval error:', result.exceptionDetails.text);
    return null;
  }
  return returnByValue ? result?.result?.value : result?.result;
}

async function main() {
  console.log('Connecting to Chrome DevTools...');
  const ws = await connect();
  console.log('Connected!\n');

  await sendCommand(ws, 'Runtime.enable');

  // 1. Explore CanvasContext
  console.log('=== EXPLORING CanvasContext ===\n');
  const canvasCtx = await evaluate(ws, `
    (function() {
      const CC = window.CanvasContext;
      if (!CC) return { error: 'CanvasContext not found' };

      // Get prototype methods
      const proto = CC.prototype;
      const methods = [];
      for (const key of Object.getOwnPropertyNames(proto)) {
        if (typeof proto[key] === 'function' && key !== 'constructor') {
          methods.push(key);
        }
      }

      // Get static methods
      const statics = [];
      for (const key of Object.getOwnPropertyNames(CC)) {
        if (typeof CC[key] === 'function') {
          statics.push(key);
        }
      }

      return { methods, statics, name: CC.name };
    })()
  `);
  console.log('CanvasContext:', JSON.stringify(canvasCtx, null, 2));

  // 2. Explore MutableCanvasContext
  console.log('\n=== EXPLORING MutableCanvasContext ===\n');
  const mutableCtx = await evaluate(ws, `
    (function() {
      const MCC = window.MutableCanvasContext;
      if (!MCC) return { error: 'MutableCanvasContext not found' };

      const proto = MCC.prototype;
      const methods = [];
      for (const key of Object.getOwnPropertyNames(proto)) {
        if (typeof proto[key] === 'function' && key !== 'constructor') {
          methods.push(key);
        }
      }

      return { methods, name: MCC.name };
    })()
  `);
  console.log('MutableCanvasContext:', JSON.stringify(mutableCtx, null, 2));

  // 3. Explore Figma Plugin API
  console.log('\n=== EXPLORING figma API ===\n');
  const figmaApi = await evaluate(ws, `
    (function() {
      if (!window.figma) return { error: 'figma not found' };

      const api = {};

      // Top-level methods
      api.methods = Object.keys(figma).filter(k => typeof figma[k] === 'function');

      // Top-level properties
      api.properties = Object.keys(figma).filter(k => typeof figma[k] !== 'function');

      // Current page info
      if (figma.currentPage) {
        api.currentPage = {
          name: figma.currentPage.name,
          id: figma.currentPage.id,
          type: figma.currentPage.type,
          childCount: figma.currentPage.children?.length,
        };
      }

      // Root (document)
      if (figma.root) {
        api.root = {
          name: figma.root.name,
          type: figma.root.type,
          pageCount: figma.root.children?.length,
        };
      }

      return api;
    })()
  `);
  console.log('Figma API:', JSON.stringify(figmaApi, null, 2));

  // 4. Get all pages
  console.log('\n=== DOCUMENT STRUCTURE ===\n');
  const docStructure = await evaluate(ws, `
    (function() {
      if (!window.figma || !figma.root) return { error: 'No document' };

      const pages = figma.root.children.map(page => ({
        id: page.id,
        name: page.name,
        childCount: page.children?.length || 0,
      }));

      return { pages };
    })()
  `);
  console.log('Document structure:', JSON.stringify(docStructure, null, 2));

  // 5. Get selected node details
  console.log('\n=== CURRENT SELECTION ===\n');
  const selection = await evaluate(ws, `
    (function() {
      if (!window.figma) return { error: 'figma not found' };

      const sel = figma.currentPage.selection;
      if (!sel || sel.length === 0) return { selection: [] };

      return {
        count: sel.length,
        nodes: sel.slice(0, 5).map(node => {
          const info = {
            id: node.id,
            name: node.name,
            type: node.type,
          };

          // Get size/position if available
          if (node.width !== undefined) {
            info.width = node.width;
            info.height = node.height;
          }
          if (node.x !== undefined) {
            info.x = node.x;
            info.y = node.y;
          }

          // Get fills if available
          if (node.fills && Array.isArray(node.fills)) {
            info.fills = node.fills.map(f => ({
              type: f.type,
              visible: f.visible,
              opacity: f.opacity,
              color: f.color,
            }));
          }

          // Get effects if available
          if (node.effects && Array.isArray(node.effects)) {
            info.effects = node.effects.map(e => ({
              type: e.type,
              visible: e.visible,
              radius: e.radius,
            }));
          }

          // Get stroke info
          if (node.strokes && Array.isArray(node.strokes)) {
            info.strokes = node.strokes.length;
            info.strokeWeight = node.strokeWeight;
          }

          // Get corner radius
          if (node.cornerRadius !== undefined) {
            info.cornerRadius = node.cornerRadius;
          }

          return info;
        })
      };
    })()
  `);
  console.log('Selection:', JSON.stringify(selection, null, 2));

  // 6. Find internal WASM bindings
  console.log('\n=== SEARCHING FOR WASM BINDINGS ===\n');
  const wasmSearch = await evaluate(ws, `
    (function() {
      const results = [];

      // Search for anything WASM-related
      const searchTerms = ['wasm', 'WASM', 'Module', 'asm', 'emscripten', 'Kiwi', 'kiwi'];

      for (const key of Object.keys(window)) {
        for (const term of searchTerms) {
          if (key.toLowerCase().includes(term.toLowerCase())) {
            results.push({ key, type: typeof window[key] });
          }
        }
      }

      // Check for common Emscripten globals
      const emscriptenGlobals = ['Module', 'HEAP8', 'HEAP16', 'HEAP32', 'HEAPU8', 'HEAPU16', 'HEAPU32', 'HEAPF32', 'HEAPF64'];
      for (const name of emscriptenGlobals) {
        if (window[name]) {
          results.push({ key: name, type: typeof window[name], isEmscripten: true });
        }
      }

      return results;
    })()
  `);
  console.log('WASM-related globals:', JSON.stringify(wasmSearch, null, 2));

  // 7. Check for Module.asm or similar
  console.log('\n=== CHECKING MODULE OBJECT ===\n');
  const moduleCheck = await evaluate(ws, `
    (function() {
      if (!window.Module) return { exists: false };

      const keys = Object.keys(Module);
      const funcs = keys.filter(k => typeof Module[k] === 'function').slice(0, 20);
      const asmKeys = Module.asm ? Object.keys(Module.asm).slice(0, 30) : [];

      return {
        exists: true,
        keyCount: keys.length,
        sampleKeys: keys.slice(0, 20),
        functions: funcs,
        hasAsm: !!Module.asm,
        asmKeyCount: asmKeys.length,
        asmSample: asmKeys,
        hasMemory: !!Module.HEAP8,
      };
    })()
  `);
  console.log('Module object:', JSON.stringify(moduleCheck, null, 2));

  // 8. Look for render/draw methods on nodes
  console.log('\n=== NODE PROTOTYPE METHODS ===\n');
  const nodeMethods = await evaluate(ws, `
    (function() {
      if (!window.figma || !figma.currentPage) return { error: 'No figma' };

      const node = figma.currentPage.children[0];
      if (!node) return { error: 'No nodes' };

      const proto = Object.getPrototypeOf(node);
      const methods = [];
      const props = [];

      // Get all prototype chain
      let current = proto;
      while (current && current !== Object.prototype) {
        for (const key of Object.getOwnPropertyNames(current)) {
          const desc = Object.getOwnPropertyDescriptor(current, key);
          if (typeof current[key] === 'function') {
            methods.push(key);
          } else if (desc && (desc.get || desc.set)) {
            props.push(key);
          }
        }
        current = Object.getPrototypeOf(current);
      }

      return {
        nodeType: node.type,
        methods: [...new Set(methods)].sort(),
        properties: [...new Set(props)].sort(),
      };
    })()
  `);
  console.log('Node methods:', JSON.stringify(nodeMethods, null, 2));

  // Save all results
  const output = {
    timestamp: new Date().toISOString(),
    canvasContext: canvasCtx,
    mutableCanvasContext: mutableCtx,
    figmaApi,
    docStructure,
    selection,
    wasmSearch,
    moduleCheck,
    nodeMethods,
  };

  fs.writeFileSync('figma_exploration.json', JSON.stringify(output, null, 2));
  console.log('\n\nSaved detailed results to figma_exploration.json');

  ws.close();
}

main().catch(console.error);
