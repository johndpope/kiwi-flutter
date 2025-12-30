/// Test image rendering with downloaded images
///
/// Run with: flutter test test/image_rendering_test.dart

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
  });

  test('count available images', () {
    final imagesDir = Directory('images');
    if (!imagesDir.existsSync()) {
      print('No images directory found');
      return;
    }

    final files = imagesDir.listSync().whereType<File>().toList();
    print('Available images: ${files.length}');

    // Check which of our needed images are available
    final nodeMap = document.nodeMap;
    int neededImages = 0;
    int foundImages = 0;
    final missingHashes = <String>[];

    for (final node in nodeMap.values) {
      final fills = node['fillPaints'] as List? ?? [];
      for (final fill in fills) {
        if (fill is Map && fill['type'] == 'IMAGE') {
          final image = fill['image'] as Map?;
          if (image != null) {
            final hashBytes = image['hash'];
            if (hashBytes is List && hashBytes.isNotEmpty) {
              neededImages++;
              final hexHash = hashBytes.map((b) => (b as int).toRadixString(16).padLeft(2, '0')).join();
              final imageFile = File('images/$hexHash');
              if (imageFile.existsSync()) {
                foundImages++;
              } else {
                if (!missingHashes.contains(hexHash)) {
                  missingHashes.add(hexHash);
                }
              }
            }
          }
        }
      }
    }

    print('\n=== Image Coverage ===');
    print('Nodes needing images: $neededImages');
    print('Images found: $foundImages');
    print('Unique missing hashes: ${missingHashes.length}');

    if (missingHashes.isNotEmpty && missingHashes.length <= 20) {
      print('\nMissing hashes:');
      for (final h in missingHashes.take(10)) {
        print('  $h');
      }
    }
  });

  testWidgets('render node with image', (tester) async {
    // Find a node with an IMAGE fill that we have
    final nodeMap = document.nodeMap;
    String? nodeWithImage;
    String? imageHash;

    for (final entry in nodeMap.entries) {
      final node = entry.value;
      final fills = node['fillPaints'] as List? ?? [];
      for (final fill in fills) {
        if (fill is Map && fill['type'] == 'IMAGE') {
          final image = fill['image'] as Map?;
          if (image != null) {
            final hashBytes = image['hash'];
            if (hashBytes is List && hashBytes.isNotEmpty) {
              final hexHash = hashBytes.map((b) => (b as int).toRadixString(16).padLeft(2, '0')).join();
              final imageFile = File('images/$hexHash');
              if (imageFile.existsSync()) {
                nodeWithImage = entry.key;
                imageHash = hexHash;
                break;
              }
            }
          }
        }
      }
      if (nodeWithImage != null) break;
    }

    if (nodeWithImage == null) {
      print('No node with available image found');
      return;
    }

    print('Testing node: $nodeWithImage with image: $imageHash');

    final node = nodeMap[nodeWithImage]!;
    final props = FigmaNodeProperties.fromMap(node);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              height: 300,
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
    );

    await tester.pump(const Duration(milliseconds: 100));

    // Verify an Image widget was created
    final imageFinder = find.byType(Image);
    print('Found ${imageFinder.evaluate().length} Image widgets');
  });

  testWidgets('render full canvas with images', (tester) async {
    // Find the main page canvas (usually the first CANVAS node)
    final nodeMap = document.nodeMap;
    String? canvasId;

    for (final entry in nodeMap.entries) {
      if (entry.value['type'] == 'CANVAS') {
        canvasId = entry.key;
        break;
      }
    }

    if (canvasId == null) {
      print('No canvas found');
      return;
    }

    print('Rendering canvas: $canvasId');

    final key = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: Container(
              width: 800,
              height: 600,
              color: Colors.grey[200],
              child: FigmaCanvasView(
                document: document,
                imagesDirectory: 'images',
                initialViewportWidth: 800,
                initialViewportHeight: 600,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Count Image widgets
    final imageFinder = find.byType(Image);
    print('Total Image widgets rendered: ${imageFinder.evaluate().length}');
  });
}
