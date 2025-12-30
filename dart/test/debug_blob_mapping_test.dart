/// Debug test to understand blob-to-image mapping
///
/// Run with: flutter test test/debug_blob_mapping_test.dart

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwi_schema/kiwi.dart';

void main() {
  test('analyze raw message structure for images', () async {
    final schemaFile = File('test/fixtures/figma_schema.bin');
    final messageFile = File('test/fixtures/figma_message.bin');

    final schemaBytes = await schemaFile.readAsBytes();
    final messageBytes = await messageFile.readAsBytes();

    final schema = decodeBinarySchema(schemaBytes);
    final compiled = compileSchema(schema);
    final message = compiled.decode('Message', messageBytes);

    print('\n=== MESSAGE TOP-LEVEL KEYS ===');
    if (message is Map) {
      print('Keys: ${message.keys.toList()}');

      // Check blobs structure
      final blobs = message['blobs'] as List?;
      if (blobs != null) {
        print('\n=== BLOB STRUCTURE ===');
        print('Total blobs: ${blobs.length}');

        for (int i = 0; i < blobs.length && i < 5; i++) {
          final blob = blobs[i];
          if (blob is Map) {
            print('Blob[$i] keys: ${blob.keys.toList()}');
            final bytes = blob['bytes'];
            if (bytes is List) {
              print('  bytes: ${bytes.length} bytes');
              // Check if it looks like an image (PNG/JPEG headers)
              if (bytes.length > 8) {
                final header = bytes.take(8).toList();
                print('  header: $header');
                if (header[0] == 0x89 && header[1] == 0x50) {
                  print('  FORMAT: PNG');
                } else if (header[0] == 0xFF && header[1] == 0xD8) {
                  print('  FORMAT: JPEG');
                } else if (header[0] == 0x52 && header[1] == 0x49) {
                  print('  FORMAT: WEBP');
                }
              }
            }
          }
        }
      }

      // Check for images map
      if (message.containsKey('images')) {
        print('\n=== IMAGES MAP ===');
        final images = message['images'];
        print('Type: ${images.runtimeType}');
        if (images is Map) {
          print('Keys sample: ${images.keys.take(5).toList()}');
        }
      }

      // Check for paintImages
      if (message.containsKey('paintImages')) {
        print('\n=== PAINT IMAGES ===');
        final paintImages = message['paintImages'];
        print('Type: ${paintImages.runtimeType}');
        if (paintImages is List) {
          print('Count: ${paintImages.length}');
          for (int i = 0; i < paintImages.length && i < 3; i++) {
            print('paintImages[$i]: ${paintImages[i]}');
          }
        }
      }

      // Check nodeChanges for image references
      print('\n=== IMAGE REFERENCES IN NODES ===');
      final nodeChanges = message['nodeChanges'] as List?;
      if (nodeChanges != null) {
        int imageFillCount = 0;
        final uniqueHashes = <String>{};

        for (final change in nodeChanges) {
          if (change is Map) {
            final fills = change['fillPaints'] as List? ?? [];
            for (final fill in fills) {
              if (fill is Map && fill['type'] == 'IMAGE') {
                imageFillCount++;
                final image = fill['image'] as Map?;
                if (image != null) {
                  final hash = image['hash'];
                  if (hash is List) {
                    final hashStr = hash.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
                    uniqueHashes.add(hashStr);
                  }
                }
              }
            }
          }
        }

        print('Total IMAGE fills: $imageFillCount');
        print('Unique image hashes: ${uniqueHashes.length}');
        print('Sample hashes:');
        for (final hash in uniqueHashes.take(5)) {
          print('  $hash');
        }
      }
    }
  });

  test('check if blob bytes match image data', () async {
    final schemaFile = File('test/fixtures/figma_schema.bin');
    final messageFile = File('test/fixtures/figma_message.bin');

    final schemaBytes = await schemaFile.readAsBytes();
    final messageBytes = await messageFile.readAsBytes();

    final schema = decodeBinarySchema(schemaBytes);
    final compiled = compileSchema(schema);
    final message = compiled.decode('Message', messageBytes);

    final blobs = message['blobs'] as List? ?? [];

    print('\n=== BLOB FORMAT ANALYSIS ===');

    int pngCount = 0;
    int jpegCount = 0;
    int webpCount = 0;
    int otherCount = 0;
    int vectorCount = 0;

    for (int i = 0; i < blobs.length; i++) {
      final blob = blobs[i];
      if (blob is Map) {
        final bytes = blob['bytes'];
        if (bytes is List && bytes.length > 8) {
          final h = bytes.take(8).toList();
          if (h[0] == 0x89 && h[1] == 0x50 && h[2] == 0x4E && h[3] == 0x47) {
            pngCount++;
          } else if (h[0] == 0xFF && h[1] == 0xD8 && h[2] == 0xFF) {
            jpegCount++;
          } else if (h[0] == 0x52 && h[1] == 0x49 && h[2] == 0x46 && h[3] == 0x46) {
            webpCount++;
          } else {
            // Might be vector data or other binary
            otherCount++;
            if (i < 3) {
              print('Blob[$i] unknown format: header=$h size=${bytes.length}');
            }
          }
        } else {
          vectorCount++;
        }
      }
    }

    print('PNG images: $pngCount');
    print('JPEG images: $jpegCount');
    print('WEBP images: $webpCount');
    print('Other/binary: $otherCount');
    print('Small/vector: $vectorCount');
    print('Total: ${blobs.length}');
  });
}
