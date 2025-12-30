/// Download Figma images from URLs found in HAR file
///
/// Run with: dart scripts/download_figma_images.dart ~/Desktop/test.json images/

import 'dart:convert';
import 'dart:io';

void main(List<String> args) async {
  if (args.length < 2) {
    print('Usage: dart download_figma_images.dart <har_file> <output_dir>');
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

  // Collect all image URLs
  final imageUrls = <String>{};

  for (final entry in entries) {
    final request = entry['request'] as Map<String, dynamic>;
    final response = entry['response'] as Map<String, dynamic>;
    final url = request['url'] as String;

    final content = response['content'] as Map<String, dynamic>?;
    if (content == null) continue;

    final mimeType = content['mimeType'] as String?;
    if (mimeType == null) continue;

    // Check if it's an image or figma upload
    if (mimeType.startsWith('image/') || url.contains('/uploads/')) {
      if (url.contains('static.figma.com')) {
        imageUrls.add(url);
      }
    }
  }

  print('Found ${imageUrls.length} unique image URLs');

  // Download each image
  final client = HttpClient();
  int downloadCount = 0;
  int errorCount = 0;
  final savedImages = <String, String>{};

  for (final url in imageUrls) {
    // Extract hash from URL
    String? hash;
    if (url.contains('/uploads/')) {
      final match = RegExp(r'/uploads/([a-f0-9]+)').firstMatch(url);
      hash = match?.group(1);
    }

    if (hash == null) {
      // Use last path segment
      hash = url.split('/').last.split('?').first;
    }

    if (hash.isEmpty) continue;

    final outputPath = '$outputDir/$hash';

    // Skip if already downloaded
    if (File(outputPath).existsSync()) {
      print('  Already exists: $hash');
      savedImages[hash] = outputPath;
      downloadCount++;
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
        savedImages[hash] = outputPath;
        downloadCount++;

        if (downloadCount <= 20) {
          print('Downloaded: $hash (${bytes.length} bytes)');
        } else if (downloadCount % 50 == 0) {
          print('Progress: $downloadCount/${imageUrls.length}');
        }
      } else {
        print('Error ${response.statusCode}: $hash');
        errorCount++;
      }
    } catch (e) {
      print('Error downloading $hash: $e');
      errorCount++;
    }
  }

  client.close();

  print('');
  print('=== Summary ===');
  print('Total URLs: ${imageUrls.length}');
  print('Downloaded: $downloadCount');
  print('Errors: $errorCount');
  print('Output directory: $outputDir');

  // Save mapping file
  final mappingPath = '$outputDir/image_mapping.json';
  await File(mappingPath).writeAsString(
    const JsonEncoder.withIndent('  ').convert(savedImages),
  );
  print('Mapping saved to: $mappingPath');
}
