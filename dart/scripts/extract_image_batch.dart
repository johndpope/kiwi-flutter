/// Extract image/batch requests from HAR file and match to Figma hashes
///
/// Run with: dart scripts/extract_image_batch.dart ~/Desktop/test.json

import 'dart:convert';
import 'dart:io';

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart extract_image_batch.dart <har_file>');
    exit(1);
  }

  final harPath = args[0];

  print('Reading HAR file: $harPath');
  final harContent = await File(harPath).readAsString();
  final har = jsonDecode(harContent) as Map<String, dynamic>;

  final log = har['log'] as Map<String, dynamic>;
  final entries = log['entries'] as List;

  print('Found ${entries.length} entries\n');

  // Find all image/batch requests
  print('=== IMAGE/BATCH REQUESTS ===\n');

  final allRequestedHashes = <String>{};
  final hashToUrl = <String, String>{};

  for (final entry in entries) {
    final request = entry['request'] as Map<String, dynamic>;
    final response = entry['response'] as Map<String, dynamic>;
    final url = request['url'] as String;

    // Check for image/batch requests
    if (url.contains('/image/batch')) {
      print('Found image/batch request:');
      print('  URL: $url');
      print('  Method: ${request['method']}');

      final postData = request['postData'] as Map<String, dynamic>?;
      if (postData != null) {
        final text = postData['text'] as String?;
        if (text != null) {
          try {
            final body = jsonDecode(text) as Map<String, dynamic>;
            final sha1s = body['sha1s'] as List?;
            if (sha1s != null) {
              print('  Request SHA1s: ${sha1s.length}');
              for (final hash in sha1s) {
                allRequestedHashes.add(hash.toString());
              }
              print('  First 5: ${sha1s.take(5).toList()}');
            }
          } catch (e) {
            print('  Error parsing request body: $e');
          }
        }
      }

      // Check response
      final content = response['content'] as Map<String, dynamic>?;
      if (content != null) {
        print('  Response size: ${content['size']}');
        final responseText = content['text'] as String?;
        if (responseText != null) {
          print('  Response text available!');
          try {
            final responseBody = jsonDecode(responseText) as Map<String, dynamic>;
            print('  Response keys: ${responseBody.keys.toList()}');

            // The response should map hashes to URLs
            for (final key in responseBody.keys) {
              final value = responseBody[key];
              if (value is String && value.contains('http')) {
                hashToUrl[key] = value;
              } else if (value is Map && value.containsKey('url')) {
                hashToUrl[key] = value['url'].toString();
              }
            }
          } catch (e) {
            print('  Error parsing response: $e');
          }
        } else {
          print('  Response text NOT captured (browser limitation)');
        }
      }
      print('');
    }
  }

  print('\n=== SUMMARY ===');
  print('Total unique hashes requested: ${allRequestedHashes.length}');
  print('Hashes with URLs found: ${hashToUrl.length}');

  // Now look for static.figma.com/uploads URLs to build an alternative mapping
  print('\n=== FIGMA UPLOAD URLS ===\n');

  final uploadUrls = <String, String>{};

  for (final entry in entries) {
    final request = entry['request'] as Map<String, dynamic>;
    final url = request['url'] as String;

    if (url.contains('static.figma.com/uploads/')) {
      final match = RegExp(r'/uploads/([a-f0-9]+)').firstMatch(url);
      if (match != null) {
        final hash = match.group(1)!;
        uploadUrls[hash] = url;
      }
    }
  }

  print('Found ${uploadUrls.length} upload URLs');
  print('Sample:');
  for (final entry in uploadUrls.entries.take(5)) {
    print('  ${entry.key}: ${entry.value}');
  }

  // Check if any of these match the requested hashes
  print('\n=== MATCHING ANALYSIS ===\n');

  int matchCount = 0;
  for (final uploadHash in uploadUrls.keys) {
    if (allRequestedHashes.contains(uploadHash)) {
      matchCount++;
      print('MATCH: $uploadHash');
    }
  }
  print('\nMatches between uploads and requests: $matchCount');

  // Save all requested hashes
  final outputPath = 'images/requested_hashes.json';
  final dir = Directory('images');
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  await File(outputPath).writeAsString(
    const JsonEncoder.withIndent('  ').convert({
      'requested_hashes': allRequestedHashes.toList(),
      'upload_urls': uploadUrls,
      'hash_to_url': hashToUrl,
    }),
  );
  print('\nSaved data to: $outputPath');
}
