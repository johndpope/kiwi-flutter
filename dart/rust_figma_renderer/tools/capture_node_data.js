#!/usr/bin/env node
/**
 * Capture detailed node data from Figma via CDP
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

  await sendCommand(ws, 'Runtime.enable');

  // 1. Get detailed node data from current selection
  console.log('=== CAPTURING SELECTED NODE DATA ===\n');

  const nodeData = await evaluate(ws, `
    (function() {
      if (!window.figma || !figma.currentPage) return { error: 'No figma' };

      const selection = figma.currentPage.selection;
      if (!selection || selection.length === 0) {
        return { error: 'No selection. Please select a node in Figma.' };
      }

      function captureNode(node, depth = 0) {
        if (depth > 3) return { id: node.id, name: node.name, type: node.type, truncated: true };

        const data = {
          id: node.id,
          name: node.name,
          type: node.type,
        };

        // Geometry
        if (node.width !== undefined) {
          data.width = node.width;
          data.height = node.height;
          data.x = node.x;
          data.y = node.y;
        }

        // Transform
        if (node.relativeTransform) {
          data.relativeTransform = node.relativeTransform;
        }
        if (node.absoluteTransform) {
          data.absoluteTransform = node.absoluteTransform;
        }
        if (node.absoluteBoundingBox) {
          data.absoluteBoundingBox = node.absoluteBoundingBox;
        }

        // Fills with full detail
        if (node.fills && Array.isArray(node.fills)) {
          data.fills = node.fills.map(fill => {
            const f = {
              type: fill.type,
              visible: fill.visible,
              opacity: fill.opacity,
              blendMode: fill.blendMode,
            };

            if (fill.color) {
              f.color = {
                r: fill.color.r,
                g: fill.color.g,
                b: fill.color.b,
                a: fill.color.a !== undefined ? fill.color.a : 1,
              };
            }

            if (fill.gradientStops) {
              f.gradientStops = fill.gradientStops.map(stop => ({
                position: stop.position,
                color: {
                  r: stop.color.r,
                  g: stop.color.g,
                  b: stop.color.b,
                  a: stop.color.a,
                },
              }));
            }

            if (fill.gradientTransform) {
              f.gradientTransform = fill.gradientTransform;
            }

            if (fill.imageHash) {
              f.imageHash = fill.imageHash;
              f.scaleMode = fill.scaleMode;
            }

            return f;
          });
        }

        // Strokes
        if (node.strokes && Array.isArray(node.strokes)) {
          data.strokes = node.strokes.map(stroke => ({
            type: stroke.type,
            visible: stroke.visible,
            opacity: stroke.opacity,
            color: stroke.color,
          }));
          data.strokeWeight = node.strokeWeight;
          data.strokeAlign = node.strokeAlign;
          data.strokeCap = node.strokeCap;
          data.strokeJoin = node.strokeJoin;
          data.strokeMiterLimit = node.strokeMiterLimit;
          data.dashPattern = node.dashPattern;
        }

        // Effects
        if (node.effects && Array.isArray(node.effects)) {
          data.effects = node.effects.map(effect => ({
            type: effect.type,
            visible: effect.visible,
            radius: effect.radius,
            offset: effect.offset,
            spread: effect.spread,
            color: effect.color,
            blendMode: effect.blendMode,
          }));
        }

        // Corner radii
        if (node.cornerRadius !== undefined) {
          data.cornerRadius = node.cornerRadius;
        }
        if (node.topLeftRadius !== undefined) {
          data.cornerRadii = {
            topLeft: node.topLeftRadius,
            topRight: node.topRightRadius,
            bottomRight: node.bottomRightRadius,
            bottomLeft: node.bottomLeftRadius,
          };
        }

        // Text properties
        if (node.type === 'TEXT') {
          data.characters = node.characters;
          data.fontSize = node.fontSize;
          data.fontName = node.fontName;
          data.textAlignHorizontal = node.textAlignHorizontal;
          data.textAlignVertical = node.textAlignVertical;
          data.textAutoResize = node.textAutoResize;
          data.letterSpacing = node.letterSpacing;
          data.lineHeight = node.lineHeight;
          data.textDecoration = node.textDecoration;
          data.textCase = node.textCase;
        }

        // Vector properties
        if (node.type === 'VECTOR' || node.type === 'STAR' || node.type === 'POLYGON' ||
            node.type === 'ELLIPSE' || node.type === 'LINE') {
          data.vectorNetwork = node.vectorNetwork ? 'present' : null;
          data.vectorPaths = node.vectorPaths ? node.vectorPaths.length : null;
        }

        // Layout properties
        if (node.layoutMode) {
          data.layoutMode = node.layoutMode;
          data.primaryAxisSizingMode = node.primaryAxisSizingMode;
          data.counterAxisSizingMode = node.counterAxisSizingMode;
          data.primaryAxisAlignItems = node.primaryAxisAlignItems;
          data.counterAxisAlignItems = node.counterAxisAlignItems;
          data.paddingLeft = node.paddingLeft;
          data.paddingRight = node.paddingRight;
          data.paddingTop = node.paddingTop;
          data.paddingBottom = node.paddingBottom;
          data.itemSpacing = node.itemSpacing;
        }

        // Constraints
        if (node.constraints) {
          data.constraints = node.constraints;
        }

        // Blend mode & opacity
        data.blendMode = node.blendMode;
        data.opacity = node.opacity;
        data.visible = node.visible;
        data.locked = node.locked;

        // Children
        if (node.children && node.children.length > 0) {
          data.childCount = node.children.length;
          data.children = node.children.slice(0, 20).map(child => captureNode(child, depth + 1));
        }

        return data;
      }

      return selection.map(node => captureNode(node));
    })()
  `);

  console.log('Node data:', JSON.stringify(nodeData, null, 2));

  // 2. Get nodes from current page
  console.log('\n=== SAMPLING PAGE NODES ===\n');

  const pageNodes = await evaluate(ws, `
    (function() {
      if (!window.figma || !figma.currentPage) return { error: 'No figma' };

      function sampleNodes(children, maxCount = 10) {
        const samples = [];
        const types = {};

        function visit(nodes) {
          for (const node of nodes) {
            types[node.type] = (types[node.type] || 0) + 1;

            if (samples.length < maxCount) {
              samples.push({
                id: node.id,
                name: node.name,
                type: node.type,
                hasFills: !!(node.fills && node.fills.length > 0),
                hasEffects: !!(node.effects && node.effects.length > 0),
                hasStrokes: !!(node.strokes && node.strokes.length > 0),
              });
            }

            if (node.children) {
              visit(node.children);
            }
          }
        }

        visit(children);
        return { samples, typeDistribution: types };
      }

      return sampleNodes(figma.currentPage.children);
    })()
  `);

  console.log('Page node samples:', JSON.stringify(pageNodes, null, 2));

  // 3. Navigate to a more complex page and capture
  console.log('\n=== NAVIGATING TO COMPONENTS PAGE ===\n');

  const navResult = await evaluate(ws, `
    (function() {
      if (!window.figma || !figma.root) return { error: 'No figma' };

      // Find the Colors page which has lots of design tokens
      const colorsPage = figma.root.children.find(p => p.name.includes('Colors'));
      if (colorsPage) {
        figma.currentPage = colorsPage;
        return {
          navigatedTo: colorsPage.name,
          childCount: colorsPage.children.length,
        };
      }
      return { error: 'Colors page not found' };
    })()
  `);

  console.log('Navigation:', navResult);

  // Small delay for page to load
  await new Promise(r => setTimeout(r, 1000));

  // Capture nodes from Colors page
  const colorsData = await evaluate(ws, `
    (function() {
      if (!window.figma || !figma.currentPage) return { error: 'No figma' };

      function captureColors(nodes, max = 50) {
        const colors = [];

        function visit(node) {
          if (colors.length >= max) return;

          // Capture fill colors
          if (node.fills && node.fills.length > 0) {
            for (const fill of node.fills) {
              if (fill.type === 'SOLID' && fill.color) {
                colors.push({
                  nodeName: node.name,
                  nodeType: node.type,
                  type: 'SOLID',
                  r: fill.color.r,
                  g: fill.color.g,
                  b: fill.color.b,
                  a: fill.color.a !== undefined ? fill.color.a : 1,
                  opacity: fill.opacity,
                });
              } else if (fill.type.includes('GRADIENT') && fill.gradientStops) {
                colors.push({
                  nodeName: node.name,
                  nodeType: node.type,
                  type: fill.type,
                  stops: fill.gradientStops.map(s => ({
                    position: s.position,
                    r: s.color.r,
                    g: s.color.g,
                    b: s.color.b,
                    a: s.color.a,
                  })),
                });
              }
            }
          }

          if (node.children) {
            for (const child of node.children) {
              visit(child);
            }
          }
        }

        for (const child of nodes) {
          visit(child);
        }

        return colors;
      }

      return {
        pageName: figma.currentPage.name,
        colors: captureColors(figma.currentPage.children),
      };
    })()
  `);

  console.log('Colors captured:', colorsData?.colors?.length || 0);

  // 4. Capture typography data
  console.log('\n=== NAVIGATING TO TYPOGRAPHY PAGE ===\n');

  const typographyData = await evaluate(ws, `
    (function() {
      if (!window.figma || !figma.root) return { error: 'No figma' };

      // Find Typography page
      const typePage = figma.root.children.find(p => p.name.includes('Typography'));
      if (typePage) {
        figma.currentPage = typePage;

        // Wait a moment
        const textNodes = [];

        function findTextNodes(node) {
          if (textNodes.length >= 20) return;

          if (node.type === 'TEXT') {
            textNodes.push({
              name: node.name,
              characters: node.characters ? node.characters.slice(0, 50) : null,
              fontSize: node.fontSize,
              fontName: node.fontName,
              fontWeight: node.fontWeight,
              textAlignHorizontal: node.textAlignHorizontal,
              textAlignVertical: node.textAlignVertical,
              letterSpacing: node.letterSpacing,
              lineHeight: node.lineHeight,
              fills: node.fills ? node.fills.map(f => ({
                type: f.type,
                color: f.color,
              })) : null,
            });
          }

          if (node.children) {
            for (const child of node.children) {
              findTextNodes(child);
            }
          }
        }

        for (const child of typePage.children) {
          findTextNodes(child);
        }

        return {
          pageName: typePage.name,
          textNodes,
        };
      }
      return { error: 'Typography page not found' };
    })()
  `);

  console.log('Typography:', JSON.stringify(typographyData?.textNodes?.slice(0, 5), null, 2));

  // 5. Get some effects data
  console.log('\n=== LOOKING FOR EFFECTS/SHADOWS ===\n');

  const effectsData = await evaluate(ws, `
    (function() {
      if (!window.figma || !figma.root) return { error: 'No figma' };

      const effects = [];

      function findEffects(node) {
        if (effects.length >= 20) return;

        if (node.effects && node.effects.length > 0) {
          for (const effect of node.effects) {
            effects.push({
              nodeName: node.name,
              nodeType: node.type,
              effectType: effect.type,
              visible: effect.visible,
              radius: effect.radius,
              offset: effect.offset,
              spread: effect.spread,
              color: effect.color,
              blendMode: effect.blendMode,
            });
          }
        }

        if (node.children) {
          for (const child of node.children) {
            findEffects(child);
          }
        }
      }

      // Search across all pages
      for (const page of figma.root.children) {
        if (effects.length >= 20) break;
        for (const child of page.children) {
          findEffects(child);
        }
      }

      return effects;
    })()
  `);

  console.log('Effects found:', JSON.stringify(effectsData?.slice(0, 5), null, 2));

  // Navigate back to thumbnail page
  await evaluate(ws, `
    (function() {
      const thumbPage = figma.root.children.find(p => p.name.includes('Thumbnail'));
      if (thumbPage) figma.currentPage = thumbPage;
    })()
  `);

  // Save all captured data
  const output = {
    timestamp: new Date().toISOString(),
    selectedNodes: nodeData,
    pageNodeSamples: pageNodes,
    navigation: navResult,
    colorsData,
    typographyData,
    effectsData,
  };

  fs.writeFileSync('figma_node_capture.json', JSON.stringify(output, null, 2));
  console.log('\n\n=== SAVED TO figma_node_capture.json ===');

  ws.close();
}

main().catch(console.error);
