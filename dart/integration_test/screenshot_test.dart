/// Integration test for pixel-perfect screenshot capture
///
/// Run with: flutter test integration_test/screenshot_test.dart -d macos
///
/// This test runs on a real device/emulator and can access system fonts
/// for proper text rendering.

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kiwi_schema/kiwi.dart';
import 'package:kiwi_schema/flutter_renderer.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FigmaDocument document;

  setUpAll(() async {
    // Load from bundled assets
    final schemaData = await rootBundle.load('test/fixtures/figma_schema.bin');
    final messageData = await rootBundle.load('test/fixtures/figma_message.bin');

    final schemaBytes = schemaData.buffer.asUint8List();
    final messageBytes = messageData.buffer.asUint8List();

    final schema = decodeBinarySchema(schemaBytes);
    final compiled = compileSchema(schema);
    final message = compiled.decode('Message', messageBytes);

    document = FigmaDocument.fromMessage(message);
    // Images directory - use Apple iOS UI Kit images (has all 190 images)
    final imageDirs = [
      '/Users/johndpope/Downloads/Apple iOS UI Kit/images',
      '/Users/johndpope/Documents/GitHub/kiwi-flutter/dart/images',
      'images',
    ];
    for (final dir in imageDirs) {
      if (Directory(dir).existsSync()) {
        document.imagesDirectory = dir;
        final count = Directory(dir).listSync().length;
        print('Using images directory: $dir ($count images)');
        break;
      }
    }
  });

  testWidgets('capture thumbnail page with real fonts', (tester) async {
    // Find C.04 Thumbnail page
    String? pageId;
    for (final page in document.pages) {
      final name = page['name']?.toString() ?? '';
      if (name.contains('C.04') || name.contains('Thumbnail')) {
        pageId = page['_guidKey'] as String?;
        break;
      }
    }

    expect(pageId, isNotNull, reason: 'Should find Thumbnail page');

    final page = document.nodeMap[pageId!]!;
    final key = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: Container(
              width: 1920,
              height: 1080,
              color: const Color(0xFF1E1E1E),
              child: FigmaNodeWidget(
                node: page,
                nodeMap: document.nodeMap,
                blobMap: document.blobMap,
                imagesDirectory: 'images',
                scale: 0.12,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Capture screenshot
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData != null) {
      final pngBytes = byteData.buffer.asUint8List();
      final outputPath = '/tmp/thumbnail_with_fonts.png';
      await File(outputPath).writeAsBytes(pngBytes);
      print('Screenshot saved to $outputPath');
      print('Size: ${pngBytes.length} bytes');
    }
  });

  testWidgets('capture colors page with real fonts', (tester) async {
    // Find Colors page
    String? pageId;
    for (final page in document.pages) {
      final name = page['name']?.toString() ?? '';
      if (name.contains('A.01') || name.contains('Colors')) {
        pageId = page['_guidKey'] as String?;
        break;
      }
    }

    expect(pageId, isNotNull, reason: 'Should find Colors page');

    final page = document.nodeMap[pageId!]!;
    final key = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: Container(
              width: 1920,
              height: 1080,
              color: const Color(0xFF1E1E1E),
              child: FigmaNodeWidget(
                node: page,
                nodeMap: document.nodeMap,
                blobMap: document.blobMap,
                imagesDirectory: 'images',
                scale: 0.06,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Capture screenshot
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData != null) {
      final pngBytes = byteData.buffer.asUint8List();
      final outputPath = '/tmp/colors_with_fonts.png';
      await File(outputPath).writeAsBytes(pngBytes);
      print('Screenshot saved to $outputPath');
    }
  });
}
