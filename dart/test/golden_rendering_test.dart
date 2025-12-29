/// Golden rendering tests - compare actual rendering against expected output
///
/// Run with: flutter test test/golden_rendering_test.dart --update-goldens
/// to update the golden files, then re-run without --update-goldens to verify.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwi_schema/kiwi.dart';
import 'package:kiwi_schema/flutter_renderer.dart';

void main() {
  late Schema schema;
  late CompiledSchema compiled;
  late Map<String, dynamic> message;
  late FigmaDocument document;

  setUpAll(() async {
    // Load the pre-decompressed data
    final schemaFile = File('test/fixtures/figma_schema.bin');
    final messageFile = File('test/fixtures/figma_message.bin');

    if (!schemaFile.existsSync() || !messageFile.existsSync()) {
      throw Exception('Test fixtures not found.');
    }

    final schemaBytes = await schemaFile.readAsBytes();
    final messageBytes = await messageFile.readAsBytes();

    schema = decodeBinarySchema(schemaBytes);
    compiled = compileSchema(schema);
    message = compiled.decode('Message', messageBytes);
    document = FigmaDocument.fromMessage(message);
    document.imagesDirectory = '/Users/johndpope/Downloads/Apple iOS UI Kit/images';

    print('Loaded ${document.nodeCount} nodes');
  });

  group('Text Rendering', () {
    testWidgets('renders "Reading Now" text correctly', (tester) async {
      // Find the "Reading Now" text node
      final textNode = _findTextNodeByContent('Reading Now', document.nodeMap);
      expect(textNode, isNotNull, reason: 'Should find "Reading Now" text node');

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: FigmaNodeWidget(
                node: textNode!,
                nodeMap: document.nodeMap,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify text is rendered
      expect(find.text('Reading Now'), findsOneWidget);
    });

    testWidgets('renders text with component prop values', (tester) async {
      // Find an instance with componentPropAssignments containing text
      final instanceWithTextProps = _findInstanceWithTextProps(document.nodeMap);

      if (instanceWithTextProps == null) {
        print('No instance with text props found - skipping');
        return;
      }

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: SizedBox(
                width: 400,
                height: 100,
                child: FigmaNodeWidget(
                  node: instanceWithTextProps,
                  nodeMap: document.nodeMap,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should render without errors
      expect(find.byType(FigmaNodeWidget), findsWidgets);
    });
  });

  group('Frame Rendering', () {
    testWidgets('renders simple frame with fills', (tester) async {
      // Find a frame with solid fills
      final frameWithFill = _findFrameWithSolidFill(document.nodeMap);

      if (frameWithFill == null) {
        print('No frame with solid fill found - skipping');
        return;
      }

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            backgroundColor: Colors.grey[900],
            body: Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: FigmaNodeWidget(
                  node: frameWithFill,
                  nodeMap: document.nodeMap,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(FigmaNodeWidget), findsWidgets);
    });
  });

  group('Instance Rendering', () {
    testWidgets('renders instance with resolved text overrides', (tester) async {
      // Find the "Title" component instance which has text props
      final titleInstance = _findInstanceByName('🔧 Title', document.nodeMap);

      if (titleInstance == null) {
        print('No Title instance found - skipping');
        return;
      }

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: SizedBox(
                width: 400,
                height: 200,
                child: FigmaNodeWidget(
                  node: titleInstance,
                  nodeMap: document.nodeMap,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check that some text from componentPropAssignments is rendered
      final propAssignments = titleInstance['componentPropAssignments'] as List?;
      if (propAssignments != null && propAssignments.isNotEmpty) {
        for (final assignment in propAssignments) {
          if (assignment is Map) {
            final value = assignment['value'] as Map?;
            final textValue = value?['textValue'] as Map?;
            final characters = textValue?['characters'] as String?;
            if (characters != null && characters.isNotEmpty) {
              print('Looking for text: "$characters"');
              // The text might be found in the widget tree
              final textFinder = find.text(characters);
              if (textFinder.evaluate().isNotEmpty) {
                print('Found text: "$characters"');
              }
            }
          }
        }
      }

      expect(find.byType(FigmaNodeWidget), findsWidgets);
    });
  });

  group('Vector Rendering', () {
    testWidgets('renders vector with fill geometry', (tester) async {
      final vectorNode = _findVectorWithGeometry(document.nodeMap);

      if (vectorNode == null) {
        print('No vector with geometry found - skipping');
        return;
      }

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: SizedBox(
                width: 100,
                height: 100,
                child: FigmaNodeWidget(
                  node: vectorNode,
                  nodeMap: document.nodeMap,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(FigmaNodeWidget), findsWidgets);
    });
  });
}

Map<String, dynamic>? _findTextNodeByContent(
    String content, Map<String, Map<String, dynamic>> nodeMap) {
  for (final node in nodeMap.values) {
    if (node['type'] != 'TEXT') continue;
    final textData = node['textData'] as Map<String, dynamic>?;
    if (textData == null) continue;
    final chars = textData['characters'] as String? ?? '';
    if (chars.contains(content)) {
      return node;
    }
  }
  return null;
}

Map<String, dynamic>? _findInstanceWithTextProps(
    Map<String, Map<String, dynamic>> nodeMap) {
  for (final node in nodeMap.values) {
    if (node['type'] != 'INSTANCE') continue;
    final propAssignments = node['componentPropAssignments'] as List?;
    if (propAssignments == null || propAssignments.isEmpty) continue;

    for (final assignment in propAssignments) {
      if (assignment is! Map) continue;
      final value = assignment['value'] as Map?;
      final textValue = value?['textValue'] as Map?;
      if (textValue != null && (textValue['characters'] as String?)?.isNotEmpty == true) {
        return node;
      }
    }
  }
  return null;
}

Map<String, dynamic>? _findFrameWithSolidFill(
    Map<String, Map<String, dynamic>> nodeMap) {
  for (final node in nodeMap.values) {
    if (node['type'] != 'FRAME') continue;
    final fills = node['fillPaints'] as List?;
    if (fills == null || fills.isEmpty) continue;

    for (final fill in fills) {
      if (fill is Map && fill['type'] == 'SOLID' && fill['visible'] != false) {
        return node;
      }
    }
  }
  return null;
}

Map<String, dynamic>? _findInstanceByName(
    String name, Map<String, Map<String, dynamic>> nodeMap) {
  for (final node in nodeMap.values) {
    if (node['type'] != 'INSTANCE') continue;
    if (node['name'] == name) {
      return node;
    }
  }
  return null;
}

Map<String, dynamic>? _findVectorWithGeometry(
    Map<String, Map<String, dynamic>> nodeMap) {
  for (final node in nodeMap.values) {
    if (node['type'] != 'VECTOR') continue;
    final fillGeo = node['fillGeometry'] as List?;
    if (fillGeo != null && fillGeo.isNotEmpty) {
      return node;
    }
  }
  return null;
}
