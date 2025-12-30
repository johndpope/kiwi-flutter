/// Fetch Figma images using the Figma file/image/batch API
///
/// This script mimics what the Figma web app does to fetch images:
/// 1. Reads the .fig file to get all image hashes
/// 2. Calls the file/image/batch endpoint to get signed URLs
/// 3. Downloads the images and saves them with their hash names
///
/// Usage: dart scripts/fetch_figma_images.dart
///
/// You will need to set FIGMA_FILE_KEY environment variable or edit the script
/// The script will guide you through getting authentication tokens

import 'dart:convert';
import 'dart:io';
import 'package:kiwi_schema/kiwi.dart';

void main(List<String> args) async {
  // Configuration
  final fileKey = Platform.environment['FIGMA_FILE_KEY'] ?? 'pGelQwws3OkfbtVmeHDLwN';
  final outputDir = 'images';

  print('=== Figma Image Fetcher ===\n');
  print('File key: $fileKey');
  print('Output directory: $outputDir\n');

  // Step 1: Read the Figma message to get all image hashes
  print('Step 1: Reading Figma message to extract image hashes...');

  final schemaFile = File('test/fixtures/figma_schema.bin');
  final messageFile = File('test/fixtures/figma_message.bin');

  if (!schemaFile.existsSync() || !messageFile.existsSync()) {
    print('ERROR: Missing fixture files. Run the tests first to generate them.');
    exit(1);
  }

  final schemaBytes = await schemaFile.readAsBytes();
  final messageBytes = await messageFile.readAsBytes();

  final schema = decodeBinarySchema(schemaBytes);
  final compiled = compileSchema(schema);
  final message = compiled.decode('Message', messageBytes);

  // Extract all image hashes from nodeChanges
  final imageHashes = <String>{};

  final nodeChanges = message['nodeChanges'] as List? ?? [];
  for (final node in nodeChanges) {
    if (node is Map) {
      // Check fillPaints
      final fills = node['fillPaints'] as List? ?? [];
      for (final fill in fills) {
        if (fill is Map && fill['type'] == 'IMAGE') {
          final image = fill['image'] as Map?;
          if (image != null) {
            final hash = image['hash'];
            if (hash is List && hash.isNotEmpty) {
              // Convert bytes to hex string
              final hashStr = hash.map((b) => (b as int).toRadixString(16).padLeft(2, '0')).join();
              imageHashes.add(hashStr);
            }
          }
        }
      }
    }
  }

  print('Found ${imageHashes.length} unique image hashes\n');

  if (imageHashes.isEmpty) {
    print('No images to fetch.');
    exit(0);
  }

  // Step 2: Read existing mapping or create new one
  final dir = Directory(outputDir);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  final mappingFile = File('$outputDir/hash_to_url.json');
  Map<String, String> hashToUrl = {};

  if (mappingFile.existsSync()) {
    try {
      final content = await mappingFile.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      hashToUrl = Map<String, String>.from(data);
      print('Loaded existing mapping with ${hashToUrl.length} entries');
    } catch (e) {
      print('Could not load existing mapping: $e');
    }
  }

  // Check which hashes we're missing
  final missingHashes = imageHashes.where((h) => !hashToUrl.containsKey(h)).toSet();

  print('Missing ${missingHashes.length} image URLs');

  if (missingHashes.isEmpty) {
    print('All images already have URLs. Proceeding to download...\n');
  } else {
    // Step 3: Explain how to get the image URLs
    print('\n=== MANUAL STEP REQUIRED ===\n');
    print('To fetch image URLs, you need to make a POST request to:');
    print('  https://www.figma.com/file/$fileKey/image/batch');
    print('\nWith headers:');
    print('  Content-Type: application/json');
    print('  Cookie: <your Figma session cookies>');
    print('\nAnd body:');
    print('  {"sha1s": [...], "needs_compressed_textures": false}');
    print('\nThe first 10 missing hashes are:');
    for (final hash in missingHashes.take(10)) {
      print('  "$hash",');
    }

    // Save hashes for manual use
    final hashesFile = File('$outputDir/missing_hashes.json');
    await hashesFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'file_key': fileKey,
        'hashes': missingHashes.toList(),
        'count': missingHashes.length,
      }),
    );
    print('\nFull list saved to: ${hashesFile.path}');

    print('\n=== ALTERNATIVE: Use Browser Developer Tools ===\n');
    print('1. Open the Figma file in Chrome: https://www.figma.com/design/$fileKey');
    print('2. Open Developer Tools (F12)');
    print('3. Go to Network tab');
    print('4. Filter by "image/batch"');
    print('5. Right-click the request -> Copy -> Copy response');
    print('6. Paste into: $outputDir/image_batch_response.json');
    print('\nOnce you have the response, run this script again.\n');

    // Check if response file exists
    final responseFile = File('$outputDir/image_batch_response.json');
    if (responseFile.existsSync()) {
      print('Found image_batch_response.json, parsing...');
      try {
        final response = jsonDecode(await responseFile.readAsString());
        if (response is Map) {
          for (final entry in response.entries) {
            if (entry.value is String && entry.value.toString().contains('http')) {
              hashToUrl[entry.key.toString()] = entry.value.toString();
            } else if (entry.value is Map && entry.value['url'] != null) {
              hashToUrl[entry.key.toString()] = entry.value['url'].toString();
            }
          }
          print('Extracted ${hashToUrl.length} URLs from response');

          // Save updated mapping
          await mappingFile.writeAsString(
            const JsonEncoder.withIndent('  ').convert(hashToUrl),
          );
          print('Saved mapping to: ${mappingFile.path}');
        }
      } catch (e) {
        print('Error parsing response: $e');
      }
    }
  }

  // Step 4: Download images that we have URLs for
  print('\n=== Downloading Images ===\n');

  final client = HttpClient();
  int downloaded = 0;
  int skipped = 0;
  int failed = 0;

  for (final hash in imageHashes) {
    final outputPath = '$outputDir/$hash';

    // Skip if already exists
    if (File(outputPath).existsSync()) {
      skipped++;
      continue;
    }

    final url = hashToUrl[hash];
    if (url == null) {
      failed++;
      continue;
    }

    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode == 200) {
        final bytes = await response.fold<List<int>>(
          [],
          (buffer, chunk) => buffer..addAll(chunk),
        );

        await File(outputPath).writeAsBytes(bytes);
        downloaded++;

        if (downloaded <= 10) {
          print('Downloaded: $hash (${bytes.length} bytes)');
        } else if (downloaded % 20 == 0) {
          print('Progress: $downloaded downloaded...');
        }
      } else {
        print('HTTP ${response.statusCode} for $hash');
        failed++;
      }
    } catch (e) {
      print('Error downloading $hash: $e');
      failed++;
    }
  }

  client.close();

  print('\n=== Summary ===');
  print('Total image hashes: ${imageHashes.length}');
  print('Downloaded: $downloaded');
  print('Skipped (exists): $skipped');
  print('Failed (no URL or error): $failed');
  print('Output directory: $outputDir');
}
