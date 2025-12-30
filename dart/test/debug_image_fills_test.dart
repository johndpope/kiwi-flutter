/// Debug test to analyze IMAGE fill structure
///
/// Run with: flutter test test/debug_image_fills_test.dart

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwi_schema/kiwi.dart';
import 'package:kiwi_schema/flutter_renderer.dart';

void main() {
  late FigmaDocument document;
  late Map<String, Map<String, dynamic>> nodeMap;
  late Map<String, List<int>>? blobMap;

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
    blobMap = document.blobMap;
  });

  test('analyze IMAGE fill structure', () {
    print('\n=== IMAGE FILL STRUCTURE ANALYSIS ===\n');

    int count = 0;
    for (final node in nodeMap.values) {
      final fills = node['fillPaints'] as List? ?? [];
      for (final fill in fills) {
        if (fill is Map && fill['type'] == 'IMAGE') {
          if (count < 10) {
            print('Node: ${node['name']} (${node['type']})');
            print('Fill keys: ${fill.keys.toList()}');

            // Print all values
            for (final key in fill.keys) {
              final value = fill[key];
              if (value is Map) {
                print('  $key: Map with keys ${value.keys.toList()}');
                if (key == 'image' || key == 'imageRef') {
                  for (final subKey in value.keys) {
                    final subValue = value[subKey];
                    if (subValue is List) {
                      print('    $subKey: List[${subValue.length}] first=${subValue.take(5).toList()}');
                    } else {
                      print('    $subKey: $subValue');
                    }
                  }
                }
              } else if (value is List) {
                print('  $key: List[${value.length}]');
              } else {
                print('  $key: $value');
              }
            }
            print('');
          }
          count++;
        }
      }
    }
    print('Total IMAGE fills: $count');
  });

  test('analyze blobMap structure', () {
    print('\n=== BLOBMAP STRUCTURE ===\n');
    print('BlobMap keys count: ${blobMap?.length ?? 0}');

    if (blobMap != null) {
      final keys = blobMap!.keys.take(20).toList();
      print('First 20 keys: $keys');

      for (final key in keys.take(5)) {
        final data = blobMap![key];
        print('  blob[$key]: ${data?.length ?? 0} bytes, first 10: ${data?.take(10).toList()}');
      }
    }
  });

  test('find matching blobs for images', () {
    print('\n=== BLOB MATCHING ANALYSIS ===\n');

    int matched = 0;
    int unmatched = 0;

    for (final node in nodeMap.values) {
      final fills = node['fillPaints'] as List? ?? [];
      for (final fill in fills) {
        if (fill is Map && fill['type'] == 'IMAGE') {
          // Try different blob reference fields
          final blobIndex = fill['imagePaintDataIndex'] ?? fill['blobIndex'];
          final imageHash = fill['imageHash'];
          final image = fill['image'] as Map?;

          bool found = false;
          String? matchKey;

          if (blobIndex != null && blobMap?.containsKey(blobIndex.toString()) == true) {
            found = true;
            matchKey = 'imagePaintDataIndex=$blobIndex';
            matched++;
          } else if (imageHash != null && blobMap?.containsKey(imageHash.toString()) == true) {
            found = true;
            matchKey = 'imageHash=$imageHash';
            matched++;
          } else if (image != null) {
            final hash = image['hash'];
            if (hash is List && hash.isNotEmpty) {
              // Try numeric index
              final possibleIndex = hash[0];
              if (blobMap?.containsKey(possibleIndex.toString()) == true) {
                found = true;
                matchKey = 'image.hash[0]=$possibleIndex';
                matched++;
              }
            }
          }

          if (!found) {
            unmatched++;
            if (unmatched <= 10) {
              print('UNMATCHED: ${node['name']}');
              print('  imagePaintDataIndex: $blobIndex');
              print('  imageHash: $imageHash');
              print('  image: ${image?.keys.toList()}');
              if (image != null && image['hash'] is List) {
                print('  image.hash: ${(image['hash'] as List).take(5).toList()}');
              }
              print('');
            }
          } else if (matched <= 5) {
            print('MATCHED: ${node['name']} via $matchKey');
          }
        }
      }
    }

    print('\n=== RESULTS ===');
    print('Matched: $matched');
    print('Unmatched: $unmatched');
  });
}
