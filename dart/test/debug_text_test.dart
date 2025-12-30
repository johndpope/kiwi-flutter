/// Debug test to trace text rendering issues
///
/// Run with: flutter test test/debug_text_test.dart

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

  test('dump all TEXT nodes in Device 349:50793', () {
    print('\n=== TEXT Nodes in Device ===\n');

    void findTextNodes(String nodeKey, int depth, Set<String> visited) {
      if (visited.contains(nodeKey)) return;
      if (depth > 15) return;
      visited.add(nodeKey);

      final node = nodeMap[nodeKey];
      if (node == null) return;

      final type = node['type'];
      final name = node['name'] ?? '';

      if (type == 'TEXT') {
        final textData = node['textData'] as Map?;
        final characters = textData?['characters'] ?? node['characters'];
        final fills = node['fillPaints'] as List? ?? [];
        final fontSize = node['fontSize'];
        final visible = node['visible'] ?? true;

        String fillInfo = 'no fills';
        if (fills.isNotEmpty) {
          final fill = fills.first as Map?;
          final fillType = fill?['type'];
          final color = fill?['color'] as Map?;
          if (color != null) {
            final r = ((color['r'] as num?)?.toDouble() ?? 0) * 255;
            final g = ((color['g'] as num?)?.toDouble() ?? 0) * 255;
            final b = ((color['b'] as num?)?.toDouble() ?? 0) * 255;
            fillInfo = 'RGB(${r.toInt()},${g.toInt()},${b.toInt()})';
          } else {
            fillInfo = '$fillType';
          }
        }

        final charPreview = characters?.toString().substring(0,
            (characters?.toString().length ?? 0) > 40 ? 40 : (characters?.toString().length ?? 0));

        print('${'  ' * depth}[$nodeKey] "$name"');
        print('${'  ' * depth}  characters: "$charPreview"');
        print('${'  ' * depth}  fontSize: $fontSize, fill: $fillInfo, visible: $visible');
        print('');
      }

      // Recurse to children
      final children = node['children'] as List? ?? [];
      for (final childKey in children) {
        if (childKey is String) {
          findTextNodes(childKey, depth + 1, visited);
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
                  findTextNodes(childKey, depth + 1, Set.from(visited));
                }
              }
            }
          }
        }
      }
    }

    findTextNodes('349:50793', 0, {});
  });

  test('check a specific text node', () {
    // Find first TEXT node we can examine
    for (final entry in nodeMap.entries) {
      final node = entry.value;
      if (node['type'] == 'TEXT') {
        print('\n=== Full TEXT node dump: ${entry.key} ===');
        print('name: ${node['name']}');
        print('type: ${node['type']}');
        print('visible: ${node['visible']}');
        print('opacity: ${node['opacity']}');

        final textData = node['textData'];
        if (textData is Map) {
          print('\ntextData:');
          print('  characters: "${textData['characters']}"');
          print('  characterStyleIDs: ${textData['characterStyleIDs']}');
          print('  layoutSize: ${textData['layoutSize']}');
          print('  glyphs: ${(textData['glyphs'] as List?)?.length ?? 0} glyphs');
        }

        print('\ncharacters (direct): ${node['characters']}');
        print('fontSize: ${node['fontSize']}');
        print('fontWeight: ${node['fontWeight']}');

        final fills = node['fillPaints'] as List?;
        if (fills != null && fills.isNotEmpty) {
          print('\nfillPaints:');
          for (int i = 0; i < fills.length && i < 3; i++) {
            final fill = fills[i] as Map?;
            print('  [$i] type: ${fill?['type']}, visible: ${fill?['visible']}');
            final color = fill?['color'] as Map?;
            if (color != null) {
              print('      color: r=${color['r']}, g=${color['g']}, b=${color['b']}, a=${color['a']}');
            }
          }
        }

        break; // Just first one
      }
    }
  });

  testWidgets('render single text node', (tester) async {
    // Find a TEXT node to render
    String? textNodeKey;
    for (final entry in nodeMap.entries) {
      final node = entry.value;
      if (node['type'] == 'TEXT') {
        final textData = node['textData'] as Map?;
        final chars = textData?['characters'] ?? node['characters'];
        if (chars != null && chars.toString().isNotEmpty && chars.toString().length > 5) {
          textNodeKey = entry.key;
          print('Found text node: $textNodeKey');
          print('  Text: "$chars"');
          break;
        }
      }
    }

    if (textNodeKey == null) {
      fail('No TEXT node found');
    }

    final textNode = nodeMap[textNodeKey]!;
    final testKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: testKey,
          child: Container(
            width: 400,
            height: 100,
            color: Colors.white,
            alignment: Alignment.center,
            child: FigmaNodeWidget(
              node: textNode,
              nodeMap: nodeMap,
              scale: 1.0,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(testKey),
      matchesGoldenFile('goldens/debug_single_text.png'),
    );
  });
}
