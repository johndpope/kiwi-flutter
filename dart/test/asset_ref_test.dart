import 'dart:io';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:kiwi_schema/kiwi.dart';

void main() {
  group('Variable Resolution', () {
    late Map<String, dynamic> message;
    late Map<String, Map<String, dynamic>> nodeMap;

    setUpAll(() {
      final schemaFile = File('test/fixtures/figma_schema.bin');
      final messageFile = File('test/fixtures/figma_message.bin');

      final schemaBytes = schemaFile.readAsBytesSync();
      final messageBytes = messageFile.readAsBytesSync();

      final schema = decodeBinarySchema(schemaBytes);
      final compiled = compileSchema(schema);
      message = compiled.decode('Message', messageBytes);

      // Build nodeMap
      nodeMap = {};
      final nodeChanges = message['nodeChanges'] as List? ?? [];
      for (final node in nodeChanges) {
        if (node is Map) {
          final guid = node['guid'];
          if (guid is Map) {
            final guidKey = '${guid['sessionID']}:${guid['localID']}';
            nodeMap[guidKey] = node as Map<String, dynamic>;
          }
        }
      }
    });

    test('examine VARIABLE node structure', () {
      // Find a few specific VARIABLE nodes to examine
      final targetGuids = [
        '128:42087', // system/teal
        '128:42082', // system/red
        '128:42271', // bg/primary-base
        '128:42123', // bg/primary-elevated
      ];

      print('🔍 Examining VARIABLE node structures:');
      for (final guidKey in targetGuids) {
        final node = nodeMap[guidKey];
        if (node != null) {
          print('\n📦 VARIABLE $guidKey: ${node['name']}');
          print('   All keys: ${node.keys.toList()}');

          // Print all values
          for (final key in node.keys) {
            final value = node[key];
            if (value is Map) {
              print('   $key: Map with keys ${value.keys.toList()}');
              if (value.length < 10) {
                for (final subKey in value.keys) {
                  print('      $subKey: ${value[subKey]}');
                }
              }
            } else if (value is List) {
              print('   $key: List (${value.length} items)');
              if (value.isNotEmpty && value.length <= 3) {
                for (var i = 0; i < value.length; i++) {
                  print('      [$i]: ${value[i]}');
                }
              }
            } else {
              print('   $key: $value');
            }
          }
        }
      }
    });

    test('examine VARIABLE_SET node structure', () {
      // Find VARIABLE_SET nodes (collections)
      print('🔍 Looking for VARIABLE_SET nodes:');

      final nodeChanges = message['nodeChanges'] as List? ?? [];
      for (final node in nodeChanges) {
        if (node is Map) {
          final type = node['type']?.toString();
          if (type == 'VARIABLE_SET') {
            final guid = node['guid'];
            if (guid is Map) {
              final guidKey = '${guid['sessionID']}:${guid['localID']}';
              print('\n📦 VARIABLE_SET $guidKey: ${node['name']}');
              print('   All keys: ${node.keys.toList()}');

              // Show key properties
              for (final key in ['variableSetModes', 'libraryModeReferences', 'defaultModeId']) {
                if (node.containsKey(key)) {
                  print('   $key: ${node[key]}');
                }
              }
            }
          }
        }
      }
    });

    test('extract color values from VARIABLE nodes', () {
      print('🎨 Extracting color values from VARIABLE nodes:');

      final colorVariables = <String, Map<String, dynamic>>{};

      final nodeChanges = message['nodeChanges'] as List? ?? [];
      for (final node in nodeChanges) {
        if (node is Map) {
          final type = node['type']?.toString();
          if (type == 'VARIABLE') {
            final guid = node['guid'];
            if (guid is Map) {
              final guidKey = '${guid['sessionID']}:${guid['localID']}';
              final name = node['name']?.toString() ?? 'unknown';

              // Look for color-related properties
              final variableResolvedDataType = node['variableResolvedDataType'];
              if (variableResolvedDataType == 'COLOR') {
                colorVariables[guidKey] = {
                  'name': name,
                  'variableDataValues': node['variableDataValues'],
                  'scopes': node['scopes'],
                };
              }
            }
          }
        }
      }

      print('📊 Found ${colorVariables.length} COLOR variable nodes');

      // Print first 10
      for (final entry in colorVariables.entries.take(10)) {
        print('\n🎨 ${entry.key}: ${entry.value['name']}');
        final dataValues = entry.value['variableDataValues'];
        if (dataValues is Map) {
          print('   variableDataValues keys: ${dataValues.keys.toList()}');
          for (final modeKey in dataValues.keys) {
            final modeValue = dataValues[modeKey];
            print('   [$modeKey]: $modeValue');
          }
        } else if (dataValues is List) {
          print('   variableDataValues (${dataValues.length} items):');
          for (var i = 0; i < dataValues.length && i < 3; i++) {
            print('      [$i]: ${dataValues[i]}');
          }
        }
      }
    });

    test('resolve colorVar to actual color value', () {
      print('🔍 Resolving colorVar references to actual colors:');

      // Find a Card node with colorVar
      Map<String, dynamic>? cardNode;
      final nodeChanges = message['nodeChanges'] as List? ?? [];

      for (final node in nodeChanges) {
        if (node is Map) {
          final name = node['name']?.toString() ?? '';
          if (name == 'Card') {
            final fills = node['fillPaints'] as List?;
            if (fills != null && fills.isNotEmpty) {
              final fill = fills[0] as Map;
              if (fill['colorVar'] != null) {
                cardNode = node as Map<String, dynamic>;
                break;
              }
            }
          }
        }
      }

      if (cardNode != null) {
        print('\n📦 Found Card node:');
        final fills = cardNode['fillPaints'] as List;
        final fill = fills[0] as Map;
        final colorVar = fill['colorVar'] as Map;
        print('   fill.colorVar: $colorVar');
        print('   fill.color: ${fill['color']}');

        // Try to resolve the colorVar
        final value = colorVar['value'] as Map?;
        if (value != null && value['alias'] is Map) {
          final alias = value['alias'] as Map;

          // GUID-based reference
          if (alias['guid'] is Map) {
            final refGuid = alias['guid'] as Map;
            final guidKey = '${refGuid['sessionID']}:${refGuid['localID']}';
            print('\n🔗 Following GUID reference: $guidKey');

            final varNode = nodeMap[guidKey];
            if (varNode != null) {
              print('   Resolved to: ${varNode['name']} (${varNode['type']})');

              // Get the color value from variableDataValues
              final dataValues = varNode['variableDataValues'];
              print('   variableDataValues: $dataValues');

              if (dataValues is Map) {
                for (final modeKey in dataValues.keys) {
                  final modeValue = dataValues[modeKey];
                  print('   Mode $modeKey: $modeValue');
                }
              }
            }
          }

          // assetRef-based reference
          if (alias['assetRef'] is Map) {
            final assetRef = alias['assetRef'] as Map;
            print('\n🔗 assetRef reference: ${assetRef['key']?.toString().substring(0, 20)}...');
            print('   version (GUID): ${assetRef['version']}');
            print('   This references an EXTERNAL LIBRARY style - not in this file');
          }
        }
      }
    });

    test('follow full alias chain for bg/primary-elevated', () {
      print('🔍 Following full alias chain:');

      // Start with bg/primary-elevated (128:42123)
      final startKey = '128:42123';
      var currentKey = startKey;
      var depth = 0;
      final maxDepth = 10;

      while (depth < maxDepth) {
        final node = nodeMap[currentKey];
        if (node == null) {
          print('   ❌ Node $currentKey not found!');
          break;
        }

        print('\n📦 [$depth] $currentKey: ${node['name']} (${node['type']})');

        final variableDataValues = node['variableDataValues'];
        if (variableDataValues is! Map) {
          print('   No variableDataValues');
          break;
        }

        final entries = variableDataValues['entries'];
        if (entries is! List || entries.isEmpty) {
          print('   No entries');
          break;
        }

        // Look at Light mode entry (128:0)
        Map<String, dynamic>? lightEntry;
        for (final entry in entries) {
          if (entry is Map) {
            final modeID = entry['modeID'];
            if (modeID is Map && modeID['sessionID'] == 128 && modeID['localID'] == 0) {
              lightEntry = entry as Map<String, dynamic>;
              break;
            }
          }
        }

        if (lightEntry == null) {
          print('   No Light mode entry found, using first entry');
          lightEntry = entries[0] as Map<String, dynamic>;
        }

        final variableData = lightEntry['variableData'];
        if (variableData is! Map) {
          print('   No variableData');
          break;
        }

        print('   Light mode variableData: $variableData');

        final dataType = variableData['dataType']?.toString();
        final valueData = variableData['value'];

        if (dataType == 'COLOR' && valueData is Map) {
          final colorValue = valueData['colorValue'];
          if (colorValue is Map) {
            print('   ✅ FINAL COLOR: r=${colorValue['r']}, g=${colorValue['g']}, b=${colorValue['b']}, a=${colorValue['a']}');
            break;
          }
        }

        if (dataType == 'ALIAS' && valueData is Map) {
          final alias = valueData['alias'];
          if (alias is Map) {
            // Check for GUID alias
            if (alias['guid'] is Map) {
              final guid = alias['guid'] as Map;
              currentKey = '${guid['sessionID']}:${guid['localID']}';
              print('   → Following alias to: $currentKey');
              depth++;
              continue;
            }
            // Check for assetRef alias
            if (alias['assetRef'] is Map) {
              final assetRef = alias['assetRef'] as Map;
              print('   ⚠️ EXTERNAL assetRef: key=${assetRef['key']?.toString().substring(0, 20)}...');
              print('      version: ${assetRef['version']}');
              print('      This is an external library reference - cannot resolve further');
              break;
            }
          }
        }

        print('   Unknown structure, stopping');
        break;
      }
    });

    test('list all unresolvable assetRef GUIDs', () {
      print('📚 Analyzing assetRef GUIDs that reference external libraries:');

      final assetRefsByGuid = <String, int>{};
      final assetRefsBySessionId = <int, int>{};

      final nodeChanges = message['nodeChanges'] as List? ?? [];
      for (final node in nodeChanges) {
        if (node is Map) {
          final fills = node['fillPaints'] as List?;
          if (fills != null) {
            for (final fill in fills) {
              if (fill is Map) {
                final colorVar = fill['colorVar'];
                if (colorVar is Map) {
                  final value = colorVar['value'];
                  if (value is Map && value['alias'] is Map) {
                    final alias = value['alias'] as Map;
                    if (alias['assetRef'] is Map) {
                      final assetRef = alias['assetRef'] as Map;
                      final version = assetRef['version']?.toString() ?? '';
                      assetRefsByGuid[version] = (assetRefsByGuid[version] ?? 0) + 1;

                      final parts = version.split(':');
                      if (parts.length == 2) {
                        final sessionId = int.tryParse(parts[0]) ?? 0;
                        assetRefsBySessionId[sessionId] = (assetRefsBySessionId[sessionId] ?? 0) + 1;
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }

      print('\n📊 assetRef GUIDs by version (external library styles):');
      final sortedGuids = assetRefsByGuid.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      for (final entry in sortedGuids.take(20)) {
        print('   ${entry.key}: ${entry.value} references');
      }

      print('\n📊 assetRef by sessionID:');
      final sortedSessions = assetRefsBySessionId.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      for (final entry in sortedSessions) {
        print('   sessionID ${entry.key}: ${entry.value} references');
      }

      // These sessionIDs (362, 499, 500, etc.) are from the external Apple iOS UI Kit library
      // They are NOT in this file's nodeChanges
      print('\n💡 These sessionIDs are from EXTERNAL LIBRARIES (not in this file)');
      print('   The colors for these need to be resolved differently - they may');
      print('   require having the source library file, or using fallback colors.');
    });

    test('explore message structure for external styles', () {
      print('📚 Exploring top-level message structure:');
      print('   Top-level keys: ${message.keys.toList()}');

      // Look for any style-related keys
      for (final key in message.keys) {
        final value = message[key];
        if (key.toLowerCase().contains('style') ||
            key.toLowerCase().contains('library') ||
            key.toLowerCase().contains('external') ||
            key.toLowerCase().contains('shared')) {
          print('\n📦 $key:');
          if (value is List) {
            print('   List with ${value.length} items');
            if (value.isNotEmpty) {
              print('   First item: ${value[0]}');
            }
          } else if (value is Map) {
            print('   Map with keys: ${value.keys.toList()}');
          } else {
            print('   $value');
          }
        }
      }

      // Look for STYLE type nodes
      print('\n🔍 Looking for STYLE type nodes:');
      final styleNodes = <String, Map<String, dynamic>>{};
      final nodeChanges = message['nodeChanges'] as List? ?? [];
      for (final node in nodeChanges) {
        if (node is Map) {
          final type = node['type']?.toString();
          if (type?.contains('STYLE') == true) {
            final guid = node['guid'];
            if (guid is Map) {
              final guidKey = '${guid['sessionID']}:${guid['localID']}';
              styleNodes[guidKey] = node as Map<String, dynamic>;
            }
          }
        }
      }
      print('   Found ${styleNodes.length} STYLE-related nodes');
      for (final entry in styleNodes.entries.take(5)) {
        print('   ${entry.key}: ${entry.value['type']} - ${entry.value['name']}');
        print('      Keys: ${entry.value.keys.toList()}');
      }
    });

    test('find assetRef keys in STYLE nodes', () {
      print('🔍 Looking for style nodes with assetRef keys:');

      // First collect all unique assetRef keys from fillPaints
      final assetRefKeys = <String>{};
      final nodeChanges = message['nodeChanges'] as List? ?? [];

      for (final node in nodeChanges) {
        if (node is Map) {
          final fills = node['fillPaints'] as List?;
          if (fills != null) {
            for (final fill in fills) {
              if (fill is Map) {
                final colorVar = fill['colorVar'];
                if (colorVar is Map) {
                  final value = colorVar['value'];
                  if (value is Map && value['alias'] is Map) {
                    final alias = value['alias'] as Map;
                    if (alias['assetRef'] is Map) {
                      final assetRef = alias['assetRef'] as Map;
                      final key = assetRef['key']?.toString() ?? '';
                      if (key.isNotEmpty) {
                        assetRefKeys.add(key);
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }

      print('📊 Found ${assetRefKeys.length} unique assetRef keys in fills');

      // Now look for STYLE nodes that might have these keys or contain color definitions
      print('\n🔍 Examining all STYLE nodes for color definitions:');
      for (final node in nodeChanges) {
        if (node is Map) {
          final type = node['type']?.toString();
          if (type?.contains('STYLE') == true) {
            final guid = node['guid'];
            if (guid is Map) {
              final guidKey = '${guid['sessionID']}:${guid['localID']}';

              // Check for any color-related properties
              final styleKey = node['styleKey']?.toString() ?? '';
              final styleType = node['styleType']?.toString() ?? '';
              final fillPaints = node['fillPaints'];
              final strokePaints = node['strokePaints'];

              // Check if this style has a matching key
              if (assetRefKeys.contains(styleKey)) {
                print('\n✅ MATCHED STYLE $guidKey:');
                print('   styleKey: $styleKey');
                print('   styleType: $styleType');
                print('   All keys: ${node.keys.toList()}');
              }

              // Also print styles with fillPaints (potential color definitions)
              if (fillPaints != null && fillPaints is List && fillPaints.isNotEmpty) {
                print('\n🎨 STYLE with fills $guidKey: ${node['name']}');
                print('   styleKey: $styleKey');
                print('   fillPaints: $fillPaints');
              }
            }
          }
        }
      }
    });

    test('test VariableColorResolver with real data', () {
      // Import and test the actual resolver
      final resolver = _TestVariableColorResolver(nodeMap: nodeMap);

      // Test resolving Card's colorVar (should follow alias chain to white)
      print('🧪 Testing VariableColorResolver:');

      // Simulate the colorVar structure from Card node
      final cardColorVar = {
        'value': {
          'alias': {
            'guid': {'sessionID': 128, 'localID': 42123}
          }
        },
        'dataType': 'ALIAS',
        'resolvedDataType': 'COLOR'
      };

      final color = resolver.resolveColorVar(cardColorVar, debug: true);
      print('   Card colorVar resolved to: $color');

      // Test resolving a colorful variable (system/teal)
      final tealColorVar = {
        'value': {
          'alias': {
            'guid': {'sessionID': 128, 'localID': 42087}
          }
        },
        'dataType': 'ALIAS',
        'resolvedDataType': 'COLOR'
      };

      final tealColor = resolver.resolveColorVar(tealColorVar, debug: true);
      print('   Teal colorVar resolved to: $tealColor');

      // Test resolving system/red
      final redColorVar = {
        'value': {
          'alias': {
            'guid': {'sessionID': 128, 'localID': 42082}
          }
        },
        'dataType': 'ALIAS',
        'resolvedDataType': 'COLOR'
      };

      final redColor = resolver.resolveColorVar(redColorVar, debug: true);
      print('   Red colorVar resolved to: $redColor');

      // Verify the colors are correct
      expect(color, isNotNull, reason: 'Card color should resolve');
      expect(tealColor, isNotNull, reason: 'Teal color should resolve');
      expect(redColor, isNotNull, reason: 'Red color should resolve');
    });

    test('find SF Symbol icons', () {
      print('🔍 Looking for SF Symbol icons (play, download, tabs):');

      final sfSymbolNodes = <Map<String, dynamic>>[];
      final nodeChanges = message['nodeChanges'] as List? ?? [];

      for (final node in nodeChanges) {
        if (node is Map) {
          final type = node['type']?.toString();
          final name = node['name']?.toString() ?? '';

          // Look for text nodes that might contain SF Symbols
          if (type == 'TEXT') {
            final textData = node['textData'];
            String? characters;

            if (textData is Map) {
              characters = textData['characters']?.toString();
            }
            // Also check styledTextSegments
            final segments = node['styledTextSegments'];
            if (segments is List && segments.isNotEmpty) {
              final firstSeg = segments[0];
              if (firstSeg is Map) {
                characters ??= firstSeg['characters']?.toString();
              }
            }

            if (characters != null && characters.isNotEmpty) {
              // Check for surrogate pairs (SF Symbols)
              bool hasSFSymbol = false;
              for (int i = 0; i < characters.length; i++) {
                final code = characters.codeUnitAt(i);
                if (code >= 0xD800 && code <= 0xDBFF) {
                  hasSFSymbol = true;
                  break;
                }
              }

              if (hasSFSymbol) {
                sfSymbolNodes.add({
                  'name': name,
                  'guid': node['guid'],
                  'characters': characters,
                  'charCodes': characters.codeUnits.toList(),
                  'fontFamily': node['fontMetaData']?.values?.first?['family'] ?? node['fontName']?['family'],
                });
              }
            }
          }

          // Also look for nodes named like icons
          if (name.toLowerCase().contains('play') ||
              name.toLowerCase().contains('download') ||
              name.toLowerCase().contains('tab') ||
              name.toLowerCase().contains('icon')) {
            if (type != 'TEXT') {
              sfSymbolNodes.add({
                'name': name,
                'type': type,
                'guid': node['guid'],
                'hasChildren': node['children'] != null,
              });
            }
          }
        }
      }

      print('📊 Found ${sfSymbolNodes.length} potential SF Symbol nodes');

      // Group by type
      final textNodes = sfSymbolNodes.where((n) => n['characters'] != null).toList();
      final otherNodes = sfSymbolNodes.where((n) => n['characters'] == null).toList();

      print('\n📝 TEXT nodes with SF Symbols: ${textNodes.length}');
      for (final node in textNodes.take(10)) {
        final chars = node['characters'] as String;
        final codes = node['charCodes'] as List;
        print('   "${node['name']}": chars=${chars.length} codes=$codes font=${node['fontFamily']}');
      }

      print('\n🎨 Other icon-related nodes: ${otherNodes.length}');
      for (final node in otherNodes.take(15)) {
        print('   "${node['name']}" (${node['type']}) hasChildren=${node['hasChildren']}');
      }
    });

    test('find colorful podcast elements', () {
      print('🎨 Looking for colorful elements (teal, red, gradients):');

      final colorfulNodes = <Map<String, dynamic>>[];
      final nodeChanges = message['nodeChanges'] as List? ?? [];

      for (final node in nodeChanges) {
        if (node is Map) {
          final fills = node['fillPaints'] as List?;
          if (fills != null) {
            for (final fill in fills) {
              if (fill is Map && fill['visible'] != false) {
                final color = fill['color'];
                if (color is Map) {
                  final r = (color['r'] as num?)?.toDouble() ?? 0;
                  final g = (color['g'] as num?)?.toDouble() ?? 0;
                  final b = (color['b'] as num?)?.toDouble() ?? 0;

                  // Look for non-white, non-black, non-gray colors
                  final isGray = (r - g).abs() < 0.05 && (g - b).abs() < 0.05;
                  final isColorful = !isGray && (r > 0.1 || g > 0.1 || b > 0.1);

                  if (isColorful) {
                    colorfulNodes.add({
                      'name': node['name'],
                      'type': node['type'],
                      'guid': node['guid'],
                      'color': color,
                      'fillType': fill['type'],
                      'hasColorVar': fill['colorVar'] != null,
                    });
                  }
                }

                // Also look for gradients
                final fillType = fill['type']?.toString();
                if (fillType?.startsWith('GRADIENT_') == true) {
                  colorfulNodes.add({
                    'name': node['name'],
                    'type': node['type'],
                    'guid': node['guid'],
                    'fillType': fillType,
                    'gradientStops': fill['gradientStops'],
                  });
                }
              }
            }
          }
        }
      }

      print('📊 Found ${colorfulNodes.length} colorful/gradient nodes');

      // Group by type
      final byType = <String, int>{};
      for (final node in colorfulNodes) {
        final type = node['type']?.toString() ?? 'unknown';
        byType[type] = (byType[type] ?? 0) + 1;
      }
      print('\nBy node type:');
      for (final entry in byType.entries) {
        print('   ${entry.key}: ${entry.value}');
      }

      // Show some colorful ones
      print('\n🎨 Sample colorful nodes:');
      for (final node in colorfulNodes.take(15)) {
        final name = node['name'] ?? 'unnamed';
        final type = node['type'];
        final fillType = node['fillType'];
        final hasColorVar = node['hasColorVar'] == true;
        final color = node['color'];

        if (color != null) {
          final r = (color['r'] as num?)?.toDouble() ?? 0;
          final g = (color['g'] as num?)?.toDouble() ?? 0;
          final b = (color['b'] as num?)?.toDouble() ?? 0;
          final hexR = (r * 255).round().clamp(0, 255);
          final hexG = (g * 255).round().clamp(0, 255);
          final hexB = (b * 255).round().clamp(0, 255);
          print('   $name ($type): $fillType #${hexR.toRadixString(16).padLeft(2, '0')}${hexG.toRadixString(16).padLeft(2, '0')}${hexB.toRadixString(16).padLeft(2, '0')} colorVar=$hasColorVar');
        } else {
          print('   $name ($type): $fillType (gradient)');
        }
      }
    });

    test('search for shared component styles', () {
      print('🔍 Looking for sharedStyleMasterData or component definitions:');

      // Check for sharedStyleMasterData in message
      if (message.containsKey('sharedStyleMasterData')) {
        final data = message['sharedStyleMasterData'];
        print('   sharedStyleMasterData: $data');
      }

      // Check for sharedComponentMasterData
      if (message.containsKey('sharedComponentMasterData')) {
        final data = message['sharedComponentMasterData'];
        print('   sharedComponentMasterData found:');
        if (data is Map) {
          for (final key in data.keys.take(5)) {
            print('      $key: ${data[key]}');
          }
        }
      }

      // Look for libraryDependencies
      if (message.containsKey('libraryDependencies')) {
        final deps = message['libraryDependencies'];
        print('   libraryDependencies: $deps');
      }

      // Print all top-level keys
      print('\n📋 All message keys:');
      for (final key in message.keys) {
        final value = message[key];
        String valueDesc;
        if (value is List) {
          valueDesc = 'List(${value.length})';
        } else if (value is Map) {
          valueDesc = 'Map(${value.length} keys)';
        } else if (value is String && value.length > 50) {
          valueDesc = 'String(${value.length} chars)';
        } else {
          valueDesc = '$value';
        }
        print('   $key: $valueDesc');
      }
    });
  });
}

/// Test version of VariableColorResolver that doesn't depend on Flutter Color
class _TestVariableColorResolver {
  final Map<String, Map<String, dynamic>>? nodeMap;
  final String currentModeId;
  final Map<String, Map<String, double>?> _cache = {};

  _TestVariableColorResolver({
    required this.nodeMap,
    this.currentModeId = '128:0',
  });

  Map<String, double>? resolveColorVar(Map<String, dynamic>? colorVar, {int maxDepth = 10, bool debug = false}) {
    if (colorVar == null || nodeMap == null || maxDepth <= 0) return null;

    final value = colorVar['value'];
    if (value is! Map) return null;

    final alias = value['alias'];
    if (alias is! Map) return null;

    if (alias['guid'] is Map) {
      final guid = alias['guid'] as Map;
      final guidKey = '${guid['sessionID']}:${guid['localID']}';

      if (_cache.containsKey(guidKey)) {
        if (debug) print('🔗 RESOLVED colorVar (cached): $guidKey -> ${_cache[guidKey]}');
        return _cache[guidKey];
      }

      final color = _resolveVariableGuid(guidKey, maxDepth: maxDepth - 1, debug: debug);
      _cache[guidKey] = color;
      if (debug && color != null) {
        print('🔗 RESOLVED colorVar: $guidKey -> $color');
      }
      return color;
    }

    if (alias['assetRef'] is Map) {
      if (debug) print('⚠️ assetRef reference - cannot resolve');
      return null;
    }

    return null;
  }

  Map<String, double>? _resolveVariableGuid(String guidKey, {int maxDepth = 10, bool debug = false}) {
    if (maxDepth <= 0) return null;

    final varNode = nodeMap?[guidKey];
    if (varNode == null) return null;

    final type = varNode['type']?.toString();
    if (type != 'VARIABLE') return null;

    final variableDataValues = varNode['variableDataValues'];
    if (variableDataValues is! Map) return null;

    final entries = variableDataValues['entries'];
    if (entries is! List) return null;

    final modeParts = currentModeId.split(':');
    final modeSessionId = modeParts.isNotEmpty ? int.tryParse(modeParts[0]) : null;
    final modeLocalId = modeParts.length > 1 ? int.tryParse(modeParts[1]) : null;

    Map<String, dynamic>? matchingEntry;
    Map<String, dynamic>? firstEntry;

    for (final entry in entries) {
      if (entry is! Map) continue;
      firstEntry ??= entry as Map<String, dynamic>;

      final modeID = entry['modeID'];
      if (modeID is Map) {
        if (modeID['sessionID'] == modeSessionId && modeID['localID'] == modeLocalId) {
          matchingEntry = entry as Map<String, dynamic>;
          break;
        }
      }
    }

    final entryToUse = matchingEntry ?? firstEntry;
    if (entryToUse == null) return null;

    final variableData = entryToUse['variableData'];
    if (variableData is! Map) return null;

    final dataType = variableData['dataType']?.toString();
    final valueData = variableData['value'];
    if (valueData is! Map) return null;

    if (dataType == 'COLOR') {
      final colorValue = valueData['colorValue'];
      if (colorValue is Map) {
        if (debug) print('   Found direct COLOR at $guidKey: $colorValue');
        return {
          'r': (colorValue['r'] as num?)?.toDouble() ?? 0,
          'g': (colorValue['g'] as num?)?.toDouble() ?? 0,
          'b': (colorValue['b'] as num?)?.toDouble() ?? 0,
          'a': (colorValue['a'] as num?)?.toDouble() ?? 1.0,
        };
      }
    }

    if (dataType == 'ALIAS') {
      final alias = valueData['alias'];
      if (alias is Map) {
        final aliasGuid = alias['guid'];
        if (aliasGuid is Map) {
          final aliasKey = '${aliasGuid['sessionID']}:${aliasGuid['localID']}';
          if (debug) print('   Following ALIAS at $guidKey -> $aliasKey');
          return _resolveVariableGuid(aliasKey, maxDepth: maxDepth - 1, debug: debug);
        }
      }
    }

    return null;
  }
}
