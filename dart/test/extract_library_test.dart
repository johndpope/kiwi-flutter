import 'dart:io';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:kiwi_schema/kiwi.dart';

void main() {
  group('Apple iOS UI Kit Library', () {
    late Map<String, dynamic> libraryMessage;
    late Map<String, Map<String, dynamic>> libraryNodeMap;

    // First run this test to extract the library data
    test('extract library from .fig file', () async {
      final figFile = File('test/fixtures/apple_ui_kit.fig');
      if (!figFile.existsSync()) {
        print('apple_ui_kit.fig not found - skipping');
        return;
      }

      final data = figFile.readAsBytesSync();
      print('Read ${data.length} bytes from apple_ui_kit.fig');

      // Parse structure first
      final structure = parseFigFileStructure(data);
      print('Header: ${structure.header}');
      print('Schema chunk: ${structure.schemaChunk.compression} (${structure.schemaChunk.data.length} bytes)');
      print('Data chunk: ${structure.dataChunk.compression} (${structure.dataChunk.data.length} bytes)');

      // We need zstd and deflate decompression
      // For now, let's just print what we have
      print('\nTo extract, we need zstd decompression');
    }, skip: 'Run manually to extract');

    // Use pre-extracted data if available
    test('analyze library structure from pre-extracted', () {
      // Check if we have pre-extracted library data
      final schemaFile = File('test/fixtures/apple_ui_kit_schema.bin');
      final messageFile = File('test/fixtures/apple_ui_kit_message.bin');

      if (!schemaFile.existsSync() || !messageFile.existsSync()) {
        print('Pre-extracted library files not found.');
        print('Need to extract from apple_ui_kit.fig using zstd decompression');
        return;
      }

      final schemaBytes = schemaFile.readAsBytesSync();
      final messageBytes = messageFile.readAsBytesSync();

      final schema = decodeBinarySchema(schemaBytes);
      final compiled = compileSchema(schema);
      libraryMessage = compiled.decode('Message', messageBytes);

      // Build nodeMap
      libraryNodeMap = {};
      final nodeChanges = libraryMessage['nodeChanges'] as List? ?? [];
      for (final node in nodeChanges) {
        if (node is Map) {
          final guid = node['guid'];
          if (guid is Map) {
            final guidKey = '${guid['sessionID']}:${guid['localID']}';
            libraryNodeMap[guidKey] = node as Map<String, dynamic>;
          }
        }
      }

      print('Library has ${nodeChanges.length} nodes');
      print('Top-level keys: ${libraryMessage.keys.toList()}');
    }, skip: 'Pre-extracted files not available yet');

    test('find external library color styles in main file', () {
      // Load the main file
      final schemaFile = File('test/fixtures/figma_schema.bin');
      final messageFile = File('test/fixtures/figma_message.bin');

      final schemaBytes = schemaFile.readAsBytesSync();
      final messageBytes = messageFile.readAsBytesSync();

      final schema = decodeBinarySchema(schemaBytes);
      final compiled = compileSchema(schema);
      final message = compiled.decode('Message', messageBytes);

      // Collect all assetRef information
      final assetRefs = <Map<String, dynamic>>[];
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
                      final staticColor = fill['color'];
                      assetRefs.add({
                        'assetRef': assetRef,
                        'staticColor': staticColor,
                        'nodeName': node['name'],
                        'nodeGuid': node['guid'],
                      });
                    }
                  }
                }
              }
            }
          }
        }
      }

      print('Found ${assetRefs.length} assetRef color references');

      // Group by unique assetRef key
      final byKey = <String, List<Map<String, dynamic>>>{};
      for (final ref in assetRefs) {
        final key = (ref['assetRef'] as Map)['key']?.toString() ?? '';
        byKey.putIfAbsent(key, () => []).add(ref);
      }

      print('\n📊 Unique assetRef keys: ${byKey.length}');
      for (final entry in byKey.entries) {
        final key = entry.key;
        final refs = entry.value;
        final version = (refs[0]['assetRef'] as Map)['version'];
        final staticColor = refs[0]['staticColor'];

        print('\n🔑 key: ${key.substring(0, 40)}...');
        print('   version: $version');
        print('   used in ${refs.length} nodes');
        if (staticColor is Map) {
          final r = (staticColor['r'] as num?)?.toDouble() ?? 0;
          final g = (staticColor['g'] as num?)?.toDouble() ?? 0;
          final b = (staticColor['b'] as num?)?.toDouble() ?? 0;
          final a = (staticColor['a'] as num?)?.toDouble() ?? 1;
          print('   staticColor: r=${r.toStringAsFixed(3)}, g=${g.toStringAsFixed(3)}, b=${b.toStringAsFixed(3)}, a=${a.toStringAsFixed(3)}');

          // Convert to hex
          final hexR = (r * 255).round().clamp(0, 255);
          final hexG = (g * 255).round().clamp(0, 255);
          final hexB = (b * 255).round().clamp(0, 255);
          print('   hex: #${hexR.toRadixString(16).padLeft(2, '0')}${hexG.toRadixString(16).padLeft(2, '0')}${hexB.toRadixString(16).padLeft(2, '0')}');
        }
      }
    });

    test('create color mapping from static colors', () {
      // Load the main file
      final schemaFile = File('test/fixtures/figma_schema.bin');
      final messageFile = File('test/fixtures/figma_message.bin');

      final schemaBytes = schemaFile.readAsBytesSync();
      final messageBytes = messageFile.readAsBytesSync();

      final schema = decodeBinarySchema(schemaBytes);
      final compiled = compileSchema(schema);
      final message = compiled.decode('Message', messageBytes);

      // Build mapping from assetRef key to static color
      final colorMapping = <String, Map<String, double>>{};
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
                      final staticColor = fill['color'];

                      if (key.isNotEmpty && staticColor is Map && !colorMapping.containsKey(key)) {
                        final r = (staticColor['r'] as num?)?.toDouble() ?? 0;
                        final g = (staticColor['g'] as num?)?.toDouble() ?? 0;
                        final b = (staticColor['b'] as num?)?.toDouble() ?? 0;
                        final a = (staticColor['a'] as num?)?.toDouble() ?? 1;
                        colorMapping[key] = {'r': r, 'g': g, 'b': b, 'a': a};
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }

      print('Created color mapping with ${colorMapping.length} entries');
      print('\n// Generated assetRef color mapping:');
      print('const Map<String, Map<String, double>> _assetRefColors = {');
      for (final entry in colorMapping.entries) {
        final key = entry.key;
        final color = entry.value;
        print("  '$key': {'r': ${color['r']}, 'g': ${color['g']}, 'b': ${color['b']}, 'a': ${color['a']}},");
      }
      print('};');
    });
  });
}
