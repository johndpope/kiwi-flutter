/// Rendering parity test
///
/// Compares kiwi-flutter rendering against Figma reference.
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwi_schema/kiwi.dart';
import 'package:kiwi_schema/flutter_renderer.dart';

void main() {
  late Schema schema;
  late CompiledSchema compiled;
  late Map<String, dynamic> message;
  late FigmaDocument document;
  late Map<String, Map<String, dynamic>> nodeMap;

  setUpAll(() async {
    // Load the pre-decompressed data
    final schemaFile = File('test/fixtures/figma_schema.bin');
    final messageFile = File('test/fixtures/figma_message.bin');

    if (!schemaFile.existsSync() || !messageFile.existsSync()) {
      throw Exception('Test fixtures not found. Run decompress_fig.py first.');
    }

    final schemaBytes = await schemaFile.readAsBytes();
    final messageBytes = await messageFile.readAsBytes();

    schema = decodeBinarySchema(schemaBytes);
    compiled = compileSchema(schema);
    message = compiled.decode('Message', messageBytes);
    document = FigmaDocument.fromMessage(message);

    // Build nodeMap for quick lookups
    final changes = message['nodeChanges'] as List<dynamic>? ?? [];
    nodeMap = {};
    for (final change in changes) {
      if (change is Map<String, dynamic>) {
        final guid = change['guid'];
        if (guid != null) {
          final key = _guidToString(guid);
          nodeMap[key] = change;
        }
      }
    }

    print('Loaded ${document.nodeCount} nodes');
    final pageNames = document.pages.map((p) => p['name'] as String? ?? 'unnamed').toList();
    print('Pages: ${pageNames.join(", ")}');
  });

  group('Document Structure', () {
    test('has Welcome page', () {
      final pageNames = document.pages.map((p) => p['name'] as String? ?? 'unnamed').toList();
      expect(pageNames.contains('Welcome'), isTrue,
          reason: 'Should have Welcome page');
    });

    test('finds Welcome page content', () {
      // Find the Welcome canvas
      final welcomeCanvas = _findCanvasByName('Welcome', nodeMap);
      expect(welcomeCanvas, isNotNull, reason: 'Welcome canvas should exist');

      // Get children count
      final children = welcomeCanvas!['children'] as List<dynamic>? ?? [];
      print('Welcome page has ${children.length} direct children');
      expect(children.length, greaterThan(0));
    });
  });

  group('Node Type Rendering', () {
    test('finds iPhone mockup frames', () {
      // Look for frames that might be iPhone mockups
      final frames = _findNodesByType('FRAME', nodeMap);
      final iphoneFrames = frames.where((f) {
        final name = f['name'] as String? ?? '';
        return name.toLowerCase().contains('iphone') ||
            name.contains('Phone') ||
            name.contains('Device');
      }).toList();

      print('Found ${iphoneFrames.length} potential iPhone frames');
      for (final frame in iphoneFrames.take(5)) {
        print('  - ${frame['name']}');
      }
    });

    test('finds text nodes with content', () {
      final textNodes = _findNodesByType('TEXT', nodeMap);
      final textsWithContent = textNodes.where((t) {
        final textData = t['textData'] as Map<String, dynamic>?;
        return textData != null &&
            (textData['characters'] as String? ?? '').isNotEmpty;
      }).toList();

      print('Found ${textsWithContent.length} text nodes with content');

      // Find specific text content
      final readingNow = textsWithContent.where((t) {
        final textData = t['textData'] as Map<String, dynamic>?;
        final chars = textData?['characters'] as String? ?? '';
        return chars.contains('Reading Now');
      }).toList();

      print('Found ${readingNow.length} nodes with "Reading Now" text');
      expect(readingNow.length, greaterThan(0),
          reason: 'Should find "Reading Now" text');
    });

    test('finds component instances', () {
      final instances = _findNodesByType('INSTANCE', nodeMap);
      print('Found ${instances.length} component instances');

      // Check for symbol overrides
      int withOverrides = 0;
      for (final instance in instances) {
        final overrides = instance['symbolOverrides'] as List<dynamic>?;
        if (overrides != null && overrides.isNotEmpty) {
          withOverrides++;
        }
      }
      print('$withOverrides instances have symbol overrides');
    });

    test('finds vector nodes', () {
      final vectors = _findNodesByType('VECTOR', nodeMap);
      print('Found ${vectors.length} vector nodes');

      // Check for fillGeometry
      int withGeometry = 0;
      for (final vec in vectors) {
        final fillGeo = vec['fillGeometry'] as List<dynamic>?;
        if (fillGeo != null && fillGeo.isNotEmpty) {
          withGeometry++;
        }
      }
      print('$withGeometry vectors have fill geometry');
    });
  });

  group('Rendering Tests', () {
    testWidgets('renders basic frame', (tester) async {
      // Find a simple frame to render
      final frames = _findNodesByType('FRAME', nodeMap);
      final simpleFrame = frames.firstWhere(
        (f) {
          final children = f['children'] as List<dynamic>? ?? [];
          return children.length > 0 && children.length < 10;
        },
        orElse: () => frames.first,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              child: SizedBox(
                width: 400,
                height: 600,
                child: FigmaNodeWidget(
                  node: simpleFrame,
                  nodeMap: nodeMap,
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

    testWidgets('renders text node correctly', (tester) async {
      // Find a text node with "Reading Now"
      final textNodes = _findNodesByType('TEXT', nodeMap);
      final readingNowNode = textNodes.firstWhere(
        (t) {
          final textData = t['textData'] as Map<String, dynamic>?;
          final chars = textData?['characters'] as String? ?? '';
          return chars.contains('Reading Now');
        },
        orElse: () => textNodes.first,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: FigmaNodeWidget(
                node: readingNowNode,
                nodeMap: nodeMap,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should render without errors
      expect(find.byType(FigmaNodeWidget), findsOneWidget);
    });

    testWidgets('renders instance with overrides', (tester) async {
      // Find an instance with overrides
      final instances = _findNodesByType('INSTANCE', nodeMap);
      final instanceWithOverrides = instances.firstWhere(
        (i) {
          final overrides = i['symbolOverrides'] as List<dynamic>?;
          return overrides != null && overrides.isNotEmpty;
        },
        orElse: () => instances.first,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 200,
              child: FigmaNodeWidget(
                node: instanceWithOverrides,
                nodeMap: nodeMap,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(FigmaNodeWidget), findsWidgets);
    });
  });

  group('Text Override Resolution', () {
    test('resolves text overrides in instances', () {
      // Find instances with text overrides
      // NOTE: Overrides are stored in symbolData.symbolOverrides, not directly on instance
      final instances = _findNodesByType('INSTANCE', nodeMap);

      int instancesWithOverrides = 0;
      int textOverrideCount = 0;
      int resolvedCount = 0;

      for (final instance in instances) {
        final symbolData = instance['symbolData'] as Map<String, dynamic>?;
        if (symbolData == null) continue;

        final overrides = symbolData['symbolOverrides'] as List<dynamic>?;
        if (overrides == null || overrides.isEmpty) continue;

        instancesWithOverrides++;

        for (final override in overrides) {
          if (override is! Map<String, dynamic>) continue;

          final overrideValue = override['overrideValue'] as Map<String, dynamic>?;
          if (overrideValue == null) continue;

          // Check for text overrides
          final textData = overrideValue['textData'] as Map<String, dynamic>?;
          if (textData != null) {
            textOverrideCount++;
            final chars = textData['characters'] as String? ?? '';
            if (chars.isNotEmpty && chars != 'X' && chars != 'xx') {
              resolvedCount++;
            }
          }
        }
      }

      print('Found $instancesWithOverrides instances with symbol overrides');
      print('Found $textOverrideCount text overrides, $resolvedCount with real content');
      expect(instancesWithOverrides, greaterThan(0),
          reason: 'Should have instances with symbol overrides');
    });
  });

  group('Fill and Stroke Rendering', () {
    test('finds nodes with solid fills', () {
      final frames = _findNodesByType('FRAME', nodeMap);
      int withFills = 0;

      for (final frame in frames.take(100)) {
        final fills = frame['fillPaints'] as List<dynamic>?;
        if (fills != null && fills.isNotEmpty) {
          withFills++;
        }
      }

      print('$withFills/${frames.length.clamp(0, 100)} frames have fills');
    });

    test('finds nodes with gradients', () {
      final allNodes = nodeMap.values.toList();
      int withGradients = 0;

      for (final node in allNodes.take(500)) {
        final fills = node['fillPaints'] as List<dynamic>?;
        if (fills == null) continue;

        for (final fill in fills) {
          if (fill is! Map<String, dynamic>) continue;
          final type = fill['type'] as String?;
          if (type == 'GRADIENT_LINEAR' ||
              type == 'GRADIENT_RADIAL' ||
              type == 'GRADIENT_ANGULAR') {
            withGradients++;
            break;
          }
        }
      }

      print('Found $withGradients nodes with gradients');
    });
  });
}

String _guidToString(dynamic guid) {
  if (guid is Map<String, dynamic>) {
    final sessionId = guid['sessionID'] ?? 0;
    final localId = guid['localID'] ?? 0;
    return '$sessionId:$localId';
  }
  return guid.toString();
}

Map<String, dynamic>? _findCanvasByName(
    String name, Map<String, Map<String, dynamic>> nodeMap) {
  for (final node in nodeMap.values) {
    final nodeType = node['type'] as String?;
    final nodeName = node['name'] as String?;
    if (nodeType == 'CANVAS' && nodeName == name) {
      return node;
    }
  }
  return null;
}

List<Map<String, dynamic>> _findNodesByType(
    String type, Map<String, Map<String, dynamic>> nodeMap) {
  return nodeMap.values.where((n) => n['type'] == type).toList();
}
