/// Debug test to render at full scale
///
/// Run with: flutter test test/debug_fullscale_test.dart --update-goldens

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwi_schema/kiwi.dart';
import 'package:kiwi_schema/flutter_renderer.dart';

void main() {
  late FigmaDocument document;
  late Map<String, Map<String, dynamic>> nodeMap;

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
  });

  testWidgets('render device 00 at full scale', (tester) async {
    // Use Device 349:50793 (the first device)
    final deviceNode = nodeMap['349:50793']!;
    final testKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: testKey,
          child: Container(
            width: 430, // Full device width
            height: 932, // Full device height
            color: const Color(0xFF333333),
            child: FigmaNodeWidget(
              node: deviceNode,
              nodeMap: nodeMap,
              scale: 1.0, // Full scale
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(testKey),
      matchesGoldenFile('goldens/debug_device_fullscale.png'),
    );
  });

  testWidgets('render just the calendar screen content at full scale', (tester) async {
    // 📱 Calendar › Location Permission instance: 473:27862
    final calendarNode = nodeMap['473:27862'];
    if (calendarNode == null) {
      fail('Calendar node not found');
    }
    final testKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: testKey,
          child: Container(
            width: 430,
            height: 932,
            color: Colors.white,
            child: FigmaNodeWidget(
              node: calendarNode,
              nodeMap: nodeMap,
              scale: 1.0,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(testKey),
      matchesGoldenFile('goldens/debug_calendar_fullscale.png'),
    );
  });
}
