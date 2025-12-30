/// Dump all Device frames from C.04 Thumbnail page
///
/// Run with: flutter test test/dump_devices_test.dart --update-goldens

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwi_schema/kiwi.dart';
import 'package:kiwi_schema/flutter_renderer.dart';

void main() {
  late Map<String, dynamic> message;
  late FigmaDocument document;
  late Map<String, Map<String, dynamic>> nodeMap;

  setUpAll(() async {
    final schemaFile = File('test/fixtures/figma_schema.bin');
    final messageFile = File('test/fixtures/figma_message.bin');

    final schemaBytes = await schemaFile.readAsBytes();
    final messageBytes = await messageFile.readAsBytes();

    final schema = decodeBinarySchema(schemaBytes);
    final compiled = compileSchema(schema);
    message = compiled.decode('Message', messageBytes);
    document = FigmaDocument.fromMessage(message);
    document.imagesDirectory = '/Users/johndpope/Downloads/Apple iOS UI Kit/images';
    nodeMap = document.nodeMap;

    print('Loaded ${document.nodeCount} nodes');
  });

  group('Dump All Device Frames', () {
    testWidgets('export all devices from C.04', (tester) async {
      // Navigate to: C.04 -> 🖼️ Thumbnail (349:44491) -> Rows -> Devices
      final thumbnailFrame = nodeMap['349:44491'];
      expect(thumbnailFrame, isNotNull, reason: 'Thumbnail frame should exist');

      final frameChildren = thumbnailFrame!['children'] as List? ?? [];
      final allDevices = <Map<String, dynamic>>[];
      int rowIndex = 0;

      // Collect all Device frames from all Rows
      for (final childKey in frameChildren) {
        if (childKey is String) {
          final childNode = nodeMap[childKey];
          if (childNode != null && childNode['name'] == 'Row') {
            final rowChildren = childNode['children'] as List? ?? [];
            int deviceIndex = 0;
            for (final rowChild in rowChildren) {
              if (rowChild is String) {
                final deviceNode = nodeMap[rowChild];
                if (deviceNode != null && deviceNode['name'] == 'Device') {
                  allDevices.add({
                    'node': deviceNode,
                    'key': rowChild,
                    'row': rowIndex,
                    'index': deviceIndex,
                  });
                  deviceIndex++;
                }
              }
            }
            rowIndex++;
          }
        }
      }

      print('Found ${allDevices.length} Device frames');

      // Export each device
      for (int i = 0; i < allDevices.length; i++) {
        final deviceInfo = allDevices[i];
        final deviceNode = deviceInfo['node'] as Map<String, dynamic>;
        final row = deviceInfo['row'];
        final idx = deviceInfo['index'];
        final key = deviceInfo['key'];

        final size = deviceNode['size'] as Map?;
        final width = (size?['x'] as num?)?.toDouble() ?? 430;
        final height = (size?['y'] as num?)?.toDouble() ?? 932;

        // Try to get a meaningful name from children
        String deviceName = 'device_r${row}_i$idx';

        // Look for a text node that might have the screen name
        final deviceChildren = deviceNode['children'] as List? ?? [];
        for (final dc in deviceChildren) {
          if (dc is String) {
            final dcNode = nodeMap[dc];
            if (dcNode != null) {
              final dcName = dcNode['name'] as String? ?? '';
              if (dcName.isNotEmpty && !dcName.startsWith('🧰')) {
                // Use first meaningful child name
                deviceName = dcName.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(' ', '_').toLowerCase();
                if (deviceName.length > 30) deviceName = deviceName.substring(0, 30);
                break;
              }
            }
          }
        }

        print('[$i] Exporting: $deviceName (Row $row, Index $idx) - $key');

        final goldenKey = GlobalKey();

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            debugShowCheckedModeBanner: false,
            home: RepaintBoundary(
              key: goldenKey,
              child: Container(
                width: width * 0.5,
                height: height * 0.5,
                color: const Color(0xFF2D2D2D),
                child: FigmaNodeWidget(
                  node: deviceNode,
                  nodeMap: nodeMap,
                  scale: 0.5,
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle(const Duration(milliseconds: 100));

        // Save golden file with index to ensure unique names
        final filename = 'goldens/c04_device_${i.toString().padLeft(2, '0')}_$deviceName.png';
        await expectLater(
          find.byKey(goldenKey),
          matchesGoldenFile(filename),
        );

        print('  ✓ Saved: $filename');
      }

      print('\n✅ Exported ${allDevices.length} device frames');
    });
  });
}
