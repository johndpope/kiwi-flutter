/// Debug test to check overlay opacity handling
///
/// Run with: flutter test test/debug_overlay_test.dart

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

  test('check overlay node opacity', () {
    // The Overlay node: 473:27847
    final overlay = nodeMap['473:27847'];
    if (overlay == null) {
      print('Overlay node not found');
      return;
    }

    print('\n=== Overlay Node 473:27847 Analysis ===');
    print('Name: ${overlay['name']}');
    print('Type: ${overlay['type']}');
    print('Visible: ${overlay['visible']}');
    print('Opacity: ${overlay['opacity']}');

    final fills = overlay['fillPaints'] as List? ?? [];
    print('Fills count: ${fills.length}');

    for (int i = 0; i < fills.length; i++) {
      final fill = fills[i] as Map?;
      if (fill != null) {
        print('\nFill[$i]:');
        print('  type: ${fill['type']}');
        print('  visible: ${fill['visible']}');
        print('  opacity: ${fill['opacity']}');
        print('  blendMode: ${fill['blendMode']}');

        final color = fill['color'] as Map?;
        if (color != null) {
          print('  color.r: ${color['r']}');
          print('  color.g: ${color['g']}');
          print('  color.b: ${color['b']}');
          print('  color.a: ${color['a']}');
        }
      }
    }

    // Also check the parent instance to see if there's an override
    print('\n=== Parent Alert Instance Check ===');
    final alert = nodeMap['473:27862'];
    if (alert != null) {
      final symbolData = alert['symbolData'] as Map?;
      if (symbolData != null) {
        final overrides = symbolData['symbolOverrides'] as List? ?? [];
        print('Override count: ${overrides.length}');

        for (int i = 0; i < overrides.length && i < 5; i++) {
          final override = overrides[i] as Map?;
          if (override != null) {
            final guidPath = override['guidPath'];
            final hasOpacity = override.containsKey('opacity');
            final hasFillPaints = override.containsKey('fillPaints');
            print('  Override[$i]: guidPath=$guidPath, hasOpacity=$hasOpacity, hasFillPaints=$hasFillPaints');

            if (hasFillPaints) {
              final opFills = override['fillPaints'] as List?;
              if (opFills != null && opFills.isNotEmpty) {
                final opFill = opFills.first as Map?;
                print('    fill.opacity: ${opFill?['opacity']}');
                final opColor = opFill?['color'] as Map?;
                print('    fill.color.a: ${opColor?['a']}');
              }
            }
          }
        }
      }
    }
  });

  test('check all nodes with low opacity fills', () {
    print('\n=== Nodes with Opacity < 1 ===\n');

    int count = 0;
    for (final entry in nodeMap.entries) {
      final node = entry.value;
      final fills = node['fillPaints'] as List? ?? [];

      for (final fill in fills) {
        if (fill is Map) {
          final fillOpacity = fill['opacity'];
          final colorA = (fill['color'] as Map?)?['a'];

          if ((fillOpacity is num && fillOpacity < 1) ||
              (colorA is num && colorA < 1)) {
            final name = node['name'] ?? '';
            final type = node['type'] ?? '';
            if (count < 20) {
              print('${entry.key}: $type "$name"');
              print('  fill.opacity: $fillOpacity');
              print('  color.a: $colorA');
            }
            count++;
          }
        }
      }
    }

    print('\nTotal nodes with opacity < 1: $count');
  });

  testWidgets('render overlay with correct opacity', (tester) async {
    // Create a test render with just the overlay
    final overlay = nodeMap['473:27847']!;

    await tester.pumpWidget(
      MaterialApp(
        home: Container(
          width: 430,
          height: 932,
          color: Colors.green, // Background to see through overlay
          child: FigmaNodeWidget(
            node: overlay,
            nodeMap: nodeMap,
            scale: 0.5,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Container).first,
      matchesGoldenFile('goldens/debug_overlay_opacity.png'),
    );
  });
}
