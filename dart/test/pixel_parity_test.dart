/// Pixel-Perfect Parity Test for C.04 Thumbnail Page
///
/// This test suite compares kiwi-flutter rendering against golden images.
/// Focused on C.04 (Thumbnail page) for visual regression testing.
///
/// Run to update goldens: flutter test test/pixel_parity_test.dart --update-goldens
/// Run to verify: flutter test test/pixel_parity_test.dart

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwi_schema/kiwi.dart';
import 'package:kiwi_schema/flutter_renderer.dart';

/// Target page for testing
const String kTargetPage = 'C.04';
const String kTargetPageFullName = 'C.04    🖼️    Thumbnail';

void main() {
  late Schema schema;
  late CompiledSchema compiled;
  late Map<String, dynamic> message;
  late FigmaDocument document;
  late Map<String, Map<String, dynamic>> nodeMap;
  late Map<String, dynamic>? thumbnailPage;

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
    document.imagesDirectory = '/Users/johndpope/Downloads/Apple iOS UI Kit/images';

    // Build nodeMap
    nodeMap = document.nodeMap;

    // Find C.04 Thumbnail page
    thumbnailPage = _findCanvasByPartialName(kTargetPage, nodeMap);
    if (thumbnailPage != null) {
      print('✓ Found target page: ${thumbnailPage!['name']}');
    } else {
      print('✗ Target page $kTargetPage not found');
    }

    // List all available pages for debugging
    print('\nAvailable pages:');
    for (final page in document.pages) {
      final name = page['name'] as String? ?? 'unnamed';
      print('  - $name');
    }
  });

  group('C.04 Thumbnail Page - Pixel Parity Tests', () {
    testWidgets('identifies all testable frames in C.04', (tester) async {
      if (thumbnailPage == null) {
        print('Skipping: Thumbnail page not found');
        return;
      }

      final testableFrames = <Map<String, dynamic>>[];

      // Find all frames that are children of this canvas
      // Children can be stored as GUID refs in children list or as parentIndex references
      for (final node in nodeMap.values) {
        // Check if this node's parent is the thumbnail page
        final parentIndex = node['parentIndex'] as Map?;
        if (parentIndex == null) continue;

        final pageGuid = thumbnailPage!['guid'] as Map?;
        if (pageGuid == null) continue;

        // Check if parent matches the page
        if (parentIndex['sessionID'] == pageGuid['sessionID'] &&
            parentIndex['localID'] == pageGuid['localID']) {
          final type = node['type'] as String?;
          final name = node['name'] as String? ?? '';
          final size = node['size'] as Map?;
          final width = (size?['x'] as num?)?.toDouble() ?? 0;
          final height = (size?['y'] as num?)?.toDouble() ?? 0;

          // Only include frames with reasonable sizes for testing
          if ((type == 'FRAME' || type == 'COMPONENT' || type == 'INSTANCE') &&
              width >= 50 && height >= 50 && width <= 1000 && height <= 2000) {
            testableFrames.add(node);
            print('  [testable] $name ($type) - ${width}x$height');
          }
        }
      }

      print('\nFound ${testableFrames.length} testable frames in C.04');
      // Don't fail if no frames found - just informational
      if (testableFrames.isEmpty) {
        print('NOTE: No directly testable frames found. C.04 may use nested structure.');
      }
    });

    testWidgets('golden test: Device frame from C.04 Row', (tester) async {
      if (thumbnailPage == null) {
        print('Skipping: Thumbnail page not found');
        return;
      }

      // Navigate to: C.04 -> 🖼️ Thumbnail (349:44491) -> Row -> Device
      final thumbnailFrame = nodeMap['349:44491'];
      if (thumbnailFrame == null) {
        print('Skipping: Main thumbnail frame not found');
        return;
      }

      // Get first Row's first Device
      final frameChildren = thumbnailFrame['children'] as List? ?? [];
      Map<String, dynamic>? deviceFrame;

      for (final childKey in frameChildren) {
        if (childKey is String) {
          final childNode = nodeMap[childKey];
          if (childNode != null && childNode['name'] == 'Row') {
            final rowChildren = childNode['children'] as List? ?? [];
            for (final rowChild in rowChildren) {
              if (rowChild is String) {
                final rcNode = nodeMap[rowChild];
                if (rcNode != null && rcNode['name'] == 'Device') {
                  deviceFrame = rcNode;
                  break;
                }
              }
            }
            if (deviceFrame != null) break;
          }
        }
      }

      if (deviceFrame == null) {
        print('Skipping: No Device frame found in C.04');
        return;
      }

      final name = deviceFrame['name'] as String?;
      final size = deviceFrame['size'] as Map?;
      final width = (size?['x'] as num?)?.toDouble() ?? 430;
      final height = (size?['y'] as num?)?.toDouble() ?? 932;

      print('Testing frame: $name (${width}x$height)');

      final goldenKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: goldenKey,
            child: Container(
              width: width * 0.5,
              height: height * 0.5,
              color: Colors.grey[850],
              child: FigmaNodeWidget(
                node: deviceFrame,
                nodeMap: nodeMap,
                scale: 0.5,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Golden test - will compare against stored golden file
      await expectLater(
        find.byKey(goldenKey),
        matchesGoldenFile('goldens/c04_device_frame.png'),
      );
    });

    testWidgets('golden test: Settings row from C.04', (tester) async {
      if (thumbnailPage == null) {
        print('Skipping: Thumbnail page not found');
        return;
      }

      // Find a Settings row instance
      final settingsRow = _findFrameByNamePattern(
        RegExp(r'Settings|Row|List', caseSensitive: false),
        thumbnailPage!,
        nodeMap,
      );

      if (settingsRow == null) {
        print('Skipping: No Settings row found in C.04');
        return;
      }

      final name = settingsRow['name'] as String?;
      final size = settingsRow['size'] as Map?;
      final width = (size?['x'] as num?)?.toDouble() ?? 375;
      final height = (size?['y'] as num?)?.toDouble() ?? 44;

      print('Testing frame: $name (${width}x$height)');

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: width.clamp(200, 400),
                height: height.clamp(40, 100),
                child: FigmaNodeWidget(
                  node: settingsRow,
                  nodeMap: nodeMap,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await expectLater(
        find.byType(RepaintBoundary),
        matchesGoldenFile('goldens/c04_settings_row.png'),
      );
    });

    testWidgets('renders all top-level C.04 frames without errors', (tester) async {
      if (thumbnailPage == null) {
        print('Skipping: Thumbnail page not found');
        return;
      }

      final children = thumbnailPage!['children'] as List? ?? [];
      int rendered = 0;
      int errors = 0;

      for (final child in children.take(10)) {
        if (child is! Map) continue;
        final childGuid = child['guid'];
        if (childGuid == null) continue;

        final childKey = '${childGuid['sessionID']}:${childGuid['localID']}';
        final childNode = nodeMap[childKey];
        if (childNode == null) continue;

        final name = childNode['name'] as String? ?? 'unnamed';

        try {
          await tester.pumpWidget(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              home: Container(
                color: Colors.grey[200],
                child: Center(
                  child: SizedBox(
                    width: 300,
                    height: 600,
                    child: FigmaNodeWidget(
                      node: childNode,
                      nodeMap: nodeMap,
                      scale: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          );

          await tester.pumpAndSettle(const Duration(milliseconds: 100));
          rendered++;
          print('✓ Rendered: $name');
        } catch (e) {
          errors++;
          print('✗ Error rendering $name: $e');
        }
      }

      print('\nRendered $rendered/${children.length.clamp(0, 10)} frames, $errors errors');
      expect(errors, equals(0), reason: 'Should render all frames without errors');
    });
  });

  group('SF Symbol Rendering', () {
    testWidgets('SF Symbols render as placeholder icons', (tester) async {
      // Find a text node that contains SF Symbol characters
      final sfSymbolText = _findTextWithSFSymbols(nodeMap);

      if (sfSymbolText == null) {
        print('No SF Symbol text nodes found - skipping');
        return;
      }

      final name = sfSymbolText['name'] as String? ?? 'SF Symbol';
      print('Testing SF Symbol node: $name');

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Container(
            color: Colors.white,
            child: Center(
              child: SizedBox(
                width: 100,
                height: 100,
                child: FigmaNodeWidget(
                  node: sfSymbolText,
                  nodeMap: nodeMap,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should render an Icon widget as placeholder
      expect(find.byType(Icon), findsOneWidget,
          reason: 'SF Symbol should render as Icon placeholder');
    });
  });

  group('Component Instance Rendering', () {
    testWidgets('renders instances with text overrides', (tester) async {
      // Find an instance with text component prop assignments
      final instance = _findInstanceWithTextProps(nodeMap);

      if (instance == null) {
        print('No instance with text props found - skipping');
        return;
      }

      final name = instance['name'] as String? ?? 'Instance';
      print('Testing instance: $name');

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Container(
            color: Colors.white,
            child: Center(
              child: SizedBox(
                width: 400,
                height: 100,
                child: FigmaNodeWidget(
                  node: instance,
                  nodeMap: nodeMap,
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

  group('Debug: C.04 Structure', () {
    test('explore C.04 page structure', () {
      if (thumbnailPage == null) {
        print('C.04 page not found');
        return;
      }

      final pageGuid = thumbnailPage!['guid'] as Map?;
      print('C.04 Page GUID: ${pageGuid?['sessionID']}:${pageGuid?['localID']}');

      // Check children array directly on the canvas
      final children = thumbnailPage!['children'] as List?;
      print('Children array: ${children?.length ?? 0} items');

      if (children != null && children.isNotEmpty) {
        for (final child in children.take(10)) {
          print('  Child: $child (${child.runtimeType})');
          if (child is String) {
            // Look up as string key
            final resolvedNode = nodeMap[child];
            if (resolvedNode != null) {
              final name = resolvedNode['name'] ?? 'unnamed';
              final type = resolvedNode['type'] ?? 'unknown';
              final size = resolvedNode['size'] as Map?;
              print('    Resolved: $name ($type) - ${size?['x']}x${size?['y']}');
            } else {
              print('    String key "$child" not found in nodeMap');
            }
          } else if (child is Map) {
            print('    Keys: ${child.keys.toList()}');
            final guid = child['guid'] as Map?;
            if (guid != null) {
              final key = '${guid['sessionID']}:${guid['localID']}';
              final resolvedNode = nodeMap[key];
              if (resolvedNode != null) {
                print('    Resolved: ${resolvedNode['name']} (${resolvedNode['type']})');
              }
            }
          }
        }
      }

      // Look for children of the main Thumbnail frame (349:44491)
      print('\nSearching for direct children of 349:44491 (🖼️ Thumbnail)...');
      final thumbnailFrame = nodeMap['349:44491'];
      if (thumbnailFrame != null) {
        final frameChildren = thumbnailFrame['children'] as List? ?? [];
        print('Thumbnail frame has ${frameChildren.length} children');
        for (final childKey in frameChildren.take(15)) {
          if (childKey is String) {
            final childNode = nodeMap[childKey];
            if (childNode != null) {
              final name = childNode['name'] ?? 'unnamed';
              final type = childNode['type'] ?? 'unknown';
              final size = childNode['size'] as Map?;
              print('  - $name ($type) - ${size?['x']}x${size?['y']}');

              // Explore first Row's children
              if (name == 'Row') {
                final rowChildren = childNode['children'] as List? ?? [];
                print('    Row has ${rowChildren.length} children');
                for (final rowChild in rowChildren.take(5)) {
                  if (rowChild is String) {
                    final rcNode = nodeMap[rowChild];
                    if (rcNode != null) {
                      final rcName = rcNode['name'] ?? 'unnamed';
                      final rcType = rcNode['type'] ?? 'unknown';
                      final rcSize = rcNode['size'] as Map?;
                      print('      - $rcName ($rcType) - ${rcSize?['x']}x${rcSize?['y']}');
                    }
                  }
                }
              }
            }
          }
        }
      }
    });
  });
}

/// Find a CANVAS node by partial name match
Map<String, dynamic>? _findCanvasByPartialName(
    String partialName, Map<String, Map<String, dynamic>> nodeMap) {
  for (final node in nodeMap.values) {
    final type = node['type'] as String?;
    final name = node['name'] as String? ?? '';
    if (type == 'CANVAS' && name.contains(partialName)) {
      return node;
    }
  }
  return null;
}

/// Find a frame by name pattern - searches all nodes descended from the canvas
Map<String, dynamic>? _findFrameByNamePattern(
    RegExp pattern,
    Map<String, dynamic> canvas,
    Map<String, Map<String, dynamic>> nodeMap) {
  final canvasGuid = canvas['guid'] as Map?;
  if (canvasGuid == null) return null;

  final canvasKey = '${canvasGuid['sessionID']}:${canvasGuid['localID']}';

  // Build a set of all node keys that are descendants of this canvas
  final descendantKeys = <String>{};

  void findDescendants(String parentKey) {
    for (final node in nodeMap.values) {
      final parentIndex = node['parentIndex'] as Map?;
      if (parentIndex == null) continue;

      final nodeParentKey = '${parentIndex['sessionID']}:${parentIndex['localID']}';
      if (nodeParentKey == parentKey) {
        final nodeGuid = node['guid'] as Map?;
        if (nodeGuid != null) {
          final nodeKey = '${nodeGuid['sessionID']}:${nodeGuid['localID']}';
          if (!descendantKeys.contains(nodeKey)) {
            descendantKeys.add(nodeKey);
            findDescendants(nodeKey);
          }
        }
      }
    }
  }

  findDescendants(canvasKey);

  // Now search through descendants for matching frame
  for (final key in descendantKeys) {
    final node = nodeMap[key];
    if (node == null) continue;

    final name = node['name'] as String? ?? '';
    final type = node['type'] as String?;

    if ((type == 'FRAME' || type == 'COMPONENT' || type == 'INSTANCE') &&
        pattern.hasMatch(name)) {
      // Check size is reasonable for testing
      final size = node['size'] as Map?;
      final width = (size?['x'] as num?)?.toDouble() ?? 0;
      final height = (size?['y'] as num?)?.toDouble() ?? 0;
      if (width >= 50 && height >= 50) {
        return node;
      }
    }
  }

  return null;
}

/// Find a text node containing SF Symbols
Map<String, dynamic>? _findTextWithSFSymbols(
    Map<String, Map<String, dynamic>> nodeMap) {
  for (final node in nodeMap.values) {
    if (node['type'] != 'TEXT') continue;

    final textData = node['textData'] as Map?;
    final characters = textData?['characters'] as String? ??
        node['characters'] as String? ??
        '';

    // Check for SF Symbol surrogate pairs
    for (int i = 0; i < characters.length; i++) {
      final code = characters.codeUnitAt(i);
      if (code >= 0xD800 && code <= 0xDBFF) {
        // Found high surrogate - this is likely an SF Symbol
        return node;
      }
    }
  }
  return null;
}

/// Find an instance with text component prop assignments
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
      if (textValue != null &&
          (textValue['characters'] as String?)?.isNotEmpty == true) {
        return node;
      }
    }
  }
  return null;
}
