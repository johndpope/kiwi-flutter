/// Figma Rendering Parity Test
///
/// This test renders the C.04 Thumbnail page and compares against Figma export
/// to identify rendering gaps.
///
/// Run with: flutter test test/figma_parity_test.dart --update-goldens

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwi_schema/kiwi.dart';
import 'package:kiwi_schema/flutter_renderer.dart';

void main() {
  late FigmaDocument document;
  late Map<String, Map<String, dynamic>> nodeMap;
  late Map<String, List<int>>? blobMap;

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
    blobMap = document.blobMap;

    print('Loaded ${nodeMap.length} nodes');
    print('Loaded ${blobMap?.length ?? 0} blobs');
  });

  test('analyze rendering issues', () {
    print('\n=== RENDERING PARITY ANALYSIS ===\n');

    // Count node types
    final typeCounts = <String, int>{};
    int textNodes = 0;
    int imageNodes = 0;
    int instanceNodes = 0;
    int vectorNodes = 0;
    int nodesWithImageFill = 0;

    for (final node in nodeMap.values) {
      final type = node['type'] as String? ?? 'UNKNOWN';
      typeCounts[type] = (typeCounts[type] ?? 0) + 1;

      if (type == 'TEXT') textNodes++;
      if (type == 'INSTANCE') instanceNodes++;
      if (type == 'VECTOR' || type == 'BOOLEAN_OPERATION') vectorNodes++;

      // Check for IMAGE fills
      final fills = node['fillPaints'] as List? ?? [];
      for (final fill in fills) {
        if (fill is Map && fill['type'] == 'IMAGE') {
          nodesWithImageFill++;
          break;
        }
      }
    }

    print('NODE TYPE COUNTS:');
    final sortedTypes = typeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in sortedTypes.take(15)) {
      print('  ${entry.key}: ${entry.value}');
    }

    print('\nKEY METRICS:');
    print('  TEXT nodes: $textNodes');
    print('  INSTANCE nodes: $instanceNodes');
    print('  VECTOR nodes: $vectorNodes');
    print('  Nodes with IMAGE fills: $nodesWithImageFill');
    print('  Total blobs available: ${blobMap?.length ?? 0}');

    // Check blob references
    print('\nIMAGE FILL ANALYSIS:');
    int blobsFound = 0;
    int blobsMissing = 0;

    for (final node in nodeMap.values) {
      final fills = node['fillPaints'] as List? ?? [];
      for (final fill in fills) {
        if (fill is Map && fill['type'] == 'IMAGE') {
          final imageRef = fill['imageRef'];
          if (imageRef != null && blobMap != null) {
            if (blobMap!.containsKey(imageRef.toString())) {
              blobsFound++;
            } else {
              blobsMissing++;
              if (blobsMissing <= 5) {
                print('  Missing blob: $imageRef for ${node['name']}');
              }
            }
          }
        }
      }
    }
    print('  Blobs found: $blobsFound');
    print('  Blobs missing: $blobsMissing');

    // Check text content
    print('\nTEXT CONTENT ANALYSIS:');
    int textsWithContent = 0;
    int textsEmpty = 0;
    int textsWithSFSymbols = 0;

    for (final node in nodeMap.values) {
      if (node['type'] == 'TEXT') {
        final textData = node['textData'] as Map?;
        final chars = textData?['characters'] ?? node['characters'];
        if (chars != null && chars.toString().isNotEmpty) {
          textsWithContent++;
          // Check for SF Symbols (private use area)
          final text = chars.toString();
          for (final rune in text.runes) {
            if (rune >= 0xE000 && rune <= 0xF8FF || rune >= 0x100000) {
              textsWithSFSymbols++;
              break;
            }
          }
        } else {
          textsEmpty++;
        }
      }
    }
    print('  Texts with content: $textsWithContent');
    print('  Texts empty: $textsEmpty');
    print('  Texts with SF Symbols: $textsWithSFSymbols');
  });

  test('identify specific rendering failures in Device frame', () {
    print('\n=== DEVICE FRAME 349:50793 ANALYSIS ===\n');

    void analyzeNode(String nodeKey, int depth, Set<String> visited, List<String> issues) {
      if (visited.contains(nodeKey) || depth > 10) return;
      visited.add(nodeKey);

      final node = nodeMap[nodeKey];
      if (node == null) return;

      final type = node['type'] as String?;
      final name = node['name'] as String? ?? '';
      final visible = node['visible'] ?? true;

      if (!visible) return;

      // Check for issues
      if (type == 'TEXT') {
        final textData = node['textData'] as Map?;
        final chars = textData?['characters'] ?? node['characters'];
        if (chars == null || chars.toString().isEmpty) {
          issues.add('EMPTY TEXT: $nodeKey "$name"');
        }
      }

      // Check for IMAGE fills without blobs
      final fills = node['fillPaints'] as List? ?? [];
      for (final fill in fills) {
        if (fill is Map && fill['type'] == 'IMAGE') {
          final imageRef = fill['imageRef'];
          if (imageRef == null || (blobMap != null && !blobMap!.containsKey(imageRef.toString()))) {
            issues.add('MISSING IMAGE: $nodeKey "$name" ref=$imageRef');
          }
        }
      }

      // Recurse to children
      final children = node['children'] as List? ?? [];
      for (final childKey in children) {
        if (childKey is String) {
          analyzeNode(childKey, depth + 1, visited, issues);
        }
      }

      // For INSTANCE, also check component children
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
                  analyzeNode(childKey, depth + 1, Set.from(visited), issues);
                }
              }
            }
          }
        }
      }
    }

    final issues = <String>[];
    analyzeNode('349:50793', 0, {}, issues);

    print('Found ${issues.length} potential issues:');
    for (final issue in issues.take(30)) {
      print('  - $issue');
    }
    if (issues.length > 30) {
      print('  ... and ${issues.length - 30} more');
    }
  });

  testWidgets('render full C.04 Thumbnail page at 0.25 scale', (tester) async {
    // Find C.04 Thumbnail page
    String? thumbnailPageKey;
    for (final entry in nodeMap.entries) {
      final node = entry.value;
      if (node['type'] == 'CANVAS' &&
          (node['name']?.toString().contains('Thumbnail') == true ||
           node['name']?.toString().contains('C.04') == true)) {
        thumbnailPageKey = entry.key;
        print('Found C.04 Thumbnail page: $thumbnailPageKey "${node['name']}"');
        break;
      }
    }

    if (thumbnailPageKey == null) {
      fail('C.04 Thumbnail page not found');
    }

    final pageNode = nodeMap[thumbnailPageKey]!;
    final testKey = GlobalKey();

    // Get page bounds
    final children = pageNode['children'] as List? ?? [];
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;

    for (final childKey in children) {
      if (childKey is String) {
        final child = nodeMap[childKey];
        if (child != null) {
          final transform = child['transform'] as Map?;
          final size = child['size'] as Map?;
          if (transform != null && size != null) {
            final x = (transform['m02'] as num?)?.toDouble() ?? 0;
            final y = (transform['m12'] as num?)?.toDouble() ?? 0;
            final w = (size['x'] as num?)?.toDouble() ?? 0;
            final h = (size['y'] as num?)?.toDouble() ?? 0;
            minX = minX < x ? minX : x;
            minY = minY < y ? minY : y;
            maxX = maxX > (x + w) ? maxX : (x + w);
            maxY = maxY > (y + h) ? maxY : (y + h);
          }
        }
      }
    }

    final pageWidth = maxX - minX;
    final pageHeight = maxY - minY;
    print('Page bounds: ${pageWidth.toInt()} x ${pageHeight.toInt()}');

    const scale = 0.15; // Small scale to fit
    final renderWidth = (pageWidth * scale).clamp(100, 2000).toDouble();
    final renderHeight = (pageHeight * scale).clamp(100, 1500).toDouble();

    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: testKey,
          child: Container(
            width: renderWidth,
            height: renderHeight,
            color: const Color(0xFF1E1E1E), // Figma dark background
            child: ClipRect(
              child: Transform.translate(
                offset: Offset(-minX * scale, -minY * scale),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (final childKey in children)
                      if (childKey is String && nodeMap[childKey] != null)
                        Builder(builder: (context) {
                          final child = nodeMap[childKey]!;
                          final transform = child['transform'] as Map?;
                          final x = ((transform?['m02'] as num?)?.toDouble() ?? 0) * scale;
                          final y = ((transform?['m12'] as num?)?.toDouble() ?? 0) * scale;
                          return Positioned(
                            left: x,
                            top: y,
                            child: FigmaNodeWidget(
                              node: child,
                              nodeMap: nodeMap,
                              blobMap: blobMap,
                              scale: scale,
                            ),
                          );
                        }),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(testKey),
      matchesGoldenFile('goldens/parity_c04_thumbnail.png'),
    );
  });

  testWidgets('render single device at 1.0 scale for detail comparison', (tester) async {
    // Device 349:50797 - second device which has more visible content
    final deviceNode = nodeMap['349:50797'];
    if (deviceNode == null) {
      fail('Device node not found');
    }

    final testKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: testKey,
          child: Container(
            width: 430,
            height: 932,
            color: const Color(0xFF1E1E1E),
            child: FigmaNodeWidget(
              node: deviceNode,
              nodeMap: nodeMap,
              blobMap: blobMap,
              scale: 1.0, // Full scale for detail
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(testKey),
      matchesGoldenFile('goldens/parity_device_fullscale.png'),
    );
  });
}
