/// Debug test to understand font usage in Figma file
///
/// Run with: flutter test test/debug_fonts_test.dart

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwi_schema/kiwi.dart';
import 'package:kiwi_schema/flutter_renderer.dart';

void main() {
  late FigmaDocument document;

  setUpAll(() async {
    final schemaFile = File('test/fixtures/figma_schema.bin');
    final messageFile = File('test/fixtures/figma_message.bin');

    final schemaBytes = await schemaFile.readAsBytes();
    final messageBytes = await messageFile.readAsBytes();

    final schema = decodeBinarySchema(schemaBytes);
    final compiled = compileSchema(schema);
    final message = compiled.decode('Message', messageBytes);

    document = FigmaDocument.fromMessage(message);
  });

  test('analyze fonts used in document', () {
    final nodeMap = document.nodeMap;
    final fontUsage = <String, int>{};
    final fontFamilies = <String>{};
    final fontStyles = <String>{};

    for (final node in nodeMap.values) {
      if (node['type'] == 'TEXT') {
        // Check fontName
        final fontName = node['fontName'] as Map?;
        if (fontName != null) {
          final family = fontName['family']?.toString() ?? 'unknown';
          final style = fontName['style']?.toString() ?? 'Regular';
          fontFamilies.add(family);
          fontStyles.add('$family $style');
          fontUsage[family] = (fontUsage[family] ?? 0) + 1;
        }

        // Check textData for segments with different fonts
        final textData = node['textData'] as Map?;
        if (textData != null) {
          final glyphs = textData['glyphs'] as List?;
          if (glyphs != null) {
            for (final glyph in glyphs) {
              if (glyph is Map) {
                final styleId = glyph['styleID'];
                // Style IDs reference font styles
              }
            }
          }
        }
      }
    }

    print('\n=== FONT USAGE ANALYSIS ===\n');
    print('Unique font families: ${fontFamilies.length}');
    for (final family in fontFamilies) {
      print('  - $family (${fontUsage[family]} nodes)');
    }

    print('\nUnique font styles: ${fontStyles.length}');
    final sortedStyles = fontStyles.toList()..sort();
    for (final style in sortedStyles.take(30)) {
      print('  - $style');
    }
  });

  test('analyze thumbnail page images', () {
    // Find C.04 Thumbnail page
    String? pageId;
    for (final page in document.pages) {
      final name = page['name']?.toString() ?? '';
      if (name.contains('C.04') || name.contains('Thumbnail')) {
        pageId = page['_guidKey'] as String?;
        break;
      }
    }

    if (pageId == null) {
      print('Thumbnail page not found');
      return;
    }

    final nodeMap = document.nodeMap;
    final page = nodeMap[pageId]!;

    print('\n=== THUMBNAIL PAGE IMAGE ANALYSIS ===\n');

    // Get all children recursively
    void analyzeNode(String nodeId, int depth) {
      final node = nodeMap[nodeId];
      if (node == null) return;

      final type = node['type']?.toString() ?? 'UNKNOWN';
      final name = node['name']?.toString() ?? '';
      final fills = node['fillPaints'] as List? ?? [];

      // Check for IMAGE fills
      for (final fill in fills) {
        if (fill is Map && fill['type'] == 'IMAGE') {
          final image = fill['image'] as Map?;
          if (image != null) {
            final hashBytes = image['hash'];
            if (hashBytes is List && hashBytes.isNotEmpty) {
              final hexHash = hashBytes.map((b) => (b as int).toRadixString(16).padLeft(2, '0')).join();
              final imageFile = File('images/$hexHash');
              final exists = imageFile.existsSync();
              final size = exists ? imageFile.lengthSync() : 0;

              if (depth <= 4 || !exists) {
                print('${'  ' * depth}[$type] $name');
                print('${'  ' * depth}  IMAGE: $hexHash ${exists ? '✓ ($size bytes)' : '✗ MISSING'}');
              }
            }
          }
        }
      }

      // Recurse into children
      final children = node['children'] as List? ?? [];
      for (final childId in children) {
        analyzeNode(childId.toString(), depth + 1);
      }
    }

    analyzeNode(pageId, 0);
  });

  test('check specific missing images', () {
    print('\n=== CHECKING MISSING IMAGES ===\n');

    final missingFile = File('images/missing_hashes.json');
    if (!missingFile.existsSync()) {
      print('No missing_hashes.json file');
      return;
    }

    // Check what nodes use the missing images
    final nodeMap = document.nodeMap;

    // Get the 32 still missing from our test
    final neededHashes = <String>{};
    for (final node in nodeMap.values) {
      final fills = node['fillPaints'] as List? ?? [];
      for (final fill in fills) {
        if (fill is Map && fill['type'] == 'IMAGE') {
          final image = fill['image'] as Map?;
          if (image != null) {
            final hashBytes = image['hash'];
            if (hashBytes is List && hashBytes.isNotEmpty) {
              final hexHash = hashBytes.map((b) => (b as int).toRadixString(16).padLeft(2, '0')).join();
              final imageFile = File('images/$hexHash');
              if (!imageFile.existsSync()) {
                neededHashes.add(hexHash);
              }
            }
          }
        }
      }
    }

    print('Still missing ${neededHashes.length} unique image hashes:');
    for (final hash in neededHashes) {
      // Find nodes that use this hash
      int count = 0;
      String? sampleNode;
      for (final node in nodeMap.values) {
        final fills = node['fillPaints'] as List? ?? [];
        for (final fill in fills) {
          if (fill is Map && fill['type'] == 'IMAGE') {
            final image = fill['image'] as Map?;
            if (image != null) {
              final hashBytes = image['hash'];
              if (hashBytes is List && hashBytes.isNotEmpty) {
                final hexHash = hashBytes.map((b) => (b as int).toRadixString(16).padLeft(2, '0')).join();
                if (hexHash == hash) {
                  count++;
                  sampleNode ??= node['name']?.toString();
                }
              }
            }
          }
        }
      }
      print('  $hash - used by $count nodes (e.g., "$sampleNode")');
    }
  });
}
