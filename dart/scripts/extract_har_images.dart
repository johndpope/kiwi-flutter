/// Extract images from HAR file and save them for use with the renderer
///
/// Run with: dart scripts/extract_har_images.dart ~/Desktop/test.json images/

import 'dart:convert';
import 'dart:io';

void main(List<String> args) async {
  if (args.length < 2) {
    print('Usage: dart extract_har_images.dart <har_file> <output_dir>');
    exit(1);
  }

  final harPath = args[0];
  final outputDir = args[1];

  print('Reading HAR file: $harPath');
  final harContent = await File(harPath).readAsString();
  final har = jsonDecode(harContent) as Map<String, dynamic>;

  // Create output directory
  final dir = Directory(outputDir);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  final log = har['log'] as Map<String, dynamic>;
  final entries = log['entries'] as List;

  print('Found ${entries.length} entries');

  int imageCount = 0;
  int savedCount = 0;
  final savedImages = <String, String>{};

  for (final entry in entries) {
    final request = entry['request'] as Map<String, dynamic>;
    final response = entry['response'] as Map<String, dynamic>;
    final url = request['url'] as String;

    final content = response['content'] as Map<String, dynamic>?;
    if (content == null) continue;

    final mimeType = content['mimeType'] as String?;
    if (mimeType == null) continue;

    // Check if it's an image
    if (mimeType.startsWith('image/')) {
      imageCount++;

      final text = content['text'] as String?;
      final encoding = content['encoding'] as String?;

      if (text != null && text.isNotEmpty) {
        // Extract the hash from the URL
        String? hash;
        if (url.contains('/uploads/')) {
          final match = RegExp(r'/uploads/([a-f0-9]+)').firstMatch(url);
          hash = match?.group(1);
        } else if (url.contains('figma')) {
          // Use URL hash or filename
          hash = url.split('/').last.split('?').first.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
        }

        if (hash != null && hash.isNotEmpty) {
          try {
            List<int> bytes;
            if (encoding == 'base64') {
              bytes = base64Decode(text);
            } else {
              bytes = utf8.encode(text);
            }

            // Determine extension
            String ext = 'bin';
            if (mimeType.contains('png')) ext = 'png';
            else if (mimeType.contains('jpeg') || mimeType.contains('jpg')) ext = 'jpg';
            else if (mimeType.contains('webp')) ext = 'webp';
            else if (mimeType.contains('gif')) ext = 'gif';
            else if (mimeType.contains('svg')) ext = 'svg';

            final outputPath = '$outputDir/$hash';
            await File(outputPath).writeAsBytes(bytes);
            savedCount++;
            savedImages[hash] = outputPath;

            if (savedCount <= 10) {
              print('Saved: $hash ($mimeType, ${bytes.length} bytes)');
            }
          } catch (e) {
            print('Error processing $hash: $e');
          }
        }
      }
    }
  }

  print('');
  print('=== Summary ===');
  print('Total image entries: $imageCount');
  print('Saved images: $savedCount');
  print('Output directory: $outputDir');

  // Save mapping file
  final mappingPath = '$outputDir/image_mapping.json';
  await File(mappingPath).writeAsString(
    const JsonEncoder.withIndent('  ').convert(savedImages),
  );
  print('Mapping saved to: $mappingPath');
}
