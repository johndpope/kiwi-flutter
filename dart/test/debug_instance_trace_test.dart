/// Debug test to trace INSTANCE rendering hierarchy
///
/// Run with: flutter test test/debug_instance_trace_test.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwi_schema/kiwi.dart';
import 'package:kiwi_schema/flutter_renderer.dart';

void main() {
  late FigmaDocument document;
  late Map<String, Map<String, dynamic>> nodeMap;

  setUpAll(() async {
    final schemaFile = File('test/fixtures/figma_schema.bin');
    final messageFile = File('test/fixtures/figma_message.bin');

    final schemaBytes = await schemaFile.readAsBytes();
    final messageBytes = await messageFile.readAsBytes();

    final schema = decodeBinarySchema(schemaBytes);
    final compiled = compileSchema(schema);
    final message = compiled.decode('Message', messageBytes);

    document = FigmaDocument.fromMessage(message);
    nodeMap = document.nodeMap;
  });

  test('trace INSTANCE hierarchy for Device 349:50793', () {
    print('\n=== Device 349:50793 Full Instance Hierarchy ===\n');

    void traceNode(String nodeKey, int depth, {int maxDepth = 15, Set<String>? visited}) {
      visited ??= {};
      if (depth > maxDepth) return;
      if (visited.contains(nodeKey)) {
        print('${'  ' * depth}[CYCLE: $nodeKey]');
        return;
      }
      visited.add(nodeKey);

      final node = nodeMap[nodeKey];
      if (node == null) {
        print('${'  ' * depth}[$nodeKey] NOT FOUND');
        return;
      }

      final name = node['name'] ?? '';
      final type = node['type'] ?? '';
      final children = node['children'] as List? ?? [];
      final visible = node['visible'] ?? true;
      final opacity = node['opacity'] ?? 1.0;

      // Get fills info
      final fills = node['fillPaints'] as List? ?? [];
      String fillInfo = '';
      if (fills.isNotEmpty) {
        final firstFill = fills.first as Map?;
        final fillType = firstFill?['type'];
        final fillVisible = firstFill?['visible'] ?? true;
        fillInfo = ' fill:$fillType${fillVisible ? '' : '(hidden)'}';
      }

      // Get size info
      final size = node['size'] as Map?;
      String sizeInfo = '';
      if (size != null) {
        sizeInfo = ' ${size['x']?.toStringAsFixed(0)}x${size['y']?.toStringAsFixed(0)}';
      }

      print('${'  ' * depth}[$nodeKey] $type "$name"$sizeInfo$fillInfo${visible ? '' : ' HIDDEN'}${opacity < 1 ? ' op:$opacity' : ''} (${children.length} children)');

      // For INSTANCE, also trace the source component
      if (type == 'INSTANCE') {
        final symbolData = node['symbolData'] as Map?;
        if (symbolData != null) {
          final symbolId = symbolData['symbolID'];
          if (symbolId is Map) {
            final symKey = '${symbolId['sessionID']}:${symbolId['localID']}';
            final symNode = nodeMap[symKey];
            if (symNode != null) {
              final symName = symNode['name'];
              final symChildren = symNode['children'] as List? ?? [];
              print('${'  ' * (depth + 1)}→ COMPONENT: $symKey "$symName" (${symChildren.length} children)');

              // Trace component children
              for (final childKey in symChildren) {
                if (childKey is String) {
                  traceNode(childKey, depth + 2, maxDepth: maxDepth, visited: Set.from(visited));
                }
              }
            }
          }
        }
      }

      // Trace direct children
      for (final childKey in children) {
        if (childKey is String) {
          traceNode(childKey, depth + 1, maxDepth: maxDepth, visited: visited);
        }
      }
    }

    traceNode('349:50793', 0, maxDepth: 8);
  });

  test('count visible vs hidden nodes in Device', () {
    int visibleCount = 0;
    int hiddenCount = 0;
    int zeroOpacityCount = 0;
    int noFillCount = 0;
    int whiteFillCount = 0;

    void countNodes(String nodeKey, Set<String> visited) {
      if (visited.contains(nodeKey)) return;
      visited.add(nodeKey);

      final node = nodeMap[nodeKey];
      if (node == null) return;

      final visible = node['visible'] ?? true;
      final opacity = (node['opacity'] as num?)?.toDouble() ?? 1.0;
      final fills = node['fillPaints'] as List? ?? [];

      if (!visible) {
        hiddenCount++;
      } else {
        visibleCount++;
      }

      if (opacity == 0) {
        zeroOpacityCount++;
      }

      if (fills.isEmpty) {
        noFillCount++;
      } else {
        // Check for white fills
        final firstFill = fills.first as Map?;
        final color = firstFill?['color'] as Map?;
        if (color != null) {
          final r = (color['r'] as num?)?.toDouble() ?? 0;
          final g = (color['g'] as num?)?.toDouble() ?? 0;
          final b = (color['b'] as num?)?.toDouble() ?? 0;
          if (r > 0.95 && g > 0.95 && b > 0.95) {
            whiteFillCount++;
          }
        }
      }

      // Recurse
      final children = node['children'] as List? ?? [];
      for (final childKey in children) {
        if (childKey is String) {
          countNodes(childKey, visited);
        }
      }

      // Also count component children for INSTANCE
      final type = node['type'];
      if (type == 'INSTANCE') {
        final symbolData = node['symbolData'] as Map?;
        if (symbolData != null) {
          final symbolId = symbolData['symbolID'];
          if (symbolId is Map) {
            final symKey = '${symbolId['sessionID']}:${symbolId['localID']}';
            final symNode = nodeMap[symKey];
            if (symNode != null) {
              final symChildren = symNode['children'] as List? ?? [];
              for (final childKey in symChildren) {
                if (childKey is String) {
                  countNodes(childKey, visited);
                }
              }
            }
          }
        }
      }
    }

    countNodes('349:50793', {});

    print('\n=== Node Visibility Stats for Device 349:50793 ===');
    print('Visible nodes: $visibleCount');
    print('Hidden nodes: $hiddenCount');
    print('Zero opacity nodes: $zeroOpacityCount');
    print('No fill nodes: $noFillCount');
    print('White fill nodes: $whiteFillCount');
  });

  test('check for background frames/rectangles', () {
    print('\n=== Background Elements in Device ===\n');

    void findBackgrounds(String nodeKey, int depth, Set<String> visited) {
      if (visited.contains(nodeKey)) return;
      if (depth > 10) return;
      visited.add(nodeKey);

      final node = nodeMap[nodeKey];
      if (node == null) return;

      final name = node['name'] ?? '';
      final type = node['type'] ?? '';
      final fills = node['fillPaints'] as List? ?? [];

      // Check for background-like elements
      bool isBackground = name.toLowerCase().contains('background') ||
          name.toLowerCase().contains('bg') ||
          name.toLowerCase().contains('backdrop');

      // Check for large fills
      bool hasSignificantFill = false;
      Color? fillColor;
      if (fills.isNotEmpty) {
        final fill = fills.first as Map?;
        if (fill != null && fill['visible'] != false) {
          final fillType = fill['type'];
          final color = fill['color'] as Map?;
          if (fillType == 'SOLID' && color != null) {
            hasSignificantFill = true;
            final r = ((color['r'] as num?)?.toDouble() ?? 0) * 255;
            final g = ((color['g'] as num?)?.toDouble() ?? 0) * 255;
            final b = ((color['b'] as num?)?.toDouble() ?? 0) * 255;
            fillColor = Color.fromRGBO(r.round(), g.round(), b.round(), 1);
          } else if (fillType?.startsWith('GRADIENT_') == true) {
            hasSignificantFill = true;
          }
        }
      }

      if ((isBackground || hasSignificantFill) && type != 'TEXT') {
        final size = node['size'] as Map?;
        final w = size?['x']?.toStringAsFixed(0) ?? '?';
        final h = size?['y']?.toStringAsFixed(0) ?? '?';
        print('${'  ' * depth}$type "$name" ${w}x$h ${fillColor ?? 'gradient'}');
      }

      // Recurse
      final children = node['children'] as List? ?? [];
      for (final childKey in children) {
        if (childKey is String) {
          findBackgrounds(childKey, depth + 1, visited);
        }
      }

      // For INSTANCE, check component
      if (type == 'INSTANCE') {
        final symbolData = node['symbolData'] as Map?;
        if (symbolData != null) {
          final symbolId = symbolData['symbolID'];
          if (symbolId is Map) {
            final symKey = '${symbolId['sessionID']}:${symbolId['localID']}';
            final symNode = nodeMap[symKey];
            if (symNode != null) {
              final symChildren = symNode['children'] as List? ?? [];
              for (final childKey in symChildren) {
                if (childKey is String) {
                  findBackgrounds(childKey, depth + 1, Set.from(visited));
                }
              }
            }
          }
        }
      }
    }

    findBackgrounds('349:50793', 0, {});
  });
}
