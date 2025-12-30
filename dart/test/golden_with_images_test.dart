/// Golden test with actual images
///
/// Run with: flutter test test/golden_with_images_test.dart --update-goldens

import 'dart:io';
import 'package:flutter/material.dart';
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
    document.imagesDirectory = 'images';
  });

  testWidgets('thumbnail page with images', (tester) async {
    // Find C.04 Thumbnail page
    final nodeMap = document.nodeMap;
    String? pageId;
    for (final page in document.pages) {
      final name = page['name']?.toString() ?? '';
      if (name.contains('C.04') || name.contains('Thumbnail')) {
        pageId = page['_guidKey'] as String?;
        break;
      }
    }

    expect(pageId, isNotNull, reason: 'Should find Thumbnail page');

    final page = nodeMap[pageId!]!;
    final key = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: Container(
              width: 1200,
              height: 800,
              color: const Color(0xFF1E1E1E),
              child: FigmaNodeWidget(
                node: page,
                nodeMap: nodeMap,
                blobMap: document.blobMap,
                imagesDirectory: 'images',
                scale: 0.15,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    await expectLater(
      find.byKey(key),
      matchesGoldenFile('goldens/thumbnail_with_images.png'),
    );
  });

  testWidgets('colors page with images', (tester) async {
    // Find A.02 Colors page
    final nodeMap = document.nodeMap;
    String? pageId;
    for (final page in document.pages) {
      final name = page['name']?.toString() ?? '';
      if (name.contains('A.01') || name.contains('Colors')) {
        pageId = page['_guidKey'] as String?;
        break;
      }
    }

    expect(pageId, isNotNull, reason: 'Should find Colors page');

    final page = nodeMap[pageId!]!;
    final key = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: Container(
              width: 1200,
              height: 800,
              color: const Color(0xFF1E1E1E),
              child: FigmaNodeWidget(
                node: page,
                nodeMap: nodeMap,
                blobMap: document.blobMap,
                imagesDirectory: 'images',
                scale: 0.08,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    await expectLater(
      find.byKey(key),
      matchesGoldenFile('goldens/colors_with_images.png'),
    );
  });

  testWidgets('single frame with image fill', (tester) async {
    // Find a specific node that uses the iPhone screen image
    final nodeMap = document.nodeMap;
    String? nodeId;
    String? nodeName;

    for (final entry in nodeMap.entries) {
      final node = entry.value;
      final fills = node['fillPaints'] as List? ?? [];
      final name = node['name']?.toString() ?? '';

      for (final fill in fills) {
        if (fill is Map && fill['type'] == 'IMAGE') {
          final image = fill['image'] as Map?;
          if (image != null) {
            final hashBytes = image['hash'];
            if (hashBytes is List && hashBytes.isNotEmpty) {
              final hexHash = hashBytes.map((b) => (b as int).toRadixString(16).padLeft(2, '0')).join();
              final imageFile = File('images/$hexHash');
              if (imageFile.existsSync()) {
                // Check if it's a reasonable size to render
                final props = FigmaNodeProperties.fromMap(node);
                if (props.width > 100 && props.height > 100) {
                  nodeId = entry.key;
                  nodeName = name;
                  break;
                }
              }
            }
          }
        }
      }
      if (nodeId != null) break;
    }

    expect(nodeId, isNotNull, reason: 'Should find a node with image');

    print('Rendering node: $nodeName ($nodeId)');

    final node = nodeMap[nodeId!]!;
    final props = FigmaNodeProperties.fromMap(node);
    final key = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: Container(
              width: 400,
              height: 400,
              color: Colors.white,
              child: Center(
                child: FigmaFrameWidget(
                  props: props,
                  nodeMap: nodeMap,
                  blobMap: document.blobMap,
                  imagesDirectory: 'images',
                  scale: 1.0,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    await expectLater(
      find.byKey(key),
      matchesGoldenFile('goldens/single_image_frame.png'),
    );
  });
}
