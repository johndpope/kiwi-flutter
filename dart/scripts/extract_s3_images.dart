/// Extract S3 image URLs from HAR file and map to SHA1 hashes
///
/// Run with: dart scripts/extract_s3_images.dart ~/Desktop/test.json

import 'dart:convert';
import 'dart:io';

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart extract_s3_images.dart <har_file>');
    exit(1);
  }

  final harPath = args[0];
  final outputDir = 'images';

  print('Reading HAR file: $harPath');
  final harContent = await File(harPath).readAsString();
  final har = jsonDecode(harContent) as Map<String, dynamic>;

  final log = har['log'] as Map<String, dynamic>;
  final entries = log['entries'] as List;

  print('Found ${entries.length} entries\n');

  // Pattern: https://s3-alpha-sig.figma.com/img/XXXX/XXXX/HASH
  // The XXXX/XXXX is the first 8 chars of hash split into 4/4
  final hashToUrl = <String, String>{};
  final imagePattern = RegExp(r's3-alpha-sig\.figma\.com/img/([a-f0-9]{4})/([a-f0-9]{4})/([a-f0-9]+)');

  for (final entry in entries) {
    final request = entry['request'] as Map<String, dynamic>;
    final url = request['url'] as String;

    final match = imagePattern.firstMatch(url);
    if (match != null) {
      final part1 = match.group(1)!;
      final part2 = match.group(2)!;
      final part3 = match.group(3)!;

      // Reconstruct the full hash
      final fullHash = '$part1$part2$part3';

      // Store the full URL (with signature)
      hashToUrl[fullHash] = url;
    }
  }

  print('Found ${hashToUrl.length} unique image URLs\n');

  // Create output directory
  final dir = Directory(outputDir);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  // Save hash to URL mapping
  final mappingFile = File('$outputDir/hash_to_url.json');
  await mappingFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(hashToUrl),
  );
  print('Saved mapping to: ${mappingFile.path}');

  // Download images
  print('\n=== Downloading Images ===\n');

  final client = HttpClient();
  int downloaded = 0;
  int skipped = 0;
  int failed = 0;

  for (final entry in hashToUrl.entries) {
    final hash = entry.key;
    final url = entry.value;
    final outputPath = '$outputDir/$hash';

    // Skip if already exists
    if (File(outputPath).existsSync()) {
      skipped++;
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

        if (downloaded <= 20) {
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
  print('Total URLs found: ${hashToUrl.length}');
  print('Downloaded: $downloaded');
  print('Skipped (exists): $skipped');
  print('Failed: $failed');
  print('Output directory: $outputDir');

  // Now cross-reference with our Figma file hashes
  print('\n=== Cross-Reference with Figma File ===\n');

  try {
    final requestedHashesFile = File('$outputDir/missing_hashes.json');
    if (requestedHashesFile.existsSync()) {
      final data = jsonDecode(await requestedHashesFile.readAsString());
      final missingHashes = (data['hashes'] as List).cast<String>().toSet();

      int matched = 0;
      int stillMissing = 0;
      final matchedHashes = <String>[];
      final unmatchedHashes = <String>[];

      for (final hash in missingHashes) {
        if (hashToUrl.containsKey(hash)) {
          matched++;
          matchedHashes.add(hash);
        } else {
          stillMissing++;
          unmatchedHashes.add(hash);
        }
      }

      print('Figma file needs: ${missingHashes.length} images');
      print('Found in HAR: $matched');
      print('Still missing: $stillMissing');

      if (stillMissing > 0 && stillMissing <= 10) {
        print('\nStill missing hashes:');
        for (final h in unmatchedHashes) {
          print('  $h');
        }
      }
    }
  } catch (e) {
    print('Could not cross-reference: $e');
  }
}
