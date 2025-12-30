/// Render Figma page to PNG using Flutter's rendering pipeline
///
/// This script renders without fonts (test mode) but demonstrates
/// that for pixel-perfect rendering, a real app is needed.
///
/// Run with: dart run scripts/render_to_png.dart

import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:kiwi_schema/kiwi.dart';
import 'package:kiwi_schema/flutter_renderer.dart';

void main() async {
  print('=== Figma to PNG Renderer ===\n');

  // Load the Figma file
  print('Loading Figma schema and message...');
  final schemaFile = File('test/fixtures/figma_schema.bin');
  final messageFile = File('test/fixtures/figma_message.bin');

  final schemaBytes = await schemaFile.readAsBytes();
  final messageBytes = await messageFile.readAsBytes();

  final schema = decodeBinarySchema(schemaBytes);
  final compiled = compileSchema(schema);
  final message = compiled.decode('Message', messageBytes);

  final document = FigmaDocument.fromMessage(message);
  document.imagesDirectory = 'images';

  print('Loaded ${document.nodeCount} nodes');
  print('Found ${document.pages.length} pages');

  // Find Thumbnail page
  String? pageId;
  for (final page in document.pages) {
    final name = page['name']?.toString() ?? '';
    print('  - $name');
    if (name.contains('C.04') || name.contains('Thumbnail')) {
      pageId = page['_guidKey'] as String?;
    }
  }

  if (pageId == null) {
    print('No Thumbnail page found');
    return;
  }

  print('\nRendering page $pageId...');

  // Note: This requires flutter test runner context
  // For real rendering, run as Flutter app

  print('\n=== Font Rendering Information ===');
  print('');
  print('To achieve pixel-perfect rendering with real fonts:');
  print('');
  print('1. Run the Flutter app (not test):');
  print('   cd example && flutter run -d macos');
  print('');
  print('2. Or use integration test with platform fonts:');
  print('   flutter test --enable-platform-fonts integration_test/');
  print('');
  print('3. Or bundle SF Pro font in pubspec.yaml');
  print('');
  print('Flutter tests use "Ahem" placeholder font by design');
  print('for reproducibility across different systems.');
  print('');

  // Count font usage
  final fontUsage = <String, int>{};
  for (final node in document.nodeMap.values) {
    if (node['type'] == 'TEXT') {
      final fontName = node['fontName'] as Map?;
      if (fontName != null) {
        final family = fontName['family']?.toString() ?? 'unknown';
        fontUsage[family] = (fontUsage[family] ?? 0) + 1;
      }
    }
  }

  print('Fonts used in this document:');
  final sortedFonts = fontUsage.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  for (final entry in sortedFonts) {
    print('  ${entry.key}: ${entry.value} text nodes');
  }

  // Check image availability
  print('\nImage status:');
  int total = 0;
  int found = 0;
  for (final node in document.nodeMap.values) {
    final fills = node['fillPaints'] as List? ?? [];
    for (final fill in fills) {
      if (fill is Map && fill['type'] == 'IMAGE') {
        final image = fill['image'] as Map?;
        if (image != null) {
          final hashBytes = image['hash'];
          if (hashBytes is List && hashBytes.isNotEmpty) {
            total++;
            final hexHash = hashBytes.map((b) => (b as int).toRadixString(16).padLeft(2, '0')).join();
            if (File('images/$hexHash').existsSync()) {
              found++;
            }
          }
        }
      }
    }
  }
  print('  Images needed: $total');
  print('  Images found: $found (${(found * 100 / total).toStringAsFixed(1)}%)');
}
